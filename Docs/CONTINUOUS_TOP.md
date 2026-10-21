# Continuous page background below the status bar

21 October 2026 — development build `1792583760`.

The status area extends the rendered background at the page's upper edge. It no longer forces pure black whenever Dark Pages is enabled or prefers theme metadata over a different visible header. Three samples across the top avoid adopting the colour of a small central logo or sign-in button. Header, style and scroll changes update the colour; equal colours send no extra messages. The native backdrop uses that same colour.

The status area remains opaque: scrolling text and images do not overlap the clock or cover a site's fixed header. This extends a background colour, not a copy of images or a gradient. Before the page reports its colour, Brou uses theme metadata or the existing dark/system fallback. A committed navigation discards the previous document's sample.

## Verification

- Release archive, development IPA export, code-signature verification and installation over the existing iPhone app completed. Bundle ID, signing team, storage, CloudKit and keychain identities are unchanged.
- `Tests/TopColorHarness.swift`: **7 checks passed** in macOS WebKit, with local HTML/CSS and a nonpersistent data store. Covers a grey normal header over a black root, a differently coloured central button, dynamic header colours, sticky and scrolling headers, light/dark style changes and suppression of duplicate messages.
- The same fixture fails with the previous script: it reports black instead of the visible grey header. This reproduces the colour-selection regression without accessing a personal account.
- The fixture window stays off screen. Its test-only animation-frame driver uses timers because off-screen WebKit suspends animation frames. These checks exercise DOM/CSS colour sampling; they do not verify iPhone safe-area layout or frame scheduling.
- Victor confirmed on the physical iPhone that the reported Google page now continues its grey background behind the clock without the black strip (build `1792583760`, 21 October 2026). Tab switches, Dark Pages toggles and light-page status-icon contrast have not been manually revalidated. iCloud and passwords are outside this change.

## Run the regression checks on Mac

```sh
swiftc Sources/Scripts.swift Tests/TopColorHarness.swift -o build/top-color-tests
build/top-color-tests
```

Run from this repository with Xcode installed. The fixture opens no external URL and uses no app data.
