# Reply Protection 图标、圆角提示与长文本稳定性验收

日期：2026-10-19。范围合同见 UI-STABILITY-SCOPE.md。保留全部已有未提交缓存、
品牌及迁移修改；本轮没有安装、重启或操作 `/Applications/OP.app` 工作窗口。

## CPU 结论先行

本轮未重现用户报告的持续高 CPU 卡死，因此**该次故障根因 NOT CONFIRMED**。
不能宣布所有突发 CPU 故障已消除，也不能把截图、429 或网页告警单独当作原因。

已有直接证据：08:39:33 对独立 OP Cache Validation 43277 的 sample，主线程
1410 个样本持续在 SwiftUI 布局更新链，反复出现 SelectionOverlay.updateNSView、
AttributeGraph/Subgraph/update、事务 flush；当时有持续满核及 UI 无响应的现场记录。
原始文件 `build/CachePerformance/cache-validation-sample.txt`（旧轮次、非本次重新采到）。
这确认了**此前冷恢复界面的文本选择布局循环路径**，不确认所有工作网页卡死同源。
此前只替换了冷恢复正文；本轮审查发现手动 RecoveryView 中仍保留同类 SwiftUI
Text.textSelection + LazyVStack，以及冲突文本的另一个 Text.textSelection。

本轮先冻结源码及旧宿主，再作以下有限测试，随后停止重复复现：

1. 旧手动恢复独立窗口：9 条合成回复，8 条为 180 行长文本，包含冲突副本；展开、
   滚动后没有持续满核。第一版夹具的 sequence 设置导致不足 9 条，已丢弃该数据，
   加入 9 条数量断言并使用新数据库后再测。
2. 同一旧 RecoveryView 以主 ContentView 的 sheet 打开，实际拖选正文。约 60 秒
   主线程心跳持续更新；观察到 CPU 0.0%，没有卡死。`BeforeSheet/ui-heartbeat.json`
   最大心跳间隔约 1.54 秒；`before-sheet-sample.txt` 主要为事件循环等待 mach_msg2_trap。
3. 复用 08:33:35 冻结的旧性能宿主（nm 确认仍为 SwiftUI selectable Text 的
   LocalConversationView，未含 CachedReplyText），用正确新鲜合成 A/B/C 种子运行。
   正常完成，没有复现卡死。`FrozenSelection/results.json` 是此次有限复测记录，
   不用于改写上轮正式性能验收结论。

以上目录均位于忽略的 `build/UXStability/`。测试不操作原始工作会话，也不发送新消息。
实际工作 OP 在开头采样为正常空闲状态；没有在用户工作窗口上进行复现或采样干预。

## 最小修正

- 手动恢复窗口改用已有的原生 CachedReplyText（只读、可选择 NSTextView），不再为
  多条长正文和冲突正文创建 SwiftUI SelectionOverlay。角色、时间、完成／中断状态、
  用户停止提示及正文保留；不同文本改为明确的“显示同一消息的不同文本”开关。
  这是清除剩余同类布局路径的修正；本轮没有证明该手动窗口曾触发用户这次故障。
- 不修改消息观察器、SQLite 合并规则、WebKit 生命周期和官方网页代码；没有降低
  防丢失保护，也没有增加自动重启、轮询看门狗或吞掉错误的逻辑。
- 现有默认网站数据存储、登录资料和本地快照格式不变。

修正后相同 sheet 夹具：9 条回复，60 次一秒主线程心跳全部完成，最大间隔 1.068 秒；
实际选择、滚动、冲突文本开关可响应，选择保持回归通过。交互后宿主 CPU 采样 0.0%、
RSS 约 111 MiB；`after-sheet-sample.txt` 为正常等待。前后都未卡死，所以**不计算 CPU
改善百分比**；心跳不是完整卡顿率、全 WebKit CPU 或长期稳定性保证。

证据：`build/ProtectionTests/run-20261019-093543/ui-heartbeat.json`、
`build/UXStability/after-process.txt`、`recovery-after.png`。

## 图标与圆角浮窗

