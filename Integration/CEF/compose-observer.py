"""Adapt the shared DOM profile's transport only; no site CSS or network interception."""
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
source = source.replace('__ALLOW_FIXTURES__', 'true').replace('__CAPTURE_ENABLED__', 'globalThis.__opCaptureEnabled !== false')
source = source.replace('fixtures && location.protocol === "snapshot-fixture:" && location.hostname === "local"', 'fixtures && location.origin === "__OP_FIXTURE_ORIGIN__" && location.hostname === "127.0.0.1"')
source = source.replace('window.webkit.messageHandlers.localReplySnapshot.postMessage(batch)', 'postSnapshot(batch)')
bootstrap = '''(() => {
if (!(location.origin === 'https://chatgpt.com' || (location.origin === '__OP_FIXTURE_ORIGIN__' && location.hostname === '127.0.0.1'))) return;
if (globalThis.__opObserverStarted) return;
globalThis.__opObserverStarted = true;
let request = 0;
const pending = new Map();
globalThis.__opAck = (id, accepted) => { const callback = pending.get(id); if (callback) { pending.delete(id); callback(Boolean(accepted)); } };
const postSnapshot = batch => new Promise(resolve => {
  if (pending.size || !globalThis.__opSnapshot) { resolve(false); return; }
  const id = ++request;
  pending.set(id, resolve);
  globalThis.__opSnapshot(JSON.stringify({request: id, batch}));
  setTimeout(() => { if (pending.has(id)) { pending.delete(id); resolve(false); } }, 10000);
});
const start = () => {
'''
Path(sys.argv[2]).write_text(bootstrap + source + '\n};\nif (document.documentElement) start(); else addEventListener("DOMContentLoaded", start, {once: true});\n})();\n')
