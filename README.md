# InputReplay

**Never retype because of the wrong input mode.**

[中文](README.zh-CN.md) | English

InputReplay is an open-source macOS input recovery layer. It keeps a short, in-memory history of recent key events so that when you type with the wrong input method, it can recover by safely restoring the affected text range, switching to the intended input source, and replaying the original physical keystrokes through the user's existing IME.

It is **not** a new input method, not an AI rewriting tool, and not primarily an automatic input-source switcher.

## Why this exists

Most input-source utilities focus on prevention: remember the preferred input source for each app, switch before typing, or show the current input state.

InputReplay focuses on **recovery after the mistake already happened**.

Example:

```text
ABC:     ceshiyixia
                    ↓ Recover
Pinyin:  测试一下
```

The important part is that InputReplay does not translate `ceshiyixia` with its own dictionary. It replays the original physical key events through the user's existing Pinyin IME so that the IME itself can preserve candidates, learned vocabulary, names, and user preferences.

The same architecture is intended to support Pinyin, Wubi, third-party Chinese IMEs, and other input methods through capability-based adapters.

## Core flow

```text
Capture
  ↓
Detect / Suggest
  ↓
Snapshot
  ↓
Rollback
  ↓
Switch input source
  ↓
Replay physical keys
  ↓
Verify exact replay output range
  ↓
Continue / Restore / Undo
```

## Product principles

- **Recovery first** — solve wrong-input-state mistakes after they happen instead of trying to predict every switch.
- **Fail closed** — if a safe restore path cannot be proven, suggest instead of mutating text.
- **Always reversible** — every destructive mutation must belong to a recovery transaction with a known restore plan.
- **Local only** — recent key-event history stays in memory and is not persisted or uploaded by the core app.
- **Physical keys are the source of truth for replay** — Unicode character projection is used only for detection and boundary analysis.
- **Capability based** — compatibility is evaluated per `IME × host app × direction × capability`, not by brand-name assumptions.
- **Zero surprise** — an input-source change is a strong signal, but never permission to silently rewrite user text.

## What is implemented now

The current branch includes:

- a runnable macOS menu-bar app;
- physical key-event capture with synthetic-event tagging;
- a short-lived in-memory keystroke ring buffer;
- macOS TIS input-source discovery, selection, and change observation;
- input-source epochs and typing bursts;
- debounced input-source-switch signals;
- expiring recovery suggestions that are invalidated as soon as new physical typing begins;
- hard boundaries across apps and focused text fields;
- Unicode event projection for punctuation, whitespace, Backspace, and boundary analysis;
- adapter-configurable boundary policies for Pinyin-like and code-based IMEs;
- Accessibility focused-text snapshot and replacement primitives;
- Secure Event Input / password-field capture and replay blocking;
- transactional recovery coordinator with a fail-closed mutation gate;
- exact post-replay-range verification contract;
- synthetic physical-key replay engine;
- compatibility evidence registry using `Prepared / Observed / Verified` states;
- a non-destructive diagnostics/probe CLI;
- a local `.app` / zip packaging script;
- macOS GitHub Actions CI that builds, tests, packages, validates and uploads a development app artifact.

## Current verification status

### Verified in CI

On GitHub-hosted macOS (`macOS 15.7.9`, `Xcode 16.4`, `Swift 6.1.2`):

- Swift package resolution succeeds;
- the core and menu-bar app build successfully;
- unit tests pass;
- source-switch state-machine tests pass;
- recovery coordinator safety tests pass;
- punctuation / whitespace / Backspace projection tests pass;
- the `.app` bundle, Info.plist validation, executable check, and development zip packaging succeed.

### Still requires a real interactive Mac

Hosted CI cannot verify a real focused editor plus an interactive IME composition session. The following are still **Prepared**, not yet **Verified**:

1. real TIS source-change observation under user switching gestures;
2. AX snapshot/replacement behavior in TextEdit;
3. Apple Pinyin accepting synthetic physical-key replay as normal IME composition;
4. exact replay-output-range detection during composition or commit;
5. failed-path restoration without duplicated or orphaned composition text;
6. explicit InputReplay Undo after a successful recovery.

The first real-Mac verification tuple is intentionally narrow:

```text
Host:      TextEdit
Source:    Apple ABC
Target:    Apple Pinyin - Simplified
Direction: Latin -> IME
```

See [`docs/REAL_MAC_TEST_PLAN.md`](docs/REAL_MAC_TEST_PLAN.md).

## Package a local test app

Requires macOS 13+ and Xcode / Xcode Command Line Tools.

```bash
git clone https://github.com/monkey-sking/InputReplay.git
cd InputReplay
git checkout dev/core-replay-spike
bash scripts/package-app.sh
open dist/InputReplay.app
```

Outputs:

```text
dist/InputReplay.app
dist/InputReplay-0.1.0-dev.zip
```

On first launch, open the InputReplay menu-bar item. If Accessibility is required, use `Open Accessibility Settings…`, allow InputReplay in System Settings, then choose `Restart Monitoring`.

### Most important smoke test

1. Open TextEdit and select Apple ABC.
2. Type `ceshiyixia`.
3. Do not type anything else.
4. Switch to Apple Pinyin.
5. InputReplay should show a lightweight HUD with the previous burst preview.
6. Within six seconds press `Control + Option + R`.
7. The current development build **does not delete the original `ceshiyixia`**. It only re-sends the same physical keys through the newly selected Pinyin input source.
8. Observe whether normal Pinyin composition / candidates appear.
9. Choose `Copy Diagnostics` from the menu and record the result.

