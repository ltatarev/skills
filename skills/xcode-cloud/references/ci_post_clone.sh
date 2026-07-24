#!/usr/bin/env bash
#
# Xcode Cloud runs this right after cloning, before it resolves the workspace.
# The clone carries neither node_modules/ nor <ios>/Pods/ (both gitignored), so
# without this the Pods xcconfig is absent, PODS_ROOT expands to "" and the
# archive dies on "Unable to load contents of file list: '/Target Support
# Files/...'". Everything the build phases need gets installed here.
#
# CocoaPods comes from a bottle rather than through bundler because the build
# image already has its own ruby linked, and a second keg-only one alongside it
# leaves native gems probing one ruby's headers against the other's library —
# which is how bigdecimal ends up redeclaring what it already has. A bottle
# needs no compiler, so none of that can happen. Which pods get built is fixed
# by Podfile.lock either way; only the tool itself floats.
#
# TEMPLATE — three things to check before committing this into a project:
#   1. IOS_DIR below, if the Xcode project is not in ios/
#   2. NODE_FORMULA below, against the repo's .nvmrc / engines.node
#   3. the package-manager block, if the repo is not on yarn
# Everything else is derived from the repo at run time.
#
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
IOS_DIR="$REPO_ROOT/ios"
NODE_FORMULA="node@22"

cd "$REPO_ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1
# CocoaPods reads UTF-8 podspecs and trips over the ASCII default of a CI shell.
export LANG=en_US.UTF-8

echo "--- Toolchain"
# corepack is its own formula because node 25 dropped it from the distribution —
# node alone gets you "corepack: command not found" the moment yarn is needed.
# The formula links only corepack itself; the yarn shim comes from the
# `corepack enable` below, so both steps are load-bearing. Only drop it if the
# repo is on npm and never invokes corepack.
brew install "$NODE_FORMULA" corepack cocoapods
export PATH="$(brew --prefix "$NODE_FORMULA")/bin:$PATH"
node --version
pod --version

# Build phases run in their own shell that never sees the PATH above, and
# .xcode.env falls back to `command -v node` — pin the absolute path instead.
# .xcode.env.local is gitignored by the React Native template precisely so CI
# can own it.
printf 'export NODE_BINARY=%s\n' "$(command -v node)" > "$IOS_DIR/.xcode.env.local"

echo "--- JavaScript dependencies"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
# Yarn extracts archives on worker threads by default, which walks straight into the
# async_hooks corruption bug in node 22 and takes the fetch step down with it. Doing
# that work on the event loop instead costs a few seconds and does not crash. It
# lives here rather than in .yarnrc.yml so local installs keep the faster path.
export YARN_TASK_POOL_MODE=async
corepack enable
corepack prepare --activate
yarn install --immutable
# npm:  npm ci
# pnpm: corepack enable && pnpm install --frozen-lockfile

echo "--- React Native prebuilt tarballs"
# pod install pulls RN's prebuilt tarballs from Maven with a bare, single-shot
# curl — one "Connection reset by peer" aborts the whole archive. Two separate
# scripts do this: rndependencies.rb for the "dependencies" artifacts and
# rncore.rb for the "core" ones, four downloads in total. Both check the same
# shared cache first, so we seed it here with a curl that actually retries; a
# hit then skips the download. A corrupt/partial prefetch just fails RN's SHA
# check and falls back to the old behaviour, never worse.
#
# Only applies to RN versions that ship prebuilt artifacts (0.86+). On an older
# RN the URLs 404, the loop reports each failure and moves on, and pod install
# builds from source as it always did — so this block is safe to leave in.
RN_VERSION="$(node -p "require('react-native/package.json').version")"
RN_CACHE_DIR="$HOME/Library/Caches/ReactNative"
RN_MAVEN="${ENTERPRISE_REPOSITORY:-https://repo1.maven.org/maven2}"
mkdir -p "$RN_CACHE_DIR"
for artifact in dependencies core; do
  for build_type in debug release; do
    dest="$RN_CACHE_DIR/reactnative-${artifact}-${RN_VERSION}-${build_type}.tar.gz"
    [ -f "$dest" ] && continue
    url="$RN_MAVEN/com/facebook/react/react-native-artifacts/${RN_VERSION}/react-native-artifacts-${RN_VERSION}-reactnative-${artifact}-${build_type}.tar.gz"
    echo "Prefetching ${artifact} ${build_type} tarball into shared cache"
    curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
      --connect-timeout 30 --max-time 900 \
      -A "react-native-${RN_VERSION}" "$url" -o "${dest}.download" \
      && mv "${dest}.download" "$dest" \
      || { echo "Prefetch of ${artifact} ${build_type} failed; leaving it for pod install to retry"; rm -f "${dest}.download"; }
  done
