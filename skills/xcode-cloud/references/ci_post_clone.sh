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

echo "--- CocoaPods dependencies"
cd "$IOS_DIR"
pod install

echo "--- Post-clone complete"
