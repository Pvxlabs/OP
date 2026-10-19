# OP 缓存与会话切换验收（2026-10-19）

结论：实现、定向回归、Release 构建和隔离 UI 的本地恢复路径 PASS；
最终受控真实网站端到端前后对照 BLOCKED。不能据此宣称全部性能目标已验收。
本轮没有安装替换 `/Applications/OP.app`，没有提交、打标签或推送。
原有 OP 品牌、图标、迁移等未提交修改保留。Linear 按本线程用户要求跳过。

## 实现及生效范围

- 主窗口用稳定的原生 BrowserDeck 持有网页；热选择切换隐藏状态，避免原先
  `.id(session.id)` 导致 WKWebView 从窗口反复移除、重新挂载。复用同一对象。
- **仅原生“本地副本”最近会话选择走此缓存池**；官方网页侧边栏仍由官方 SPA
  导航，不拦截点击，也没有把每次网页侧边栏选择变成独立 WebView。
- 冷选择及首窗口重启恢复：清空上一目标的原生预览，异步读取 SQLite，按目标及
  读取请求身份校验后显示本机文本。官方会话身份及非空可识别助手正文出现后交接。
  已观察可读正文不代表全历史、当前分支或服务端终态；本地副本入口继续保留。
- 没有可用快照时显示等待状态，不能凭空恢复正文。用户可以主动查看官方网页完成
  登录／安全验证。本地文本不注入网页、不回传网站。
- 每窗口最多 3 个 WebView；重复选择仍在导航中的目标复用 pending 实例，但已导航至其他 URL 时不得复用旧 pending 标识。LRU
  淘汰旧实例，内存压力 warning/critical 清除非活动实例，活动实例保留。
  此上限不等于 WebKit 全进程 RSS 上限；多窗口总量仍随窗口数增加。
- 默认持久化网站存储、SQLite 格式和保护合并规则保留。403/429、空白、错误占位
  不覆盖受保护正文；流式／页面结束不升级成确认完整。清除快照也清除当前原生预览。
- 有界 200 条切换事件区分 cacheHit、coldLoad、snapshotRestored/Miss、
  officialBodyReadable、loadFailed 和 pressure trim；系统日志只有临时操作 UUID、
  状态和耗时，不含聊天正文、会话 ID 或凭据。
- 实际测试发现新增长文本 SwiftUI 文本选择层持续布局、主线程满核；sample 栈反复
  落在 SelectionOverlay/AttributeGraph。仅冷预览正文改为只读可选择 NSTextView。
  最终长文本原生 UI 可响应，保留选择回归通过；没有重写已有手动恢复窗口。

## 测量方法和可信度

基线先冻结到 `build/CachePerformance/SourceBefore` 和 baseline 优化编译的独立测试
宿主，再实施修改。真实网站只用合成 A/B/C，会话标识保留在忽略的本机证据目录。
宿主使用生产服务及完整 ContentView，测试自己的 SQLite 和既有测试登录资料，
不读取生产工作会话。完整 Xcode Release 验证另用 `.CacheValidation` bundle ID，
由用户正常登录；为了验证恢复路径，仅该测试配置导入已采集的合成 A/B/C 快照。
这项 UI 验证不等于生产数据库升级迁移验收。

分开采样：原生选择函数、原生挂载次数/时间、官方身份与正文观察、
`WKWebView.takeSnapshot` 完成时间、显式 `load(URLRequest)` 次数、宿主 RSS。
截图完成是已有可见正文的 WebKit 位图可取得时间上界；**不是屏幕实际首帧时间**。
原生 localViewAppeared 是生命周期回调，不是物理呈现。load 次数不涵盖 reload、
官方 SPA fetch 或全部网络请求。宿主 RSS 不含共享 WebKit helper，不证明总内存下降。

### 探索性真实网站对照（每组 5 次热选择）

来源：`build/CachePerformance/baseline-full/results.json` 与
`build/CachePerformance/optimized-final/results.json`。优化样本早于最终 NSTextView
正文控件调整，不是最终候选的完整受控性能验收。

| 指标 | 修改前 | 优化探索样本 | 判断 |
|---|---:|---:|---|
| 热选择函数中位数 | 0.111 ms | 0.172 ms | 不证明交互更快；原生选择本身不是瓶颈 |
| 热选择新增挂载总数 | 5 | 0 | 稳定容器消除重复挂载，定向回归再次验证 |
| 热选择显式 load 总数 | 0 | 0 | 保持零额外显式导航 |
| 热选择 WebKit 位图就绪中位数 | 648.4 ms | 254.0 ms | 探索性改善，不能当作真实首帧或正式性能承诺 |
| 热选择宿主 RSS 范围 | 117.7–131.3 MiB | 106.4–109.5 MiB | 样本量小、排除 helper；不认定因果性内存改善 |
| 双窗口切回位图就绪（各 1 次） | 31.3 ms | 211.5 ms | 观察值变差，无充分证据认定改善或稳定回归 |

上述较早测试的启动官方正文约 5.50/5.77 秒，冷 B 约 3.92/5.51 秒，
冷 C 约 3.94/5.10 秒。网络与官网响应不受本地缓存保证，未观察到冷官方读取加速。

两项测量错误已披露并停止采用对应结果：

1. 首轮 prepared B/C 在 SPA 过渡时误关联同一 ID，首轮 baseline-run 无效。
   已加 DOM 会话身份及三个独立 ID 校验。