done

# Hermes is two more tarballs, same shared cache but a different Maven coordinate
# and the same bare curl in hermes-utils.rb. Its version is not RN's: the podspec
# reads version.properties and takes the V1 name unless RCT_HERMES_V1_ENABLED=0.
# A wrong guess only wastes the prefetch — RN verifies the SHA1 of anything it
# finds cached and re-downloads what fails.
HERMES_PROPS="$REPO_ROOT/node_modules/react-native/sdks/hermes-engine/version.properties"
if [ -f "$HERMES_PROPS" ]; then
  if [ "${RCT_HERMES_V1_ENABLED:-1}" = "0" ]; then
    HERMES_KEY="HERMES_VERSION_NAME"
  else
    HERMES_KEY="HERMES_V1_VERSION_NAME"
  fi
  HERMES_VERSION="$(sed -n "s/^${HERMES_KEY}=//p" "$HERMES_PROPS" | tr -d '[:space:]')"
  for build_type in debug release; do
    [ -n "$HERMES_VERSION" ] || continue
    dest="$RN_CACHE_DIR/hermes-ios-${HERMES_VERSION}-${build_type}.tar.gz"
    [ -f "$dest" ] && continue
    url="$RN_MAVEN/com/facebook/hermes/hermes-ios/${HERMES_VERSION}/hermes-ios-${HERMES_VERSION}-hermes-ios-${build_type}.tar.gz"
    echo "Prefetching hermes ${build_type} tarball into shared cache"
    curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
      --connect-timeout 30 --max-time 900 \
      -A "react-native-${HERMES_VERSION}" "$url" -o "${dest}.download" \
      && mv "${dest}.download" "$dest" \
      || { echo "Prefetch of hermes ${build_type} failed; leaving it for pod install to retry"; rm -f "${dest}.download"; }
  done
fi

echo "--- CocoaPods CDN"
# If Podfile.lock has a SPEC REPOS section, pod install has to reach
# cdn.cocoapods.org, and on a runner with no ~/.cocoapods the first thing it does
# is probe CocoaPods-version.yml to work out what kind of repo that URL is — one
# OpenURI call, no retry. A TLS reset there fails the archive with "Couldn't
# determine repo type for URL", under the same red-herring Rosetta advice.
# Creating the repo is all `pod repo add-cdn trunk` does, and it makes the probe
# unnecessary: the source is found by URL instead. Later CDN fetches retry on
# their own five times. Harmless when nothing resolves from the CDN.
CP_TRUNK_DIR="$HOME/.cocoapods/repos/trunk"
mkdir -p "$CP_TRUNK_DIR"
printf 'https://cdn.cocoapods.org/' > "$CP_TRUNK_DIR/.url"
if [ ! -f "$CP_TRUNK_DIR/CocoaPods-version.yml" ]; then
  curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
    --connect-timeout 30 --max-time 120 \
    https://cdn.cocoapods.org/CocoaPods-version.yml \
    -o "$CP_TRUNK_DIR/CocoaPods-version.yml.download" \
    && mv "$CP_TRUNK_DIR/CocoaPods-version.yml.download" "$CP_TRUNK_DIR/CocoaPods-version.yml" \
    || { echo "Could not seed CDN metadata; pod install will fetch it (with retries)"; rm -f "$CP_TRUNK_DIR/CocoaPods-version.yml.download"; }
fi

echo "--- CocoaPods dependencies"
cd "$IOS_DIR"
# The prefetches above remove the single-shot fetches we know about; pod install
# still makes network calls we do not control. It is idempotent, so re-running it
# after a transient failure costs a minute and saves a whole archive.
POD_INSTALL_ATTEMPTS=3
for attempt in $(seq 1 "$POD_INSTALL_ATTEMPTS"); do
  if pod install; then
    break
  fi
  if [ "$attempt" -eq "$POD_INSTALL_ATTEMPTS" ]; then
    echo "pod install failed $POD_INSTALL_ATTEMPTS times; giving up"
    exit 1
  fi
  echo "pod install failed (attempt ${attempt}/${POD_INSTALL_ATTEMPTS}); retrying in $((attempt * 15))s"
  sleep "$((attempt * 15))"
done

echo "--- Post-clone complete"
