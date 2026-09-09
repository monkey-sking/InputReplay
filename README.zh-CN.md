# InputReplay

**打错输入法，也不用重打。**

中文 | [English](README.md)

InputReplay 是一个开源的 macOS 输入恢复层。它会在内存中短暂保留最近的按键事件历史；当你因为输入法状态错误而打出一段错误内容时，InputReplay 的目标是：安全定位并回滚受影响文本，切换到目标输入源，再把原始物理按键重新交给你正在使用的输入法处理。

它**不是**一个新的输入法，不是 AI 改写工具，也不准备把自己做成另一个“自动切换输入法”应用。

## 为什么做这个项目

现在大多数输入法工具解决的是“预防”：

- 记住某个 App 应该使用中文还是英文；
- 在输入前自动切换输入源；
- 在屏幕上提示当前输入状态。

InputReplay 关注的是另一个问题：**错误已经发生以后，怎么不用删掉重打。**

例如：

```text
ABC:     ceshiyixia
                    ↓ 恢复
拼音:    测试一下
```

这里最重要的一点是：InputReplay 不自己拿词库把 `ceshiyixia` 翻译成“测试一下”。它会把用户刚才真实按下的物理按键重新 Replay 给用户现有的拼音输入法，让原输入法自己继续处理候选词、个人词库、人名、学习结果和用户偏好。

同一套架构后续可以通过能力适配器扩展到拼音、五笔、第三方中文输入法以及其他输入系统。

## 核心流程

```text
捕获按键
  ↓
检测 / 建议
  ↓
建立快照
  ↓
回滚错误文本
  ↓
切换输入源
  ↓
Replay 原始物理按键
  ↓
验证 Replay 产生的精确文本范围
  ↓
继续 / 恢复 / Undo
```

## 产品原则

- **Recovery First** — 优先解决“已经打错了怎么办”，而不是试图预测用户每一次输入法切换。
- **Fail Closed** — 无法证明恢复路径安全时，只提示，不修改文本。
- **Always Reversible** — 每一次破坏性修改都必须属于一个明确的恢复事务，并提前具备可用的 Restore 方案。
- **Local Only** — 最近按键历史只短暂存在内存中，核心应用不落盘、不上传。
- **Replay 以物理按键为准** — Unicode 字符投影只用于检测和边界分析，真正 Replay 仍使用物理 keyCode + flags。
- **Capability Based** — 兼容性按 `输入法 × Host App × 方向 × 能力` 判断，不根据品牌名拍脑袋。
- **Zero Surprise** — 输入源切换是强信号，但绝不是默认自动改字的许可。

## 当前已经实现

目前核心代码已经包含：

- 物理键事件捕获，并标记 InputReplay 自己生成的 Synthetic Event；
- 15 秒 / 128 个事件的短期内存 Ring Buffer；
- 通过 macOS TIS 发现、选择和监听真实输入源变化；
- Input Source Epoch 与 Typing Burst 分段；
- 输入源切换防抖；
- 短时 Recovery Suggestion Signal；
- 用户继续输入后立即让旧 Suggestion 失效；
- 同时保留物理 keyCode 和事件当时的 Unicode 字符投影；
- 标点、空格、Backspace 与强边界投影；
- 可由不同输入法 Adapter 配置的 Boundary Policy；
- Accessibility 焦点文本 Snapshot / Replacement 基础能力；
- Secure Field 排除；
- RecoveryTransaction + PreMutationSnapshot；
- Fail-Closed 的 RecoveryCoordinator；
- 要求 Verifier 提供“Replay 后精确输出范围”，不允许根据按键数量猜恢复范围；
- Synthetic physical-key Replay Engine；
- `Prepared / Observed / Verified` 兼容证据登记体系；
- 非破坏性的诊断 / Probe CLI；
- macOS GitHub Actions CI；
- 核心安全和状态机测试。

## 当前验证状态

### 已在 CI 中 Verified

当前 GitHub-hosted macOS 环境为：

```text
macOS 15.7.9
Xcode 16.4
Swift 6.1.2
```

已经验证：

- Swift Package Resolve 成功；
- Core Build 成功；
- Unit Tests 全部通过；
- 输入源切换状态机测试通过；
- Suggestion 过期 / 新输入失效规则测试通过；
- RecoveryCoordinator 安全路径测试通过；
- 已知精确 Replay Range 时的 Restore 测试通过；
- 未知 Replay Range 时拒绝猜测恢复测试通过；
- 标点 / 空格 / Backspace Projection 测试通过。

### 仍需要真实交互式 Mac 验证

Hosted CI 无法模拟真实的“焦点编辑器 + macOS 输入法组合态 / 候选框”。所以下面这些目前仍然是 **Prepared**，不能称为 **Verified**：

1. 用户真实通过 Control-Space、Caps Lock、中英切换等方式操作时，TIS 变化监听是否稳定；
2. TextEdit 中 AX Snapshot / Replacement 的真实表现；
3. Apple 拼音是否会把 Synthetic physical-key Replay 当成正常输入，进入正常拼音组合态 / 候选态；
4. 组合态或提交后，是否能够可靠识别 Replay 产生的精确文本范围；
5. 故意制造验证失败时，是否能无重复、无残留地恢复原文；
6. 成功 Recovery 后，InputReplay 自己的 Undo 是否可以完整恢复原状态。

