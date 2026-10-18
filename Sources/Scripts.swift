import Foundation

// The page scripts, from Resources/JS: the same code as Search for Mac's
// DarkPages.swift, Reader.swift and ReaderText.swift, by way of Penumbra
// (see NOTICE).

enum Scripts {
    private static func load(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }

    /// Dark Pages: in at document start, main frame only.
    static let dark = load("dark")
    static let darkOff = "window.__penumbraDark && window.__penumbraDark.off(); true"

    /// Reading mode: the article, then (if wanted) only its words, then the
    /// phone's viewport and Dark Pages looking again.
    static let reader = load("reader")
    static let textOnly = load("text-only")
    static let readerAfter = load("reader-after")

    /// The colour at the top of the page, for the band under the clock: a
    /// bar the page holds there (position fixed or sticky), or else the
    /// page's own background. Said again only when it changes: on load, on
    /// scroll, on a turn of the phone, and back on a page kept in memory.
    static let top = #"""
    (function () {
      if (window.__searchTop) return;
      window.__searchTop = true;
      function opaque(c) {
        var m = /rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/.exec(c || '');
        return m && (m[4] === undefined || parseFloat(m[4]) > 0.9) ? 'rgb(' + m[1] + ',' + m[2] + ',' + m[3] + ')' : '';
      }
      function behind(el) {
        for (; el && el.nodeType === 1; el = el.parentElement) {
          var c = opaque(getComputedStyle(el).backgroundColor);
          if (c) return c;
        }
        return '';
      }
      function held(el) {
        for (; el && el.nodeType === 1; el = el.parentElement) {
          var p = getComputedStyle(el).position;
          if ((p === 'fixed' || p === 'sticky') && el.getBoundingClientRect().top <= 1) return true;
        }
        return false;
      }
      function colour() {
        var at = document.elementFromPoint(innerWidth / 2, 1);
        if (held(at)) { var bar = behind(at); if (bar) return bar; }
        var root = document.documentElement;
        return opaque(getComputedStyle(root).backgroundColor) ||
          opaque(document.body ? getComputedStyle(document.body).backgroundColor : '') ||
          (/dark/.test(getComputedStyle(root).colorScheme || '') && matchMedia('(prefers-color-scheme: dark)').matches
            ? 'rgb(0,0,0)' : 'rgb(255,255,255)');
      }
      var last = '', queued = false;
      function say() {
        queued = false;
        var c = colour();
        if (c === last) return;
        last = c;
        window.webkit.messageHandlers.searchForms.postMessage({ kind: 'top', color: c });
      }
      function soon() { if (!queued) { queued = true; requestAnimationFrame(say); } }
      addEventListener('scroll', soon, { passive: true });
      addEventListener('resize', soon);
      addEventListener('load', soon);
      // Back to a page kept in memory: no script runs again, so say it anew.
      addEventListener('pageshow', function () { last = ''; soon(); });
      soon();
    })();
    """#
}
