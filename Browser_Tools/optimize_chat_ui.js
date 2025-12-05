// ==UserScript==
// @name         Chat UI Performance Booster & Cleaner (Safe Mode)
// @namespace    http://tampermonkey.net/
// @version      2.2
// @description  Optimizes chat performance using content-visibility (lazy render), and provides tools to clean cookies/storage without breaking the app.
// @author       Jules
// @match        *://*/*
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';

    // CONFIGURATION
    const OLD_MESSAGE_THRESHOLD = 20; // Keep last 20 messages visible

    console.log("🚀 Chat Optimizer v2.2 (Robust Mode) Loaded");

    function initJulesTools() {
        try {
            // 1. CSS OPTIMIZATION - The "Lazy Render" approach
            // Use GM_addStyle for reliable injection where available
            const css = `
                /* Generic Message Containers */
                article, div[class*="message"], div[class*="bubble"], .text-base {
                    content-visibility: auto;
                    contain-intrinsic-size: 100px 500px;
                }

                /* Floating Panel Style */
                #jules-panel {
                    position: fixed;
                    bottom: 20px;
                    left: 20px;
                    z-index: 2147483647;
                    display: flex;
                    gap: 10px;
                    background: rgba(0, 0, 0, 0.8); /* Darker background */
                    padding: 8px;
                    border-radius: 8px;
                    border: 1px solid #666;
                    font-family: sans-serif;
                }
                .jules-btn {
                    background: #444;
                    color: white;
                    border: 1px solid #666;
                    padding: 6px 12px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-weight: bold;
                    font-size: 12px;
                }
                .jules-btn:hover { opacity: 1; background: #555; }
                .jules-btn.danger { background: #d93025; border-color: #b31414; }
            `;

            if (typeof GM_addStyle !== 'undefined') {
                GM_addStyle(css);
            } else {
                // Fallback for environments without GM_addStyle
                const style = document.createElement('style');
                style.textContent = css;
                document.head.appendChild(style);
            }

            createPanel();
            console.log("✅ Jules Panel Injected Successfully");

        } catch (e) {
            console.error("❌ Jules Script Error:", e);
        }
    }

    // 2. COOKIE & STORAGE CLEANER
    function clearBrowserData() {
        if (!confirm("Biztosan törölni akarod a Cookie-kat és a LocalStorage-ot ezen az oldalon? Ez kiléptethet!")) return;

        // Clear LocalStorage
        localStorage.clear();

        // Clear SessionStorage
        sessionStorage.clear();

        // Clear Cookies (Attempt)
        document.cookie.split(";").forEach((c) => {
            document.cookie = c
                .replace(/^ +/, "")
                .replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
        });

        showToast("🧹 Cookies & Storage Cleaned! Reloading...");
        setTimeout(() => location.reload(), 1500);
    }

    // 3. SAFE DOM "HIDING" (Virtual Scroll Lite)
    function hideOldMessages() {
        const scrollContainers = document.querySelectorAll('main, div[class*="scroll"], div[class*="conversation"]');
        let hiddenCount = 0;

        scrollContainers.forEach(container => {
            const children = Array.from(container.children).filter(el =>
                !el.tagName.match(/SCRIPT|STYLE|LINK/) &&
                !el.className.includes('sidebar') &&
                el.id !== 'jules-panel'
            );

            const count = children.length;
            if (count > OLD_MESSAGE_THRESHOLD) {
                const toHide = count - OLD_MESSAGE_THRESHOLD;
                for (let i = 0; i < toHide; i++) {
                    if (children[i].style.display !== 'none') {
                        children[i].style.display = 'none'; // Safe hide
                        hiddenCount++;
                    }
                }
            }
        });

        if (hiddenCount > 0) {
            showToast(`Performance: Hidden ${hiddenCount} old items.`);
        } else {
            showToast("Nothing to hide.");
        }
    }

    // 4. UI HELPER (Toast)
    function showToast(msg) {
        let toast = document.getElementById('jules-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'jules-toast';
            toast.style.cssText = `
                position: fixed; top: 60px; right: 120px;
                background: #333; color: #fff; padding: 8px 12px;
                border-radius: 4px; z-index: 10000; font-size: 12px;
                pointer-events: none; opacity: 0; transition: opacity 0.3s;
            `;
            document.body.appendChild(toast);
        }
        toast.textContent = msg;
        toast.style.opacity = '1';
        setTimeout(() => toast.style.opacity = '0', 3000);
    }

    // 5. CREATE PANEL
    function createPanel() {
        if (document.getElementById('jules-panel')) return;

        const panel = document.createElement('div');
        panel.id = 'jules-panel';

        const hideBtn = document.createElement('button');
        hideBtn.className = 'jules-btn';
        hideBtn.textContent = '🙈 Hide Old Msgs';
        hideBtn.onclick = hideOldMessages;

        const cleanBtn = document.createElement('button');
        cleanBtn.className = 'jules-btn danger';
        cleanBtn.textContent = '🧹 Nuke Cookies';
        cleanBtn.onclick = clearBrowserData;

        // Status Text
        const status = document.createElement('span');
        status.textContent = '🟢 Active';
        status.style.cssText = 'color: #0f0; font-size: 10px; align-self: center; font-weight: bold; margin-left: 5px; margin-right: 5px;';

        panel.appendChild(status);
        panel.appendChild(hideBtn);
        panel.appendChild(cleanBtn);
        document.body.appendChild(panel);
    }

    // Initialize with delay/check to be safe
    if (document.readyState === "complete" || document.readyState === "interactive") {
        setTimeout(initJulesTools, 1000);
    } else {
        window.addEventListener('load', () => setTimeout(initJulesTools, 1000));
    }

})();
