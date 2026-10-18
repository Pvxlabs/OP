(() => {
  "use strict";
  const fixtures = __ALLOW_FIXTURES__;
  if (!(location.protocol === "https:" && location.hostname === "chatgpt.com") &&
      !(fixtures && location.protocol === "snapshot-fixture:" && location.hostname === "local")) return;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const documentID = crypto.randomUUID();
  let captureEnabled = __CAPTURE_ENABLED__;
  let conversation = "", sequence = 0, timer = 0, timerDue = 0, pending = false, dirty = false, lastPage = "", observedPath = "";
  const stable = new Map();
  const sent = new Map();
  const stopped = new Set();
  const errorText = text => /^(无法加载此回复|无法加载此 ChatGPT 对话|unable to load (this response|conversation)|something went wrong|network error|too many requests|请求过于频繁)([.。！!：:\s]|$)/i.test(text.trim());
  const signature = text => {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return text.length + ":" + (h >>> 0);
  };
  function collect(interrupted = false) {
    observedPath = location.pathname;
    const match = location.pathname.match(/\/c\/([0-9a-f-]+)\/?$/i);
    if (!match || !uuid.test(match[1])) return null; // No fabricated identity for temporary/unknown chats.
    const id = match[1].toLowerCase();
    if (id !== conversation) { conversation = id; stable.clear(); sent.clear(); stopped.clear(); lastPage = ""; }
    const now = performance.now(), messages = [], seen = new Set();
    let bytes = 0, needsStableScan = false;
    // Budget newest messages first; an old long message must not starve a new reply.
    const nodes = Array.from(document.querySelectorAll("[data-dil-message-id]")).slice(-500).reverse();
    for (const node of nodes) {
      const messageID = node.getAttribute("data-dil-message-id");
      if (!uuid.test(messageID || "") || seen.has(messageID.toLowerCase())) continue;
      // Live-verified 2026-10-19 profile. The secondary selection message ID is
      // absent while streaming; the primary ID, conversation and role remain present.
      // User bubbles currently expose no stable message ID, so they are deliberately skipped.
      const unit = node.closest("[data-content-search-unit-key]");
      const selection = node.closest("[data-chatgpt-selection-conversation-id]");
      const selectionID = selection?.getAttribute("data-chatgpt-selection-message-id")?.toLowerCase();
      const references = (unit?.getAttribute("data-chatgpt-search-message-ids") || "").toLowerCase().split(/\s+/);
      if (!/:assistant$/.test(unit?.getAttribute("data-content-search-unit-key") || "") ||
          (selectionID && selectionID !== messageID.toLowerCase()) ||
          selection?.getAttribute("data-chatgpt-selection-conversation-id")?.toLowerCase() !== id ||
          !references.includes(messageID.toLowerCase())) continue;
      const role = "assistant";
      const turn = node.closest("[data-talvt-turn-state]");
      // Capture response text, not thinking/tool cards, buttons or the global live region.
      const bodyNode = node;
      const text = bodyNode?.innerText?.trim() || "";
      const size = new TextEncoder().encode(text).length;
      if (size > 1024 * 1024 || bytes + size > 2 * 1024 * 1024 || messages.length >= 500) continue;
      bytes += size;
      const key = messageID.toLowerCase(), hash = signature(text), old = stable.get(key);
      if (!old || old.hash !== hash) stable.set(key, {hash, since: now});
      const settled = now - stable.get(key).since >= 1500;
      const turnState = turn?.getAttribute("data-talvt-turn-state");
      const busy = turnState === "in_progress" || turn?.getAttribute("aria-busy") === "true";
      let state = "unverified", evidence = null;
      if (errorText(text)) state = "readFailure";
      else if (stopped.has(key)) { state = "interrupted"; evidence = "user-stop"; }
      else if (interrupted) state = "interrupted";
      else if (!text) state = busy ? "streaming" : "readFailure";
      else if (busy) state = "streaming";
      // Enabled only for an explicit turn-local state; never infer from quietness, copy buttons,
      // disappearance of Stop, or the screen-reader "回答已完成" announcement.
      else if (turnState === "complete" && settled) { state = "pageEnded"; evidence = "turn-completed-stable"; }
      if (text && !settled && turnState === "complete") needsStableScan = true;
      messages.push({id: key, role, body: state === "readFailure" ? "" : text, state, evidence});
      seen.add(key);
    }
    for (const key of stable.keys()) if (!seen.has(key)) stable.delete(key);
    for (const key of stopped) if (!seen.has(key)) stopped.delete(key);
    const readFailure = messages.some(m => m.role === "assistant" && m.state === "readFailure") || Array.from(document.querySelectorAll("[role=alert], main h1, main h2, main p"))
      .some(n => errorText(n.innerText || ""));
    if (needsStableScan) schedule(1600);
    return {schema: 1, documentID, sequence: ++sequence, conversationID: id,
      pageState: interrupted ? "interrupted" : readFailure ? "readFailure" : messages.length ? "unverified" : "unavailable", messages: messages.reverse()};
  }
  async function scan(interrupted = false) {
    if (!captureEnabled) return;
    if (pending) { dirty = true; return; }
    const batch = collect(interrupted);
    if (!batch) return;
    const all = batch.messages;
    const encoded = new Map(all.map(m => [m.id, JSON.stringify(m)]));
    batch.order = all.map(m => m.id);
    batch.messages = all.filter(m => sent.get(m.id) !== encoded.get(m.id));
    const page = batch.conversationID + ":" + batch.pageState;
    if (!batch.messages.length && page === lastPage) return;
    pending = true;
    try {
      if (await window.webkit.messageHandlers.localReplySnapshot.postMessage(batch) && captureEnabled) {
        lastPage = page;
        sent.clear();
        for (const [key, value] of encoded) sent.set(key, value);
      }
      else schedule(5000);
    } catch (_) { schedule(5000); }
    finally { pending = false; if (dirty) { dirty = false; schedule(0); } }
  }
  function schedule(delay = 300) {
    const due = performance.now() + delay;
    if (timer && timerDue <= due) return;
    if (timer) clearTimeout(timer);
    timerDue = due;
    timer = setTimeout(() => { timer = 0; scan(); }, delay);
  }
  new MutationObserver(() => schedule()).observe(document.documentElement,
    {subtree: true, childList: true, characterData: true, attributes: true,
      attributeFilter: ["data-talvt-turn-state", "data-dil-message-id", "aria-busy",
        "data-chatgpt-selection-message-id", "data-chatgpt-selection-conversation-id",
        "data-content-search-unit-key", "data-chatgpt-search-message-ids"]});
  // Capture before the site's handlers run, without changing or intercepting the send.
  document.addEventListener("submit", () => scan(), true);
  document.addEventListener("keydown", e => { if (e.key === "Enter" && !e.shiftKey) scan(); }, true);
  document.addEventListener("click", event => {
    const button = event.target.closest?.("button");
    const label = button?.getAttribute("aria-label") || button?.getAttribute("title") || button?.innerText || "";
    if (/^(停止|Stop)( generating|响应|生成)?$/i.test(label.trim())) {
      for (const node of document.querySelectorAll('[data-dil-message-id]')) {
        if (node.closest('[data-talvt-turn-state]')?.getAttribute('data-talvt-turn-state') === 'in_progress')
          stopped.add(node.getAttribute('data-dil-message-id').toLowerCase());
      }
    }
    scan();
  }, true);
  addEventListener("pagehide", () => scan(true));
  setInterval(() => { if (!document.hidden && observedPath !== location.pathname) scan(); }, 1000);
  globalThis.__nativeSnapshotScan = scan; // Isolated content world, used by native flush/tests only.
  globalThis.__nativeSnapshotSetEnabled = value => {
    captureEnabled = Boolean(value);
    lastPage = "";
    sent.clear();
    stable.clear();
    if (captureEnabled) scan();
  };
  scan();
})();
