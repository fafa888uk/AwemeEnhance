# AwemeEnhance

[简体中文](README.md) · Original code: [MIT](LICENSE)

**Experimental development snapshot, NOT an accepted enhanced Douyin build.** Targets: Douyin 41.2.0 / 41.3.0, iOS 15+, arm64. Neither target is device-validated. No original, decrypted or modified third-party IPA, account information, certificates or private keys belong in this public repository.

Implemented source includes modular recommendation filters, bitrate candidate preference (not forced quality), a single-player-stack speed adapter, navigation/button styling, native progress visibility, settings, local owned-original export, local Spark reminders and manual confirmation. Runtime existence/ABI checks are not proof of compatibility. In-app permission-aware original-video export remains **unimplemented**. **Automatic messaging is NOT implemented**; reminders and clipboard preparation never mean delivery success. No cookie/session extraction, browser automation, private IM calls, anti-detection or paid-access bypass is integrated.

## Build

Run **Build** from GitHub Actions using standard `macos-latest`, Xcode's installed iOS SDK and pinned Theos. **Test** and **Security** use `ubuntu-latest`. No paid runner, certificate purchase, paid API or third-party build service. Original-plugin artifacts expire after three days. Version tags must match `VERSION`; Releases remain prereleases until device acceptance. Dependabot and upstream checks propose review PRs, never automatic merges.

```bash
export THEOS="$HOME/theos"
bash scripts/bootstrap-theos.sh
bash scripts/build.sh
```

## Private unsigned IPA integration

Provide a lawfully obtained IPA you are authorized to modify, a verified plugin and an independently confirmed source SHA256:

```bash
python tools/ipa.py --ipa "/private/source.ipa" --version 41.3.0 \
  --dylib "/private/AwemeEnhance.dylib" \
  --output "private/output/AwemeEnhance_41.3.0.ipa" \
  --expected-sha256 "64-hex-source-digest" --acknowledge-modification-rights
```

The stdlib-only integration tool works on Windows/macOS/Linux. It checks archive safety, CRC, exact app/version, encryption, architecture/subtype, dependency resolution and header padding, injects only the original standalone library, removes invalidated signatures and repackages an unsigned IPA. It does not decrypt FairPlay or establish malware-free provenance or installation eligibility. Re-signing all nested code, correct entitlements and device testing remain required.

**Build IPA** can use an existing protected private S3 bucket and scoped OIDC role; see [setup](docs/PRIVATE_BUILD.md). There is no public IPA artifact/cache/release step. Cloud storage/transfer can incur fees and is **disabled by default**, requiring a separate explicit cost authorization. Use local integration to avoid external storage charges. No cloud resource or billing setting is created.

```bash
python -m unittest discover -s Tests -v
python tools/audit.py
```

Synthetic fixture tests are not real-app or device tests. See [research](docs/RESEARCH.md), [compatibility](docs/COMPATIBILITY.md), [test report](docs/TEST_REPORT.md) and [signing](docs/SIGNING.md). All modules default off. Enable experimental adapters separately and restart. Open native settings with a two-finger long press. No telemetry or runtime network client.
