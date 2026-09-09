# First real-Mac validation gate

This plan is deliberately narrow. The first goal is not to prove universal IME support; it is to prove or falsify the core physical-key replay thesis on one controlled combination:

```text
Host: TextEdit
Source state: Apple ABC
Target: Apple Pinyin - Simplified
Direction: Latin -> IME
```

## Evidence vocabulary

- **Prepared**: code/test path exists but has not run on a real matching environment.
- **Observed**: run on a real Mac and actual behavior recorded.
- **Verified**: repeated successful behavior satisfies the gate below with no unexplained failures.

Do not mark a step verified just because CI is green.

## Gate A — build and environment

From the repository root:

```bash
swift build
swift test
swift run InputReplayProbe diagnose
swift run InputReplayProbe list-sources
```

Record:

- macOS version;
- Mac architecture;
- Xcode/Swift version;
- exact Apple ABC source ID;
- exact Apple Pinyin source ID;
- Accessibility trusted state.

Expected result: package builds/tests; ABC and Pinyin are discoverable by TIS.

## Gate B — input-source observation

Run:

```bash
swift run InputReplayProbe watch-source
```

Switch input sources using at least two of the mechanisms available on the Mac, for example Control-Space, Caps Lock/中英, Fn/Globe, or the menu.

Expected result: the probe reports the *actual selected input source* regardless of which UI gesture caused the switch.

Pass criterion: 20 consecutive deliberate source changes are observed correctly, with no duplicate source state interpreted as a new semantic switch after debounce is added.

## Gate C — event capture

Run:

```bash
swift run InputReplayProbe capture
```

Type a controlled string in TextEdit with ABC active:

```text
ceshiyixia
```

Expected result:

- physical key-down events enter the in-memory buffer;
- source ID is ABC;
- InputReplay-generated synthetic events are distinguishable from physical input;
- buffer is not persisted after process exit.

Do **not** collect passwords, secure fields, or private content during testing.

## Gate D — AX text snapshot

Put the caret directly after the controlled string in TextEdit, then run from another terminal:

```bash
swift run InputReplayProbe snapshot-before-caret 10
```

Expected result:

```text
text=ceshiyixia
```

The returned range must correspond to exactly the intended text segment.

Repeat with:

- ASCII followed by punctuation;
- ASCII after Chinese text;
- a new line boundary;
- text edited with Backspace before the snapshot.

The snapshot must never silently cross a boundary selected by the recovery candidate layer.

## Gate E — controlled synthetic replay research

This gate is **not yet exposed as a destructive CLI command**. It may be enabled only after the implementation can prove a restore strategy for the exact TextEdit + Apple Pinyin combination.

Required sequence when the controlled spike is enabled:

1. capture `ceshiyixia` as raw physical key events while ABC is active;
2. establish a pre-mutation text snapshot;
3. remove only the controlled mistaken range;
4. select the discovered Apple Pinyin source ID;
5. replay the captured physical key codes;
6. observe whether Apple Pinyin enters normal composition/candidate behavior;
7. identify the exact post-replay text/composition range;
8. cancel/restore to the original `ceshiyixia` and original input source;
9. repeat the successful and deliberately failed paths.

### Critical rule

If step 7 cannot identify an exact replay-output range, the product must not claim reliable destructive recovery for this tuple. We must not guess output length from raw key count.

## Gate F — restore / user undo

For a recovery to be considered safe, both paths must work:

### Failed recovery

A deliberately failed verification must restore:

- the original text;
- the original input source;
- a valid caret/selection position;
- no duplicate or orphaned composition text.

### Successful recovery followed by user Undo

After a successful recovery, the user-facing InputReplay Undo must restore the same original state without relying on the host app's generic Cmd-Z stack.

The host's native undo stack may be preserved when possible, but it is not the recovery contract.

## Verification threshold

For the first tuple (`ABC -> Apple Pinyin` in TextEdit), mark the replay/restore path **Verified** only after:

- 50 consecutive controlled recoveries succeed;
- 20 deliberate verification failures restore correctly;
- 20 explicit InputReplay Undo operations restore correctly;
- zero instances lose or duplicate user text;
- zero instances cross into adjacent text outside the selected recovery range.

Performance target for manual recovery after the shortcut is invoked:

- mutation/replay begins perceptibly immediately;
- target interaction should feel below ~150 ms before IME candidate/composition feedback, excluding IME-specific candidate rendering latency.

Record actual timings rather than treating this target as already achieved.

## Evidence record template

```text
Date:
Commit SHA:
macOS:
Machine:
Host app + version:
Source input source ID:
Target input source ID:
Direction:
Attempts:
Successful replay:
Successful failed-path restore:
Successful explicit Undo:
Text loss/duplication incidents:
Observed composition behavior:
Median / p95 perceived or measured latency:
Evidence level: Prepared | Observed | Verified
Notes:
```

## After this gate

Only after the first tuple is verified should we promote its capability record and move to:

1. Apple Wubi in TextEdit;
2. `IME -> ABC` recovery research;
3. Rime/Squirrel;
4. WeChat Input;
5. Sogou;
6. Electron apps and terminals;
7. Suggest-on-input-source-change behavior;
8. automatic correction, if real-world false-positive evidence ever justifies it.
