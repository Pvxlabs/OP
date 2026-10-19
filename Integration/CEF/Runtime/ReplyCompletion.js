(() => {
  'use strict';
  if (window !== top || !(location.origin === 'https://chatgpt.com' ||
      (location.origin === '__OP_FIXTURE_ORIGIN__' && location.hostname === '127.0.0.1'))) return;
  if (globalThis.__opCompletionStarted) return;
  globalThis.__opCompletionStarted = true;
  const start = () => {
  const documentID = crypto.randomUUID();
  let conversation = '', current = null, sequence = 0, timer = 0;
  const schedule = (delay = 30) => {
    clearTimeout(timer);
    timer = setTimeout(scan, delay);
  };
  function scan() {
    timer = 0;
    const id = location.pathname.match(/\/c\/([0-9a-f-]{36})\/?$/i)?.[1]?.toLowerCase() || '';
    if (conversation !== id) { conversation = id; current = null; }
    if (!id) return;
    const turn = [...document.querySelectorAll('main [data-talvt-turn-state]')].reverse()
      .find(t => t.querySelector('[data-message-author-role="assistant"], [data-content-search-unit-key$=":assistant"]'));
    if (!turn) { current = null; return; }
    if (current?.turn !== turn) current = {turn, pending: false, stopped: false, text: '', since: 0};
    const state = turn.getAttribute('data-talvt-turn-state');
    if (state === 'in_progress') {
      if (!current.pending) { current.pending = true; current.stopped = false; current.sequence = ++sequence; }
      current.since = 0;
      return;
    }
    if (!current.pending) return; // Initial history, reload and repeated completed DOM are silent.
    if (state !== 'complete' || current.stopped) { current.pending = false; return; }
    const body = turn.querySelector('[data-message-author-role="assistant"], [data-content-search-unit-key$=":assistant"]');
    const text = (body?.textContent || '').trim();
    if (!text || /^(无法加载|unable to load|something went wrong|network error|too many requests|请求过于频繁)([.。！!：:\s]|$)/i.test(text) ||
        turn.querySelector('[role="alert"]')) { current.pending = false; return; }
    const now = performance.now();
    if (!current.since || current.text !== text) { current.text = text; current.since = now; }
    const remaining = 1500 - (now - current.since);
    if (remaining > 0) { schedule(remaining + 20); return; }
    current.pending = false;
    globalThis.__opReplyEnded?.(JSON.stringify({documentID, conversationID: id, sequence: current.sequence}));
  }
  new MutationObserver(() => schedule()).observe(document.documentElement,
    {subtree: true, childList: true, characterData: true, attributes: true,
     attributeFilter: ['data-talvt-turn-state', 'data-content-search-unit-key', 'data-message-author-role']});
  document.addEventListener('click', event => {
    const button = event.target.closest?.('button');
    const label = button?.getAttribute('aria-label') || button?.getAttribute('title') || button?.innerText || '';
    if (button?.getAttribute('data-testid') === 'stop-button' || /^(停止|Stop)( generating|响应|生成)?$/i.test(label.trim())) {
      scan();
      if (current?.pending) current.stopped = true;
    }
  }, true);
  addEventListener('pagehide', () => { clearTimeout(timer); current = null; });
  scan();
  };
  if (document.documentElement) start(); else addEventListener('DOMContentLoaded', start, {once: true});
})();
