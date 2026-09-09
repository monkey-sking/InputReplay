# InputReplay

**打错输入法，也不用重打。**  
*Never retype because of the wrong input mode.*

InputReplay is an open-source macOS input recovery layer. It captures a short, in-memory history of recent key events so that when you type with the wrong input method, it can safely roll back the mistaken text, switch to the intended input source, and replay the original keystrokes through the user's existing IME.

It is **not** a new input method, not an AI rewriting tool, and not primarily an automatic input-source switcher.

## Core idea

```text
Capture -> Detect / Suggest -> Snapshot -> Rollback -> Switch -> Replay -> Verify -> Continue
```

Example:

```text
ABC:     ceshiyixia
                    ↓ Recover
Pinyin:  测试一下
```

The important part is that InputReplay does not convert `ceshiyixia` with its own dictionary. It replays the original keystrokes through the user's existing Pinyin IME, preserving that IME's candidates, learned vocabulary, names, and preferences.

The same architecture is intended to support Pinyin, Wubi, third-party Chinese IMEs, and other input methods through capability-based adapters.

## Product principles

- **Recovery first** — solve mistakes after they happen instead of trying to predict every switch.
- **Fail closed** — if a safe restore path cannot be established, suggest instead of modifying text.
- **Always reversible** — every InputReplay mutation must belong to a recovery transaction with an undo/restore plan.
- **Local only** — recent keystrokes stay in memory and are never uploaded or persisted by the core app.
- **Adapter based** — compatibility is determined per IME × host app × direction × capability, not by brand-name assumptions.
- **Zero surprise** — an input-source change is a strong signal, but never a default reason to rewrite text automatically.

## MVP focus

The first technical gate is intentionally narrow:

> In TextEdit, type Pinyin while ABC is active, trigger recovery, safely roll back the mistaken text, switch to Apple Pinyin, replay the original physical key events, enter normal IME composition/candidate state, and be able to restore the original state if anything goes wrong.

Until this path is verified on a real Mac, UI polish and automatic detection are secondary.

## Planned architecture

```text
InputEventMonitor
    ↓
KeystrokeRingBuffer
    ↓
InputSourceEpoch / TypingBurst
    ↓
RecoveryCandidate
    ↓
RecoveryTransaction + PreMutationSnapshot
    ↓
InputMethodAdapter / IMECapabilities
    ↓
Rollback -> Switch -> Replay -> Verify
    ↓
HUD + Undo / Restore
```

## Input method support strategy

InputReplay does not claim that an IME is simply "supported" or "unsupported". Each combination is tested for capabilities such as:

- can identify/select the macOS input source;
- can determine internal Chinese/English mode when relevant;
- accepts synthetic key replay reliably;
- exposes or survives composition cancellation;
- permits safe rollback and restore in the current host app;
- allows recovery verification.

Apple ABC / Pinyin are the first verification target. Apple Wubi follows. Third-party IMEs such as WeChat Input, Sogou, and Rime/Squirrel are first-class compatibility targets, with graceful degradation when capabilities are unavailable.

## Safety contract

**If InputReplay cannot establish a reliable restore plan before changing user-visible text, it must not perform an automatic destructive mutation.**

Manual suggestions are always preferable to irreversible "smart" behavior.

## Roadmap

See [ROADMAP.md](ROADMAP.md). The roadmap is organized around validation gates rather than feature-count milestones.

## Product & technical specification

See [`docs/Product_Spec_v0.3.md`](docs/Product_Spec_v0.3.md).

## License

InputReplay core is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [LICENSE](LICENSE).

MPL-2.0 keeps modifications to covered source files open while allowing the project to be combined with separately licensed modules. This leaves room for an open-source core plus optional paid distribution, store builds, services, integrations, or premium modules later.

The InputReplay name, logo, and official distribution identity are not granted by the source-code license. See [TRADEMARKS.md](TRADEMARKS.md).

## Status

Early implementation / technical validation. APIs, architecture, behavior, and compatibility claims may change rapidly.
