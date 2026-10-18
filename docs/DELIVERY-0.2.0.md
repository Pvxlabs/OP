# ChatGPT Native 0.2.0 (2) — 本机正式交付

2026-10-19（Asia/Shanghai）。基于 v0.1.0 / c69d62b 的本地版本升级。
版本基线标签：`v0.2.0`；本文件随交付提交保存。未推送、公开发布或公证分发。

## 交付范围

- 本地回复保护：公开 WebKit DOM 观察、SQLite 增量快照、身份核对、错误覆盖保护及原生恢复。
- 持久网站数据与有界会话复用；页面结束与已确认完整严格区分。
- 非异常状态改为“本地副本 → 查看保护状态…”主动查看；主窗口无左下角常驻覆盖层。
- 仅源码、Xcode 项目、合成 fixtures/测试脚本、文档及既有 Codex Run 配置纳入 Git。
- 构建包、SQLite/WAL/SHM、运行日志、UI 截图、安装回执、本机配置与回退包留在忽略目录。

## 构建与安装

复用 `build/StatusUI/build-final.log` 的 Xcode Release 成功构建，不重新构建。
安装路径：`/Applications/ChatGPT Native.app`。
Bundle ID：`local.personal.ChatGPTNative`；版本 0.2.0，build 2。
应用包使用本地 ad hoc 签名，`codesign --verify --deep --strict` 通过。
已安装包的逐文件 SHA-256 与此前验收候选包完全一致。
主可执行文件 SHA-256：`bea98cac3ce15c4e5f05ea9ac77d70b1ed9e5cbbf1bfe58dfd9ac7f641c51de1`。

通过原生 Cmd-Q 正常退出目标 ChatGPT Native 后，使用
`ditto --rsrc --extattr --acl` 备份旧包并安装新包。
旧包位于忽略目录 `build/Delivery-0.2.0/ChatGPT Native 0.1.0 rollback.app`。
此回退包仅含应用，不包含网站数据或用户快照；未测试版本回退。
运行进程路径核对为 `/Applications/ChatGPT Native.app/Contents/MacOS/ChatGPT Native`。

## 定向验收

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| 正式安装包与候选包一致 | PASS | 5 个包内文件逐一指纹一致，版本、bundle ID 和签名校验通过 |
| 网站登录保持 | PASS | 从 /Applications 启动后直接读取原合成会话，无重新登录 |
| 聊天收发 | PASS | 仅在已有合成会话发送一次简短验收提示，收到 DELIVERY_020_OK，生成停止 |
| 左下角无常驻提醒 | PASS | 正式安装版聊天截图与实际 AX 检查 |
| 保护状态与本地副本 | PASS | 原生菜单详情显示保存启用、观察器安装、6 条回复；恢复视图可读取旧合成正文 |
| 既有快照保留 | PASS | 安装前 5 条全部保留，相同 ID、正文长度和 SHA-256；新回复另增 1 条，总计 6 条 |
| 用户配置保留 | PASS | 安装前后、首次启动之前的配置文件指纹完全一致；未切换采集开关或清理任何数据 |
| SQLite 完整性 | PASS | 只读 quick_check 为 ok |
| 此次本机交付阻塞 | BLOCKED：无 | 安装与定向验收通过 |
| 上传下载、长时压力等完整重测 | 未验证 | 按用户要求不重复；复用既有 46 项回归及真实 UI 证据 |
| HTTP 403 根因或修复 | 未验证 | 仅保留此前诊断，不扩大调查，不宣称修复 |
| 公证及公开分发资格 | 未验证 | 本轮为个人本机交付 |

此前核心回归 46 项 PASS（43 core + 3 跨进程 restart），证据目录
`build/ProtectionTests/run-20261019-073757/`。提示优化证据见
`build/StatusUI/verification.md`。未把此前证据当作本轮重新执行的测试。

本轮回执和截图位于忽略目录 `build/Delivery-0.2.0/`：
`preinstall.json`、`installation.json`、`postlaunch.json`、
`installed-chat.png`、`installed-status.png`。只导出脱敏元数据，不导出私聊正文、
Cookie、Token 或认证头；未读取或迁移认证数据库。

网站数据继续由同一 bundle ID 的默认 WKWebsiteDataStore 保存；快照仍位于
`~/Library/Application Support/local.personal.ChatGPTNative/Snapshots/replies.sqlite`。
未清理、重置或搬迁数据。未操作旧 Validation 工作实例、ChatGPT Classic、
Codex Desktop 或其他应用。

## 仍然存在的限制

DOM 结束标志不能证明服务端生成/持久化完整；当前用户消息缺少经过验证的稳定 ID，
不编造全文归档。工具卡片、附件、图片和分支结构不保证完整恢复。最后尚未提交的
采集批次仍可能丢失。上述边界保持原验收结论，未因本机安装而提升为 PASS。
