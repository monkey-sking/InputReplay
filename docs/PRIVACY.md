# InputReplay Privacy Architecture

[中文](#中文) | [English](#english)

## 中文

### 默认原则

InputReplay 的核心功能不需要把用户输入内容发送到服务器。当前开源核心按照下面的约束实现：

- 最近按键历史只存在于内存中；
- 默认窗口约 15 秒 / 128 个事件；
- 不把 Raw Key History 写入磁盘；
- 不上传 Raw Key History；
- 密码框 / Secure Field 不进入缓存；
- macOS Secure Event Input 开启时停止捕获和 Replay；
- Sleep / Wake、监听重启等生命周期边界会清空最近输入状态；
- InputReplay 自己产生的 synthetic events 不进入用户物理输入历史；
- “复制诊断”默认只复制计数、输入源、Host App、可靠性等元数据，不复制实际文本。

### 为什么仍然需要 Accessibility

InputReplay 必须知道当前焦点是否仍是原来的可编辑控件，并在未来 Verified Recovery 中读取/修改受影响的精确文本范围。Accessibility 权限用于这些本机交互，不代表 InputReplay 会把输入上传。

### 诊断数据

当前开发版没有默认远程遥测。未来如果加入可选 Analytics，应遵守：

- 默认不记录 Raw Text / Raw Key Sequence；
- 只记录内容无关的计数，例如 Recovery 成功/失败、Undo、Suggestion 接受等；
- 明确区分本地诊断和远程统计；
- 用户可关闭；
- 新增任何上传行为前必须更新本文档和 UI 说明。

### 第三方输入法

Replay 会把用户刚才真实的物理按键重新发送给当前选择的目标输入法。第三方输入法自身如何处理、记录或同步这些输入，由该输入法自己的隐私政策决定；InputReplay 无法替第三方输入法提供隐私保证。

---

## English

### Defaults

InputReplay's core recovery model does not require sending typed content to a server. The open-source core follows these constraints:

- recent key history is memory-only;
- the default window is roughly 15 seconds / 128 events;
- raw key history is not persisted to disk;
- raw key history is not uploaded;
- password / secure fields are excluded;
- capture and replay stop while macOS Secure Event Input is active;
- lifecycle boundaries such as sleep/wake and listener rebuilds clear recent input state;
- InputReplay's own synthetic events never enter physical-user input history;
- copied diagnostics contain metadata by default, not actual typed text.

### Why Accessibility is needed

InputReplay needs to verify that focus is still in the original editable element and, for future verified recovery paths, read or replace the exact affected local text range. Accessibility permission enables this on-device interaction; it does not imply remote upload.

### Diagnostics and analytics

The current development build has no default remote telemetry. If optional analytics are introduced later, they should remain content-free by default and require corresponding documentation/UI updates before shipping.

### Third-party IMEs

Replay sends the user's original physical keys through the selected target IME. A third-party IME may have its own logging, sync, or cloud behavior governed by that IME's privacy policy; InputReplay cannot make privacy guarantees on behalf of third-party input methods.
