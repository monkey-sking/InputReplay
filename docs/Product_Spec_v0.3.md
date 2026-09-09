# InputReplay — Product & Technical Specification v0.3

> Status: implementation-ready MVP contract  
> Updated: 2026-09-09  
> Principles: Recovery First / Fail Closed / Local Only / Adapter-based

## 1. Product definition

InputReplay is a macOS input-recovery layer. When a user types while the wrong input method is active, InputReplay keeps a short in-memory history of the original physical key events and can reinterpret those events through the intended input method so the user does not have to delete and retype.

> **打错输入法，也不用重打。**

InputReplay is not a new IME, not an AI rewriting tool, and not primarily an automatic input-source switcher.

Core flow:

```text
Capture -> Detect / Suggest -> Snapshot -> Rollback -> Switch -> Replay -> Verify -> Continue
```

## 2. System invariants

These rules override feature requests and convenience:

1. Any InputReplay mutation of user-visible text must belong to a `RecoveryTransaction`.
2. A destructive mutation is forbidden unless a reliable `PreMutationSnapshot` / restore plan exists beforehand.
3. If safety cannot be established, downgrade to Suggest Only.
4. Raw keystrokes remain in RAM only; the open-source core never persists or uploads them.
5. Secure/password fields do not enter the recovery pipeline.
6. Unknown third-party IME internal state is never guessed.
7. InputReplay-triggered input-source changes must be marked/suppressed so they do not recursively trigger suggestions.
8. A recovery must be undoable while its transaction remains valid.

Priority when constraints conflict:

1. Do not lose or damage text.
2. Make actions reversible.
3. Recovery reliability.
4. Clear user intent.
5. Local privacy.
6. Speed.
7. Broader compatibility.
8. Intelligence/automation.

## 3. Core user flows

### Manual Recover — MVP primary path

```text
wrong input -> Recover shortcut -> safe recovery
```

Default candidate shortcut: `Option + Space`, configurable.

### User switches input source — strong signal, not permission

```text
wrong input
-> user switches to intended input source
-> close previous Input Source Epoch
-> analyze previous burst
-> if useful/safe: caret HUD suggests recovery
-> user confirms
```

**Default: Suggest only. Never auto-rewrite merely because the user switched input sources.**

Reason: finishing a Chinese sentence and intentionally switching to English for code is normal behavior.

## 4. Input timeline model

The core data model is an event timeline, not merely a visible string.

```swift
CapturedKeyEvent
+ current input source
+ source PID / focus identity
+ caret / selection changes when available
+ source-change events
+ optional local text snapshots
```

Default `KeystrokeRingBuffer`:

- maximum age: 15 seconds;
- maximum events: 128;
- whichever limit is reached first evicts older events;
- never persisted.

### Input Source Epoch

A continuous period where the actual selected input source remains unchanged.

User source switch closes the old epoch and begins a new one. InputReplay's own source switch is separately tagged/suppressed.

### Typing Burst

A cluster of input inside an epoch. Initial pause boundary: around 2 seconds, subject to dogfood tuning.

### Recovery Candidate

The actual recoverable unit derived from:

- epoch;
- typing burst;
- strong/soft boundaries;
- focus continuity;
- adapter analysis;
- trigger reason;
- safety state.

## 5. Boundaries

### Strong boundaries — never cross in MVP

- foreground App changes;
- focused editable element changes;
- mouse/caret move;
- selection changes;
- Enter/Return;
- Tab in MVP;
- composition cancellation / Escape where relevant;
- password/secure field;
- paste/cut/drag-drop;
- emoji/dictation/handwriting generated text;
- hard idle expiry.

### Soft boundaries

- space;
- comma / period / semicolon / colon / exclamation / question mark;
- Chinese counterparts;
- hyphen;
- brackets.

**Punctuation is a boundary/scoring feature, not the only trigger and not a hard “recover only after punctuation” rule.**

Example:

```text
jintian,quchifan
```

The entire burst may be recoverable; recovering only `quchifan` would leave part of the mistake behind.

## 6. Trigger levels

### T0 — Manual Recover
MVP required. Strongest explicit user intent.

### T1 — Actual Input Source Change
MVP observes all real source changes regardless of whether they came from Control-Space, Caps Lock, Fn/Globe, Input Menu, etc. Default action: Suggest only.

### T2 — Pause Suggest
Later. Detect a likely mismatch after a short pause without a source switch. Suggest only.

### T3 — Auto Recover
Later and opt-in only. Requires high confidence, reliable transaction/undo, per-app/IME policy, and real-world evidence.

## 7. Source-change invalidation

A source-change suggestion is tied to:

```text
PID + focusIdentity + candidateID
```

It immediately expires when:

- the user types the first new real printable key after switching;
- focus/app/window changes;
- caret/selection changes;
- hard expiry elapses;
- user dismisses it.

Source changes should be debounced before analysis so rapid source cycling does not spam the HUD.

## 8. Replay, never convert

Wrong approach:

```text
ceshiyixia -> own pinyin dictionary -> 测试一下
```

Correct approach:

```text
ceshiyixia
-> safe rollback
-> switch to user's Pinyin IME
-> replay physical keys
-> user's IME produces normal composition/candidates
```

Do not automatically commit the first candidate unless a later, separately validated workflow explicitly requires it.

