#!/bin/sh
# Pushes SD release artifacts to the registry. Drone gives the settings as PLUGIN_* variables.
#   mode: push (default)  the git tree of the tag, as one tar+gzip layer. Needs repository and artifact_type.
#   mode: sync            the sysext and Flatcar files that immutable.yaml pins. Optional: file.
#   username, password    the robot account. registry defaults to registry.sighup.io.
# The registry tags are immutable: a tag that already has the same files is skipped, other files fail.
set -eu

REGISTRY=${PLUGIN_REGISTRY:-registry.sighup.io}
TAB=$(printf '\t')
PH="" CPH=""
if [ "${PLUGIN_PLAIN_HTTP:-false}" = true ]; then PH=--plain-http CPH=--to-plain-http; fi # Test registries only.

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Prints "<arch> <title> <digest>" for each layer of a remote tag, sorted. "-" is the arch of a single manifest.
remote_layers() {
  m=$(oras manifest fetch $PH "$1" 2>/dev/null) || return 1
  case $(echo "$m" | yq -p json -r '.mediaType') in
  *index*)
    echo "$m" | yq -p json -r '.manifests[] | .platform.architecture + " " + .digest' |
      while read -r arch digest; do
        oras manifest fetch $PH "${1%:*}@$digest" |
          yq -p json -r ".layers[] | \"$arch \" + .annotations.\"org.opencontainers.image.title\" + \" \" + .digest"
      done
    ;;
  *) echo "$m" | yq -p json -r '.layers[] | "- " + .annotations."org.opencontainers.image.title" + " " + .digest' ;;
  esac | sort
}

# Returns 0 when the tag has exactly the files in $2, 1 when the tag does not exist. Stops for other files.
already_pushed() {
  remote_layers "$1" >"$WORK/remote" || return 1
  if cmp -s "$2" "$WORK/remote"; then
    echo "Skip $1: it has the same files."
    return 0
  fi
  echo "ERROR: $1 exists with other files. The tag is immutable, release a new version."
  echo "Expected:" && cat "$2"
  echo "In the registry:" && cat "$WORK/remote"
  exit 1
}

push_source() {
  : "${DRONE_TAG:?the push mode runs only on a tag}"
  : "${PLUGIN_REPOSITORY:?set repository, for example sd/modules/auth}"
  case ${PLUGIN_ARTIFACT_TYPE:-} in
  distribution | module | installer) ;;
  *) echo "ERROR: artifact_type must be distribution, module or installer." && exit 1 ;;
  esac
  ref="$REGISTRY/$PLUGIN_REPOSITORY:$DRONE_TAG"

  git archive --format=tar.gz -o "$WORK/source.tar.gz" HEAD
  echo "- source.tar.gz sha256:$(sha256sum "$WORK/source.tar.gz" | cut -d' ' -f1)" >"$WORK/want"
  already_pushed "$ref" "$WORK/want" && return

  created=$(git log -1 --format=%cI HEAD)
  cd "$WORK"
  oras push $PH "$ref" \
    --artifact-type "application/vnd.sighup.$PLUGIN_ARTIFACT_TYPE.v1" \
    --annotation "org.opencontainers.image.created=$created" \
    --annotation "org.opencontainers.image.source=https://github.com/${DRONE_REPO:-}" \
    --annotation "org.opencontainers.image.revision=${DRONE_COMMIT_SHA:-}" \
    --annotation "org.opencontainers.image.version=$DRONE_TAG" \
    source.tar.gz:application/vnd.sighup.source.v1.tar+gzip
  cd - >/dev/null
}

# Pushes one repo:tag from the lines "repo tag arch title sha256 url" in $1, as an index with one manifest for each arch.
push_files() {
  repo=$1 tag=$2 lines=$3
  case $repo in
  sd/sysext/*) type=sysext layer=application/vnd.sighup.sysext.v1.raw ;;
  *) type=flatcar layer=application/vnd.sighup.flatcar.v1.file ;;
  esac
  ref="$REGISTRY/$repo:$tag"
  awk -F "$TAB" '{ print $3, $4, "sha256:" $5 }' "$lines" | sort >"$WORK/want"
  already_pushed "$ref" "$WORK/want" && return

  layout="$WORK/layout"
  rm -rf "$layout" "$WORK/files"
  for arch in $(cut -f3 "$lines" | sort -u); do
    dir="$WORK/files/$arch"
    mkdir -p "$dir"
    awk -F "$TAB" -v a="$arch" '$3 == a' "$lines" >"$WORK/arch"
    while IFS="$TAB" read -r _ _ _ title sum url; do
      echo "Download $url"
      curl -fsSL -o "$dir/$title" "$url"
      echo "$sum  $dir/$title" | sha256sum -c -
    done <"$WORK/arch"
    (
      cd "$dir"
      set --
      for title in $(cut -f4 "$WORK/arch"); do set -- "$@" "$title:$layer"; done
      oras push --oci-layout "$layout:$tag-$arch" --artifact-platform "linux/$arch" \
        --artifact-type "application/vnd.sighup.$type.v1" \
        --annotation "org.opencontainers.image.version=$tag" "$@" >/dev/null
    )
  done
  # shellcheck disable=SC2046 # One argument for each arch.
  oras manifest index create --oci-layout "$layout:$tag" --artifact-type "application/vnd.sighup.$type.v1" \
    $(cut -f3 "$lines" | sort -u | sed "s/^/$tag-/") >/dev/null
  oras cp $CPH --from-oci-layout "$layout:$tag" "$ref"
  rm -rf "$layout" "$WORK/files"
}

sync_files() {
  file=${PLUGIN_FILE:-immutable.yaml}
  # One line for each file: repo, tag, arch, title, sha256, url. x86-64 becomes amd64.
  yq -r '(
    (.kubernetes[].sysext[] | .name as $n | .version as $v | .arch | to_entries[] |
      ["sd/sysext/" + $n, $v, .key, (.value.url | split("/") | .[-1]), .value.sha256, .value.url]),
    (.kubernetes[].flatcar | .version as $v | .arch | to_entries[] | .key as $a | .value | to_entries[] |
      ["sd/flatcar/" + (.key | sub("^(kernel|initrd|image)$", "boot")), $v, $a, .value.filename, .value.sha256, .value.url]))
    | .[2] |= sub("^x86-64$", "amd64") | @tsv' "$file" |
    sort -t "$TAB" -u -k1,5 >"$WORK/all"

  conflicts=$(cut -f1-4 "$WORK/all" | uniq -d)
  if [ -n "$conflicts" ]; then
    echo "ERROR: $file pins these files with two different sha256 values:" && echo "$conflicts"
    exit 1
  fi

  cut -f1,2 "$WORK/all" | uniq | while IFS="$TAB" read -r repo tag; do
    awk -F "$TAB" -v r="$repo" -v t="$tag" '$1 == r && $2 == t' "$WORK/all" >"$WORK/group"
    push_files "$repo" "$tag" "$WORK/group"
  done
}

if [ -n "${PLUGIN_USERNAME:-}" ]; then
  printf '%s' "${PLUGIN_PASSWORD:?}" | oras login $PH -u "$PLUGIN_USERNAME" --password-stdin "$REGISTRY"
fi

case ${PLUGIN_MODE:-push} in
push) push_source ;;
sync) sync_files ;;
*) echo "ERROR: mode must be push or sync." && exit 1 ;;
esac
