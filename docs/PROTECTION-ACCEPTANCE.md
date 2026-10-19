# ChatGPT Native 0.2.0 (2) — 本地回复保护验收

2026-10-19。从 v0.1.0 / c69d62b 升级；最终本机安装与版本基线见
`DELIVERY-0.2.0.md`。已安装的 /Applications/ChatGPT Native.app 为 0.2.0 (2)。
本报告保留此前开发与隔离验证的证据，交付阶段未重复完整测试。

## 实现与证据边界

- 独立 WKContentWorld + WKUserScript + WKScriptMessageHandlerWithReply，主框架、
  HTTPS chatgpt.com 来源及当前会话路径均校验；提交确认在 SQLite 事务完成之后返回。
- MutationObserver 增量传输变化的消息；空闲时只检查 SPA 路径，不周期扫描全部正文。
  当前结构使用主消息 UUID、会话选择标识、明确 assistant 单元及搜索引用相互核对。
  流式期间辅助 selection-message-id 尚未出现，出现后再做一致性校验。
- SQLite WAL / synchronous FULL，按会话和消息 UUID 唯一合并。SHA-256 指纹。
  完整或页面结束的副本遇到空白、错误、不同正文时保留原副本；不同文本明确显示差异。
- `pageEnded` 与 `complete` 严格分开。DOM complete + 1.5 秒稳定正文只产生
  “页面结束，完整性未确认”；生产观察器不会自动产生“已确认完整”。用户停止标记
  持久保留，后续页面 complete 也不会把它自动认定为完整。
- 原生恢复 sheet、最近会话菜单、Cmd-Shift-L；本地文本不注入官方页面、不回传服务。
- 每窗口最多 3 个 WebView，LRU 淘汰。窗口 owner 延迟到挂载时创建；视图重建不重新
  创建 owner。仅启动时首个窗口恢复最近会话，其后新窗口打开主页。
- 默认持久 WKWebsiteDataStore 保持不变。快照与网站数据、不同 bundle ID 的存储隔离。

