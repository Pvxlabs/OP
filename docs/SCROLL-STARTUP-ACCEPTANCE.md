# 静默启动与滚动定向验收 — 2026-10-19

本轮保留全部既有未提交工作；未操作用户工作会话，未替换 `/Applications/OP.app`，未触碰 ChatGPT Classic 或 Codex Desktop。没有提交、标签或推送。

## 实施范围

- `BrowserWorkspace.start()` 从最近会话直接开始官方导航，取消启动时自动呈现本地预览；本地副本、保护状态菜单及用户主动恢复继续可用。冷菜单选择原有预览策略保留。
- `MessageObserver.js` 复用通过身份校验的未变化正文、字节数、指纹及可见错误判断，避免每次全量重复读取／编码正文和 JSON 序列化。无关页面变化不再触发全量采集。
- 正文、替换节点、祖先可见性变化使相关缓存失效；发送前主动采集先排空 MutationObserver 待处理记录。缓存按当前观察裁剪，保留原有 500 消息／2 MiB 预算。
- 没有关闭消息观察器，没有改写官方页面 UI、完成语义或 SQLite 保护规则。正文静止仅是观察条件，不代表服务端生成完成。

## PASS：正确性、构建及独立启动 UI

- `build/ProtectionTests/run-20261019-100522/core-results.json`：61 项通过；`restart-results.json`：3 项通过，共 64 项。
- 包括持久化、429／错误占位保护、流式中断、恢复去重，以及本轮同任务正文修改、同 ID 节点替换、隐藏正文可见性变化、带隐藏前缀的可见错误回归。
- 曾出现异步断言抢跑：网页状态先更新，数据库接收及 workspace 回调后更新。测试改为同时等待读取失败与 workspace 加载失败，原目标会话和正文断言保留，没有降低断言要求。
- Release：`build/ScrollTuning/release.log` 中 BUILD SUCCEEDED；候选 `build/Build/Products/Release/OP.app` 通过 `codesign --verify --deep --strict`。
- 独立真实 SwiftUI 测试宿主：`build/ScrollTuning/StartupUI/startup-silent.png` 已实际查看。页面直接显示，无自动本地预览／管理 sheet。`notice-state.json` 记录 `localPreviewVisible=false`、`recoverySheetOpen=false`、`protectedBodyRetained=true`。

## PASS：已确认的观察器开销改善

环境：同机 Release 优化测试宿主、140 条合成回复／2240 段落，每场景 4 秒。以下是单次 rAF 驱动滚动，不是触控板或显示器合成帧性能。`BeforeRun/results.json` 对照最终 `AfterVerified/results.json`。

| 场景（观察器开启） | 旧采集次数／总耗时／最大单次 | 新采集次数／总耗时／最大单次 | rAF p95 旧→新 | >33.4 ms 间隔旧→新 |
|---|---|---|---|---|
| 纯静态滚动 | 0／0／0 ms | 0／0／0 ms | 19→18 ms | 1→0 |
| 无关区域逐帧变化 | 12／167／21 ms | 0／0／0 ms | 21→18 ms | 3→0 |
| 正文增量变化 | 12／220／22 ms | 11／34／4 ms | 20→19 ms | 3→0 |

旧版整页采集最大 22 ms，超过一个约 16.7 ms 的 60 Hz 帧预算。这证明本地观察存在可减少的开销，不能证明它是用户静态长会话卡顿的唯一根因。关闭观察器对照也有偶发长间隔。`AfterRun` 曾与其他测试重叠，已标记 comparisonEligible=false，排除于比较；`AfterFinal` 为中间实现，最终使用 AfterVerified。

## NOT CONFIRMED：真实网页仍有长帧间隔

仅重用独立官方合成会话 `SYNTHETIC_CONVERSATION_A`；没有发送新提示或访问原始工作会话。测试通过正常持久 WebKit 测试登录数据加载，未读取／复制 Cookie 或认证资料。

初测 `LiveBefore` / `LiveAfter`：相同原生裸 WKWebView 宿主，仅替换旧／最终观察脚本。首个可识别正文后等待 2 秒，每组 4 秒。

| 指标 | 旧观察器 | 新观察器 |
|---|---:|---:|
| 采集次数／总耗时／最大单次 | 4／7／2 ms | 3／5／2 ms |
| rAF p95 | 30 ms | 24 ms |
| 最大 rAF 间隔 | 123 ms | 125 ms |
| >33.4 ms 间隔 | 10 | 8 |

