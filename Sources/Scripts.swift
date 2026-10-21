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
    /// visible background at its upper edge, including normal and sticky
    /// headers. Samples rendered CSS after Dark Pages, not theme metadata.
    /// Reports changes on load, scroll, appearance changes and restoration.
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
      function colour() {
        // A logo or sign-in button can occupy the centre. Prefer the colour
        // shared by multiple points across the top; the centre wins ties.
        var colours = [0.5, 0.12, 0.88].map(function (x) {
          return behind(document.elementFromPoint(innerWidth * x, 1));
        }).filter(Boolean);
        if (colours.length) {
          return colours.reduce(function (best, c) {
            var count = function (value) { return colours.filter(function (v) { return v === value; }).length; };
            return count(c) > count(best) ? c : best;
          });
        }
        var root = document.documentElement;
        return opaque(document.body ? getComputedStyle(document.body).backgroundColor : '') ||
          opaque(getComputedStyle(root).backgroundColor) ||
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
      addEventListener('load', soon, true);
      addEventListener('search-top-refresh', soon);
      matchMedia('(prefers-color-scheme: dark)').addEventListener('change', soon);
      // Covers SPA headers and the styles installed/removed by Dark Pages.
      // One sample per frame at most, and no message if the colour is equal.
      new MutationObserver(soon).observe(document.documentElement, {
        childList: true, subtree: true, attributes: true,
        attributeFilter: ['class', 'style', 'media', 'href']
      });
      // Back to a page kept in memory: no script runs again, so say it anew.
      addEventListener('pageshow', function () { last = ''; soon(); });
      soon();
    })();
    """#
}
