# LockIn

Native macOS focus app (Swift, SwiftUI, AppKit). The Xcode project is generated from `project.yml` by XcodeGen.

## Releasing

Full steps are in [Scripts/release/README.md](Scripts/release/README.md). The short version:

```bash
git tag vX.Y.Z
Scripts/release.sh
git push origin main vX.Y.Z
gh release create vX.Y.Z build/release/LockIn-X.Y.Z.dmg build/release/LockIn.dmg build/release/appcast.xml --title "LockIn X.Y.Z"
```

Rules that are easy to get wrong:

- **Always attach all three files**: `LockIn-X.Y.Z.dmg`, `LockIn.dmg`, and `appcast.xml`. The website's download button (orlandoascanio.com/products/lockin, in the separate `Profesional-Portfolio` repo) links to `releases/latest/download/LockIn.dmg`. A release without `LockIn.dmg` makes that button 404. Don't rename any of the three: the app fetches exactly `appcast.xml`, and the appcast points at exactly `LockIn-X.Y.Z.dmg`.
- **Push the tag before `gh release create`**. Otherwise `gh` creates the tag on whatever `main` is on GitHub, which may not be the commit the DMG was built from.
- **Publish as a full release**, not a draft or prerelease. The app and the website both read from the "latest" release, and those don't count.
- Signing is under team `VW98Z8698B` (Developer ID Application: Manuel Cabeza). The notarization profile in the keychain is `LockIn-Notary`.
- The Sparkle private key lives only in the login keychain. If it is lost, installed copies can never update.
