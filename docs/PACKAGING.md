# Packaging and local test build

[中文](#中文) | [English](#english)

## 中文

### 推荐：一条命令完成环境检查、测试和打包

```bash
bash scripts/build-test-app.sh
```

它会依次执行：

1. macOS / Xcode / Swift / codesign 环境检查；
2. `swift test`；
3. Release Build；
4. 生成本地 `.app`；
5. ad-hoc codesign（除非显式跳过）；
6. 生成 zip。

产物：

```text
dist/InputReplay.app
dist/InputReplay-0.1.0-dev.zip
```

如果希望打包后直接打开：

```bash
OPEN_APP=1 bash scripts/build-test-app.sh
```

也可以使用 Makefile：

```bash
make doctor
make test
make package
```

### 单独打包

```bash
bash scripts/package-app.sh
```

启动：

```bash
open dist/InputReplay.app
```

### 首次权限

当前开发版需要 Accessibility 权限，用来：

- 验证当前焦点是不是原来的输入框；
- 排除 Secure / Password Field；
- 后续读取和恢复精确文本范围。

首次启动会显示 Onboarding。也可以从菜单栏重新打开首次使用指南。

如果监听没有启动：

1. 打开 InputReplay 菜单；
2. 点击“打开辅助功能权限…”；
3. 在 System Settings -> Privacy & Security -> Accessibility 中允许 **打包后的 `InputReplay.app`**；
4. 回到菜单点击“重新启动监听”。

> 开发阶段使用 ad-hoc 签名时，重新构建可能导致 TCC 权限需要重新确认。正式发布应使用稳定 Developer ID 签名。

### 使用自己的 Developer ID

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash scripts/package-app.sh
```

也可以覆盖版本和 Bundle ID：

```bash
VERSION=0.1.0 BUILD_NUMBER=10 BUNDLE_ID=com.example.InputReplay \
  bash scripts/package-app.sh
```

### 当前菜单栏功能

开发版已经包含：

- 监听 / Accessibility / Secure Input 状态；
- 当前输入法；
- 最近切换目标；
- 最近 Typing Burst 预览；
- 中文 / 英文目标输入源；
- `Control + Option + R` 安全 Smoke Replay；
- 设置窗口；
- 首次使用指南；
- 登录启动；
- Copy Diagnostics（默认不包含输入内容）；
- 预留 Undo Last Recovery 入口（只有未来出现 Verified Recovery Transaction 时才启用）。

### 第一轮真实 Mac Smoke Test

目标：**只验证 synthetic physical-key replay，不删除原文。**

1. 打开 TextEdit。
2. 切到 Apple ABC。
3. 输入：

```text
ceshiyixia
```

4. 不要点击别处，不要继续输入。
5. 切到 Apple 拼音。
6. InputReplay 应显示输入源切换 HUD。
7. 第一次按 `Control + Option + R`：只显示安全提示，不执行 Replay。
8. 保持焦点仍在原 TextEdit 输入框，再按一次 `Control + Option + R`。
9. InputReplay 会先执行 append-only safety check：
   - 当前必须还是同一个 App / 同一个 AX 输入框；
   - Burst 中不能包含 Backspace / Delete；
   - 不能包含方向键 / Home / End / PageUp / PageDown；
   - 不能包含 Return / Tab / Esc；
   - 不能包含 Cmd / Ctrl / Fn 系统快捷键；
   - 不能包含 Key Repeat。
10. 通过检查后，原来的 `ceshiyixia` **必须保留**，同一组安全物理键通过当前 Apple 拼音再次发送。
11. 观察是否出现正常的 Apple 拼音 composition / candidate。
12. 菜单中点击“复制诊断信息”，把结果和观察记录到 `docs/REAL_MAC_TEST_PLAN.md`。

如果你在第 7/8 步之间切换 App 或输入框，InputReplay 应拒绝 Replay。这是预期安全行为。

### 为什么还没有正式“删掉错误文本并自动恢复”

因为真实 IME Replay 后的文本/Composition Range 还必须在交互式 Mac 上验证。当前代码已经有 RecoveryTransaction / Restore / Undo 基础结构，但在无法证明精确 Restore Range 前，App 不会为了展示完整功能而冒险删除文本。

---

## English

### Recommended one-command local build

```bash
bash scripts/build-test-app.sh
```

This runs the local environment doctor, unit tests, release build, app packaging, code signing, and zip creation.

Outputs:

```text
dist/InputReplay.app
dist/InputReplay-0.1.0-dev.zip
```

To launch after packaging:

```bash
OPEN_APP=1 bash scripts/build-test-app.sh
```

Or use:

```bash
make doctor
make test
make package
```

### Accessibility

Grant Accessibility permission to the packaged `InputReplay.app`, not a transient SwiftPM executable path. The permission is needed for focus verification, secure-field exclusion, and future exact-range recovery.

### First real-Mac smoke test

1. Open TextEdit.
2. Select Apple ABC.
3. Type `ceshiyixia`.
4. Do not click elsewhere or type more.
5. Switch to Apple Pinyin.
6. The InputReplay source-switch HUD should appear.
7. Press `Control + Option + R` once. The first activation only shows a safety notice.
8. Keep focus in the same TextEdit field and press `Control + Option + R` again.
9. The append-only planner rejects destructive/navigation/shortcut/repeat events and revalidates the current AX focus.
10. The original ASCII text must remain unchanged while the same safe physical keys are replayed through Apple Pinyin.
11. Observe whether normal Pinyin composition/candidates appear.
12. Copy diagnostics and record the evidence in `docs/REAL_MAC_TEST_PLAN.md`.

Destructive recovery remains intentionally disabled until real IME output-range and restore behavior are verified on an interactive Mac.
