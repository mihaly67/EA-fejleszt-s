// ==UserScript==
// @name         Idle Callback Polyfill (Anti-Freeze)
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Prevents infinite loops in task schedulers by strictly enforcing time limits.
// @author       Jules
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    const originalRIC = window.requestIdleCallback;

    // Monkey-patch requestIdleCallback to be safer
    window.requestIdleCallback = function(callback, options) {
        const wrap = (deadline) => {
            // Proxy the deadline object to enforce strict limits
            const safeDeadline = {
                didTimeout: deadline.didTimeout,
                timeRemaining: function() {
                    // Force a maximum of 5ms reporting, or strict 0 if time is up
                    // This tricks aggressive schedulers into yielding earlier.
                    const val = deadline.timeRemaining();
                    return Math.max(0, Math.min(val, 5));
                }
            };
            callback(safeDeadline);
        };

        // Use standard timeout to prevent starvation
        const opts = options || {};
        if (!opts.timeout) opts.timeout = 1000;

        return originalRIC ? originalRIC(wrap, opts) : setTimeout(() => {
            callback({
                didTimeout: true,
                timeRemaining: () => 0
            });
        }, 1);
    };

    console.log("🛡️ IdleCallback Shim Active: Preventing task loops.");

})();
