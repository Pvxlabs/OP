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
  // Retain only accepted nodes from the current bounded observation, not all history.
  const bodyCache = new Map();
  let mutations;

  const errorSelector = "[role=alert], main h1, main h2, main p";
  const errorText = text => /^(无法加载此回复|无法加载此 ChatGPT 对话|unable to load (this response|conversation)|something went wrong|network error|too many requests|请求过于频繁)([.。！!：:\s]|$)/i.test(text.trim());
  const signature = text => {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return text.length + ":" + (h >>> 0);
  };
  function collect(interrupted = false) {
    const probe = globalThis.__opPerformance, began = probe?.begin();
    try { return collectBody(interrupted); } finally { probe?.end("collector", began); }
  }
  function collectBody(interrupted = false) {
    observedPath = location.pathname;
    const match = location.pathname.match(/\/c\/([0-9a-f-]+)\/?$/i);
    if (!match || !uuid.test(match[1])) return null; // No fabricated identity for temporary/unknown chats.
    const id = match[1].toLowerCase();
    if (id !== conversation) { conversation = id; stable.clear(); sent.clear(); stopped.clear(); bodyCache.clear(); lastPage = ""; }
    const now = performance.now(), messages = [], seen = new Set(), cachedNodes = new Set();
    let bytes = 0, needsStableScan = false;
    // Budget newest messages first; an old long message must not starve a new reply.
    const nodes = Array.from(document.querySelectorAll("[data-dil-message-id]")).slice(-500).reverse();
    globalThis.__opPerformance?.count("collectorNodes", nodes.length);
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
      let body = bodyCache.get(node);
      if (!body) {
        globalThis.__opPerformance?.count("bodyCacheMisses");
        const text = node.innerText?.trim() || "";
        body = {text, size: new TextEncoder().encode(text).length, hash: signature(text)};
      }
      const {text, size, hash} = body;
      if (size > 1024 * 1024 || bytes + size > 2 * 1024 * 1024 || messages.length >= 500) continue;
      if (body.visibleError === undefined) {
        body.visibleError = Array.from(node.querySelectorAll(errorSelector)).some(n => errorText(n.innerText || ""));
      }
      bodyCache.set(node, body); cachedNodes.add(node);
      bytes += size;
      const key = messageID.toLowerCase(), old = stable.get(key);
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
    for (const node of bodyCache.keys()) if (!cachedNodes.has(node)) bodyCache.delete(node);
    for (const key of stable.keys()) if (!seen.has(key)) stable.delete(key);
    for (const key of stopped) if (!seen.has(key)) stopped.delete(key);
    // Live-observed conversation errors may be role-less divs rather than alerts.
    // Require the exact error line plus the site's retry action, and no identified
    // messages. Do not classify arbitrary quoted error text in a normal reply.
    const conversationReadError = !messages.length && Array.from(document.querySelectorAll("button"))
      .some(n => /^(再试一次|Try again)$/i.test((n.innerText || "").trim())) &&
      (document.body?.innerText || "").split("\n").some(line =>
        /^(无法加载此\s*ChatGPT\s*对话|unable to load conversation)[。.!\s]*$/i.test(line.trim()));
    const cachedError = Array.from(bodyCache.values()).some(body => body.visibleError);
    const readFailure = conversationReadError || cachedError || messages.some(m => m.role === "assistant" && m.state === "readFailure") ||
      Array.from(document.querySelectorAll(errorSelector)).some(n => {
        const owner = n.closest("[data-dil-message-id]");
        // Rendered error checks within unchanged accepted bodies were already cached.
        // Unidentified/global errors still use the full original visible-text check.
        return !(owner && cachedNodes.has(owner)) && errorText(n.innerText || "");
      });
    if (needsStableScan) schedule(1600);
    return {schema: 1, documentID, sequence: ++sequence, conversationID: id,
      pageState: interrupted ? "interrupted" : readFailure ? "readFailure" : messages.length ? "unverified" : "unavailable", messages: messages.reverse()};
  }
  async function scan(interrupted = false) {
    if (!captureEnabled) return;
    if (pending) { dirty = true; return; }
    // A pre-send/native flush can run before MutationObserver's microtask delivery.
    consumeMutations(mutations?.takeRecords() || []);
    const batch = collect(interrupted);
    if (!batch) return;
    const all = batch.messages;
    const encoded = new Map(all.map(m => [m.id, m]));
    batch.order = all.map(m => m.id);
    batch.messages = all.filter(m => {
      const previous = sent.get(m.id);
      return !previous || previous.body !== m.body || previous.role !== m.role ||
        previous.state !== m.state || previous.evidence !== m.evidence;
    });
    const page = batch.conversationID + ":" + batch.pageState;
    if (!batch.messages.length && page === lastPage) return;
    globalThis.__opPerformance?.count("snapshotBatches");
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
  const captureRegion = "[data-dil-message-id],[data-content-search-unit-key],[data-chatgpt-selection-conversation-id],[data-talvt-turn-state],[role=alert],main";
  function relevantNode(node) {
    if (node.nodeType === Node.TEXT_NODE) return errorText(node.data || "");
    if (node.nodeType !== Node.ELEMENT_NODE) return false;
    // Include identity arrival/removal, global errors, and retry controls. The
    // route watcher and pre-send/stop/pagehide flush remain independent of this filter.
    return node.matches(captureRegion + ",p,h1,h2,button") ||
      Boolean(node.querySelector(captureRegion + ",p,h1,h2,button")) ||
      (!node.childElementCount && errorText(node.textContent || ""));
  }
  function consumeMutations(records) {
    const probe = globalThis.__opPerformance, began = probe?.begin();
    probe?.count("mutationRecords", records.length);
    try { return consumeMutationRecords(records); } finally { probe?.end("mutations", began); }
  }
  function consumeMutationRecords(records) {
    let relevant = false;
    for (const record of records) {
      const target = record.target.nodeType === Node.ELEMENT_NODE ? record.target : record.target.parentElement;
      const containing = target?.closest("[data-dil-message-id]");
      if (containing) bodyCache.delete(containing);
      const renderingAttribute = record.type === "attributes" && ["class", "style", "hidden"].includes(record.attributeName);
      // Reparenting/removal and ancestor visibility changes can alter rendered text
      // without changing textContent. Invalidate those cached bodies conservatively.
      const changedTrees = renderingAttribute ? [target] : [...(record.addedNodes || []), ...(record.removedNodes || [])];
      let invalidated = false;
      for (const tree of changedTrees) {
        if (tree?.nodeType !== Node.ELEMENT_NODE) continue;
        for (const node of bodyCache.keys()) if (tree.contains(node)) { bodyCache.delete(node); invalidated = true; }
      }
      if (record.type === "attributes" && !renderingAttribute) relevant = true;
      else if (invalidated || target?.closest(captureRegion)) relevant = true;
      else if (record.type === "characterData") relevant ||= errorText(record.target.data || "");
      else if (record.type === "childList") relevant ||= changedTrees.some(relevantNode);
    }
    return relevant;
  }
  mutations = new MutationObserver(records => {
    if (captureEnabled && consumeMutations(records)) schedule();
  });
  mutations.observe(document.documentElement,
    {subtree: true, childList: true, characterData: true, attributes: true,
      attributeFilter: ["data-talvt-turn-state", "data-dil-message-id", "aria-busy", "class", "style", "hidden", "role",
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
    bodyCache.clear();
    if (captureEnabled) scan();
  };
  scan();
})();