两次滚动范围约 8978 px。该初测轨迹有底部边界停留，静止等待也不充分，不作为静态从底向上滚动正式验收。它只表明短时正文扫描低于长帧间隔，不能据此将问题归因于 WebKit、官方 React、布局、GPU 或网络。裸 WKWebView 无本地管理视图时也有长间隔，因此管理视图不是这些间隔的必要条件。

## 未验证与剩余证据

用户明确反馈静态会话从底部向上也卡。定向补测改为底部起始、连续向上，记录实际滚动位移，并比较观察器未安装／安装环境；每组要求合成正文长度／节点数静止至少 3 秒，不将静止或网页轮次标记解释为服务器终态。

当前生产 OP 未替换，候选优化不应被视为已经改善用户当前窗口。未进行物理触控板动画帧分析、与 Codex Desktop 同条件对比或原始私人工作会话采样。尚需卡顿同一时刻的 JS、布局／绘制及合成器时间线，才能确定剩余成本归属。不会以 rAF 间隔冒充显示掉帧率，也不会使用私有 WebKit 选项、修改官方样式或暂停回复保护来掩盖问题。

### BLOCKED：静态底部向上对照

`StaticBottomUpVerified/results.json` 记录 HTTP 403，合成官方正文未通过静止校验，`samples=[]`。没有有效滚动结果，未把脚本执行或窗口可见标记为性能 PASS。前一次 `StaticBottomUp` 未返回有效结果，正常退出独立宿主，单独记录 attempt-status.json；其宿主调用栈主要为空闲，不证明高 CPU。

在收到用户“当前窗口从底部向上”描述后，开始对当前 OP 进行只读 CPU／符号调用栈采样；不读取正文、不切换／刷新／重启窗口。系统 `lsappinfo` 将对应 XPC 标记为 **OP Web Content**，再对该 PID 采样；没有将其他 WebKit 进程猜测为 OP。

OP 主进程 只读时间窗：2026-10-19T02:16:59Z 至 2026-10-19T02:17:44Z，45 个 ps 滚动 CPU 样本，最高 0.2%。没有用户滚动时刻确认，不能与主观卡顿对齐，也不能排除瞬时尖峰。

OP Web Content 只读时间窗：2026-10-19T02:17:14Z 至 2026-10-19T02:17:53Z，40 个 ps 滚动 CPU 样本，最高 4.3%。没有用户滚动时刻确认，不能与主观卡顿对齐，也不能排除瞬时尖峰。

符号采样文件 `CurrentOPScroll/native-*.txt` 与 `webcontent-*.txt` 仅含调用栈。未取得卡顿瞬间的完整渲染时间线，剩余根因 **NOT CONFIRMED**。已通过 Time Profiler 对标记为 OP Web Content 的单进程记录限定时长追踪；追踪是否包含故障需与用户触发时间对齐后判定。

进一步检查 `webcontent-15.txt`：3 秒符号采样共 2485 个主线程采样点，其中 134 个在定时器触发的 `Document::updateStyleIfNeeded()` 路径，包含样式解析、Flex／块布局及文本测量。该样本未出现 innerText 或 MutationObserver 的具名栈；JIT／符号可见性有限，不能据此完全排除观察器。聚合采样也不能把 134 个点解释成单次连续 134 ms 卡顿。此处确认的是网页渲染工作存在，未确认触发原因或与用户卡顿的因果关系。

Time Profiler 独立时间窗为 10:17:41.971–10:17:57.858（UTC+8），约 15.887 秒；time-profile 有 64 条运行态样本，potential-hangs（250 ms 阈值）0 条。这一时间窗没有捕获到被工具识别的长挂起，不能排除更短掉帧或证明滚动流畅。CPU 采样与用户具体滚动时间尚未对齐。

最终状态：静默启动、正文增量采集开销与保护回归 **PASS**；官方静态底部向上开／关对照 **BLOCKED（403）**；原始静态滚动卡顿根因 **NOT CONFIRMED**；当前生产窗口的修复后验收 **未验证**。保留当前 OP，不安装／重启，不将候选功能宣称为当前已生效。

## 后续同步滚动采样 — 10:21–10:24（UTC+8）

上面的初测状态保留用于复核；此节为用户回复“本次已滚动”后的新增证据，不将旧的低 CPU 记录当作故障已排除。

