// ==UserScript==
// @name         Chat UI Performance Booster (Turbo Mode)
// @namespace    http://tampermonkey.net/
// @version      4.0
// @description  Aggressively fixes lag: Forces passive scroll listeners, auto-hides old messages, and forces GPU rendering.
// @author       Jules
// @match        *://*/*
// @run-at       document-start
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';

    // CONFIGURATION
    const KEEP_MESSAGES = 15;
    const AUTO_CLEAN_INTERVAL = 4000; // Check every 4 seconds

    console.log("🚀 Chat Optimizer v4.0 (Turbo Mode) Starting...");

    // 1. SCROLL FIX (Monkey-Patch addEventListener)
    // This forces all scroll events to be 'passive', preventing the page from blocking the main thread.
    // Solves: "[Violation] Added non-passive event listener to a scroll-blocking..."
    const originalAddEventListener = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
        if (['wheel', 'mousewheel', 'touchstart', 'touchmove', 'scroll'].includes(type)) {
            // Force passive: true
            if (typeof options === 'boolean') {
                options = { capture: options, passive: true };
            } else if (typeof options === 'object') {
                options.passive = true;
            } else {
                options = { passive: true };
            }
        }
        return originalAddEventListener.call(this, type, listener, options);
    };
    console.log("✅ Passive Scroll Listeners Enforced");

    // 2. GPU ACCELERATION & LAYOUT FIXES
    function injectPerformanceCSS() {
        const css = `
            /* Force GPU layer for scrolling containers */
            main, div[class*="scroll"], div[class*="conversation"] {
                will-change: transform;
                transform: translateZ(0);
                backface-visibility: hidden;
            }

            /* Floating Panel */
            #jules-panel {
                position: fixed; bottom: 20px; left: 20px; z-index: 2147483647;
                display: flex; gap: 8px; background: rgba(0,0,0,0.85); padding: 8px;
                border: 1px solid #555; border-radius: 6px; font-family: sans-serif;
            }
            .jules-btn {
                background: #333; color: #fff; border: 1px solid #555; padding: 5px 10px;
                cursor: pointer; font-size: 11px; border-radius: 3px;
            }
            .jules-btn:hover { background: #555; }
        `;
        if (typeof GM_addStyle !== 'undefined') {
            GM_addStyle(css);
        } else {
            const style = document.createElement('style');
            style.textContent = css;
            document.head.appendChild(style);
        }
    }

    // 3. AUTO-HIDER (Safe display:none)
    // Runs periodically to keep the DOM light without crashing frameworks.
    function hideOldMessages() {
        // Try to find the chat container
        const scrollContainers = document.querySelectorAll('main, div[class*="scroll"], div[class*="conversation"], div[role="presentation"]');
        let hiddenTotal = 0;

        scrollContainers.forEach(container => {
            const children = Array.from(container.children).filter(el =>
                !el.tagName.match(/SCRIPT|STYLE|LINK/) &&
                el.id !== 'jules-panel' &&
                el.style.display !== 'none' // Only count visible ones
            );

            if (children.length > KEEP_MESSAGES) {
                const toHide = children.length - KEEP_MESSAGES;
                // Hide from the TOP (oldest)
                for (let i = 0; i < toHide; i++) {
                    children[i].style.display = 'none';
                    hiddenTotal++;
                }
            }
        });

        if (hiddenTotal > 0) {
            console.log(`⚡ Turbo: Auto-hid ${hiddenTotal} messages.`);
            updateStatus(`Hid ${hiddenTotal}`);
        }
    }

    // 4. UI & INIT
    function updateStatus(msg) {
        const el = document.getElementById('jules-status');
        if (el) {
            el.textContent = msg;
            el.style.color = '#4caf50';
            setTimeout(() => { el.textContent = 'Active'; el.style.color = '#ccc'; }, 2000);
        }
    }

    function createPanel() {
        if (document.getElementById('jules-panel')) return;
        const panel = document.createElement('div');
        panel.id = 'jules-panel';
        panel.innerHTML = `
            <span id="jules-status" style="color:#ccc; font-size:10px; align-self:center; font-weight:bold; width: 50px;">Active</span>
            <button class="jules-btn" onclick="location.reload()">🔄 Reload</button>
            <button class="jules-btn" style="background:#8b0000;" onclick="localStorage.clear();sessionStorage.clear();location.reload()">🧹 Nuke</button>
        `;
        document.body.appendChild(panel);
    }

    // Main Loop
    window.addEventListener('load', () => {
        injectPerformanceCSS();
        createPanel();
        // Start Auto-Cleaner
        setInterval(hideOldMessages, AUTO_CLEAN_INTERVAL);
    });

})();
