# OP 滚动嵌入方式定向实验验收 — 2026-10-19

## 最终决定

**拒绝本轮实验性产品变更。** 仅实验了“缓存会话对象不变，非活动 WebView 从原生视图树移出”。未取得官网真实滚动改善的可靠证据，且已确认热切回旧会话会增加挂载，违反已有回归不变性。

实验通过独立编译的 BrowserDeck 副本执行，没有写入产品源码；副本和候选 bundle 仅保留在忽略的 build/ScrollEmbedding 中供复核。最终产品实现等于入场时的工作树，先前全部未提交修改保留。没有 reset、clean、提交、标签、推送、安装或重启工作 OP。

## 复用证据与源码检查

- 复用 `build/ScrollTuning/CurrentOPScroll/scroll-synchronized-1021.trace` 及分析，不重复采集工作 OP。
- 已有直接调用链：滚动更新 → WebKit 合成层更新 → 重叠区域计算；此前 CPU 138.7% 和 RSS 约 1336 MiB 是单个 OP WebContent 记录，不与本轮多个进程汇总直接比较。
- BrowserView 没有重写 scrollWheel，ContentView／BrowserDeck 没有额外的原生 ScrollView、drawingGroup 或 compositingGroup 包住网页。不能仅凭源码排除复杂官网下的嵌入交互成本。
- 基线两个非活动 WebView 仍在视图树，但实测 `document.hidden=true`；移出后仍为 hidden。不能假定基线隐藏页面持续前台渲染。
- 本轮不修改消息观察器、完成语义、SQLite 合并、WebKit 登录数据或官方页面样式。

## 实验一：官网隔离基线与候选

基线为本轮入场工作树，含此前尚未安装的观察器／静默启动改动，**不是当前 /Applications/OP.app 的二进制**。

独立官方合成会话 A `SYNTHETIC_CONVERSATION_A`，B、C 为已有 OP_CACHE 测试会话。通过测试 profile 的正常 WKWebsiteDataStore.default() 加载，没有读取、复制或导入 Cookie／Token。

`op-live2/results.json`：

- 1100×800 原生内容区，网站滚动区域 787×800；5 个可识别助手消息，7015 字符；前后指纹 `3957721341` 相同。
- 12 秒从底部向上 8978 px，3 个会话各显式导航 1 次；5 条回复保存在独立测试 SQLite。
- 对新出现且经 OS 标记为“OP Embedding Validation Web Content”的 4 个测试进程汇总：20 秒窗口 CPU 峰值约 176.0%，RSS 汇总峰值约 2052.2 MiB。窗口包含滚动和后续静止，RSS 汇总可能重复计算共享映射，不能当作独占物理内存。
- 同时采样的 4 个测试网页进程中，只有一个样本出现明显滚动、布局和合成路径，另外三个未出现对应热点。未读取私聊 DOM 或用私有 API 定位进程。
- `op-live1` 为帧工具预检：视口为 640×480，与后续不同，**不纳入性能比较**。

候选 `detached-live1/results.json` 在首个可识别官方正文出现前返回 HTTP 403，状态 **BLOCKED**，没有候选性能结果。该阶段尚无两份隐藏会话，不能把 403 归因于移出隐藏视图。不继续刷新、绕过验证或重复请求官网。

## 实验二：同夹具／同视口／同轨迹

共用 `Tests/Resources/scroll-embedding.html`：80 条合成助手消息、表格和工具卡片样式元素；293791 字符。所有原生变体使用同一观察器，消息身份、正文指纹和保存数均核对。夹具没有模拟官方虚拟化、完整交互及原始私人长会话的全部结构。

原生视口均 1100×756，起点 155309 px，12 秒向上 9600 px。前后正文指纹均 `2944515575`，每组保存 80 条回复，无额外导航。使用固定时间函数控制程序化滚动位置；其步数／定时器间隔不代表物理触控板或显示帧率。

| 变体 | 测试网页进程数 | CPU 区间峰值汇总 | RSS 峰值汇总 |
|---|---:|---:|---:|
| 现有 OP 容器，3 个会话挂载 | 3 | 10.38% | 185.97 MiB |
| 候选，仅活动视图挂载，保留 3 个会话 | 3 | 9.57% | 153.47 MiB |
| 裸 WKWebView，1 个会话 | 1 | 9.36% | 65.98 MiB |

证据：`mounted-fixture1`、`detached-fixture1`、`bare-fixture1` 的 results／resources／attribution JSON 和符号采样；总表 `comparison.json`。

仅各一次探索性结果，不计算统计显著性、不声称 CPU 改善百分比。候选 RSS 汇总较低，但本地夹具未重现官网的 CPU 高占用；减少缓存页面内存与修复真实滚动卡顿不是同一个验收结论。裸 WKWebView 与 OP 容器均未在该夹具中出现官网规模的热点，**不能据此彻底排除 OP 在复杂网页下的嵌入问题**。

