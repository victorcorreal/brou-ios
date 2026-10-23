# Build Brou for iPhone and iPad

## Simulator, no signing secrets

Use full Xcode and XcodeGen. The deployment target is iOS 18; current validation uses Xcode 27.1. Install XcodeGen with `brew install xcodegen` if needed.

iPhone Duo needs the iOS 27.1 SDK (Xcode 27.1 or later). Built with an older SDK, Brou runs there in a compatibility frame beside the status bar instead of using the whole screen.

```sh
xcodegen generate
xcodebuild -project Brou.xcodeproj -scheme Brou \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= build
```

Select an available iPhone/iPad simulator in Xcode to run. The project and scheme are Brou; the product is Brou.app. The simulator is not evidence of real iCloud sync. Do not install a simulator product on a physical phone.

The unsigned product above stops at launch: CloudKit wants its entitlement. To run it from the command line, sign it ad hoc instead, which keeps the entitlements and needs no account:

```sh
xcodebuild -project Brou.xcodeproj -scheme Brou \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= build
xcrun simctl install booted build/Simulator/Build/Products/Debug-iphonesimulator/Brou.app
```

On iPhone Duo, check both screens, closed and open, in both orientations, with the keyboard up for the address field and for a page's own field. Xcode's Device Hub opens, closes and folds the simulated device.

## Your own Apple Developer account

Full continuity needs a paid Apple Developer team and matching configuration in [Brou for Mac](https://github.com/victorcorreal/brou/blob/main/Docs/BUILDING.md). Signing secrets and provisioning profiles are not shipped in either repo.

Choose your own App ID (e.g. com.example.brou), container (iCloud.com.example.brou) and shared group. The group uses the actual App Identifier Prefix from your provisioning profile, which may differ from a legacy team's ID.

| File | Change |
| --- | --- |
| `project.yml` | DEVELOPMENT_TEAM, bundleIdPrefix, PRODUCT_BUNDLE_IDENTIFIER, CFBundleURLName, container and keychain group properties |
| `Sources/CloudSync.swift` | container constant |
| `Sources/Vault.swift` | full group constant, matching the profile and Mac |

Regenerate with `xcodegen generate`; it also regenerates Brou.entitlements and Info.plist from the project properties. In Xcode select your team, use automatic signing, enable iCloud/CloudKit and Keychain Sharing for your App ID and connect a registered device. Use the same container/group in Mac.

The `com.apple.developer.web-browser` entitlement was approved for the maintainer's current identity. That approval does not transfer to your account. Apply to Apple for your own default-browser entitlement, or remove that property from project.yml in your development checkout and regenerate. Without it you can still test ordinary browsing with iCloud capabilities that your own profile allows; do not expect default-browser selection or Add to Home Screen. Do not remove the iCloud entitlement from a physical-device build: the current iOS CloudSync startup expects a correctly provisioned container.

```sh
xcodebuild -project Brou.xcodeproj -scheme Brou -configuration Debug \
  -destination 'id=YOUR-DEVICE-UDID' -derivedDataPath build/Device \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device YOUR-DEVICE-UDID \
  build/Device/Build/Products/Debug-iphoneos/Brou.app
```

Apple controls capability availability and provisioning. A successful simulator compilation cannot verify your team's approvals or physical iCloud access. Use disposable data for first testing. Never commit certificates, profiles, exports, cookies or private account data; the ignore file is a guardrail, not a substitute for reviewing changes.

## Existing installations and public distribution

The maintainer build retains cat.correal.search, its group/container, Search labels/data directory and CloudKit Development. Updating over it preserves those identities; another team's build is a separate app and cannot read its data. Do not uninstall just to update.

There is no generally installable IPA with this source preview. Public TestFlight/App Store distribution needs Apple review and a coordinated Production CloudKit schema/data plan; changing the environment does not migrate records. See [SYNC.md](SYNC.md). No credentials or personal development profiles belong in a GitHub Release.