- 只读 Time Profiler：10:21:17.834–10:24:18.756，附加到系统已标记为 OP Web Content 的 PID 50390。
- 同时使用累计 CPU 时间对实际单调时间差计算每个约 1 秒区间的 CPU，替代先前 ps 滚动平均值；原生 PID 50379 与 WebContent PID 50390 各 180 个样本。
- 用户“本次已滚动”回复接收记录为 10:23:50（仅是记录时间，非精确滚动终点），在追踪时间窗内。用户确认滚动操作，尚未明确确认本次主观卡顿与起止秒点。
- 10:23:16–10:23:41 出现明显滚动更新栈和资源上升。网页进程约 1 秒区间 CPU 峰值 81.70%，RSS 峰值 1336.4 MiB；原生主进程 CPU 峰值 12.75%，RSS 峰值约 104.8 MiB。CPU 100% 约等于占满一个逻辑核心，不能解释成整机 CPU 占用百分比。

### CONFIRMED：滚动期间的开销层级及调用路径

实际栈显示：`AsyncScrollingCoordinator::applyScrollUpdate` → `ScrollableArea::scrollPositionChanged` → `RenderLayerScrollableArea::setScrollOffset` → `RenderLayerCompositor::updateCompositingLayers` → `computeCompositingRequirements`／重叠区域计算。这是滚动更新直接进入合成层计算的调用链，而非仅凭 CPU 时间相邻推断。

该 25 秒分析窗包含约 6533 ms 统计运行态样本权重；其中合成层路径约 1570 ms、滚动更新路径 1456 ms、样式路径 1268 ms、布局路径 947 ms、GC 路径 308 ms、Mutation 回调路径 114 ms、innerText 路径 8 ms。分类相互重叠，不可相加；这些是采样权重，**不是单次阻塞耗时或帧率**。证据：`synchronized-analysis.json` 与可复核原始 trace／time-profile XML。

### NOT CONFIRMED：最终根因与修复效果

- 不能将网页样式复杂度、历史消息进入可视区的行为、WebKit 合成策略或特定官网 JS 中任一项认定为唯一根因；采样未给出可定位的 DOM／CSS 节点，也未将 JIT 回调归属到本地观察器或官网脚本。
- 本地正文读取不是该窗口里占优的可见调用栈；不能据此完全排除其间接触发布局，或宣称候选缓存优化已修复当前工作窗口。
- RSS 上升只能确认驻留内存增长，不能判定泄漏、归属单个 WebView、GPU 压力或重复导航。WebContent 可承载同一应用的多个页面，本次未读取私聊 DOM 来逐页归属。
- potential-hangs（250 ms 阈值）0 条。短于阈值的卡顿仍可能存在，未取得显示合成帧率，不能标记滚动流畅 PASS。

### 下一步边界

已有证据足以将后续排查收敛到官方长页面在 WebKit 中的滚动合成／布局成本；不足以支持修改官方 CSS、私有 WebKit 开关或替换浏览器引擎。候选本地采集优化与同一类长页面的真实前后对照仍待完成，独立官方测试 403 仍为阻碍。本轮只新增只读性能记录和报告，没有修改应用源码、重新构建、安装或重启当前 OP，没有采集聊天正文／Cookie／Token。

补充完整时间窗峰值（覆盖用户回复之后的后续活动，不能全部归属前述 15 秒滚动）：网页进程约 1 秒区间 CPU 最高 **138.69%（10:24:10）**，原生主进程最高 12.75%；网页 RSS 最高 1336.36 MiB，结束时 262.55 MiB；原生 RSS 最高 110.20 MiB。10:24:05–10:24:18 的 trace 仍有样式、布局与滚动合成路径，见 `synchronized-after-scroll-analysis.json`。这个后续时间窗是否又有用户输入未确认，不能称为“停止滚动后仍然失控”。RSS 已回落，也不能反向证明无泄漏。性能采样自身有开销；尚无同负载不采样的帧率对照。

本次同步采样结果：**PASS（确实记录到滚动更新调用链及资源增长）**；特定卡顿瞬间、显示帧率及最终修复根因 **NOT CONFIRMED**；独立官方测试对照 **BLOCKED（403，沿用已有证据）**；候选优化在当前生产窗口的改善 **未验证**。本轮记录结束，未留下持续采样任务。
