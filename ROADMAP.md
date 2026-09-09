# InputReplay Roadmap

InputReplay is developed around **validation gates**, not feature-count milestones. A phase is only complete when its gate is observed on a real Mac in the target host apps and IMEs.

## Phase 0 — Technical survival gate

Goal: prove the core replay model is real.

### Scope
- Capture recent physical key events with `CGEventTap`.
- Track actual macOS input-source changes.
- Build an in-memory `KeystrokeRingBuffer`.
- Build `InputSourceEpoch`, `TypingBurst`, and `RecoveryCandidate` models.
- Create `PreMutationSnapshot` + `RecoveryTransaction`.
- In TextEdit: type Pinyin while ABC is active, recover, switch to Apple Pinyin, replay the original events, and enter normal Apple Pinyin composition/candidate state.
- Undo/restore must return the user to the pre-recovery state.

### Go gate
All of the following must be observed on a real Mac:
1. `ABC -> Apple Pinyin` replay works in TextEdit.
2. The replayed sequence is handled by Apple Pinyin as normal IME composition, not pasted final text.
3. Failed recovery never destroys the original text.
4. A completed recovery can be undone reliably.

### No-Go / redesign triggers
- Synthetic replay is systematically rejected by the target IME.
- Reliable rollback cannot be established.
- Accessibility permissions or host-app behavior make safe recovery too fragile for normal use.

---

## Phase 1 — Manual Recovery MVP

Goal: make the smallest version that a real user can rely on daily.

### Scope
- Menu bar app.
- Accessibility onboarding and permission diagnostics.
- Default Recover shortcut (`Option + Space`, configurable).
- Apple ABC -> Apple Pinyin recovery.
- Apple Pinyin -> ABC recovery where raw keystrokes are available.
- Transactional undo / restore.
- Minimal caret-adjacent HUD with fallback placement.
- Secure Input / password-field fail-closed behavior.
- App/focus/caret boundaries.
- No cloud, no account, no telemetry containing typed content.

### Go gate
- User can recover mistakes repeatedly in TextEdit, Safari standard inputs, and at least one Electron editor without content loss.
- 100% of destructive InputReplay mutations have a valid restore plan.
- Recovery latency is subjectively immediate enough to stay in typing flow.

---

## Phase 2 — Wubi + IME capability architecture

Goal: prove InputReplay is an input-recovery platform, not a Pinyin-specific trick.

### Scope
- `InputMethodAdapter` protocol.
- `IMECapabilities` model.
- Apple Wubi adapter and real compatibility tests.
- Treat Wubi's typical four-code shape as a scoring signal, never as a hard "last 4 chars" recovery rule.
- Capability matrix keyed by `IME × Host App × Direction`.
- Degrade modes: Full Recovery / Manual Recovery / Suggest Only / Unsupported.

### Go gate
- Apple Wubi recovery works in the agreed host-app baseline.
- Core recovery engine contains no Wubi-specific branching outside adapters/policies.

---

## Phase 3 — Third-party Chinese IMEs

Goal: support the input methods people actually use without lying about compatibility.

### Initial targets
- WeChat Input
- Sogou Input
- Rime / Squirrel

### Capability probes
For each target combination, test:
- macOS input source can be identified and selected;
- internal Chinese/English mode can be observed or controlled;
- synthetic key replay is accepted;
- composition can be safely cancelled or replaced;
- rollback/restore is reliable in the host app;
- post-recovery verification is possible.

### Rule
Unknown internal IME state is **never guessed**. If state or restore safety cannot be established, InputReplay downgrades to Suggest Only.

### Go gate
Publish a truthful compatibility matrix with observed evidence for each supported path.

---

## Phase 4 — Suggest mode

Goal: reduce the number of manual recovery actions without introducing surprise edits.

### Signals
- User changes actual input source after a recent typing burst.
- Recent burst strongly fits the newly selected IME.
- Existing text is bounded to the same focus/epoch.
- English/code dictionary exclusions and IME-specific scoring.

### UX
Input-source changes may show a small caret-adjacent suggestion such as:

> 刚才这段可能输错了 · Option + Space 恢复

Default behavior is **suggest, never rewrite automatically**.

### Go gate
- Suggestions are useful enough to keep enabled.
- False-positive prompts are low enough not to train users to ignore the HUD.

---

## Phase 5 — Safe automation

Goal: optionally recover extremely high-confidence mistakes automatically.

This phase only starts after sufficient real-world evidence from manual recovery and Suggest mode.

### Requirements
- User opt-in.
- Per-IME and per-app confidence policy.
- Every auto action has a transaction and visible Undo.
- Immediate downgrade after undo / correction feedback.
- No automatic mutation where restore confidence is below the hard safety threshold.

### Go gate
Auto recovery must be demonstrably more useful than disruptive. If not, InputReplay remains a manual/suggest product.

---

## Phase 6 — Distribution and growth

Goal: make the open-source core easy to trust and install.

### Scope
- Signed/notarized direct download.
- Homebrew Cask if appropriate.
- GitHub Releases + changelog.
- Public compatibility matrix.
- Issue templates for IME/app compatibility reports.
- Privacy and security documentation.
- Optional diagnostics export that never includes raw typed content by default.

### Success signals
- Daily/weekly active users.
- Recoveries per active user.
- Repeat usage after first successful recovery.
- Low undo-after-recovery rate.
- Community-submitted compatibility fixes.

---

## Phase 7 — Commercial layer

Goal: monetize distribution, convenience, services, and advanced workflows **without making the open-source recovery core artificially bad**.

Potential paid surfaces:
- Mac App Store / Setapp distribution and automatic updates.
- Polished premium UI / onboarding / diagnostics.
- Advanced per-app/per-site policy packs.
- Cross-device settings sync.
- Team-managed policy and deployment.
- Premium third-party IME integrations where separate modules are appropriate.
- Support / enterprise deployment / compliance tooling.
- Optional cloud services that do not require uploading raw keystrokes.

Commercial decisions are intentionally deferred until real retention and recovery frequency prove that users care.

---

## Non-goals throughout the roadmap

- Building a new Chinese IME.
- Replacing Apple/third-party candidate ranking.
- Uploading a global keylogger stream.
- Becoming a generic AI writing assistant.
- Optimizing for feature count over recovery reliability.

## North-star validation

The project deserves continued investment when users repeatedly experience:

> "I typed with the wrong input mode — and I didn't have to retype it."
