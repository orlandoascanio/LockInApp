# Quietwhile

Native macOS focus app (Swift, SwiftUI, AppKit). The Xcode project is generated from `project.yml` by XcodeGen.

## Releasing

Full steps are in [Scripts/release/README.md](Scripts/release/README.md). The short version:

```bash
git tag vX.Y.Z
Scripts/release.sh
git push origin main vX.Y.Z
gh release create vX.Y.Z build/release/Quietwhile-X.Y.Z.dmg build/release/Quietwhile.dmg build/release/appcast.xml --title "Quietwhile X.Y.Z"
```

Rules that are easy to get wrong:

- **Always attach all three files**: `Quietwhile-X.Y.Z.dmg`, `Quietwhile.dmg`, and `appcast.xml`. The website's download button (orlandoascanio.com/products/quietwhile, in the separate `Profesional-Portfolio` repo) links to `releases/latest/download/Quietwhile.dmg`. A release without `Quietwhile.dmg` makes that button 404. Don't rename any of the three: the app fetches exactly `appcast.xml`, and the appcast points at exactly `Quietwhile-X.Y.Z.dmg`.
- **Push the tag before `gh release create`**. Otherwise `gh` creates the tag on whatever `main` is on GitHub, which may not be the commit the DMG was built from.
- **Publish as a full release**, not a draft or prerelease. The app and the website both read from the "latest" release, and those don't count.
- Signing is under team `VW98Z8698B` (Developer ID Application: Manuel Cabeza). The notarization profile in the keychain is `LockIn-Notary`.
- The Sparkle private key lives only in the login keychain. If it is lost, installed copies can never update.
- The app was called LockIn until 0.3.3. Identifiers that installed copies already depend on still say `lockin`: the bundle id `com.lockin.app` (Sparkle refuses an update whose bundle id differs), the app group, the `LockInStatus` widget kind, the `LockInFocusFilter` type, UserDefaults keys, the watchdog label, the `LockIn-Notary` profile, and the `LockInApp` GitHub repo in the update feed URL. Don't rename them.
