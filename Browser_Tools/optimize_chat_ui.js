// ==UserScript==
// @name         Chat UI Performance Booster & Cleaner (Manual Mode)
// @namespace    http://tampermonkey.net/
// @version      3.0
// @description  Manual tools to fix lag: "Hide Old Msgs" (display:none) and "Nuke Cookies". No auto-CSS to prevent layout thrashing.
// @author       Jules
// @match        *://*/*
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';

    // CONFIGURATION
    const OLD_MESSAGE_THRESHOLD = 15; // Keep last 15 messages visible

    console.log("🚀 Chat Optimizer v3.0 (Manual Mode) Loaded");

    function initJulesTools() {
        try {
            // 1. BASIC UI STYLING (No performance CSS, just the panel)
            const css = `
                /* Floating Panel Style */
                #jules-panel {
                    position: fixed;
                    bottom: 20px;
                    left: 20px;
                    z-index: 2147483647;
                    display: flex;
                    gap: 10px;
                    background: rgba(0, 0, 0, 0.85);
                    padding: 8px;
                    border-radius: 8px;
                    border: 1px solid #777;
                    font-family: sans-serif;
                    box-shadow: 0 4px 10px rgba(0,0,0,0.5);
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
                    transition: background 0.2s;
                }
                .jules-btn:hover { background: #666; }
                .jules-btn.danger { background: #a50e0e; border-color: #ff3333; }
                .jules-btn.success { background: #2d7d32; border-color: #4caf50; }
            `;

            if (typeof GM_addStyle !== 'undefined') {
                GM_addStyle(css);
            } else {
                const style = document.createElement('style');
                style.textContent = css;
                document.head.appendChild(style);
            }

            createPanel();
            console.log("✅ Jules Panel Injected (Passive Mode)");

        } catch (e) {
            console.error("❌ Jules Script Error:", e);
        }
    }

    // 2. COOKIE CLEANER
    function clearBrowserData() {
        if (!confirm("Vigyázz! Ez törli a sütiket és újratölti az oldalt. Folytatod?")) return;
        localStorage.clear();
        sessionStorage.clear();
        document.cookie.split(";").forEach((c) => {
            document.cookie = c
                .replace(/^ +/, "")
                .replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
        });
        showToast("🧹 Tisztítás kész! Újratöltés...");
        setTimeout(() => location.reload(), 1000);
    }

    // 3. MANUAL HIDE (The safe fix)
    function hideOldMessages() {
        // Broad selectors to catch common chat layouts
        const scrollContainers = document.querySelectorAll('main, div[class*="scroll"], div[class*="conversation"], div[role="presentation"]');
        let hiddenCount = 0;

        scrollContainers.forEach(container => {
            // Get direct children that look like messages
            const children = Array.from(container.children).filter(el =>
                !el.tagName.match(/SCRIPT|STYLE|LINK/) &&
                el.id !== 'jules-panel' &&
                el.offsetHeight > 0 // Only count visible items
            );

            const count = children.length;
            if (count > OLD_MESSAGE_THRESHOLD) {
                const toHide = count - OLD_MESSAGE_THRESHOLD;
                for (let i = 0; i < toHide; i++) {
                    // Safe Hiding: display: none
                    // This removes it from the layout calculation entirely, fixing the "Reflow" lag.
                    if (children[i].style.display !== 'none') {
                        children[i].style.display = 'none';
                        hiddenCount++;
                    }
                }
            }
        });

        if (hiddenCount > 0) {
            showToast(`🙈 Elrejtve: ${hiddenCount} régi üzenet.`);
        } else {
            showToast("Nincs mit elrejteni (vagy nem találom a konténert).");
        }
    }

    // 4. UI HELPER
    function showToast(msg) {
        let toast = document.getElementById('jules-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'jules-toast';
            toast.style.cssText = `
                position: fixed; top: 20px; left: 20px;
                background: #333; color: #fff; padding: 10px 15px;
                border-radius: 4px; z-index: 2147483647; font-size: 14px;
                pointer-events: none; opacity: 0; transition: opacity 0.3s;
                border: 1px solid #fff;
            `;
            document.body.appendChild(toast);
        }
        toast.textContent = msg;
        toast.style.opacity = '1';
        setTimeout(() => toast.style.opacity = '0', 3000);
    }

    // 5. PANEL CREATION
    function createPanel() {
        if (document.getElementById('jules-panel')) return;

        const panel = document.createElement('div');
        panel.id = 'jules-panel';

        // Hide Button
        const hideBtn = document.createElement('button');
        hideBtn.className = 'jules-btn success';
        hideBtn.innerHTML = '🙈 Hide Old (Fix Lag)';
        hideBtn.title = "A régi üzenetek elrejtése (display:none). Ez megszünteti a laggot.";
        hideBtn.onclick = hideOldMessages;

        // Clean Button
        const cleanBtn = document.createElement('button');
        cleanBtn.className = 'jules-btn danger';
        cleanBtn.innerHTML = '🧹 Nuke Cookies';
        cleanBtn.onclick = clearBrowserData;

        // Status
        const status = document.createElement('span');
        status.textContent = 'Active (Manual)';
        status.style.cssText = 'color: #ccc; font-size: 10px; align-self: center; margin: 0 5px;';

        panel.appendChild(status);
        panel.appendChild(hideBtn);
        panel.appendChild(cleanBtn);
        document.body.appendChild(panel);
    }

    // Initialize (Wait for Load)
    if (document.readyState === "complete" || document.readyState === "interactive") {
        setTimeout(initJulesTools, 1500);
    } else {
        window.addEventListener('load', () => setTimeout(initJulesTools, 1500));
    }

})();
