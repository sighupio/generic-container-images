import os
import re
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

    # We use <version>-rev.X for revisions, for example in the on-premises installer
    # The library considers '-rev.X' a prerelease. An rc of a revision (v1.36.5-rev.1-rc.0) uses the notes of v1.36.5-rev.1.
    if sversion.prerelease and sversion.prerelease[0] == "rev":
        revision = re.sub(r"-rc\.\d+$", "", version)
        release_notes_file = f"./docs/releases/v{revision}.md"

    print(f"Copying from {release_notes_file} to {RELEASE_NOTES_FILE_PATH}")
    copyfile(release_notes_file, RELEASE_NOTES_FILE_PATH)