2. 后续探索组 B/C 种子时间为 epoch zero，被正常保留策略淘汰；相关冷本地预览耗时
   **不证明显示了已保存正文**，标记 coldCacheEvidenceValid=false。后续加入新鲜且
   非空种子校验，真实 UI 验证使用正确的新鲜合成副本。

### 最后一次新鲜种子受控对照：BLOCKED

`before-final` 和 `after-final` 的 `results.json` 均为 BLOCKED。
对应 `blocked-metadata.json`：目标 A、主文档 HTTP 200、已识别回复节点 0、
等待官方正文超时，页面可见“无法加载此 ChatGPT 对话”。两组均未形成可比较样本。
不能把 HTTP 200 认作聊天可用，也不把 403/429、React 或扩展错误单独归因。
依停止边界没有继续重复网站基准。正式冷切换、官方恢复及完整端到端前后比较仍 BLOCKED。

### 最终 Xcode Release 的实际 UI：局部 PASS

最终独立 app 路径：`build/CacheValidation/Build/Products/Release/OP Cache Validation.app`。
用户登录后正常退出／重启，无再次要求输入凭据；已加载账户导航，网站读取可间歇失败。
A 曾发生会话读取失败，本地副本保留。最后补完 pending URL 身份边界后重新构建启动，
再次先观察到 A 原生长副本，之后观察到同一 A 官方页面（含 DELIVERY_020_OK 回复），
原生预览已撤下，官方交接 PASS。截图 final-candidate-ui.png。不能把这一次成功交接
等同于网站始终可用，也没有重新开展成对性能测量。

最终源码一次真实原生冷 B 选择，观察本地 B 正文存在且 A 标记不存在。随后官方读取失败；
该次没有证实官方 B 交接。跨身份交接及去重由真实 WKWebView 合成 fixture 验证。

最终源码重启 A 的原生长回复副本截图：
`build/CachePerformance/final-restart-ui.png`；失败后副本仍可用：
`final-local-read-failure.png`。当前本地状态 loadFailed、1/3 个 WebView、8 条保存回复
可由原生“查看保护状态”主动查看；菜单保留查看本地回复及 A/B/C 入口。

系统日志 `final-ui-switching.log` 中一次重启相对开始：snapshotRestored 108.96 ms、
localViewAppeared 111.64 ms、loadFailed 1113.99 ms。一次冷 B：原生选择 74.25 ms、
snapshotRestored 125.61 ms、localViewAppeared 127.18 ms。这是单次事件回调，不能
替代实际可见首帧测量。最终候选 08:52:36 的单次启动另外记录：本地读取
86.17 ms、原生出现回调 88.62 ms、官方正文可读 5970.24 ms；中途有 loadFailed
事件，随后恢复。前一次最终渲染控件验证中，重启长文本保留约 40 秒时，宿主 CPU 采样 0.1%、RSS
约 124 MiB，未复现此前持续满核；不构成长时稳定性或总 WebKit 内存上界证明。

## 最终回归、构建与保护

**PASS**：`script/test-protection.sh`，55 项 core + 3 项独立进程 restart = 58 项。
证据 `build/ProtectionTests/run-20261019-085150/{core,restart}-results.json`。
包含完整／部分保护、错误占位、真实 loopback 403/429、错误 div 分类、流式中断、
身份隔离、去重、LRU、pending 去重、41 次热选零额外请求、完整 ContentView 重建、
冷目标隔离、正确身份后交接、压力 trim 与释放、清除后不残留原生副本、长文本选择保持。
SQLite 独立进程读 3.07 ms 只是合成本地读，不充当网站恢复时间。

**PASS**：生产 `script/build_and_run.sh --build` Xcode Release（仅构建）；
`build/CachePerformance/release-final.log`。独立 Release 构建
`ui-final-build.log`。两个 app 的 `codesign --verify --deep --strict` 通过。
`git diff --check`、shell 脚本语法检查通过。未操作用户工作窗口和生产数据，
未触碰 ChatGPT Classic；只关闭本轮测试实例。旧阻断性能宿主正常退出 UI 超时后，
核实精确 PID/路径，仅对它发送 SIGTERM 收尾。

**BLOCKED**：最终受控真实网页端到端比较、最终真实 B 官方交接；官网会话正文读取失败。

**未验证**：物理屏幕首帧、全 WebKit 进程内存、系统真实压力通知实发、长时多窗口负载、
生产安装后的升级验收。测试直接调用 trim 路径，不声称触发真实 OS 内存压力。

## 剩余风险和下一步边界

冷 WKWebView 分配仍在主线程，探索中原生选择约 31–100 ms，未做到零阻塞。
隐藏保留视图仍可能承担网站自身活动；没有无限预加载或固定字节的网页内存保证。
官方 DOM 可能变化；只对可验证身份及正文交接，无法可靠识别时继续本地视图并允许
主动看官方网页。副本不是完整历史、附件、分支或账号隔离的离线客户端。

下一步性能结论需要官网能稳定读出合成 A/B/C 后，再完成一次新鲜种子的成对测量，
而不是扩大本轮实现。多窗口单样本变慢、官网读取故障均记录，未扩大排查或引入新缓存层。
候选位于 `build/Build/Products/Release/OP.app`；本轮不安装、不覆盖现有 OP。
