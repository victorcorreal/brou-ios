// Once reading mode has put the article in place, and text-only.js has
// taken everything but the words out of it.

(() => {
  if (!document.getElementById('penumbra-reader')) return 'none';
  // A phone lays out a page that names no viewport of its own 980 points
  // wide: the article would come out in tiny print.
  if (!document.querySelector('meta[name="viewport"]')) {
    const viewport = document.createElement('meta');
    viewport.name = 'viewport';
    viewport.content = 'width=device-width, initial-scale=1';
    document.head.appendChild(viewport);
  }
  // A white page now, whatever the site was: Dark Pages looks again.
  if (window.__penumbraDark) window.__penumbraDark.check();
  return 'read';
})();
