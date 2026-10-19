// AppKit lifecycle follows the CEF BSD-licensed cefsimple macOS sample.
// See Resources/LICENSE-CEF.txt. Product integration code is OP-specific.
#import <Cocoa/Cocoa.h>
#include "Bridge.h"
#include "include/cef_app.h"
#include "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_command_line.h"
#include "include/cef_devtools_message_observer.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"
#include <map>
#include <set>
#include <string>

namespace {
class Client;
std::map<int, CefRefPtr<Client>> clients;
bool quitting = false;
std::string fixtureOrigin;
std::string worldSource;
std::string querySource;
std::string Origin(const std::string& text) {
  NSURL* u = [NSURL URLWithString:[NSString stringWithUTF8String:text.c_str()]];
  if (!u || u.user || u.password) return "";
  if ([u.scheme isEqual:@"https"] && [u.host isEqual:@"chatgpt.com"] && (!u.port || u.port.intValue == 443)) return "https://chatgpt.com";
  if (!fixtureOrigin.empty() && [u.scheme isEqual:@"http"] && [u.host isEqual:@"127.0.0.1"]) {
    std::string origin = "http://127.0.0.1:" + std::to_string(u.port.intValue);
    if (origin == fixtureOrigin) return origin;
  }
  return "";
}
CefRefPtr<CefDictionaryValue> Dictionary(const void* bytes, size_t count) {
  auto v = CefParseJSON(CefString(static_cast<const char*>(bytes), count), JSON_PARSER_RFC);
  return v && v->GetType() == VTYPE_DICTIONARY ? v->GetDictionary() : nullptr;
}
class Client final : public CefClient, public CefLifeSpanHandler, public CefLoadHandler,
                     public CefDisplayHandler, public CefRequestHandler,
                     public CefDownloadHandler, public CefDevToolsMessageObserver {
 public:
  explicit Client(int64_t key, std::string url) : key_(key), requestedURL_(url), world_("OPReplyProtection-" + std::string(NSUUID.UUID.UUIDString.UTF8String)) {}
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  CefRefPtr<CefDownloadHandler> GetDownloadHandler() override { return this; }
  void Event(const char* event, const std::string& value = "") {
    op_native_event(key_, browser_ ? browser_->GetIdentifier() : 0, event, value.c_str());
  }
  int Command(const std::string& method, CefRefPtr<CefDictionaryValue> params = nullptr) {
    return browser_->GetHost()->ExecuteDevToolsMethod(++command_, method, params);
  }
  void Evaluate(int context, const std::string& expression) {
    auto p = CefDictionaryValue::Create(); p->SetInt("contextId", context); p->SetString("expression", expression);
    Command("Runtime.evaluate", p);
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> b) override {
    CEF_REQUIRE_UI_THREAD(); browser_ = b; clients[b->GetIdentifier()] = this;
    NSView* view = (__bridge NSView*)b->GetHost()->GetWindowHandle(); view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    registration_ = b->GetHost()->AddDevToolsMessageObserver(this);
    Command("Page.enable"); Command("Runtime.enable");
    auto binding = CefDictionaryValue::Create(); binding->SetString("name", "__opSnapshot"); binding->SetString("executionContextName", world_);
    Command("Runtime.addBinding", binding);
    auto completion = CefDictionaryValue::Create(); completion->SetString("name", "__opReplyEnded"); completion->SetString("executionContextName", world_);
    Command("Runtime.addBinding", completion);
    auto script = CefDictionaryValue::Create(); script->SetString("worldName", world_); script->SetString("source", worldSource);
    script->SetBool("runImmediately", true); install_ = Command("Page.addScriptToEvaluateOnNewDocument", script);
    tree_ = Command("Page.getFrameTree"); Event("created");
  }
  bool DoClose(CefRefPtr<CefBrowser> b) override {
    // Only destroy this child view, never the native window hosting other cached sessions.
    NSView* view = (__bridge NSView*)b->GetHost()->GetWindowHandle(); [view removeFromSuperview]; return true;
  }
  void OnBeforeClose(CefRefPtr<CefBrowser> b) override {
    CEF_REQUIRE_UI_THREAD(); int id = b->GetIdentifier();
    Event("closed"); contexts_.clear(); pending_.clear(); registration_ = nullptr; browser_ = nullptr;
    clients.erase(id); if (quitting && clients.empty()) CefQuitMessageLoop();
  }
  bool OnBeforePopup(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>, int, const CefString& url,
                    const CefString&, WindowOpenDisposition, bool gesture, const CefPopupFeatures&,
                    CefWindowInfo&, CefRefPtr<CefClient>&, CefBrowserSettings&, CefRefPtr<CefDictionaryValue>&, bool*) override {
    // User-initiated https popups get a separately owned native window and normal profile.
    NSURL* target = [NSURL URLWithString:[NSString stringWithUTF8String:url.ToString().c_str()]];
    if (gesture && [target.scheme isEqual:@"https"] && !target.user && !target.password) op_native_popup(url.ToString().c_str());
    return true;
  }
  void OnTitleChange(CefRefPtr<CefBrowser>, const CefString& title) override { Event("title", title.ToString()); }
  void OnAddressChange(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, const CefString& url) override {
    if (frame->IsMain()) Event("address", url.ToString());
  }
  bool OnBeforeBrowse(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, CefRefPtr<CefRequest> request, bool, bool) override {
    if (!fixtureOrigin.empty() && frame->IsMain()) Event("fixtureBrowse", request->GetURL());
    return false;
  }
  void OnLoadingStateChange(CefRefPtr<CefBrowser>, bool loading, bool back, bool forward) override {
    Event("navigation", std::string(loading ? "1" : "0") + (back ? "1" : "0") + (forward ? "1" : "0"));
  }
  void OnLoadEnd(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> f, int status) override {
    if (f->IsMain()) Event("http", std::to_string(status));
  }
  void OnLoadError(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> f, ErrorCode code, const CefString&, const CefString&) override {
    if (f->IsMain() && code != ERR_ABORTED) Event("loadError", std::to_string(code));
  }
  void OnRenderProcessTerminated(CefRefPtr<CefBrowser>, TerminationStatus, int code, const CefString&) override {
    contexts_.clear(); pending_.clear(); Event("rendererTerminated", std::to_string(code));
  }
  bool OnBeforeDownload(CefRefPtr<CefBrowser>, CefRefPtr<CefDownloadItem>, const CefString&, CefRefPtr<CefBeforeDownloadCallback> callback) override {
    callback->Continue("", true); return true;
  }
  void OnDownloadUpdated(CefRefPtr<CefBrowser>, CefRefPtr<CefDownloadItem> item, CefRefPtr<CefDownloadItemCallback>) override {
    if (item->IsComplete()) Event("downloadComplete", std::to_string(item->GetReceivedBytes()));
    else if (item->IsCanceled()) Event("downloadCancelled");
  }
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser>, int id, bool success, const void* result, size_t size) override {
    auto query = queries_.find(id);
    if (query != queries_.end()) {
      auto value = success ? Dictionary(result, size) : nullptr;
      auto remote = value ? value->GetDictionary("result") : nullptr;
      if (remote && remote->GetType("value") == VTYPE_STRING) Event("executionQuery", remote->GetString("value"));
      else {
        auto failure = CefDictionaryValue::Create(); failure->SetString("request", query->second);
        failure->SetString("status", "uncertain"); failure->SetString("reason", "网页执行未确认");
        auto v = CefValue::Create(); v->SetDictionary(failure); Event("executionQuery", CefWriteJSON(v, JSON_WRITER_DEFAULT));
      }
      queries_.erase(query);
    }
    if (id == flush_) Event("flushed");
    if (id == diagnostic_ && success) {
      auto value = Dictionary(result, size); auto remote = value ? value->GetDictionary("result") : nullptr;
      if (remote && remote->GetType("value") == VTYPE_STRING) Event("diagnostic", remote->GetString("value"));
    }
    if (id == isolationTest_ && success) {
      auto value = Dictionary(result, size); auto remote = value ? value->GetDictionary("result") : nullptr;
      Event("bridgeIsolation", remote && remote->GetBool("value") ? "true" : "false");
    }
    if (id == install_) Event(success ? "observerInstalled" : "observerFailed");
    if (id == tree_ && success) {
      auto p = Dictionary(result, size);
      if (p && p->GetDictionary("frameTree") && p->GetDictionary("frameTree")->GetDictionary("frame"))
        mainFrame_ = p->GetDictionary("frameTree")->GetDictionary("frame")->GetString("id");
    }
  }
  void OnDevToolsEvent(CefRefPtr<CefBrowser>, const CefString& method, const void* bytes, size_t size) override {
    const std::string name = method;
    // Never subscribe to Network/console domains, nor serialize authentication data.
    if (name != "Runtime.bindingCalled" && name != "Runtime.executionContextCreated" && name != "Runtime.executionContextDestroyed" &&
        name != "Runtime.executionContextsCleared" && name != "Page.frameNavigated" && name != "Runtime.exceptionThrown") return;
    if (size > 12 * 1024 * 1024) { Event("bridgeRejected", "size"); return; }
    auto p = Dictionary(bytes, size); if (!p) return;
    if (name == "Runtime.exceptionThrown") {
      auto detail = p->GetDictionary("exceptionDetails");
      if (detail && contexts_.count(detail->GetInt("executionContextId"))) Event("observerException", std::to_string(detail->GetInt("lineNumber")) + ":" + std::to_string(detail->GetInt("columnNumber")));
    } else if (name == "Page.frameNavigated") {
      auto frame = p->GetDictionary("frame");
      if (frame && frame->GetString("parentId").empty()) { mainFrame_ = frame->GetString("id"); Event("mainFrame", mainFrame_); }
    } else if (name == "Runtime.executionContextsCleared") { contexts_.clear(); pending_.clear(); }
    else if (name == "Runtime.executionContextDestroyed") { contexts_.erase(p->GetInt("executionContextId")); pending_.erase(p->GetInt("executionContextId")); }
    else if (name == "Runtime.executionContextCreated") {
      auto c = p->GetDictionary("context"); if (!c) return;
      auto aux = c->GetDictionary("auxData");
      if (c->GetString("name").ToString() == world_) Event("isolatedContext", std::string(Origin(c->GetString("origin")).empty() ? "originDenied" : "originAllowed") + (aux && aux->GetString("frameId").ToString() == mainFrame_ ? ":main" : ":other"));
      if (c->GetString("name").ToString() == world_ && aux && !aux->GetBool("isDefault") && !Origin(c->GetString("origin")).empty()) {
        contexts_[c->GetInt("id")] = aux->GetString("frameId");
        Evaluate(c->GetInt("id"), std::string("globalThis.__opCaptureEnabled = ") + (enabled_ ? "true" : "false") + ";globalThis.__nativeSnapshotSetEnabled?.(globalThis.__opCaptureEnabled)");
      }
    } else if (name == "Runtime.bindingCalled") {
      int context = p->GetInt("executionContextId");
      Event("bindingReceived", contexts_.count(context) ? (contexts_[context] == mainFrame_ ? "main" : "other") : "unknown");
      if (!contexts_.count(context) || contexts_[context] != mainFrame_ || mainFrame_.empty()) return;
      std::string url = browser_->GetMainFrame()->GetURL();
      if (p->GetString("name") == "__opReplyEnded") {
        std::string payload = p->GetString("payload");
        if (!Origin(url).empty() && payload.size() <= 4096) Event("replyEnded", payload);
        return;
      }
      if (p->GetString("name") != "__opSnapshot") return;
      if (!enabled_ || Origin(url).empty() || pending_.count(context)) return;
      std::string payload = p->GetString("payload"); auto data = Dictionary(payload.data(), payload.size());
      if (!data || !data->GetDictionary("batch") || data->GetInt("request") <= 0) return;
      int request = data->GetInt("request"); pending_[context] = request;
      auto value = CefValue::Create(); value->SetDictionary(data->GetDictionary("batch"));
      std::string json = CefWriteJSON(value, JSON_WRITER_DEFAULT);
      op_native_snapshot(key_, browser_->GetIdentifier(), context, request, url.c_str(), json.c_str());
    }
  }
  void Enabled(bool enabled) {
    if (enabled_ == enabled) return;
    enabled_ = enabled;
    for (auto& entry : contexts_) if (entry.second == mainFrame_)
      Evaluate(entry.first, std::string("globalThis.__opCaptureEnabled = ") + (enabled ? "true" : "false") + ";globalThis.__nativeSnapshotSetEnabled?.(globalThis.__opCaptureEnabled)");
  }
  void Ack(int context, int request, bool accepted) {
    if (!pending_.count(context) || pending_[context] != request || !contexts_.count(context)) return;
    pending_.erase(context);
    Evaluate(context, "globalThis.__opAck?.(" + std::to_string(request) + "," + (accepted ? "true" : "false") + ")");
  }
  void Flush() {
    for (auto& item : contexts_) if (item.second == mainFrame_) {
      auto p = CefDictionaryValue::Create(); p->SetInt("contextId", item.first);
      p->SetString("expression", "globalThis.__nativeSnapshotScan?.(true)"); p->SetBool("awaitPromise", true);
      flush_ = Command("Runtime.evaluate", p); return;
    }
    Event("flushed");
  }
  void Diagnose() {
    if (Origin(browser_->GetMainFrame()->GetURL()).empty()) return;
    auto p = CefDictionaryValue::Create();
    p->SetString("expression", R"JS(JSON.stringify((() => {
      const uuid = /^[0-9a-f-]{36}$/i;
      const id = value => uuid.test(value || '') ? value : null;
      const nodes = [...document.querySelectorAll('[data-dil-message-id]')].slice(-8);
      return {
        conversation: id(location.pathname.match(/\/c\/([0-9a-f-]+)/i)?.[1]),
        dilCount: document.querySelectorAll('[data-dil-message-id]').length,
        assistantCount: document.querySelectorAll('[data-message-author-role="assistant"]').length,
        unitCount: document.querySelectorAll('[data-content-search-unit-key]').length,
        messageUnits: [...document.querySelectorAll('[data-content-search-unit-key]')].slice(-8).map(n => ({
          key:n.getAttribute('data-content-search-unit-key'), role:n.getAttribute('data-message-author-role'),
          userBodies:n.querySelectorAll('[data-message-author-role="user"]').length,
          visible:n.getClientRects().length > 0, characters:(n.innerText || '').trim().length
        })),
        selectionCount: document.querySelectorAll('[data-chatgpt-selection-conversation-id]').length,
        composers: [...document.querySelectorAll('textarea, [contenteditable]')].slice(-12).map(n => ({
          tag:n.tagName, id:n.id, editable:n.getAttribute('contenteditable'),
          visible:n.getClientRects().length > 0, form:Boolean(n.closest('form')),
          characters:(n.innerText || n.value || '').trim().length
        })),
        sendButtons: [...document.querySelectorAll('button[data-testid="send-button"]')].map(n => ({
          visible:n.getClientRects().length > 0, disabled:n.disabled, form:Boolean(n.closest('form'))
        })),
        submitControls: [...document.querySelectorAll('button[type="submit"], button[aria-label*="Send"], button[aria-label*="发送"], button[data-testid*="send"], button[data-testid*="submit"]')].slice(-8).map(n => ({
          id:n.id, testID:n.getAttribute('data-testid'), label:n.getAttribute('aria-label'), type:n.getAttribute('type'),
          visible:n.getClientRects().length > 0, disabled:n.disabled, form:Boolean(n.closest('form'))
        })),
        conversationScopes: [...document.querySelectorAll('[data-chatgpt-selection-conversation-id]')].slice(-8).map(n => ({
          conversation:id(n.getAttribute('data-chatgpt-selection-conversation-id')),
          message:id(n.getAttribute('data-chatgpt-selection-message-id')),
          inTurn: Boolean(n.closest('[data-talvt-turn-state]')),
          turnAssistantBodies:n.closest('[data-talvt-turn-state]')?.querySelectorAll('[data-dil-message-id]').length || 0
        })),
        nodes: nodes.map(n => ({id:id(n.getAttribute('data-dil-message-id')), characters:(n.innerText || '').trim().length,
          assistant: /:assistant$/.test(n.closest('[data-content-search-unit-key]')?.getAttribute('data-content-search-unit-key') || ''),
          selectionConversation: id(n.closest('[data-chatgpt-selection-conversation-id]')?.getAttribute('data-chatgpt-selection-conversation-id')),
          selectionMessage: id(n.closest('[data-chatgpt-selection-message-id]')?.getAttribute('data-chatgpt-selection-message-id')),
          referenced: (n.closest('[data-content-search-unit-key]')?.getAttribute('data-chatgpt-search-message-ids') || '').split(/\s+/).filter(v=>uuid.test(v)),
          turnConversations: [...(n.closest('[data-talvt-turn-state]')?.querySelectorAll('[data-chatgpt-selection-conversation-id]') || [])].slice(-8).map(e=>id(e.getAttribute('data-chatgpt-selection-conversation-id'))),
          turn: n.closest('[data-talvt-turn-state]')?.getAttribute('data-talvt-turn-state') || null }))
      };
    })()))JS");
    p->SetBool("returnByValue", true); diagnostic_ = Command("Runtime.evaluate", p);
  }
  void TestIsolation() {
    auto p = CefDictionaryValue::Create(); p->SetString("expression", "typeof globalThis.__opSnapshot === 'undefined' && typeof globalThis.__opAck === 'undefined' && typeof globalThis.__opReplyEnded === 'undefined' && typeof globalThis.__nativeSnapshotScan === 'undefined'");
    p->SetBool("returnByValue", true); isolationTest_ = Command("Runtime.evaluate", p);
  }
  void Query(const std::string& payload) {
    if (!browser_ || payload.size() > 64 * 1024 || querySource.empty() || Origin(browser_->GetMainFrame()->GetURL()).empty()) return;
    auto data = Dictionary(payload.data(), payload.size());
    if (!data || data->GetString("request").empty()) return;
    for (const auto& context : contexts_) if (context.second == mainFrame_) {
      auto value = CefValue::Create(); value->SetDictionary(data);
      auto p = CefDictionaryValue::Create(); p->SetInt("contextId", context.first);
      p->SetString("expression", "(" + querySource + ")(" + CefWriteJSON(value, JSON_WRITER_DEFAULT).ToString() + ")");
      p->SetBool("returnByValue", true); p->SetBool("awaitPromise", true);
      queries_[Command("Runtime.evaluate", p)] = data->GetString("request");
      return;
    }
  }
  CefRefPtr<CefBrowser> browser_;
 private:
  int64_t key_; std::string requestedURL_, world_, mainFrame_;
  int command_ = 0, install_ = 0, tree_ = 0, isolationTest_ = 0, flush_ = 0, diagnostic_ = 0;
  bool enabled_ = true;
  std::map<int, std::string> contexts_; std::map<int, int> pending_;
  std::map<int, std::string> queries_;
  CefRefPtr<CefRegistration> registration_;
  IMPLEMENT_REFCOUNTING(Client);
};
class App final : public CefApp, public CefBrowserProcessHandler {
 public:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
  void OnContextInitialized() override { op_native_start(); }
 private: IMPLEMENT_REFCOUNTING(App);
};
}
int32_t op_cef_create(void* parent, const char* url, int64_t key) {
  CEF_REQUIRE_UI_THREAD(); NSView* host = (__bridge NSView*)parent;
  CefWindowInfo info; info.SetAsChild((__bridge void*)host, CefRect(0, 0, host.bounds.size.width, host.bounds.size.height)); info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;
  CefBrowserSettings settings; CefRefPtr<Client> client = new Client(key, url);
  // Let CEF own its initial navigation. The isolated script's runImmediately
  // installation also observes an already loading document without a second
  // competing navigation. Authentication URLs are never logged natively.
  auto browser = CefBrowserHost::CreateBrowserSync(info, client, url, settings, nullptr, nullptr);
  if (!browser) return 0;
  return browser->GetIdentifier();
}
void op_cef_action(int32_t id, int32_t action) {
  CEF_REQUIRE_UI_THREAD(); auto found = clients.find(id); if (found == clients.end()) return;
  auto b = found->second->browser_; if (!b) return;
  switch (action) {
    case 0: b->Reload(); break;
    case 1: if (b->CanGoBack()) b->GoBack(); break;
    case 2: if (b->CanGoForward()) b->GoForward(); break;
    case 3: b->GetHost()->SetFocus(true); break;
    case 4: found->second->Diagnose(); break;
  }
}
void op_cef_flush(int32_t id) { CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i != clients.end()) i->second->Flush(); }
void op_cef_close(int32_t id) { CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i != clients.end()) i->second->browser_->GetHost()->CloseBrowser(true); }
void op_cef_enabled(int32_t id, bool enabled) { CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i != clients.end()) i->second->Enabled(enabled); }
void op_cef_ack(int32_t id, int32_t context, int32_t request, bool ok) { CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i != clients.end()) i->second->Ack(context, request, ok); }
void op_cef_query(int32_t id, const char* payload) { CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i != clients.end()) i->second->Query(payload); }
void op_cef_test(int32_t id, int32_t action) {
  CEF_REQUIRE_UI_THREAD(); auto i = clients.find(id); if (i == clients.end() || fixtureOrigin.empty()) return;
  auto b = i->second->browser_;
  if (Origin(b->GetMainFrame()->GetURL()) != fixtureOrigin) return;
  if (action == 6) { i->second->TestIsolation(); return; }
  if (action == 9) { i->second->Command("Page.crash"); return; }
  b->GetMainFrame()->ExecuteJavaScript("window.fixture?.(" + std::to_string(action) + ")", "", 0);
}
void op_cef_quit(void) {
  CEF_REQUIRE_UI_THREAD(); quitting = true;
  if (clients.empty()) { CefQuitMessageLoop(); return; }
  auto copy = clients; for (auto& item : copy) item.second->browser_->GetHost()->CloseBrowser(true);
}
@interface OPApplication : NSApplication <CefAppProtocol> { BOOL sending_; }
@end
@implementation OPApplication
- (BOOL)isHandlingSendEvent { return sending_; }
- (void)setHandlingSendEvent:(BOOL)value { sending_ = value; }
- (void)sendEvent:(NSEvent*)event { CefScopedSendingEvent scope; [super sendEvent:event]; }
- (void)terminate:(id)sender { op_native_quit(); }
@end
int main(int argc, char* argv[]) {
  CefScopedLibraryLoader loader; if (!loader.LoadInMain()) return 1;
  @autoreleasepool {
    [OPApplication sharedApplication]; CHECK([NSApp isKindOfClass:OPApplication.class]);
    CefSettings settings;
    NSString* identity = NSBundle.mainBundle.bundleIdentifier ?: @"local.personal.OP.CEFIntegration";
    NSString* support = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString* root = [[support stringByAppendingPathComponent:identity] stringByAppendingPathComponent:@"Chromium"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    CefString(&settings.root_cache_path) = root.UTF8String;
    CefString(&settings.cache_path) = [root stringByAppendingPathComponent:@"Profile"].UTF8String;
    settings.persist_session_cookies = true; settings.log_severity = LOGSEVERITY_DISABLE;
    // This target never exposes a remote debugging listener, including in Release.
    NSString* source = [NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"CEFObserver" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!source) return 2;
    NSString* query = [NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"ExecutionQuery" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!query) return 2;
    querySource = query.UTF8String;
    auto command = CefCommandLine::CreateCommandLine(); command->InitFromArgv(argc, argv);
    if (command->HasSwitch("self-test-origin")) {
      std::string value = command->GetSwitchValue("self-test-origin");
      NSURL* test = [NSURL URLWithString:[NSString stringWithUTF8String:value.c_str()]];
      if ([test.scheme isEqual:@"http"] && [test.host isEqual:@"127.0.0.1"] && test.port && [test.path isEqual:@""]) fixtureOrigin = value;
    }
    worldSource = source.UTF8String;
    NSString* completion = [NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"ReplyCompletion" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!completion) return 2;
    worldSource += "\n"; worldSource += completion.UTF8String;
    const std::string marker = "__OP_FIXTURE_ORIGIN__";
    size_t pos;
    while ((pos = worldSource.find(marker)) != std::string::npos) worldSource.replace(pos, marker.size(), fixtureOrigin);
    CefMainArgs args(argc, argv); CefRefPtr<App> app = new App;
    if (!CefInitialize(args, settings, app, nullptr)) return CefGetExitCode();
    CefRunMessageLoop(); CefShutdown();
  }
  return 0;
}
