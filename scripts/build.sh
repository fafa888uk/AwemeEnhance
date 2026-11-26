#!/usr/bin/env bash
set -euo pipefail
python3 tools/environment.py --require-ios
python3 tools/audit.py
python3 -m unittest discover -s Tests -v
bash scripts/native-tests.sh
make clean
make -j2 package FINALPACKAGE=1 TARGET_CODESIGN=/usr/bin/codesign 'TARGET_CODESIGN_FLAGS=--force --sign -'
mkdir -p dist
test -f .theos/obj/AwemeEnhance.dylib
cp .theos/obj/AwemeEnhance.dylib dist/AwemeEnhance.dylib
debs=(packages/*.deb)
[[ ${#debs[@]} -eq 1 && -f "${debs[0]}" ]]
cp "${debs[0]}" dist/AwemeEnhance.deb
xcrun lipo -verify_arch arm64 dist/AwemeEnhance.dylib
codesign --verify --strict dist/AwemeEnhance.dylib
python3 tools/release.py --collect
python3 tools/release.py --verify
