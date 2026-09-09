# InputReplay Real-Mac Test Checklist

[中文](#中文) | [English](#english)

## 中文

这份表用于把真实环境结果从“我试了一下感觉可以”变成可复现证据。

### 测试前

- 使用最新 `dev/core-replay-spike`。
- `bash scripts/package-app.sh` 后运行 `dist/InputReplay.app`。
- 已授权 Accessibility，菜单显示“监听：已开启”。
- 只在测试文本中使用，不要在密码、账号、私人聊天或重要文档里测试。
- 如果菜单显示锁形图标 / Secure Input，请确认捕获和 Replay 都被拒绝。

### 每个组合都记录

| 字段 | 记录内容 |
|---|---|
| macOS | 版本号 |
| InputReplay | commit SHA / 版本 |
| Host App | 名称 + 版本 |
| Source | 原输入源 ID + 名称 |
| Target | 目标输入源 ID + 名称 |
| Direction | Latin -> IME / IME -> Latin |
| Switch observed | Yes / No |
| Burst preview correct | Yes / No / Partial |
| Synthetic replay accepted | Yes / No |
| Composition / candidate normal | Yes / No / N/A |
| Original text preserved in smoke test | Yes / No |
| Secure input blocked | Yes / No / N/A |
| Result | Prepared / Observed / Verified / Unsupported |
| Notes | 异常、延迟、候选框、内部中英状态等 |

### 第一优先级：Apple 输入法

| Host | Source -> Target | Switch | Preview | Replay | Candidate | 结果 |
|---|---|---:|---:|---:|---:|---|
| TextEdit | Apple ABC -> Apple 拼音 | ☐ | ☐ | ☐ | ☐ | Prepared |
| TextEdit | Apple ABC -> Apple 五笔 | ☐ | ☐ | ☐ | ☐ | Prepared |
| TextEdit | Apple 拼音 -> Apple ABC | ☐ | ☐ | ☐ | N/A | Prepared |
| Safari 普通文本框 | ABC -> Apple 拼音 | ☐ | ☐ | ☐ | ☐ | Prepared |
| Chrome 普通文本框 | ABC -> Apple 拼音 | ☐ | ☐ | ☐ | ☐ | Prepared |
| VS Code 编辑器 | ABC -> Apple 拼音 | ☐ | ☐ | ☐ | ☐ | Prepared |
| Terminal | ABC -> Apple 拼音 | ☐ | ☐ | ☐ | ☐ | Prepared |

### 第二优先级：第三方 IME

不要因为能在 TIS 列表看到输入源就标记为“支持”。第三方输入法可能在一个 macOS input source 内部再维护中文 / 英文模式。

| Host | Target IME | 能识别 Source | 内部中英状态 | Replay | Candidate | 结果 |
|---|---|---:|---:|---:|---:|---|
| TextEdit | Rime / Squirrel | ☐ | ☐ | ☐ | ☐ | Prepared |
| TextEdit | 微信输入法 | ☐ | ☐ | ☐ | ☐ | Prepared |
| TextEdit | 搜狗输入法 | ☐ | ☐ | ☐ | ☐ | Prepared |
| Chrome | Rime / Squirrel | ☐ | ☐ | ☐ | ☐ | Prepared |
| VS Code | Rime / Squirrel | ☐ | ☐ | ☐ | ☐ | Prepared |

### Privacy / Boundary 必测

| 场景 | 期望 | 结果 |
|---|---|---|
| 密码输入框 | 不进入 Burst，不允许 Replay | ☐ |
| Secure Event Input | 菜单显示保护状态，不捕获、不 Replay | ☐ |
| 输入框 A 打字 -> 点击 B -> 切输入法 | 不提示 A 的 Burst | ☐ |
| App A 打字 -> 切 App B -> 切输入法 | 不提示 A 的 Burst | ☐ |
| 切输入法后继续输入新字符 | 旧 Suggestion 立即失效 | ☐ |
| 睡眠 / 唤醒 | 最近 Buffer 清空 | ☐ |
| 手动清空 Buffer | 最近 Buffer 清空 | ☐ |
| InputReplay synthetic replay | 不回流进物理输入历史 | ☐ |

### Apple ABC -> 拼音 Smoke Test

建议固定用同一组样本：

```text
ceshiyixia
wojintianquchifan
beijing2026
nihao,world
```

第一轮只判断：

1. Burst 是否准确；
2. 切换是否触发；
3. `Control + Option + R` 是否把物理键送进 Apple 拼音；
4. 是否出现正常组合态 / 候选；
5. 原 ASCII 是否完全未被修改。

不要在这一轮测试 destructive recovery。

### 把结果发回来

菜单栏选择“复制诊断信息”，再补充：

```text
Host:
Source -> Target:
Typed sample:
What appeared after Control+Option+R:
Candidate window appeared: Yes/No
Anything duplicated/lost:
```

---

## English

Use this checklist to turn compatibility testing into reproducible evidence instead of informal “seems to work” reports.

### Before testing

- Use the latest `dev/core-replay-spike`.
- Run `bash scripts/package-app.sh`, then `dist/InputReplay.app`.
- Grant Accessibility and confirm `Monitoring: On`.
- Test only in disposable text, never passwords, private chats, credentials, or important documents.
- A lock icon / Secure Input state must block both capture and replay.

### Evidence fields

For each tuple record macOS version, InputReplay commit, host app/version, source and target input-source IDs, direction, switch observation, burst accuracy, synthetic replay acceptance, candidate/composition behavior, privacy behavior, and final `Prepared / Observed / Verified / Unsupported` status.

### Priority order

1. TextEdit: Apple ABC -> Apple Pinyin.
2. TextEdit: Apple ABC -> Apple Wubi.
3. TextEdit: Apple Pinyin -> Apple ABC.
4. Safari / Chrome ordinary fields.
5. VS Code and Terminal.
6. Rime / Squirrel.
7. WeChat Input.
8. Sogou.

Third-party IMEs must not be marked supported just because macOS exposes an input-source ID; internal Chinese/English modes may be separate from TIS state.

### Privacy boundaries to test

- password field: no burst, no replay;
- Secure Event Input: protected state, no capture, no replay;
- type in field A, click field B, then switch source: never surface field A's burst;
- type in app A, move to app B, then switch source: never surface app A's burst;
- new physical typing after a switch invalidates the previous suggestion;
- sleep/wake and manual privacy reset clear recent state;
- synthetic replay never feeds back into physical-input history.

### Smoke-test samples

```text
ceshiyixia
wojintianquchifan
beijing2026
nihao,world
```

For the current build, only verify that the previous burst is correct, the actual source switch is observed, `Control + Option + R` is accepted by the target IME, normal composition/candidates appear, and the original ASCII remains untouched.

Do not test destructive recovery yet.