## Safari 对照

用户准备空白窗口后，仅使用该窗口及新建测试标签页：

- Safari 能正常读取同一既有官方 A 合成会话，包括 NATIVE_PROTECTION_LIVE_R1 正文，无登录／验证绕过。
- 新标签页加载相同本地 HTML，按钮启动相同 12 秒时间函数；80 条消息，12.014 秒、约 9602 px 位移，状态 done。结果为 `safari/safari-fixture.json`。
- Safari 视口 1505×1415，与原生测试不一致，因此仅确认夹具与交互可运行；**没有 Safari／OP 的公平性能比值或已确认根因结论**。
- 未采样其他 Safari 私人标签页的调用栈，未使用 ChatGPT Classic。测试标签页及本地 HTTP 服务已关闭；官方合成页保留。

## BLOCKED：真正的长帧分布

对独立测试宿主尝试 Animation Hitches，时限 20 秒。工具打印 Reached specified time limit 后超过 2 分钟仍停在结束处理，xctrace 自身约 90% CPU。为避免继续干扰，确认命令只针对本轮测试进程后终止此诊断工具。早于最终化的导出返回 Document Missing Template Error；保留部分 trace、工具符号采样和 hitches-status.json，标记 comparisonEligible=false。

没有取得可复核的帧生命周期／hitch 分布。没有把定时器间隔、rAF、无 250 ms hang 或 CPU 较低标记为真实显示流畅。测量口径参考 [Apple：Understanding hitches in your app](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)。

## FAIL（候选已拒绝）：热切换挂载不变性

独立原生生命周期 probe，未加载网络、使用 nonPersistent 测试配置：

| 行为 | 原实现 | 候选 |
|---|---:|---:|
| A 首次挂载 | 1 | 1 |
| A→B→A 后 A 挂载次数 | 1 | 2 |
| 再次同选择更新后的次数 | 1 | 2 |
| 显式导航 | 0 | 0 |
| 保持原热切换挂载不变性 | PASS | FAIL |

证据：`lifecycle/baseline/result.json`、`lifecycle/detached/result.json`，以及本地 Probe.swift。没有为让候选通过而改写原有热切换断言。

## 验证宿主崩溃及修正

10:41:42 候选因官网 403 超时结束；10:41:43 界面检查工具发现它已退出，按工具语义不带参数重新打开。新写的验证宿主未检查必需参数，在 EmbeddingRunner.run() 读取参数数组越界，触发 EXC_BREAKPOINT／SIGTRAP。用户截图 PID 66735 与本机 `.ips`、时序一致；这是测试宿主缺陷，不能算为生产 OP／网页崩溃或候选渲染故障。

修正 `Tests/EmbeddingTests.swift`：在创建 NSApplication／窗口及索引参数前校验参数个数、mode 和绝对输出目录。0 参数、缺参数、错误 mode、相对目录 4 种情况均正常返回并打印 usage；LaunchServices 无参数启动也快速结束（open -W 因进程已退出提示无法阻塞，命令返回 0）。之后完整本地夹具流程完成，无新增 Embedding Validation 崩溃报告。记录 `argument-validation.json` 与脱敏 `validation-host-crash.json`。

## PASS：最终保留状态的回归／构建／工作区保护

- `build/ProtectionTests/run-20261019-105131`：core 61 项、独立重启 3 项，共 64 项 PASS。包含回复保护、429／错误占位、流式中断、持久化、身份隔离、LRU、热切换与视图重建、内存压力回归。
- 实验夹具各保留 80 条回复，滚动前后同会话正文指纹不变；未把静止或 pageEnded 当作服务端完整交付。
- Release `./script/build_and_run.sh --build`，日志 `build/ScrollEmbedding/release.log` 为 BUILD SUCCEEDED；不运行默认会退出工作 OP 的路径。
- 入场已修改／未跟踪文件散列见 entry/hashes.json；全部一致。测试 source、夹具、脚本和本报告为本轮新增；产品源码没有实验残留。
- 当前工作 OP 保持原 PID 50379，未替换 /Applications/OP.app，未清理网站数据、快照或配置。没有持续诊断任务遗留。

## 最终技术结论

**CONFIRMED**：真实记录热点位于网页滚动更新引起的合成／布局路径；隐藏视图基线确为 hidden；候选带来额外热挂载。

**NOT CONFIRMED**：具体网页结构、WebKit 行为与 OP 嵌入之间的最终归因；真实显示掉帧率；候选对原始官网卡顿的改善。尚缺同一官方长页面上可完成的前后对照及实际帧事件，不能以这次夹具结果宣布修复。

按用户“没有可靠改善则撤销”的验收要求，本轮不交付滚动功能变更，不引入 CSS／私有 WebKit 参数／滚轮事件覆盖，也不关闭保护机制。未验证项保持未验证。
