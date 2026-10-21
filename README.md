<div align="center">
  <img src="Brand/Brou.png" width="104" alt="Brou — white steam on black">
  <h1>Brou for iPhone and iPad</h1>
  <p>A little room to read. And a way to pick it up again.</p>
  <p><a href="Docs/BUILDING.md">Build</a> · <a href="Docs/SYNC.md">Continuity</a> · <a href="Docs/PRIVACY.md">Privacy</a> · <a href="CONTRIBUTING.md">Contribute</a></p>
</div>

The native iPhone companion to [Brou for Mac](https://github.com/victorcorreal/brou). Read with less clutter, keep your bookmarks close and share Brou credentials between your devices.

Maintained by [Victor Correal](https://github.com/victorcorreal). Based in part on [Search by Office Commun](https://github.com/driceroland/Search), under MIT. **Brou** means broth in Catalan. The shared icon is a single white wisp of steam on black.

## Small by design

- **Ready to search.** On launch and each new tab, the cursor is in the address field and the keyboard is ready. A small blue **…** menu at the bottom right opens bookmarks, tabs and settings. Previous tabs remain available.
- **Comfortable reading.** Dark Pages, text-only reading and a page background that continues behind the status bar.
- **Your saved web, on both devices.** Bookmark folders via CloudKit and Brou credentials via iCloud Keychain. Password suggestions use the current host, keeping CMS, development and root-site accounts separate. The historical `www`/root alias remains.
- **Native browsing.** WebKit, tabs, back/forward gestures, a content blocker and sharing. iPad uses a sidebar. The approved maintainer build supports default-browser selection and Add to Home Screen.

History, cookies and sessions remain local. There is no iPhone private-browsing mode or dedicated download manager in this version. The browser entitlement does not grant access to Apple's Passwords database.

## Try the source preview

Requires full Xcode, XcodeGen and iOS 18 or later. Current builds are checked with Xcode 27. No private signing files are needed to compile for the simulator:

```sh
git clone https://github.com/victorcorreal/brou-ios.git
cd brou-ios
xcodegen generate
xcodebuild -project Brou.xcodeproj -scheme Brou \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= build
```

Then select an available simulator and run the Brou scheme in Xcode. The project, target and product are named **Brou**. A simulator build does not validate iCloud continuity. [Build and Apple signing guide](Docs/BUILDING.md) explains physical devices and your own account.

There is no public TestFlight/App Store release of this source preview. The existing maintainer development distribution is tied to registered devices and uses **CloudKit Development**. Do not mistake it for a generally installable release.

## Continuity and privacy

The paired apps use the same iCloud account, CloudKit container and keychain access group. Bookmarks fetch on launch, foreground activation and every five minutes. Credentials use the system's synchronizable keychain. They are separate from Apple's Passwords app.

Creating, renaming and deleting a bookmark, plus credential save/read/delete in both directions, were verified on a physical Mac and iPhone. Offline changes, concurrent conflicts and account switching remain unverified. See [sync design](Docs/SYNC.md) and [verification](Docs/VERIFICATION.md).

Brou adds no analytics or maintainer telemetry. Websites, Google searches and iCloud still make network requests. The blocker is not a promise of anonymity. [Privacy and network notes](Docs/PRIVACY.md).

## Contribute

[Report a bug](https://github.com/victorcorreal/brou-ios/issues/new/choose), using synthetic data and redacted screenshots. Never send saved passwords, cookies or browsing history. [Security reports](SECURITY.md) are private.

```sh
python3 Tests/UpstreamRegression/run.py
swiftc Sources/Scripts.swift Tests/TopColorHarness.swift -o build/top-colour
build/top-colour
```

These regression harnesses run production logic against synthetic keychain data and local WebKit pages on macOS. They do not replace physical iPhone tests. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License and origin

[MIT](LICENSE), with original Office Commun notices and Victor Correal's contributions preserved. [NOTICE](NOTICE) maps the reused code to its current paths. This is an independent companion app, not an Office Commun release. Read [Brou 1.1.0 notes](Docs/RELEASE_1.1.0.md), [upstream maintenance](Docs/UPSTREAM_INTEGRATION.md) and [brand provenance](Brand/README.md).

[Project naming and compatibility](Docs/NAME_MIGRATION.md).
