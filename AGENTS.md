# AGENTS.md

|Scope: Applies to the entire Candlebar repository.
|Language: Use Simplified Chinese for user-facing summaries; keep code identifiers, paths, commands, and error text in English.
|Priority: System/developer/current-session instructions > nearest AGENTS.md > this file.
|Project: Candlebar is a SwiftPM macOS menu bar app using AppKit, SwiftUI views, Sparkle updates, and local Keychain/UserDefaults state.
|ReadFirst: Before changing behavior, inspect the relevant source files, release scripts, `README.md`, `README_CN.md`, `VERSION`, and `BUILD_NUMBER` when applicable.
|ScopeControl: Prefer the smallest change that preserves existing menu bar, settings, Sparkle, and Binance read-only behavior. Do not add dependencies or broad abstractions unless the current task requires them.
|State: Treat `AppStore.preferences` as published app state. Preserve `@Published`/Combine timing semantics when reacting to preference changes; use emitted values when needed instead of assuming stored values have already updated.
|UI: Preserve menu bar app expectations: status item toggles the main panel, pinned panels ignore outside-click close, unpinned panels close on outside click, and the Settings button toggles the settings window.
|Localization: Any new visible string must go through `LocalizedCopy` in English and Chinese unless it is a platform-standard fixed label.
|Security: Never commit Sparkle private keys, API keys, Keychain data, diagnostic exports, `.build/`, `dist/`, or local `.DS_Store` files. Binance API use must remain read-only.
|Testing: For code changes, run `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test` when available. For app packaging or launch behavior, run `script/build_and_run.sh --build-only` or `script/build_and_run.sh --verify`.
|Release: Use `VERSION` and `BUILD_NUMBER` for release versioning. Run `script/release_check.sh` before publishing a GitHub Release, then upload the generated DMG and `dist/appcast.xml` to the matching `v<VERSION>` release.
|Git: Do not rewrite history or discard user changes. Before commits or releases, review `git status --short`, `git diff --check`, tests, and release artifacts.
