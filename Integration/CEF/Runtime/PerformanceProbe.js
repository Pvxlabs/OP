// Manual, bounded numeric diagnostics in OP's existing isolated world.
(() => {
  'use strict';
  if (window !== top || !(location.origin === 'https://chatgpt.com' ||
      (location.origin === '__OP_FIXTURE_ORIGIN__' && location.hostname === '127.0.0.1'))) return;
  const probe = {
    active: false, stats: {},
    begin() { return this.active ? performance.now() : null; },
    end(name, began) {
      if (!this.active || began === null) return;
      const ms = performance.now() - began;
      const value = this.stats[name] ||= {calls: 0, milliseconds: 0, maximum: 0};
      value.calls++; value.milliseconds += ms; value.maximum = Math.max(value.maximum, ms);
    },
    count(name, count = 1) { if (this.active) this.stats[name] = (this.stats[name] || 0) + count; },
    async run() {
      if (this.active) return JSON.stringify({status: 'busy'});
      const path = location.pathname, began = performance.now();
      const metadata = () => ({nodes: document.getElementsByTagName('*').length,
        messages: document.querySelectorAll('[data-dil-message-id]').length,
        turns: document.querySelectorAll('[data-talvt-turn-state]').length,
        width: innerWidth, height: innerHeight, visible: !document.hidden,
        heapBytes: performance.memory?.usedJSHeapSize ?? null});
      const before = metadata(), frames = [], delays = [], longTasks = [];
      let frame = 0, previous = performance.now(), hidden = document.hidden;
      const onVisibility = () => { hidden ||= document.hidden; };
      document.addEventListener('visibilitychange', onVisibility);
      const tick = now => {
        if (!this.active) return;
        if (frames.length < 10000) frames.push(now - previous);
        previous = now; frame = requestAnimationFrame(tick);
      };
      const observer = PerformanceObserver.supportedEntryTypes.includes('longtask')
        ? new PerformanceObserver(list => { for (const e of list.getEntries()) if (longTasks.length < 2000) longTasks.push(e.duration); }) : null;
      observer?.observe({type: 'longtask'});
      this.stats = {}; this.active = true;
      frame = requestAnimationFrame(tick);
      let expected = performance.now() + 100;
      const timer = setInterval(() => {
        const now = performance.now();
        if (delays.length < 1000) delays.push(Math.max(0, now - expected));
        expected = now + 100;
      }, 100);
      await new Promise(resolve => setTimeout(resolve, 30000));
      this.active = false; clearInterval(timer); cancelAnimationFrame(frame); observer?.disconnect();
      document.removeEventListener('visibilitychange', onVisibility);
      const summary = values => {
        const sorted = [...values].sort((a, b) => a - b);
        return {count: sorted.length, total: values.reduce((a, b) => a + b, 0),
          p50: sorted[Math.floor(sorted.length * .5)] ?? null,
          p95: sorted[Math.floor(sorted.length * .95)] ?? null,
          maximum: sorted.at(-1) ?? null, over50: values.filter(v => v > 50).length};
      };
      return JSON.stringify({schema: 1, status: 'measured', elapsedMilliseconds: performance.now() - began,
        startDocumentMilliseconds: began,
        sameConversation: path === location.pathname, hiddenDuringSample: hidden,
        before, after: metadata(),
        conversationReads: performance.getEntriesByType('resource').filter(entry => {
          try { return /^\/backend-api\/(conversation|conversations)(\/|$)/.test(new URL(entry.name).pathname); }
          catch (_) { return false; }
        }).slice(-16).map(entry => ({startMilliseconds: entry.startTime, durationMilliseconds: entry.duration,
          responseStatus: entry.responseStatus ?? null, transferBytes: entry.transferSize,
          decodedBytes: entry.decodedBodySize})),
        frames: summary(frames), eventLoopDelay: summary(delays),
        longTasks: observer ? summary(longTasks) : null, op: this.stats});
    }
  };
  globalThis.__opPerformance = probe;
})();
