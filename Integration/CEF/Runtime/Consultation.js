(() => {
  'use strict';
  const origin = location.origin;
  if (window !== top || !(origin === 'https://chatgpt.com' ||
      (origin === '__OP_FIXTURE_ORIGIN__' && location.hostname === '127.0.0.1'))) return;
  const normalize = text => String(text || '').replace(/\s+/g, ' ').trim();
  const visible = node => node instanceof HTMLElement && node.getClientRects().length > 0 && getComputedStyle(node).visibility !== 'hidden';
  const selector = '[data-content-search-unit-key$=":user"], [data-content-search-unit-key$=":assistant"], [data-message-author-role="user"], [data-message-author-role="assistant"]';
  const messages = () => [...document.querySelectorAll(selector)].filter(node => !node.parentElement?.closest(selector));
  const role = node => node.getAttribute('data-message-author-role') || node.getAttribute('data-content-search-unit-key')?.split(':').at(-1);
  const text = node => {
    const copy = node.cloneNode(true);
    copy.querySelectorAll('button, [role="button"], [aria-hidden="true"]').forEach(n => n.remove());
    return normalize(copy.textContent);
  };
  const busy = () => [...document.querySelectorAll('button[data-testid="stop-button"], button[aria-label="Stop generating"], button[aria-label="停止生成"], [data-is-streaming="true"], [data-talvt-turn-state="in_progress"]')].some(visible);
  const live = new WeakSet(), stopped = new WeakSet(), stable = new Map();
  const observe = () => document.querySelectorAll('[data-talvt-turn-state="in_progress"]').forEach(turn => live.add(turn));
  const start = () => {
    observe();
    new MutationObserver(observe).observe(document.documentElement, {subtree:true,childList:true,attributes:true,attributeFilter:['data-talvt-turn-state']});
    document.addEventListener('click', event => {
      const button = event.target.closest?.('button');
      const label = button?.getAttribute('aria-label') || button?.getAttribute('title') || '';
      if (button?.getAttribute('data-testid') === 'stop-button' || /^(停止|Stop)( generating|响应|生成)?$/i.test(label.trim())) {
        document.querySelectorAll('[data-talvt-turn-state="in_progress"]').forEach(turn => stopped.add(turn));
      }
    }, true);
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape') document.querySelectorAll('[data-talvt-turn-state="in_progress"]').forEach(turn => stopped.add(turn));
    }, true);
  };
  if (document.documentElement) start(); else addEventListener('DOMContentLoaded', start, {once:true});
  globalThis.__opConsultation = async config => {
    const result = (status, reason='', extra={}) => JSON.stringify({request:config.request,status,reason,...extra});
    const conversation = location.pathname.match(/^\/c\/([0-9a-f-]{36})\/?$/i)?.[1]?.toLowerCase();
    if (!conversation || window !== top || location.origin !== origin ||
        (config.conversation && config.conversation !== conversation)) return result('blocked','conversation_mismatch');
    const identity = () => location.origin === origin && location.pathname.replace(/\/$/,'') === '/c/' + conversation;
    const alerts = [...document.querySelectorAll('[role="alert"], [data-testid="login-button"], a[href*="/auth/login"]')].filter(visible);
    if (alerts.length || /^(Just a moment|Verify you are human)/i.test(document.title)) return result('blocked','login_challenge_or_page_error');
    if (config.operation === 'inspect') {
      if (busy() || document.querySelectorAll('form [contenteditable="true"]').length !== 1) return result('blocked','composer_or_generation_unavailable');
      return result('ready','',{conversation});
    }
    const marker = 'OP_CONSULT_REQUEST:' + config.request_id;
    const all = messages();
    const users = all.filter(node => role(node) === 'user' && text(node).includes(marker));
    if (users.length > 1) return result('blocked','duplicate_request_bubbles');
    if (users.length === 1) {
      const user = users[0];
      if (text(user) !== normalize(config.message)) return result('blocked','user_payload_mismatch');
      const userID = user.getAttribute('data-message-id') || user.getAttribute('data-content-search-unit-key');
      if (!userID || userID.length > 256) return result('blocked','user_identity_unavailable');
      const next = all[all.indexOf(user) + 1];
      if (!next) return result('sent','',{user_message_id:userID});
      if (role(next) !== 'assistant') return result('blocked','interleaved_user_turn');
      const turn = next.closest('[data-talvt-turn-state]');
      const bodies = next.matches('[data-dil-message-id]') ? [next] : [...next.querySelectorAll('[data-dil-message-id]')];
      if (!turn || bodies.length !== 1) return result('sent','assistant_identity_pending',{user_message_id:userID});
      if (stopped.has(turn)) return result('blocked','user_stopped_reply');
      if (turn.getAttribute('data-talvt-turn-state') === 'in_progress') { live.add(turn); return result('sent','reply_generating',{user_message_id:userID}); }
      if (turn.getAttribute('data-talvt-turn-state') !== 'complete') return result('blocked','reply_state_ambiguous');
      // Recovered history may be readable, but lacks same-document generation evidence.
      if (!live.has(turn)) return result('blocked','completion_not_observed_in_this_document');
      const body = bodies[0], id = body.getAttribute('data-dil-message-id')?.toLowerCase();
      const scope = body.closest('[data-chatgpt-selection-conversation-id]');
      const refs = (body.closest('[data-content-search-unit-key]')?.getAttribute('data-chatgpt-search-message-ids') || '').toLowerCase().split(/\s+/);
      if (!/^[0-9a-f-]{36}$/.test(id || '') || scope?.getAttribute('data-chatgpt-selection-conversation-id')?.toLowerCase() !== conversation || !refs.includes(id)) return result('blocked','reply_identity_mismatch');
      const reply = (body.innerText || '').trim();
      if (!reply || !reply.includes(marker) || new TextEncoder().encode(reply).length > 1024*1024 || turn.querySelector('[role="alert"]')) return result('blocked','reply_body_or_marker_unreadable');
      const old = stable.get(config.request_id), now = performance.now();
      if (!old || old.id !== id || old.reply !== reply) {
        stable.set(config.request_id,{id,reply,since:now});
        if (stable.size > 100) stable.delete(stable.keys().next().value);
        return result('sent','reply_settling',{user_message_id:userID});
      }
      if (now - old.since < 1500) return result('sent','reply_settling',{user_message_id:userID});
      if (!identity()) return result('blocked','conversation_changed');
      return result('completed','',{user_message_id:userID,reply_id:id,reply});
    }
    if (config.operation === 'preflight') return globalThis.__opSendExecutionQuery({...config,preflight:true});
    if (config.operation !== 'send') return result('missing','no_matching_user_bubble_read_only');
    // Reuse the existing production composer guards and exact-payload bubble readback.
    if (!identity()) return result('blocked','conversation_changed');
    return globalThis.__opSendExecutionQuery(config);
  };
})();
