(async function (config) {
  const reply = (status, reason = '') => JSON.stringify({request: config.request, status, reason});
  const normalize = text => String(text || '').replace(/\s+/g, ' ').trim();
  const visible = node => {
    if (!(node instanceof HTMLElement) || getComputedStyle(node).visibility === 'hidden') return false;
    if (node.getClientRects().length > 0) return true;
    // display:contents message wrappers have no box, even when their text is rendered.
    if (getComputedStyle(node).display !== 'contents') return false;
    const range = document.createRange();
    range.selectNodeContents(node);
    return range.getClientRects().length > 0;
  };
  const identity = () => location.pathname.match(/^\/c\/([0-9a-f-]{36})\/?$/i)?.[1]?.toLowerCase() === config.conversation;
  if (window !== top || !identity()) return reply('waiting', '请先打开要查询的 ChatGPT 对话。');
  const busy = () => [...document.querySelectorAll('button[data-testid="stop-button"], button[aria-label="Stop generating"], button[aria-label="停止生成"], [data-is-streaming="true"], [data-talvt-turn-state="in_progress"]')].some(visible);
  const modal = () => [...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')].some(visible);
  if (busy()) return reply('waiting', 'ChatGPT 正在生成，请结束后再点击收取。');
  if (modal()) return reply('waiting', '请先关闭网页对话框。');
  const editors = [...document.querySelectorAll('form [contenteditable="true"]')].filter(visible);
  if (editors.length !== 1) return reply('waiting', '未找到 ChatGPT 输入框。');
  const editor = editors[0], form = editor.closest('form');
  if (editor.getAttribute('aria-disabled') === 'true' || editor.getAttribute('contenteditable') !== 'true') return reply('waiting', '输入框暂不可用。');
  if (normalize(editor.innerText) || editor.querySelector('img, [data-type="mention"]')) return reply('waiting', '输入框已有草稿，请先处理草稿后再点击收取。');
  const attachments = () => [...form.querySelectorAll('img, [data-testid*="attachment"], button[aria-label^="Remove"], button[aria-label^="移除"], input[type="file"]')]
    .some(node => node instanceof HTMLInputElement ? node.files?.length : visible(node));
  if (attachments()) return reply('waiting', '输入区有附件，请先处理附件后再点击收取。');
  const users = () => [...document.querySelectorAll('[data-content-search-unit-key$=":user"], [data-message-author-role="user"]')]
    .filter(node => visible(node) && !node.parentElement?.closest('[data-content-search-unit-key$=":user"], [data-message-author-role="user"]'));
  const matches = () => users().filter(node => {
    const copy = node.cloneNode(true);
    copy.querySelectorAll('button, [role="button"], [aria-hidden="true"]').forEach(n => n.remove());
    return normalize(copy.textContent) === normalize(config.message);
  });
  const messageKey = node => node.getAttribute('data-content-search-unit-key');
  // A previous identical query does not suppress a new explicit click.
  // History may be unmounted as the new turn arrives; its total count need not grow.
  const previous = new Set(matches().map(messageKey));
  if (Date.now() > config.deadline || !identity() || busy() || modal() || attachments()) return reply('waiting', '页面状态已改变，请重新点击收取。');
  if (config.preflight === true) return reply('ready');
  editor.focus();
  if (document.activeElement !== editor) return reply('waiting', '输入框无法获得焦点。');
  const selection = getSelection(), range = document.createRange();
  range.selectNodeContents(editor); range.collapse(false); selection.removeAllRanges(); selection.addRange(range);
  if (!document.execCommand('insertText', false, config.message)) return reply('uncertain', '未能写入查询，请检查输入框。');
  for (let i = 0; i < 20; i++) {
    if (Date.now() > config.deadline || !identity() || !editor.isConnected || !visible(editor) || busy() || modal() || attachments() ||
        normalize(editor.innerText) !== normalize(config.message)) return reply('uncertain', '页面或输入已改变，未继续发送；请检查当前对话和草稿。');
    const buttons = [...form.querySelectorAll('button[type="submit"]')].filter(visible);
    if (buttons.length === 1 && !buttons[0].disabled && buttons[0].getAttribute('aria-disabled') !== 'true') {
      buttons[0].click();
      for (let j = 0; j < 60; j++) {
        if (!identity()) return reply('uncertain', '发送后对话已切换，请检查原对话。');
        if (matches().some(node => {
          const key = messageKey(node);
          return key && !previous.has(key);
        })) return reply('sent');
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      return reply('uncertain', '尚未核验到新的查询消息，请检查当前对话；不会自动重发。');
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  return reply('uncertain', '网页发送按钮不可用，查询已留在输入框，请检查后手动发送。');
})
