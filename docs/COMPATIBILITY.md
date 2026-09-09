# InputReplay compatibility model

InputReplay does not label an input method simply as "supported" or "unsupported".

Compatibility is tracked by the tuple:

```text
IME input source × host app × recovery direction × capability
```

A result proven in TextEdit must not be generalized to VS Code, Terminal, WeChat, Slack, or another host. Likewise, `ABC -> Pinyin` evidence does not automatically prove `Pinyin -> ABC`.

## Evidence levels

- **prepared** — code/path exists but has not been exercised on a real matching environment.
- **observed** — behavior has been run on a real Mac and the result recorded, but reliability is not yet strong enough for a product guarantee.
- **verified** — repeated evidence exists for the exact combination and the recovery/restore contract is considered reliable enough for the advertised support level.

Evidence must never be promoted merely because code compiles.

## Capability fields

Each exact tuple records whether we can reliably:

- select the input source;
- observe the IME's internal language/mode state;
- control that internal state;
- feed synthetic key replay;
- cancel composition safely;
- restore the original user text/state;
- verify the result of a recovery.

The effective recovery mode is derived from capabilities. Missing evidence fails closed.

## First compatibility targets

The order below is a test priority, not a support claim.

| IME / source family | First hosts | Direction | Current target |
| --- | --- | --- | --- |
| Apple ABC + Apple Pinyin | TextEdit | Latin -> IME | first real-Mac gate |
| Apple ABC + Apple Wubi | TextEdit | Latin -> IME | after Pinyin gate |
| Apple Pinyin | TextEdit | IME -> Latin | raw-key recovery research |
| Rime / Squirrel | TextEdit, VS Code | both | capability probe |
| WeChat Input | TextEdit, WeChat | both | internal-mode probe |
| Sogou | TextEdit, common editors | both | internal-mode probe |
| Terminal / shells | Terminal, iTerm-like hosts | both | conservative host-specific path |

## Third-party IME rule

Some third-party Chinese IMEs keep Chinese/English state inside the IME instead of exposing it as a distinct macOS TIS input source. InputReplay must not infer that state from brand name alone.

When internal state is unknown, behavior must degrade to one of:

1. non-destructive suggestion;
2. user-confirmed manual replay when the target state can be made explicit;
3. unsupported for that exact tuple.

It must not silently rewrite user text.

## Community compatibility reports

Future compatibility contributions should include, at minimum:

- macOS version;
- host app and version;
- exact input-source ID and localized name as reported by `InputReplayProbe list-sources`;
- recovery direction;
- whether replay reached composition/candidates;
- whether the original state could be restored after a deliberately failed verification;
- repeat count and observed failures.

A single successful attempt is `observed`, not automatically `verified`.
