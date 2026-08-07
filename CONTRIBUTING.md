# Contributing

Thanks for your interest. Here's how to help.

## Reporting bugs

Open a [GitHub issue](https://github.com/acalise/swiftui-revenuecat-admob-starter/issues) with:

- A clear title and description
- Steps to reproduce
- Expected vs. actual behaviour
- Your environment: macOS version, Xcode version, simulator or device, iOS version

Build failures are worth reporting even when they look like your setup. This starter pins SDK versions in `Package.resolved` specifically so that "works on my machine" is a bug, not a shrug.

## Suggesting features

Open an issue describing the use case. The bar for a starter is different from an app: a feature earns its place if it saves most people a real afternoon, not if it's merely nice. Something used by one app in ten is better as a doc snippet than as code everyone has to read and delete.

## Pull requests

1. **Fork** and clone.
2. **Branch** from `main` with a descriptive prefix:
   - `feat/your-feature`
   - `fix/what-you-fixed`
   - `docs/what-you-clarified`
3. **Build and run it.** `⌘R` on a simulator, at minimum. If you touched a service, exercise it from the Growth tab.
4. **Conventional commits:**
   - `feat: add StoreKit 2 fallback for non-consumables`
   - `fix: banner no longer reserves height when ads are off`
   - `docs: clarify AppsFlyer AAP default`
5. **One thing per PR.**
6. **Open the PR** against `main`, saying what changed and why.

## Code style

- **SwiftUI first.** Reach for UIKit only where SwiftUI genuinely can't do the job (as `Ads.swift` does for the AdMob banner).
- **`@Observable`**, not `ObservableObject`. The deployment target is iOS 17.
- **Colors come from `Theme`.** No literal colors in views. If you need a new token, add it to `Theme.swift` with both appearances.
- **Guard third-party calls with `#if canImport(...)`.** This is what lets someone delete a package without editing call sites, and it's the single most important convention in the repo.
- **Match the surrounding comment density.** Files in `Services/` carry a header explaining *why* they're built the way they are. That's the point of this repo, not decoration.
- Build cleanly. No new warnings.

## Documentation

If you change behaviour, update the matching file in `docs/`. Each one ends with a removal checklist; keep it accurate.

If you fix something that failed *silently*, say so explicitly in the docs. Silent failures are the whole reason `docs/launch-checklist.md` exists, and the next person will not guess.
