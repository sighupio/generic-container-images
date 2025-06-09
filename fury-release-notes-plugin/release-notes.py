import os
from shutil import copyfile

import semantic_version  # pylint: disable=import-error

RELEASE_NOTES_FILE_PATH = os.getenv("RELEASE_NOTES_FILE_PATH")
DRONE_TAG = os.getenv("DRONE_TAG")

if __name__ == "__main__":
    version = DRONE_TAG.lstrip('v')  # Remove the v prefix if present

    sversion = semantic_version.Version(version)

    major = sversion.major
    minor = sversion.minor
    patch = sversion.patch

    # This allows us to use the "final" release notes also for Release Candidates
    release_notes_file = f"./docs/releases/v{major}.{minor}.{patch}.md"

    # We use <version>-rev.1 for revisions:
    if sversion.prerelease[0] == "rev":
        release_notes_file = f"./docs/releases/v{version}.md"

    print(f"Copying from {release_notes_file} to {RELEASE_NOTES_FILE_PATH}")
    copyfile(release_notes_file, RELEASE_NOTES_FILE_PATH)
