// ==UserScript==
// @name         Chat UI Performance Booster & Cleaner
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  Adds a button to clean old messages and optimized performance without breaking sidebars.
// @author       Jules
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // CONFIGURATION
    const MAX_MESSAGES = 15; // Keep last 15 message pairs
    const CLEANUP_INTERVAL = 30000; // Auto-check every 30s (less aggressive)

    console.log("🚀 Chat Optimizer v1.1 Loaded");

    // 1. CSS OPTIMIZATION (Disable Animations, keep layout)
    const style = document.createElement('style');
    style.textContent = `
        * {
            transition: none !important;
            animation: none !important;
            box-shadow: none !important;
            text-shadow: none !important;
            backdrop-filter: none !important;
        }
        /* Ensure Sidebars stay visible but static */
        aside, nav, [class*="sidebar"], [class*="Sidebar"] {
            transform: none !important;
            opacity: 1 !important;
            visibility: visible !important;
        }
        /* Optimize heavy code blocks */
        pre, code {
            contain: content;
        }
        /* Floating Button Style */
        #jules-clean-btn {
            position: fixed;
            top: 10px;
            right: 120px;
            z-index: 9999;
            background: #d93025;
            color: white;
            border: none;
            padding: 8px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-weight: bold;
            font-family: sans-serif;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            opacity: 0.8;
        }
        #jules-clean-btn:hover { opacity: 1; }
    `;
    document.head.appendChild(style);

    // 2. CLEANUP LOGIC
    function cleanUpChat() {
        // Attempt to find the specific message list container.
        // Adjust selectors based on specific chat platform (e.g., ChatGPT, Claude, etc.)
        // Common generic selectors:
        const scrollContainers = document.querySelectorAll('main, div[class*="scroll"], div[class*="conversation"]');

        let cleanedCount = 0;

        scrollContainers.forEach(container => {
            // Filter direct children that look like messages (divs, lis)
            // Excluding sidebars which might be adjacent
            const children = Array.from(container.children).filter(el =>
                !el.tagName.match(/SCRIPT|STYLE|LINK/) &&
                !el.className.includes('sidebar') &&
                !el.className.includes('nav')
            );

            const count = children.length;

            if (count > MAX_MESSAGES * 2) {
                const toRemove = count - (MAX_MESSAGES * 2);
                // We assume messages are appended at the bottom, so we remove from TOP.
                // BE CAREFUL: Ensure we don't remove the very first "Welcome" elements if they are structural.
                // Usually safe to remove old message divs.

                for (let i = 0; i < toRemove; i++) {
                    // Safety check: Don't remove if it contains the floating button itself (if inserted there)
                    if (children[i].id !== 'jules-clean-btn') {
                        children[i].remove();
                        cleanedCount++;
                    }
                }
            }
        });

        if (cleanedCount > 0) {
            console.log(`🧹 Cleaned ${cleanedCount} old DOM elements.`);
            showToast(`Memory Freed: Removed ${cleanedCount} old items.`);
        } else {
            console.log("🧹 Nothing to clean.");
        }
    }

    // 3. UI HELPER (Toast)
    function showToast(msg) {
        const toast = document.createElement('div');
        toast.textContent = msg;
        toast.style.cssText = `
            position: fixed; top: 50px; right: 120px;
            background: #333; color: #fff; padding: 5px 10px;
            border-radius: 4px; z-index: 10000; font-size: 12px;
        `;
        document.body.appendChild(toast);
        setTimeout(() => toast.remove(), 2000);
    }

    // 4. ADD BUTTON
    function addButton() {
        if (document.getElementById('jules-clean-btn')) return;

        const btn = document.createElement('button');
        btn.id = 'jules-clean-btn';
        btn.textContent = '🧹 Clean RAM';
        btn.title = "Remove old messages to speed up browser";
        btn.onclick = cleanUpChat;

        document.body.appendChild(btn);
    }

    // Initialize
    addButton();

    // Auto-run periodically (optional)
    setInterval(cleanUpChat, CLEANUP_INTERVAL);

})();
