// ==UserScript==
// @name         Chat UI Performance Booster
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Aggressively optimizes chat UI by removing old messages, disabling animations, and simplifying DOM.
// @author       Jules
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("🚀 Chat Optimizer Started...");

    // CONFIGURATION
    const MAX_MESSAGES = 10; // Only keep the last 10 message pairs in the DOM
    const REMOVE_ANIMATIONS = true;
    const SIMPLIFY_STYLES = true;

    // 1. STYLE OPTIMIZATION (Disable Animations & Shadows)
    if (REMOVE_ANIMATIONS || SIMPLIFY_STYLES) {
        const style = document.createElement('style');
        style.textContent = `
            * {
                transition: none !important;
                animation: none !important;
                box-shadow: none !important;
                text-shadow: none !important;
                backdrop-filter: none !important;
            }
            .markdown-body pre { white-space: pre-wrap !important; } /* Wrap code to avoid horiz scroll lag */
        `;
        document.head.appendChild(style);
        console.log("🎨 Styles Simplified (Animations Disabled)");
    }

    // 2. DOM CLEANUP (Remove Old Messages)
    function cleanUpChat() {
        // Selector strategy: Try to find common chat message containers.
        // Adjust these selectors based on the specific platform's DOM structure.
        // Assuming typical React/Div structures often used in these chats.

        // This is a heuristic guess. The user might need to inspect element to verify the class name.
        // Common patterns: div[class*="Message"], div[class*="chat-row"], li

        // Strategy: Look for the main scrollable container
        const chatContainers = document.querySelectorAll('main, div[role="log"], div[class*="scroll"], div[class*="Chat"]');

        chatContainers.forEach(container => {
            // Get direct children (messages)
            const children = Array.from(container.children);
            const count = children.length;

            if (count > MAX_MESSAGES * 2) { // *2 assuming User + AI pairs
                const toRemove = count - (MAX_MESSAGES * 2);
                console.log(`🧹 Removing ${toRemove} old message elements to free memory...`);

                // Remove from the TOP (oldest)
                for (let i = 0; i < toRemove; i++) {
                    children[i].remove();
                }
            }
        });
    }

    // 3. OBSERVER (Run cleanup automatically on new messages)
    const observer = new MutationObserver((mutations) => {
        // Debounce simple check
        cleanUpChat();
    });

    // Start observing the body for changes (new messages added)
    observer.observe(document.body, { childList: true, subtree: true });

    // Initial Cleanup
    setTimeout(cleanUpChat, 2000);

    // Manual Trigger accessible in console
    window.optimizeChat = cleanUpChat;

})();
