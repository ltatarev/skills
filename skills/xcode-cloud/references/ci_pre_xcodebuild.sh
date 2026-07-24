#!/usr/bin/env bash
#
# Runs after the clone, before xcodebuild.
#
# The build number in a React Native template is hardcoded to 1 in every
# configuration, which is fine for exactly one upload — App Store Connect
# rejects the next build that reuses a number for the same marketing version.
# Xcode Cloud hands us a counter that increments per build, so stamp that in.
#
# Every configuration is rewritten on purpose. Each target has at least a debug
# and a release config, and an app extension must carry the same build number as
# its host or App Store Connect refuses the upload — so they have to move
# together. MARKETING_VERSION is deliberately left alone; bump that by hand when
# you actually ship a version.
#
# TEMPLATE — generic as written: it globs for the single .xcodeproj under
# IOS_DIR. Set PROJECT explicitly if the repo has more than one.
#
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
IOS_DIR="$REPO_ROOT/ios"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is unset — leaving the build number as it is"
  exit 0
fi

shopt -s nullglob
projects=("$IOS_DIR"/*.xcodeproj)
shopt -u nullglob
if [ "${#projects[@]}" -ne 1 ]; then
  echo "error: expected exactly one .xcodeproj in $IOS_DIR, found ${#projects[@]}" >&2
  exit 1
fi
PROJECT="${projects[0]}/project.pbxproj"

sed -i '' -E \
  "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" \
  "$PROJECT"

# A silent no-op here ships a duplicate build number and is rejected on upload,
# by which point the archive has already burned its compute — fail loudly instead.
stamped="$(grep -c "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};" "$PROJECT" || true)"
if [ "$stamped" -eq 0 ]; then
  echo "error: no build number was stamped — the project layout must have changed" >&2
  exit 1
fi

echo "Build number set to $CI_BUILD_NUMBER across $stamped configurations"
