# Contributing to InputReplay

Thanks for helping improve InputReplay.

## Project priority

InputReplay is a system-level input utility. Reliability and reversibility matter more than feature count.

Before proposing a change, keep these rules in mind:

1. **Never mutate user-visible text without a recovery plan.**
2. **Fail closed** when IME/app state is uncertain.
3. **Do not persist raw keystrokes** in the open-source core.
4. **Do not claim IME compatibility without observed evidence.**
5. Keep IME-specific behavior behind adapters/policies rather than scattering brand-specific branches through the core engine.
6. A user input-source change is a signal, not permission to rewrite text automatically.

## Good first contributions

- Reproduction cases for specific IME × app combinations.
- Compatibility probes and test fixtures.
- Safe Accessibility fallbacks.
- Recovery transaction tests.
- Documentation and diagnostic improvements.

## Compatibility reports

Please include:

- macOS version;
- Mac architecture;
- input method and version;
- source/target input mode;
- host app and version;
- exact reproduction steps;
- whether input-source switching worked;
- whether synthetic replay entered normal IME composition;
- whether Undo/Restore worked;
- whether the behavior was observed or inferred.

Never attach passwords, private messages, or raw keystroke logs containing sensitive content.

## Development workflow

- Keep changes focused.
- Add tests for pure logic where possible.
- Mark macOS/IME behavior as `prepared`, `observed`, or `verified`; do not call untested behavior verified.
- Prefer minimal reliable changes over broad refactors.

## Licensing

By submitting a contribution, you agree that your contribution is licensed under the repository's Mozilla Public License 2.0 unless explicitly stated otherwise for a separately licensed file or dependency.

See `docs/LICENSING.md` for the project's licensing strategy.
