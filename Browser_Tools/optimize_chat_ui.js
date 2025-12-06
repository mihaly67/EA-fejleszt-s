// ==UserScript==
// @name         Chat UI Performance Booster (v5.0 Ultimate)
// @namespace    http://tampermonkey.net/
// @version      5.0
// @description  Hybrid performance fix: Passive listeners, "Hard Pause" during streaming, and Virtual Scrolling (hides off-screen content without losing position).
// @author       Jules
// @match        *://*/*
// @run-at       document-start
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';

    // --- CONFIGURATION ---
    const BUFFER_PX = 2000; // Keep content visible within 2000px of viewport
    const CHECK_INTERVAL_MS = 300; // Check scroll/virtualization every 300ms
    const STREAM_COOLDOWN_MS = 1000; // Wait 1s after streaming ends before resuming

    // --- STATE ---
    let isGenerating = false;
    let lastStreamTime = 0;
    let scrollContainer = null;
    let virtualMap = new Map(); // Stores { height, originalNode, placeholder }

    console.log("🚀 Chat Optimizer v5.0 (Ultimate Hybrid) Starting...");

    // 1. PASSIVE LISTENER PATCH (Immediate Fix for Scroll Blocking)
    const originalAddEventListener = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
        if (['wheel', 'mousewheel', 'touchstart', 'touchmove', 'scroll'].includes(type)) {
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

    // 2. STYLES
    function injectStyles() {
        const css = `
            .jules-placeholder {
                background: rgba(0,0,0,0.02);
                border: 1px dashed rgba(100,100,100,0.1);
                width: 100%;
                content-visibility: hidden; /* Browser native optimization for placeholders */
            }
            #jules-panel {
                position: fixed; bottom: 20px; left: 20px; z-index: 2147483647;
                display: flex; gap: 8px; background: rgba(0,0,0,0.85); padding: 8px;
                border: 1px solid #555; border-radius: 6px; font-family: sans-serif;
                color: #ccc; font-size: 11px; align-items: center;
            }
            .jules-badge {
                font-weight: bold; padding: 2px 5px; border-radius: 3px;
            }
            .status-ok { color: #4caf50; }
            .status-wait { color: #ff9800; }
        `;
        if (typeof GM_addStyle !== 'undefined') GM_addStyle(css);
        else {
            const style = document.createElement('style');
            style.textContent = css;
            document.head.appendChild(style);
        }
    }

    // 3. HARD PAUSE DETECTOR
    // Detects if the AI is currently typing (streaming).
    function checkStreamingStatus() {
        // Common selectors for "Stop" buttons in ChatGPT, Gemini, Claude, AI Studio
        const stopSelectors = [
            '[data-testid="stop-button"]',
            'button[aria-label*="Stop"]',
            '.stop-generating',
            '[aria-label="Stop streaming"]'
        ];

        const stopBtn = stopSelectors.some(sel => document.querySelector(sel));

        if (stopBtn) {
            isGenerating = true;
            lastStreamTime = Date.now();
            updateStatus("STREAMING (Paused)", "status-wait");
        } else {
            // Cooldown check
            if (Date.now() - lastStreamTime < STREAM_COOLDOWN_MS) {
                isGenerating = true; // Still in cooldown
            } else {
                isGenerating = false;
                updateStatus("Active", "status-ok");
            }
        }
    }

    // 4. VIRTUAL SCROLL ENGINE
    function findScrollContainer() {
        // Try to find the main scrollable area
        const candidates = document.querySelectorAll('main, div[class*="scroll"], div[class*="conversation"]');
        for (const el of candidates) {
            const style = window.getComputedStyle(el);
            if (style.overflowY === 'auto' || style.overflowY === 'scroll') {
                return el;
            }
        }
        return document.documentElement; // Fallback to body
    }

    function virtualizeContent() {
        if (isGenerating) return; // HARD PAUSE

        if (!scrollContainer || !scrollContainer.isConnected) {
            scrollContainer = findScrollContainer();
        }
        if (!scrollContainer) return;

        const containerRect = scrollContainer.getBoundingClientRect();
        const topThreshold = containerRect.top - BUFFER_PX;
        const bottomThreshold = containerRect.bottom + BUFFER_PX;

        // Identify message items (Heuristic)
        // We look for direct children of the scroll container that look like blocks
        let children = Array.from(scrollContainer.children);

        // If container has wrapper, go one level deeper
        if (children.length === 1 && children[0].offsetHeight > 1000) {
             children = Array.from(children[0].children);
        }

        let virtCount = 0;

        for (const child of children) {
            // Skip our panel or script tags
            if (child.id === 'jules-panel' || child.tagName === 'SCRIPT' || child.tagName === 'STYLE') continue;

            // Don't mess with very small elements (separators)
            if (child.offsetHeight < 50) continue;

            // Is it a placeholder?
            if (child.classList.contains('jules-placeholder')) {
                // Check if we need to RESTORE it
                const rect = child.getBoundingClientRect();
                if (rect.bottom > topThreshold && rect.top < bottomThreshold) {
                    restoreNode(child);
                }
            } else {
                // It's a real node. Check if we need to VIRTUALIZE it.
                const rect = child.getBoundingClientRect();
                // If completely out of view (above OR below)
                if (rect.bottom < topThreshold || rect.top > bottomThreshold) {
                    replaceWithPlaceholder(child, rect.height);
                    virtCount++;
                }
            }
        }
    }

    function replaceWithPlaceholder(node, height) {
        // Create placeholder
        const placeholder = document.createElement('div');
        placeholder.className = 'jules-placeholder';
        placeholder.style.height = `${height}px`;
        // Store ID if exists for consistency
        if(node.id) placeholder.id = `virt-${node.id}`;

        // Save mapping
        virtualMap.set(placeholder, node);

        // Swap
        node.replaceWith(placeholder);
    }

    function restoreNode(placeholder) {
        const original = virtualMap.get(placeholder);
        if (original) {
            placeholder.replaceWith(original);
            virtualMap.delete(placeholder);
        }
    }

    // 5. UI
    function updateStatus(text, cls) {
        const el = document.getElementById('jules-status-text');
        if (el) {
            el.textContent = text;
            el.className = `jules-badge ${cls}`;
        }
    }

    function createPanel() {
        if (document.getElementById('jules-panel')) return;
        const panel = document.createElement('div');
        panel.id = 'jules-panel';
        panel.innerHTML = `
            <span id="jules-status-text" class="jules-badge status-ok">Initializing...</span>
            <span>v5.0</span>
            <button class="jules-btn" style="background:#8b0000; border:none; color:white; border-radius:4px; cursor:pointer;" onclick="if(confirm('Reset?')) location.reload()">Reset</button>
        `;
        document.body.appendChild(panel);
    }

    // MAIN LOOP
    window.addEventListener('load', () => {
        injectStyles();
        createPanel();

        // Run the optimizer loop
        setInterval(() => {
            checkStreamingStatus();
            // Only run virtualization if NOT streaming
            if (!isGenerating) {
                // Use requestAnimationFrame to run virtualization in sync with render cycle
                requestAnimationFrame(virtualizeContent);
            }
        }, CHECK_INTERVAL_MS);
    });

})();
