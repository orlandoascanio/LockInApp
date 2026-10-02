# Shipping a LockIn release

Everything here is one-time setup except the last section.

## 1. Developer ID certificate

Notarization needs a **Developer ID Application** certificate. Your Mac only
has an *Apple Development* one, which is fine for local builds but not for
anything you hand to someone else.

Xcode › Settings › Accounts › your team (VW98Z8698B) › Manage Certificates ›
**+** › Developer ID Application. Check it arrived:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## 2. Notarization credentials

Create an app-specific password at account.apple.com › Sign-In and Security ›
App-Specific Passwords, then store it in your keychain under a profile name
the release script knows. It prompts for the password, which then lives in
your keychain rather than in any file:

```bash
xcrun notarytool store-credentials LockIn-Notary --apple-id YOUR_APPLE_ID --team-id VW98Z8698B
```

## 3. Sparkle signing key

```bash
Scripts/release/setup_sparkle.sh
```

This creates the key updates are signed with (private half in your login
keychain — back it up) and writes the public half into `project.yml`. Commit
that change. Builds without a key simply have no updater.

The app looks for updates at
`https://github.com/orlandoascanio/LockInApp/releases/latest/download/appcast.xml`,
so the repository's releases have to be public for installed copies to see
them.

## 4. Each release

```bash
git tag v0.3.0
Scripts/release.sh
gh release create v0.3.0 build/release/LockIn-0.3.0.dmg build/release/appcast.xml --title "LockIn 0.3.0"
```

`release.sh` refuses to run on uncommitted changes, an untagged commit, or
missing credentials, before it spends any time building. It archives with
Developer ID and a secure timestamp, packages a DMG, notarizes and staples it,
signs it for Sparkle, and writes `appcast.xml`.
