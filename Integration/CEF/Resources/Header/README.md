# OP header assets

Vectors come directly from the owner-edited Figma file
https://www.figma.com/design/xWHKogXYl3WijpAvXxn7MP?node-id=1-2,
“02 你的调整区”, exported 2026-10-20. The SVG source export SHA-256 is
`00bc49564c5e13d76c40195414aabe49b317b7dad023e8e4125f2b41a2e6b5b5`.
The local full export is in `build/Figma-Delivery-20261020/design/OP/顶部栏工作稿.svg`.

The 24 pt SVG viewports preserve the glyph's original offset from each button
center. PDF versions are lossless vector conversions for AppKit; fill/stroke
are normalized to black solely for native template tinting. Dark and light
variants deliberately differ because the design uses a checkmark in night mode
and the existing tray in light mode.

Inter Bold is the unmodified static OpenType font from the official Inter v4.1
release: https://github.com/rsms/inter/releases/tag/v4.1 . See LICENSE-Inter.txt.
It is registered only within the OP process, not installed into macOS.
