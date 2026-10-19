# OP 名称与图标更新

2026-10-19（Asia/Shanghai）。ChatGPT Native 更名为 OP，版本 0.2.0 (3)。

- 应用显示名、产品名、主窗口、应用菜单、快速启动菜单及 Web 弹窗名称已更新。
- 图标使用用户参考图下半部的黑色圆环设计，白底；通过内置 imagegen 制作，
  再以标准 sips 尺寸转换接入 macOS AppIcon 资源目录。未使用上半部结形标志。
- 最终生成提示：仅提取参考图下半部的黑色圆环；纯白正方形背景、居中黑环，
  外径约画布 70%、内径约 46%，平滑轮廓，无文字、水印、阴影或上方标志。
- 最终资源：ChatGPTNative/Assets.xcassets/AppIcon.appiconset/icon_1024.png。
- 安装位置：/Applications/OP.app；原包保留在忽略的
  build/OP-Branding/ChatGPT Native 0.2.0 rollback.app。
- bundle ID 继续使用 local.personal.ChatGPTNative，项目名和数据目录保持不变。

PASS：Xcode Release 构建、签名校验、安装包指纹一致、实际“About OP”窗口的
名称/图标/版本检查、原登录及合成会话保持。原有 6 条快照 ID、正文长度和指纹全部不变。
未重跑完整功能回归，未发送新的聊天测试请求，未操作其他应用。

本地 UI 证据：build/OP-Branding/about-op.png；构建日志：build/OP-Branding/build.log。
0.2.0 (2) 的历史交付记录与 v0.2.0 标签保留，不改写为新图标包的验收。