公开 API 依据：[Apple WKContentWorld](https://developer.apple.com/documentation/webkit/wkcontentworld)。
未拦截 fetch、未访问 React 内部状态、未调用 ChatGPT 私有接口，未读取认证数据。

## 合成回归与构建

命令：`./script/test-protection.sh`；`./script/build_and_run.sh --build`。
最终回归：**46 项 PASS**（core 43 + 跨进程 restart 3）。
证据目录：`build/ProtectionTests/run-20261019-073757/`。
正式 Release 的版本为 0.2.0 (2)，bundle ID 为 `local.personal.ChatGPTNative`；
`codesign --verify --deep --strict` 通过，构建包约 880 KiB。

| 验收项 | 状态 | 证据 |
| --- | --- | --- |
| 可信完整输入的持久保存及错误覆盖保护 | PASS | 实际 SQLite 事务，空白、占位、读取失败及不同文本保护 |
| 实际 WKWebView DOM 桥接 | PASS | 使用与实际网页相同的验证结构；无 .markdown 假设 |
| 真实流式期间辅助 ID 缺失 | PASS | 合成 DOM 延迟提供辅助 ID，正文仍逐步持久化 |
| 刷新及按 ID 去重 | PASS | 实际 WKWebView.reload；记录无重复，正文指纹保持 |
| HTTP 429 保护 | PASS | 临时 127.0.0.1 HTTP 端点实际返回 429；公开导航代理观测到状态，本地正文保留 |
| 流式中断与用户停止 | PASS | 退役 WebView、跨进程中断及 Stop 后 DOM complete 均不误标完整 |
| 身份/顺序/差异处理 | PASS | 无效 ID、角色、旧序列、跨会话同 ID、100 条前置历史和正文冲突 |
| 存储限制/清理/暂停/重新启用 | PASS | 会话数、消息数、逻辑大小、年龄；清除后不立即重建，显式启用后重新采集 |
| 跨进程持久化 | PASS | 两个独立宿主进程读回原完整内容；旧流式记录为 interrupted |
| 原生恢复视图 | PASS | 独立预览及实际 Xcode 应用重启均观察到本地副本；清除确认框已展示并取消 |
| WebView 复用/视图重建/新窗口 | PASS | 41 次热选择、20 次 ContentView 重建；owner 仅创建一次；其后新窗口打开主页 |
| Xcode 正式 Release 构建 | PASS | Xcode 27.1，Swift 6，BUILD SUCCEEDED；无额外运行时依赖 |

测试 HTTP 端点仅在回归期间运行，脚本退出自动停止。应用不依赖本地服务器。
Xcode 的 CoreDevice/CoreSimulator 环境诊断未阻止 macOS 构建；未修改其他工具链环境。

## 真实官方网站验证

Chrome 因 Cloudflare 验证受阻，未绕过。用户在独立 WKWebView 测试配置中正常登录。
真实 Xcode 应用使用隔离验证 bundle ID `local.personal.ChatGPTNative.ProtectionTests`
和独立产品名；默认网站数据在此测试配置中保持持久，未导入其他客户端 Cookie。

测试仅对会话 `SYNTHETIC_CONVERSATION_A` 发送合成输入。
验证应用后来被用于工作会话后，停止该实例的自动操作，剩余检测转回固定合成 URL 的
独立宿主。此前自动重启针对验证实例执行；发现其已被用于工作聊天后不再刷新或重启它。
没有向工作会话发送合成测试输入。诊断只导出目标测试会话的脱敏元数据。

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| 实际身份/角色/正文范围 | PASS | 主 ID、会话选择 ID、assistant 单元；未依赖旧版 author-role 或 .markdown |
| 网站登录保持 | PASS | 正常退出重启测试宿主及实际隔离 Xcode 应用，重新打开目标会话无登录框 |
| 实际回复持久保存 | PASS | SYNTHETIC_MESSAGE_A，2476 字符，SHA-256 1b338919829ca0ff8ce51dac23742a222f198c2434803949d39a1cb8ae886f2f |
| 发送下一条后的副本保护 | PASS | 上述副本保留；后续 SYNTHETIC_MESSAGE_B 在最终流式测试全程也保持原指纹 |
| 实际增量持久化 | PASS | SYNTHETIC_MESSAGE_C，观察到 25 次持久快照，81 -> 1558 字符，streaming -> unverified -> pageEnded |
| 正常重启后官方正文与本地读回核对 | PASS | 上述消息仍存在；官方 DOM 与 SQLite 的 SHA-256 均为 cd85ba930148e66d67c33121cdaf92688e13d79cf1095147b5eaf8bf152e68c8；1558 字符、重复记录 0、无登录框 |
| 原始网页消失故障的根因修复 | 未验证 | 本功能为本地防护；未建立或宣称上游故障因果链 |
| 自动证明生成完整/服务端持久化终态 | BLOCKED | DOM 结束标记不足以证明；保守保存并保持完整性未确认 |
| 用户提问全文归档 | BLOCKED | 当前 DOM 未暴露经过验证的稳定用户消息 ID，主动跳过 |
| 任务卡片、附件、图片及官方分支完全归档 | 未验证 | 当前只保存可识别回复的可见文本，不恢复互动卡片或附件对象 |
| 本轮上传/下载/替代 OAuth 回归 | 未验证 | 原代理功能保留；0.1.0 证据不冒充本轮真实回归 |
| 长时间、多窗口内存压力 | 未验证 | 有界视图/记录策略和释放路径已测，不等于长期内存资格验收 |

元数据证据：`live-before-send.json`、`live-store-timeline.jsonl`、
`live-incremental-verified.jsonl`、`live-proof-summary.json`、`live-after-restart.json` 位于忽略的
`build/ProtectionTests/`。正文只在本机快照库中；不提交原始运行证据或聊天数据库。
界面证据：`build/ProtectionTests/recovery-ui.png`（合成会话的本地恢复视图）。

## 性能数据与解释

来自最终同一合成回归，不是 ChatGPT 实网速度，也不是 0.1.0/0.2.0 的端到端 A/B。

| 场景 | 结果 |
| --- | --- |
| 冷打开合成会话 | 1 次加载；导航完成约 143.1 ms |
| 41 次热选择 | 0 次新增 fixture 请求；原生选择操作中位数 0.0080 ms |
| 换回已有视图后的两次 rAF 等待 | 22.3 ms；仅帧调度观察，不是端到端切换延迟 |
| 跨进程本地快照读取 | 约 4.3 ms；不依赖网站网络 |
| 视图重建与激活 | 新增加载 0；window owner 创建 1 次 |
| 内存中 WebView 上限 | 每窗口 3；不宣称所有窗口合计 3 或固定 RSS |

基线本来就没有在 updateNSView 或激活回调中主动刷新。本轮消除的是 View 值构造时
创建有副作用 owner 的路径，并为明确的最近会话切换新增有界复用；不声称修复了未观察到
的激活刷新故障。

## 存储与剩余边界

生产路径：`~/Library/Application Support/local.personal.ChatGPTNative/Snapshots/replies.sqlite`。
本机明文，目录 0700、数据库 0600。SQLite 与默认 WebKit 网站存储相互独立。
清除会暂停采集，不退出登录；不承诺物理介质取证级擦除。

30 天、200 个会话、64 MiB 逻辑记录、每会话最近 500 条；单消息 1 MiB、批正文 2 MiB，
桥接另有编码载荷限制。超限内容可能不采集；SQLite/WAL 的物理占用可大于逻辑预算。
页面隐藏、崩溃或退出前最后一个尚未提交的防抖批次可能丢失；此前已提交内容保持。
缺失消息可能来自分页或分支变化，不自动认定服务端删除，也不回写官方会话。
上述容量只限制新增的快照缓存；默认 WebKit 网站数据仍由系统管理，不设置自定义总配额。

开发验证阶段未替换工作实例。后续经用户明确授权，已将同一验证包安装到
/Applications，并完成登录、简短聊天、提示优化及原快照保留的定向验收；
详见 DELIVERY-0.2.0.md。未公开发布或推送，未补做上传/下载等完整功能验收。