## 9. IME adapter architecture

IME-specific behavior lives behind `InputMethodAdapter` and `IMECapabilities`.

Capabilities are evaluated per:

```text
IME × Host App × Direction × Capability
```

Relevant capabilities include:

- discover/select source;
- observe/control internal Chinese/English mode;
- accept synthetic replay;
- detect/cancel composition safely;
- rollback/restore safely;
- verify post-replay state.

Compatibility levels:

- Full Recovery;
- Manual Recovery;
- Suggest Only;
- Unsupported.

### Apple Pinyin

Pinyin syllable analysis may be used as a detector/scoring feature only. Conversion remains the user's actual Apple Pinyin engine.

### Apple Wubi

Do **not** implement “recover last four keys.” Wubi's typical four-code structure is only a scoring feature. Recovery scope still comes from Epoch + Burst + boundaries + trigger. Apple Wubi variants and mixed candidate behaviors must be tested on a real Mac.

### Third-party IMEs

First-class targets:

- WeChat Input;
- Sogou Input;
- Rime / Squirrel.

A third-party IME can have two state layers:

```text
macOS Input Source
+ IME internal Chinese/English/full-width/etc mode
```

If the internal mode is unknown and the recovery depends on it, InputReplay must downgrade rather than guess.

## 10. Recovery transaction

State model:

```text
Prepared
-> RollingBack
-> SwitchingInputSource
-> Replaying
-> Verifying
-> Committed
```

Failure path:

```text
any failure -> Restoring -> Restored / Aborted safely
```

The transaction stores enough local state to restore the user's pre-recovery condition while valid, including original source, candidate text/range when readable, selection/caret context, and raw event slice.

No reliable restore plan = no destructive mutation.

## 11. Editing-event rules

- Backspace can remain inside a candidate only for simple tail corrections with unchanged caret; rollback must never be inferred from net key count alone.
- Arrow/Home/End/Page or selection movement invalidates destructive recovery.
- Paste/Cut/Drag-Drop is a strong boundary and clipboard content is not analyzed.
- Space/number keys inside active IME composition are interpreted by the adapter, not a global punctuation rule.
- Key repeat is preserved but reduces detector confidence.

## 12. Recovery critical section

Recovery must be short and must not silently lose real user keys.

If new physical input arrives during:

```text
Preparing -> Rollback -> Switch -> Replay -> Verify
```

preferred behavior is to buffer that input briefly and release it after successful verification; if this cannot be implemented safely, abort/restore rather than drop input or interleave it unpredictably.

## 13. EventTap lifecycle

On event-tap disable, Accessibility revocation, sleep/wake, session change, or monitor rebuild:

```text
clear raw buffer
clear candidate/transaction
re-check permission
rebuild monitor
```

Never recover from a pre-sleep buffer after wake.

## 14. HUD / UI

UI layers:

1. Menu bar — status, permissions, settings, Undo Last Recovery.
2. Caret-adjacent transient HUD — suggestions, success, failure, undo affordance.

Design principle:

> **平时不可见，出错时可理解，恢复后立即消失。**

HUD must not take keyboard focus or become the key window. If caret bounds are unavailable, fall back near the focused control/window.

Default HUD should avoid echoing the user's raw typed text for privacy. Prefer action-level feedback such as:

```text
✓ 已用“拼音”重新输入
```

## 15. User-configurable vs built-in rules

### Built-in, not user-editable

- secure-input exclusion;
- strong safety boundaries;
- transaction requirement;
- raw-key retention/persistence policy;
- unknown-state fail-closed behavior;
- restore safety threshold.

### User configurable in MVP

- Recover shortcut;
- Suggest on/off;
- source-change Suggest on/off;
- default/paired English and Chinese input sources;
- per-app disable list.

Advanced detector thresholds should not be exposed in MVP.

## 16. Privacy

The open-source core:

- keeps raw key events only in RAM;
- does not persist typed content;
- does not upload keystrokes;
- does not inspect password/secure fields;
- should export diagnostics without raw text by default.

## 17. MVP definition of done

MVP is not complete until all are observed on real macOS:

1. Long-running app behavior is stable.
2. ABC -> Apple Pinyin Manual Recover works in the supported baseline apps.
3. User source switch can generate a low-noise Suggest without automatic rewrite.
4. Reverse recovery has a reliable path in agreed baseline apps.
5. App/focus/caret/selection changes cannot damage unrelated text.
6. Secure fields never enter recovery.
7. Failure restores or safely aborts.
8. Last valid recovery can be undone.
9. HUD has caret positioning + fallback.
10. Raw key events never persist.
11. Compatibility is published honestly per tested path.
12. At least ten common apps have observed compatibility results before a broad stable release.
13. Apple Wubi replay feasibility is tested.
14. The maintainer dogfoods the tool for multiple real work days.

## 18. Implementation order

The first gate is **not UI**. It is:

```text
TextEdit
ABC mistaken Pinyin
-> establish safe snapshot
-> rollback
-> select Apple Pinyin
-> synthetic replay
-> Apple Pinyin receives normal composition/candidates
-> verify
-> Undo/Restore works
```

Only after this is observed should automatic detection and richer UI expand.

See `ROADMAP.md` for phase gates and commercial/distribution sequencing.