**PASS — 图标**：白色圆角底、黑色双向重播箭头，主 OP 图标不变。
原生矢量源 `script/make-protection-icon.swift`；ICNS 与预览位于 Tests/Resources。
重生成 ICNS SHA256 与工作区图标资源一致：
`a889ef3c948f3ad905e8bc85ab8cae56002d97b6d6fd912cca31eaf884305730`。
测试及性能宿主脚本都打包该图标并设置 CFBundleIconFile。实际运行宿主的
NSApp.applicationIconImage 已读出并检查，确认为该白底重播图标（系统可能施加图标材质）。
证据 `build/ProtectionTests/run-20261019-093916/loaded-app-icon.png`。

**PASS — 浮窗**：原矩形 material 提示替换为圆角 18 的原生浮层，有适配明暗外观的
背景、细边框、柔和阴影、回复保护标识、查看本地副本／重试和关闭按钮。保留原有
异常触发条件；普通“尚未识别消息”状态不因此弹出。关闭只记住本次会话／导航／提示文本
组合的提示状态，不清除页面错误、保存正文或保护状态。新目标或新导航错误仍可提示。

独立宿主使用生产 ContentView，通过合成原生 readFailure 状态检查明暗外观，不把
这个 UI 注入状态宣称为真实 HTTP 403 证据。最初尝试从自定义 scheme 取得 HTTP403
失败并超时，已保留该次 FAIL 记录；改为 UI 注入，真实 403/429 保护沿用 loopback 回归。

- 浅色和深色实际截图分别为 `build/UXStability/notice-light.png`、`notice-dark.png`。
- 点击查看本地副本后，可读取合成保存正文。
- 关闭浮窗后，网页保留；新鲜的后续诊断元数据仍为 readFailure、errorRetained=true、
  protectedBodyRetained=true，见 `notice-state-after-dismiss.json`。
- 点击重试，系统日志记录新的 navigation started/finished；受保护正文保留。
  夹具继续提供空助手节点，因此 readFailure 提示仍可显示；不将重试等同于官方恢复成功。
  证据 `notice-retry-navigation.log` 和 `notice-state-after-retry.json`。

## 构建、回归与最终状态

**PASS**：60 项回归（57 core + 3 独立进程 restart），
`build/ProtectionTests/run-20261019-093502/{core,restart}-results.json`。
新增完整手动恢复使用原生文本、正文／未完成状态／停止原因／可选冲突文本保护检查，
其余原有流式、中断、身份隔离、403/429、去重、LRU 与重建检查保留。

**PASS**：Xcode Release 构建 `build/UXStability/release.log`，生产候选位于
`build/Build/Products/Release/OP.app`；严格签名校验、脚本语法及 git diff --check 通过。
独立验证宿主实际 UI 通过上述检查。没有将 swiftc 验证宿主宣称为生产安装后的验收。

**BLOCKED**：本次用户突发卡死的唯一根因及彻底消除结论；本轮未复现同一现场，缺少
峰值时 OP 主进程与其对应 WebContent 的同期 CPU、主线程／工作线程采样证据。
已确认并处理的旧原生选择布局路径与其他可能的网页／WebKit 原因分开记录。

**未验证**：长时间真实网页使用稳定性、WebContent 总 CPU／内存、安装后的正式工作
实例表现、所有极端消息规模。现有工作 OP 不受影响，不安装、不提交、不推送。

## 后续授权安装

用户随后明确授权“直接安装替换”。已复用本报告的 Release 候选安装至
`/Applications/OP.app`，版本号仍为 0.2.0 (3)，没有另行重新构建。
安装时 OP 已退出；以 ditto --rsrc --extattr --acl 暂存候选，再保留旧包并替换。
7 个包内文件与候选一致，严格签名校验 PASS。

新进程从正式路径启动；只读 UI 检查确认网页及账户菜单存在、无登录按钮、当前无警报
浮层。安装前后首次启动前的快照与配置相同；启动后原有 37 条回复的正文指纹全部
保留，SQLite quick_check=ok。未发送测试消息，不重复完整验收；长期 CPU 结论不变。

安装回执及旧包位于忽略目录 `build/Install-UIStability-20261019-094757/`：
before.json、installation.json、postlaunch.json、OP previous.app。
未提交或推送 Git，未改其他应用、Cookie 或认证数据。
