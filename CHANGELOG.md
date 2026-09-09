# Changelog

All notable project changes will be recorded here once tagged releases begin.

The project currently uses a development version (`0.1.0-dev`).

## 0.1.0-dev — unreleased

### Added
- macOS menu-bar development app.
- short-lived in-memory key-event history.
- actual macOS input-source discovery, selection, and change observation.
- input-source epochs and typing-burst segmentation.
- source-switch suggestion signals with expiry and stale-input invalidation.
- physical-key replay with synthetic-event tagging.
- Accessibility focused-text primitives and secure-field exclusion.
- recovery transaction / restore / undo foundation.
- IME capability and compatibility evidence model.
- Apple ABC / Pinyin / Wubi adapter foundations.
- append-only SmokeReplayPlanner with focus revalidation.
- settings and first-run onboarding.
- launch-at-login support.
- bilingual README and packaging/testing documentation.
- macOS CI that builds, tests, packages, and uploads a development app artifact.

### Safety
- destructive automatic recovery remains disabled until real Mac replay-output range and restore behavior are verified.
- copied diagnostics exclude typed content by default.
- product shortcuts and synthetic replay events are excluded from user input history.
