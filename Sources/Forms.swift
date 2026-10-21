import Foundation

// Sign-in forms: the page says when a sign-in box is touched and when a
// password is sent; Search offers what it keeps, fills it in, and offers to
// keep a new one. In the page's own frame (main frame only), in a world of
// Search's own, so the page's scripts can't read it.

enum Forms {
    static let name = "searchForms"

    static let script = #"""
    (() => {
      if (window.__searchForms) return;
      const post = (message) => {
        try { window.webkit.messageHandlers.searchForms.postMessage(message); } catch (e) {}
      };
      const passwordIn = (root) => root && root.querySelector && root.querySelector('input[type="password"]');
      // Adapted from Search upstream 4be2fd3: accessible names matter too.
      const aside = (el) => {
        const words = [el.name, el.id, el.getAttribute('autocomplete'), el.getAttribute('aria-label'),
          el.getAttribute('placeholder')].join(' ').toLowerCase();
        return el.type === 'search' || /(^|[\s_-])(q|title)($|[\s_-])|query|search|otp|otc|one-time|captcha|code|coupon|promo/.test(words) ||
          !!(el.closest && el.closest('[role="search"]'));
      };
      const isUser = (el) => el && el.tagName === 'INPUT' && !aside(el) &&
        (/^(email|text|tel)$/i.test(el.type || 'text')) &&
        (/user|login|email|mail|account|nombre|usuario|correo/i.test((el.name || '') + ' ' + (el.id || '') + ' ' + (el.autocomplete || '')) ||
         el.type === 'email' || el.autocomplete === 'username');
      const userFor = (password) => {
        const scope = password.form || document;
        const fields = [...scope.querySelectorAll('input')].filter((f) => !aside(f) && (f.offsetParent !== null || f === document.activeElement));
        const before = fields.slice(0, fields.indexOf(password)).reverse();
        return before.find(isUser) || before.find((f) => /^(email|text|tel)$/i.test(f.type || 'text')) || null;
      };
      // A value set the way typing sets it, so the page's own framework sees it.
      const setValue = (el, value) => {
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(el, value);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      };
      document.addEventListener('focusin', (event) => {
        const el = event.target;
        if (!el || el.tagName !== 'INPUT' || aside(el)) return;
        const password = el.type === 'password' ? el : passwordIn(el.form);
        if (password || isUser(el)) post({ kind: 'focus' });
      }, true);
      const sent = (form) => {
        const password = passwordIn(form || document);
        if (!password || !password.value) return;
        const user = userFor(password);
        post({ kind: 'submit', user: user ? user.value : '', password: password.value });
      };
      document.addEventListener('submit', (event) => sent(event.target), true);
      // Many sign-ins never submit a form: their button runs a script instead.
      document.addEventListener('click', (event) => {
        const button = event.target && event.target.closest && event.target.closest('button, input[type="submit"], [role="button"]');
        if (!button) return;
        const scope = button.form || button.closest('form') || document;
        if (passwordIn(scope)) setTimeout(() => sent(scope), 0);
      }, true);
      window.__searchForms = {
        fill(user, password) {
          const field = document.activeElement && document.activeElement.tagName === 'INPUT' ? document.activeElement : null;
          const passwordField = field && field.type === 'password' ? field : passwordIn((field && field.form) || document);
          if (!passwordField) return false;
          const userField = userFor(passwordField);
          if (userField && user) setValue(userField, user);
          setValue(passwordField, password);
          return true;
        }
      };
    })();
    """#

    /// The call that fills a sign-in in, with both values written as JSON
    /// strings so nothing in them can be read as script.
    static func fill(user: String, password: String) -> String {
        func quoted(_ text: String) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: [text])) ?? Data("[\"\"]".utf8)
            let array = String(data: data, encoding: .utf8) ?? "[\"\"]"
            return String(array.dropFirst().dropLast())
        }
        return "window.__searchForms && window.__searchForms.fill(\(quoted(user)), \(quoted(password)))"
    }
}
