# Packaging and local test build

[中文](#中文) | [English](#english)

## 中文

### 目标

当前版本可以直接从 Swift Package 打出一个本地可运行的菜单栏 `InputReplay.app`。这不是正式发布签名流程，但足够用于真实 Mac 上验证：

- 菜单栏 App 是否能正常启动；
- Accessibility 权限；
- 真实输入源变化监听；
- 最近物理按键缓存；
- 输入法切换 HUD；
- `Control + Option + R` 非破坏 synthetic replay；
- Apple 拼音 / 五笔 / 第三方 IME 是否接受 replay。

### 本地打包

在仓库根目录执行：

```bash
bash scripts/package-app.sh
```

产物：

```text
dist/InputReplay.app
dist/InputReplay-0.1.0-dev.zip
```

启动：

```bash
open dist/InputReplay.app
```

### 首次权限

InputReplay 当前需要 Accessibility 权限来进行全局按键观察和后续文本恢复验证。

启动后：

1. 点击菜单栏 InputReplay 图标；
2. 如果显示“辅助功能：需要授权”，点击“打开辅助功能权限…”；
3. 在 System Settings -> Privacy & Security -> Accessibility 中允许 InputReplay；
4. 回到菜单点击“重新启动监听”。

开发阶段使用 ad-hoc 签名时，重新构建可能导致 macOS 把新二进制视为新的权限主体。如果权限表现异常，可先删除旧授权再重新添加。正式发布会使用稳定 Developer ID 签名。

### 使用自己的 Developer ID

如果本机 Keychain 已有 Developer ID Application 证书：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash scripts/package-app.sh
```

也可以覆盖：

```bash
VERSION=0.1.0 BUILD_NUMBER=10 BUNDLE_ID=com.example.InputReplay \
  bash scripts/package-app.sh
```

### 当前最重要的测试

1. 打开 TextEdit。
2. 切到 Apple ABC。
3. 输入一小段拼音字母，例如 `ceshiyixia`。
4. **不要继续输入。**
5. 切到 Apple 拼音。
6. InputReplay 应出现切换 HUD。
7. 在 6 秒内按 `Control + Option + R`。
8. InputReplay **不会删除原来的 `ceshiyixia`**，只会把同一组物理键通过当前拼音输入法重新发送。
9. 观察是否正常出现拼音 composition / candidate。
10. 把诊断信息和测试结果记录到 `docs/REAL_MAC_TEST_PLAN.md` 的 evidence 表。

这一阶段故意不做 destructive recovery。只有 replay 本身和恢复范围都经过真实验证后，才会开启“删除错误文本 -> replay -> 一键 Undo”的正式路径。

---

## English

### Goal

The current branch can package a locally runnable menu-bar `InputReplay.app` directly from Swift Package Manager. This is not the final signed release pipeline, but it is enough to validate on a real Mac:

- menu-bar launch;
- Accessibility permission;
- actual input-source change observation;
- recent physical-key buffering;
- source-switch HUD;
- non-destructive `Control + Option + R` synthetic replay;
- whether Apple Pinyin, Wubi, or third-party IMEs accept replay.

### Package locally

From the repository root:

```bash
bash scripts/package-app.sh
```

Outputs:

```text
dist/InputReplay.app
dist/InputReplay-0.1.0-dev.zip
```

Launch:

```bash
open dist/InputReplay.app
```

### First-run permission

InputReplay currently needs Accessibility permission for global key observation and later text-recovery validation.

1. Open the InputReplay menu-bar item.
2. If it shows `Accessibility: Required`, choose `Open Accessibility Settings…`.
3. Allow InputReplay in System Settings -> Privacy & Security -> Accessibility.
4. Return to the menu and choose `Restart Monitoring`.

During development, ad-hoc signing can cause rebuilt binaries to be treated as new permission subjects. A stable Developer ID signature will be used for distribution.

### Use a Developer ID

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash scripts/package-app.sh
```

### Most important test now

1. Open TextEdit.
2. Select Apple ABC.
3. Type a short Pinyin sequence such as `ceshiyixia`.
4. Do not type anything else.
5. Switch to Apple Pinyin.
6. InputReplay should show a source-switch HUD.
7. Within 6 seconds press `Control + Option + R`.
8. InputReplay does **not** delete the original ASCII text; it only re-sends the same physical keys through the newly selected IME.
9. Observe whether normal Pinyin composition / candidates appear.
10. Record the evidence in `docs/REAL_MAC_TEST_PLAN.md`.

Destructive recovery remains intentionally disabled until replay and rollback-range safety are verified on a real interactive Mac.
