(async function (config) {
  const reply = (status, reason = '', observation) => JSON.stringify({request: config.request, status, reason, observation});
  const normalize = text => String(text || '').replace(/\s+/g, ' ').trim();
  const visible = node => node instanceof HTMLElement && node.getClientRects().length > 0 && getComputedStyle(node).visibility !== 'hidden';
  const identity = () => location.pathname.match(/^\/c\/([0-9a-f-]{36})\/?$/i)?.[1]?.toLowerCase() === config.conversation;
  const scope = () => [...document.querySelectorAll('[data-chatgpt-selection-conversation-id]')].some(node =>
    visible(node) && node.getAttribute('data-chatgpt-selection-conversation-id')?.toLowerCase() === config.conversation);
  if (window !== top || !identity() || !scope()) return reply('waiting', '等待核验原对话身份。');
  const users = () => [...document.querySelectorAll('[data-content-search-unit-key$=":user"]')].filter(visible);
  // Long user messages are visually collapsed and include Show more/less
  // controls. Match the full DOM text, excluding controls, to the frozen payload.
  const userText = node => {
    const copy = node.cloneNode(true);
    copy.querySelectorAll('button, [role="button"], [aria-hidden="true"]').forEach(n => n.remove());
    copy.querySelectorAll('br').forEach(n => n.replaceWith('\n'));
    return normalize(copy.textContent);
  };
  if (config.inspect) {
    const units = [...document.querySelectorAll('[data-content-search-unit-key]')].filter(visible);
    const assistant = n => /:assistant$/.test(n.getAttribute('data-content-search-unit-key') || '');
    const precedingUser = n => units.slice(0, units.indexOf(n)).reverse().find(e => /:user$/.test(e.getAttribute('data-content-search-unit-key') || ''));
    const complete = n => n.closest('[data-talvt-turn-state]')?.getAttribute('data-talvt-turn-state') === 'complete';
    const witnesses = units.filter(assistant).flatMap(unit => {
      const prior = precedingUser(unit)?.innerText || '';
      if (/\[OP-CLINX(?::|-IDENTIFY:)/.test(prior) || !complete(unit)) return [];
      const body = unit.querySelector('[data-dil-message-id]');
      const id = body?.getAttribute('data-dil-message-id');
      const owner = body?.closest('[data-chatgpt-selection-conversation-id]');
      if (!/^[0-9a-f-]{36}$/i.test(id || '') || owner?.getAttribute('data-chatgpt-selection-conversation-id')?.toLowerCase() !== config.conversation) return [];
      const text = body.innerText || '';
      if (!/CLINX|clinx_|Codex|task_ref|execution_ref/i.test(text + (unit.closest('[data-talvt-turn-state]')?.innerText || ''))) return [];
      return [{id: id.toLowerCase(), excerpt: text.slice(0, 1600)}];
    }).slice(-100);
    let selections, answerComplete = false;
    if (config.identification && config.marker && config.message) {
      const queries = users().filter(n => userText(n) === normalize(config.message));
      if (queries.length === 1) {
        const after = units.slice(units.indexOf(queries[0]) + 1);
        const response = after[0];
        if (response && assistant(response) && complete(response)) {
          answerComplete = true;
          const texts = [...response.querySelectorAll('pre code')].map(n => n.innerText);
          texts.push(response.innerText || '');
          for (const text of texts) {
            if (text.length > 20000) continue;
            try {
              const data = JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1));
              if (data.op_clinx_identification !== config.identification || data.conversation_id !== config.conversation ||
                  !Array.isArray(data.tasks) || data.tasks.length > 10 || !data.tasks.every(t => t && t.created_here === true &&
                    /^[A-Za-z0-9_-]{1,128}$/.test(t.task_ref || '') && /^exec_[A-Za-z0-9]{1,96}$/.test(t.execution_ref || ''))) continue;
              selections = data.tasks.map(t => ({task_ref:t.task_ref, execution_ref:t.execution_ref, created_here:true}));
              break;
            } catch {}
          }
        }
      }
    }
    return reply('observed', '', {witnesses, selections, answerComplete});
  }
  const readback = () => {
    const matches = users().filter(node => userText(node) === normalize(config.message));
    if (matches.length !== 1) return null;
    const user = matches[0];
    const assistant = [...document.querySelectorAll('[data-message-author-role="assistant"], [data-content-search-unit-key$=":assistant"]')]
      .find(node => visible(node) && normalize(node.innerText) && (user.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING));
    return reply(assistant ? 'responding' : 'sent');
  };
  const existing = readback();
  if (existing) return existing;
  if (config.verify) return reply('uncertain', '原对话中尚未找到匹配回执。');
  if (Date.now() > config.deadline) return reply('waiting', '本次回传检查已过期，稍后重新核对。');
  // A partial/different receipt or duplicate marker is not safe to send again.
  if (users().some(node => node.innerText.includes(config.marker))) return reply('uncertain', '已存在回执标记，需人工核对内容。');
  const busy = () => [...document.querySelectorAll('button[data-testid="stop-button"], button[aria-label="Stop generating"], button[aria-label="停止生成"], [data-is-streaming="true"], [data-talvt-turn-state="in_progress"]')].some(visible);
  if (busy()) return reply('waiting', 'ChatGPT 正在生成，稍后回传。');
  if ([...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')].some(visible)) return reply('waiting', '请先关闭网页对话框。');
  const editors = [...document.querySelectorAll('form [contenteditable="true"]')].filter(visible);
  if (editors.length !== 1) return reply('waiting', '未找到可核验的 ChatGPT 输入框。');
  const editor = editors[0];
  if (!editor.closest('form') || editor.getAttribute('aria-disabled') === 'true') return reply('waiting', '输入框暂不可用。');
  const form = editor.closest('form');
  if (normalize(editor.innerText) || editor.querySelector('img, [data-type="mention"]')) return reply('waiting', '输入框已有草稿，保留原文并等待。');
  if ([...form.querySelectorAll('img, [data-testid*="attachment"], button[aria-label^="Remove"], button[aria-label^="移除"], input[type="file"]')]
      .some(node => node instanceof HTMLInputElement ? node.files?.length : visible(node))) return reply('waiting', '输入区有附件，等待处理后回传。');
  if (!identity() || !scope() || busy()) return reply('waiting', '会话状态已改变，稍后重新核对。');
  // Use the real contenteditable input path. No private ChatGPT HTTP endpoint or
  // application internals; never replace HTML or an existing draft.
  editor.focus();
  if (document.activeElement !== editor) return reply('waiting', '输入框无法获得焦点。');
  const selection = getSelection(), range = document.createRange();
  range.selectNodeContents(editor); range.collapse(false); selection.removeAllRanges(); selection.addRange(range);
  if (!document.execCommand('insertText', false, config.message)) return reply('uncertain', '未能写入回执，请检查草稿。');
  // Wait for the site's editor state to expose its ordinary send button. Any
  // user edit/navigation during this interval stops the send and preserves text.
  for (let i = 0; i < 20; i++) {
    if (Date.now() > config.deadline || !identity() || !scope() || busy() || normalize(editor.innerText) !== normalize(config.message)) return reply('uncertain', '输入、会话或回传时限已改变，回执未自动重试。');
    const buttons = [...form.querySelectorAll('button[type="submit"]')].filter(visible);
    if (buttons.length === 1 && !buttons[0].disabled && buttons[0].getAttribute('aria-disabled') !== 'true') {
      buttons[0].click();
      for (let j = 0; j < 60; j++) {
        if (!identity()) return reply('uncertain', '发送后会话已切换。');
        const found = readback();
        if (found) return found;
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      return reply('uncertain', '发送后尚未核验到用户回执。');
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  return reply('uncertain', '回执已留在输入框，但网页发送按钮不可用。');
})
