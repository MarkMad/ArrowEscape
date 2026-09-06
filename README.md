# Arrow Escape

Unwind and challenge your brain with Arrow Escape, a clean, minimalist puzzle game built purely for the love of play.


---

## 🌟 Key Features


- Infinite Levels: Procedurally generated puzzles ensure you never run out of challenges.

- 100% Offline Play: Play anywhere, on a plane, underground, or off the grid, without needing an internet connection.

- Zero Ads and Trackers: No popup interruptions, banner ads, or background tracking scripts. Just pure gameplay.

- Complete Privacy: No account needed, no data collected, and no unnecessary permissions requested.


- Minimalist Design: Clean visuals and crisp effects designed to help you focus and relax.

Whether you have two minutes to spare or want to zone out for an hour, Arrow Escape is the ultimate clean, privacy-respecting puzzle fix.

## 🎨 Themes & Custom Skins

Arrow Escape includes a theme selection system with custom skins. If you use it , support by giving a star to repo.

*   **Unlock Code**: `THANKYOU` (Enter this code to unlock all themes & custom skins instantly).

---

## License

GPL v3

## Automatic Android builds

The [Build APKs workflow](https://github.com/MarkMad/ArrowEscape/actions/workflows/test.yml)
runs on every push to `main`, every pull request targeting `main`, and on demand.
It checks analysis and tests, then uploads `arm64-v8a`, `armeabi-v7a`, and
`x86_64` APKs with SHA-256 checksums. Each binary is named after Arrow Escape
and its app version. Download the ZIP from the run's **Artifacts** section or
the link in its summary. Artifacts are retained for 30 days and use the version
from `pubspec.yaml`.

These APKs are for testing and need no signing secrets. Use `arm64-v8a` for
most modern phones. Debug signing keys can differ between CI runs and local
builds, so Android may refuse to install one over another; uninstalling the
existing app also removes its saved progress.

The separate **Build and Release** workflow publishes signed release APKs when
a `v*.*.*` version tag is pushed, and can also be run manually. It verifies
that the tag matches `pubspec.yaml` and requires repository secrets
`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS` for the
release signing key.
