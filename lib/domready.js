(function() {
  var ready;
  ready = (function() {
    var ready_event_fired;
    ready_event_fired = false;
    return function(fn) {
      var do_scroll_check, idempotent_fn, _ref;
      idempotent_fn = function() {
        if (!ready_event_fired) {
          ready_event_fired = true;
          return fn();
        }
      };
      do_scroll_check = function() {
        try {
          document.documentElement.doScroll("left");
        } catch (e) {
          setTimeout(do_scroll_check, 1);
          return;
        }
        return idempotent_fn();
      };
      if (document.readyState === "complete") {
        return idempotent_fn();
      }
      if (document.addEventListener) {
        document.addEventListener("DOMContentLoaded", idempotent_fn, false);
        return window.addEventListener("load", idempotent_fn, false);
      } else if (document.attachEvent) {
        document.attachEvent("onreadystatechange", idempotent_fn);
        window.attachEvent("onload", idempotent_fn);
        if ((typeof document !== "undefined" && document !== null ? (_ref = document.documentElement) != null ? _ref.doScroll : void 0 : void 0) && (typeof window !== "undefined" && window !== null ? window.frameElement : void 0) === null) {
          return do_scroll_check();
        }
      }
    };
  })();
  if (window) {
    window.ready = ready;
  }
}).call(this);
