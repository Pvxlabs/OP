# ChatGPT Native — implementation contract

2026-10-19. Personal native macOS client. User explicitly waived Linear.

## Objective and boundaries
Swift 6 + SwiftUI + public WKWebView APIs, directly load https://chatgpt.com/.
Preserve official web UI. No OpenAI API, server, Electron, Chromium, DOM restyling,
user-agent spoofing, CAPTCHA bypass, browser cookie import, private WebKit APIs.
Independent Xcode project outside CLINX; existing apps remain intact.

## Architecture
SwiftUI WindowGroup owns one browser session per window. NSViewRepresentable
embeds WKWebView. Native delegate handles file panels, downloads, JavaScript
panels and web-created popup windows. All windows share default persistent
WKWebsiteDataStore. Native edit commands use the responder chain.

## Milestones and gates
- M1: Xcode project, persistent web view, build and launch; actual ChatGPT load,
  authentication and restart persistence, simple chat. MUST pass before M2.
- M2: upload/download/drag-drop acceptance; multiple windows, shortcuts,
  menu-bar quick launch. Notifications require feasibility verification against
  public WebKit APIs; do not claim web push parity from local notifications.
- M3: install to /Applications, verify signing, independent launch and Spotlight.

## Acceptance
Record PASS, BLOCKED, NOT_RUN independently for load, login, Cloudflare,
restart session, chat/history, uploads/downloads/drag-drop, multiple windows,
menus/shortcuts, notifications, build/install/Spotlight. Source/build evidence
never substitutes for observed UI. User may need to perform credential/2FA
entry. Authentication errors must be diagnosed from rendered errors and native
navigation logs without retaining credentials or conversation contents.

## Dependency and fallback
Requires macOS 14+, Xcode and network access to ChatGPT/auth providers.
If public WKWebView authentication is rejected, retain evidence and assess
Safari Add to Dock, which is a different implementation and must be disclosed.

## Current state
M1 PASS: real account login, synthetic response and repeated authenticated restart.
M2 PARTIAL: implemented public file/download/dialog/popup delegates, native page
commands, multiwindow, menu-bar entry and opt-in download notifications.
Upload/download, multiwindow, reload and copy/paste acceptance PASS. Native
notification submission/history PASS, banner BLOCKED by screen-sharing/focus
policy. Menu-bar click recovery, drag/drop and other website features NOT_RUN.
Official Web Push remains BLOCKED pending a supported public integration.
M3 PARTIAL: final 0.1.0 (1) installed, signature and independent launch PASS;
Spotlight indexing PASS, direct Spotlight UI launch NOT_RUN due tooling limits.
Full acceptance is not closed. See ACCEPTANCE.md for every boundary.