第一个实机验证目标刻意限定为：

```text
Host:      TextEdit
Source:    Apple ABC
Target:    Apple 拼音 - 简体
Direction: Latin -> IME
```

详细验收规则见 [`docs/REAL_MAC_TEST_PLAN.md`](docs/REAL_MAC_TEST_PLAN.md)。

## 当前架构

```text
InputEventMonitor
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

## 输入法兼容策略

InputReplay 不会简单写一个“这个输入法支持 / 不支持”的表格。

兼容性按下面这个精确组合记录：

```text
输入源 × Host App × Recovery 方向 × Capability
```

每个组合分别验证 InputReplay 是否能可靠做到：

- 识别并选择 macOS 输入源；
- 必要时观察输入法内部的中文 / 英文状态；
- 必要时控制该内部状态；
- 接受 Synthetic physical-key Replay；
- 安全取消 Composition；
- 恢复原始用户文本和输入状态；
- 验证 Recovery 的真实结果。

证据缺失或状态不确定时，一律 Fail Closed。

首批兼容优先级：

1. TextEdit 中 Apple ABC -> Apple 拼音；
2. Apple 五笔；
3. 中文 IME -> ABC 方向恢复；
4. Rime / Squirrel；
5. 微信输入法；
6. 搜狗输入法；
7. Electron 应用与终端类 Host。

更完整的模型见 [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md)。

## 空格、标点和 Backspace 怎么处理

这部分不会做成一个全局统一的死规则。

InputReplay 会把“最近真实按键历史”和“用于检测的可见文本投影”分开：

- **Replay History**：保留用户真实 keyCode / flags，不重写；
- **Typing Projection**：根据当时的 Unicode 投影推算最近输入片段，用于候选检测和文本边界判断。

例如：

```text
hello,wo jintian
```

对拼音类 Policy，可以把标点当边界，但允许空格留在最近候选段里：

```text
wo jintian
```

对代码型 IME，可以把空格也当更强的提交边界：

```text
jintian
```

Backspace 会影响可见文本投影，但不会删除 Raw Replay History，因为 Replay 必须尽量还原用户实际的按键过程。

如果出现 Cmd-V、Forward Delete、Escape 或其他不能仅靠最近 key events 安全重建可见文本的操作，事件投影会降级为“不可靠”，后续必须依赖 AX / Host 状态，不允许猜。

## 安全契约

第一条：

> **如果 InputReplay 在修改用户可见文本之前，无法建立可靠的 Restore 方案，就不得执行自动破坏性修改。**

第二条同样重要：

> **如果 InputReplay 无法识别 Replay 后实际占据的精确文本 / Composition Range，就不得通过猜长度来恢复。**

宁可退化成 Manual Recovery 或 Suggestion，也不要为了“智能”而冒险丢用户文本。

## Developer Probe

当前 Probe 故意不开放完整破坏性 Recovery 命令。

现有命令：

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

其中：

- `diagnose`：打印 macOS、Accessibility、前台 App、当前输入源和全部输入源；
- `watch-source`：监听 macOS 实际输入源变化；
- `capture`：短期内存捕获 keyCode、Unicode 投影、Repeat 和输入源；
- `snapshot-before-caret N`：通过 Accessibility 读取焦点光标前 N 个字符，不修改文本。

`capture` 仅用于开发验证，不要在密码框、Secure Field 或私人敏感内容附近运行。

## 为什么现在还没有“自动修正”

因为误判一次的成本远高于少自动修正十次。

当前产品优先级是：

```text
Manual Recovery
    ↓
Switch Suggestion
    ↓
高置信度 Suggest
    ↓
最后才考虑 Auto Fix
```

在真实用户数据证明误判率足够低之前，不会把“检测到像拼音”直接等价成“可以修改用户内容”。

## Roadmap

见 [`ROADMAP.md`](ROADMAP.md)。

Roadmap 以**验证门槛**组织，而不是以“做了多少功能”组织。

## 产品与技术规格

见 [`docs/Product_Spec_v0.3.md`](docs/Product_Spec_v0.3.md)。

## License

InputReplay Core 使用 **Mozilla Public License 2.0 (MPL-2.0)**，见 [`LICENSE`](LICENSE)。

MPL-2.0 要求对 MPL 覆盖源文件的修改继续开放，同时允许项目与独立授权的模块组合。这给项目保留了未来采用“开源核心 + 官方付费发行 / 商店版本 / 服务 / 集成 / Premium Module”的空间。

InputReplay 名称、Logo 和官方发行身份不随源码许可证自动授权，见 [`TRADEMARKS.md`](TRADEMARKS.md)。

## 项目状态

目前处于**早期实现 / 技术验证阶段**。

核心架构、安全契约、CI 和状态机基础已经落地，但真实 IME Recovery 兼容性仍然必须按具体组合逐项验证。

项目统一使用：

```text
Prepared  = 已准备，但没有真实运行证据
Observed  = 已在真实环境观察到行为
Verified  = 达到明确重复验证门槛
```

不会把“代码写出来了”当成“功能已经可用”。