This smoke test is intentionally non-destructive. Full recovery remains gated until replay behavior and the exact replay-output range are verified on a real Mac.

See [`docs/PACKAGING.md`](docs/PACKAGING.md) for packaging details and [`docs/TEST_CHECKLIST.md`](docs/TEST_CHECKLIST.md) for the compatibility test matrix.

## Privacy and Secure Input

InputReplay is a system-wide keyboard utility, so capture defaults are fail-closed:

- recent key metadata is memory-only and is not persisted or uploaded;
- if Accessibility cannot identify the current focused element, physical keystrokes do not enter the ring buffer;
- macOS Secure Event Input blocks capture and replay;
- Secure / Password text fields block capture and replay;
- changing app or focused field ends the previous typing burst;
- sleep/wake, listener restart, and `Clear Recent Input Buffer` clear short-lived state;
- InputReplay's own synthetic replay events are tagged and excluded from user-input history.

The menu-bar app surfaces protected mode with a lock icon and refuses the experimental replay action while secure input is active.

## Architecture

```text
InputEventMonitor
    ↓
InputPrivacyGuard
    ↓
KeystrokeRingBuffer
    ↓
InputContextTracker
    ├── InputSourceEpoch
    ├── TypingBurst
    └── InputSourceSwitchSignal
    ↓
TypingProjection / Boundary Policy
    ↓
RecoveryCandidate
    ↓
PreMutationSnapshot
    ↓
RecoveryTransaction
    ↓
InputMethodAdapter / IMECapabilities
    ↓
RecoveryCoordinator
    ↓
Rollback -> Switch -> Replay -> Verify
    ↓
Continue / Restore / Undo
```

## Input-method compatibility strategy

InputReplay does not label an entire IME as simply "supported" or "unsupported".

Compatibility is tracked using the exact tuple:

```text
IME input source × host app × recovery direction × capability
```

Capabilities include whether InputReplay can reliably:

- identify and select the macOS input source;
- observe an IME's internal Chinese/English mode when relevant;
- control that internal mode when required;
- feed synthetic key replay;
- cancel composition safely;
- restore the original user text/state;
- verify the exact result of a recovery.

Missing or uncertain evidence fails closed.

Initial compatibility priorities:

1. Apple ABC -> Apple Pinyin in TextEdit;
2. Apple Wubi;
3. IME -> ABC recovery;
4. Rime / Squirrel;
5. WeChat Input;
6. Sogou;
7. Electron apps and terminals.

See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).

## Whitespace, punctuation and Backspace

Detection and replay intentionally use different representations:

- **Replay history** keeps the actual physical keyCode / flags sequence.
- **Typing projection** estimates the recently visible text for detection and boundary analysis.

A Pinyin-like policy may keep whitespace inside the candidate suffix while punctuation ends a segment. A code-based IME policy may treat whitespace as a stronger commit boundary. Backspace updates the visible-text projection without rewriting raw replay history.

If Cmd-V, Forward Delete, Escape, or another operation makes event-only reconstruction unsafe, projection becomes unreliable and later stages must use Accessibility / host state rather than guessing.

## Safety contract

> **If InputReplay cannot establish a reliable restore plan before changing user-visible text, it must not perform an automatic destructive mutation.**

A second rule is equally important:

> **If InputReplay cannot identify the exact text/composition range produced by replay, it must not guess the range during restore.**

Manual recovery and non-destructive suggestions are always preferable to irreversible "smart" behavior.

## Developer probe

The menu-bar app is the preferred real-Mac smoke-test surface. The CLI probe remains useful for lower-level diagnostics:

```bash
swift build
swift test
swift run InputReplayProbe diagnose
swift run InputReplayProbe list-sources
swift run InputReplayProbe current-source
swift run InputReplayProbe watch-source
swift run InputReplayProbe capture
swift run InputReplayProbe snapshot-before-caret 10
```

`capture` records only short-lived in-memory key-event metadata and only when a non-secure focused element can be identified.

## Why automatic correction is not enabled yet

A false positive is more expensive than missing several opportunities to help. The intended progression is:

```text
Manual Recovery
    ↓
Switch Suggestion
    ↓
High-confidence Suggest
    ↓
Auto Fix only after evidence
```

InputReplay will not equate “looks like Pinyin” with “safe to rewrite user content” until real-world evidence supports it.

## Roadmap

See [`ROADMAP.md`](ROADMAP.md). The roadmap is organized around validation gates rather than feature-count milestones.

## Product and technical specification

See [`docs/Product_Spec_v0.3.md`](docs/Product_Spec_v0.3.md).

## License

InputReplay core is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [`LICENSE`](LICENSE).

MPL-2.0 keeps modifications to covered source files open while allowing the project to be combined with separately licensed modules. This leaves room for an open-source core plus optional paid distribution, store builds, services, integrations, or premium modules later.

The InputReplay name, logo, and official distribution identity are not granted by the source-code license. See [`TRADEMARKS.md`](TRADEMARKS.md).

## Status

Early implementation / technical validation.

The core architecture, safety contracts, CI, menu-bar app, and packaging pipeline are in place, but real IME recovery compatibility is still being validated tuple by tuple. Compatibility claims should use the project's `Prepared / Observed / Verified` terminology instead of assuming that code existence equals real-world support.
