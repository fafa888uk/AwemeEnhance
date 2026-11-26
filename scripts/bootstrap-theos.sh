#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'An Apple-hosted macOS/Xcode environment is required.' >&2; exit 1; }
command -v xcodebuild >/dev/null
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
command -v perl >/dev/null
command -v make >/dev/null
command -v dpkg-deb >/dev/null || brew install dpkg
export THEOS="${THEOS:-$HOME/theos}"
pin=$(python3 -c 'import json; print(json.load(open("dependencies.lock.json"))["theos"]["sha"])')
if [[ ! -d "$THEOS/.git" ]]; then
  [[ ! -e "$THEOS" ]] || { echo 'THEOS destination exists and is not a checkout' >&2; exit 1; }
  git clone --no-checkout https://github.com/theos/theos.git "$THEOS"
fi
git -C "$THEOS" fetch origin "$pin" --depth=1
git -C "$THEOS" checkout --detach "$pin"
git -C "$THEOS" submodule update --init --recursive --depth=1
[[ "$(git -C "$THEOS" rev-parse HEAD)" == "$pin" ]]
[[ -f "$THEOS/makefiles/common.mk" && -f "$THEOS/bin/logos.pl" ]]
# Use Xcode's SDK. Do not download a redistributable iOS SDK from an unknown mirror.
if [[ -n "${GITHUB_ENV:-}" ]]; then echo "THEOS=$THEOS" >> "$GITHUB_ENV"; fi
echo 'Pinned Theos and local Xcode SDK are ready.'
