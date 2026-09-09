# Security Policy

InputReplay handles keyboard-event metadata and Accessibility APIs, so security and privacy bugs are treated as product-critical.

## Supported versions

The project is in early development. Security fixes are applied to the current development branch and the latest tagged release once releases begin.

## Reporting a vulnerability

Please do **not** publish sensitive proof-of-concept data, captured text, credentials, or private user content in a public issue.

For now, open a GitHub issue with the minimum non-sensitive reproduction details and clearly mark it as a security concern. If the report requires secrets or private content, do not attach that material publicly; request a private reporting channel first.

Useful non-sensitive details include:

- macOS version;
- InputReplay version/commit;
- host app and version;
- input source / IME name;
- whether Accessibility permission was granted;
- whether Secure Event Input was active;
- whether the issue occurred during capture, suggestion, replay, rollback, restore, or undo;
- whether user-visible text was changed unexpectedly.

## Security invariants

The following behaviors are considered hard requirements:

1. Raw recent key history remains local and memory-only in the open-source core.
2. Password/secure fields and Secure Event Input are excluded from capture and replay.
3. Synthetic InputReplay events never enter the user's physical-input history.
4. Cross-app or cross-focused-element recovery is rejected.
5. Automatic destructive mutation is forbidden without a reliable restore plan.
6. Restore must never guess the length of unknown replay output.
7. Copied diagnostics exclude actual typed text by default.

A regression in any of these invariants should be treated as security-sensitive even if no data has yet been lost or exposed.
