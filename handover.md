# HANDOVER / RETROSPECTIVE FOR THE NEXT AGENT

## CURRENT STATE
- The user is extremely dissatisfied with the current performance. The "Jules" agent (me) failed to deliver a working HMM scalping GUI within the session.
- The latest attempts at optimizing the code caused severe CPU usage (100%-800%) on the user's remote VPS (`5.189.163.88`, user: `misi`, pass: `1104`), freezing the server and yielding "Initializing..." messages indefinitely.
- The user **explicitly instructed to abandon the current patching/experimentation** and start fresh or reconsider the approach.
- XGBoost training + HMM on a VPS is considered too heavy and not viable for the current hardware.

## CRITICAL USER INSTRUCTIONS (DO NOT IGNORE)
1. **LIVE DEPLOYMENT IS MANDATORY:** It is NOT enough to just `git commit` your code into this repository sandbox. You MUST SSH/SCP into the user's VPS (`misi@5.189.163.88`) and update the files in `/home/misi/HMM_Pipe_HUD/` and run/restart the processes there.
2. **CPU PERFORMANCE (THE BIGGEST ROADBLOCK):** Streamlit `while True` loops + Plotly charts + `GaussianHMM.fit()` running simultaneously will completely choke the Ryzen 8-core CPU.
    - The GUI MUST be incredibly lightweight (e.g. `TradingView Lightweight Charts` via Streamlit, or entirely separate).
    - HMM `.fit()` must be executed **strictly once** (or incredibly rarely), relying only on `.predict()` for new ticks.
3. **READ THE DOCS:** The user has provided extensive RAG databases (MQL5 articles, theory, etc.) and complete, working GitHub repos in the workspace. Stop "reinventing the wheel". Find the proven logic and copy-paste the functional parts.
4. **DON'T GUESS:** Stop applying "hotfixes" to broken code. If the logic is flawed and eats 300% CPU, delete it and rewrite it using O(1) structures (like `SimpleRingBuffer`) and clean separation of concerns.

## FINAL ACTIONS TAKEN
- I have logged into the VPS, killed all runaway Python/Streamlit processes to save the server from crashing.
- I have reset the git repository in the sandbox to the last clean commit (`b7be7e6`) and deleted my broken patch files.
