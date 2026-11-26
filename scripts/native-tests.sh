#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
cc -std=c11 -Wall -Wextra -Werror Tests/policy.c Sources/Core/AEPolicy.c -lm -o artifacts/policy-tests
artifacts/policy-tests
if [[ "$(uname -s)" == Darwin ]]; then
  clang -c Sources/Core/AEPolicy.c -o artifacts/policy.o
  clang -fobjc-arc -Wall -Wextra -framework Foundation -I Sources Tests/config.m Sources/Core/AEConfig.m Sources/Core/AELog.m artifacts/policy.o -o artifacts/config-tests
  artifacts/config-tests
  sdk=$(xcrun --sdk iphoneos --show-sdk-path)
  for file in Sources/Core/*.m Sources/Modules/*.m Sources/Spark/*.m Sources/Settings/*.m; do
    xcrun --sdk iphoneos clang --analyze -arch arm64 -miphoneos-version-min=15.0 -isysroot "$sdk" -fobjc-arc -I Sources -Xanalyzer -analyzer-output=text "$file"
  done
fi
