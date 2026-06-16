import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./clean_v10.py"], check=True, env=env)

with open('clean_v10.py', 'r', encoding='utf-8') as f:
    content = f.read()

# A "analyze_time_based_trend" végénél látszik, hogy megmaradt az eredeti "Makro: UP" stb. logika is
# és hiányzik belőle a "Hysteresis" amit korábban patch-eltünk. Valószínűleg a "revert" és a "fix_hmm_and_nameerror" rossz sorrendre futott le,
# vagy a regex nem talált rá megfelelően.
# Cseréljük az egész "analyze_time_based_trend" testét.

old_analyze = re.search(r'def analyze_time_based_trend\(self, current_time, current_price, is_dead_market=False\):.*?(?=\n    def get_reason)', content, re.DOTALL)

new_analyze = """def analyze_time_based_trend(self, current_time, current_price, is_dead_market=False):
        micro_window_ticks = int(self.get_safe_float(self.inp_micro_win, 100))
        med_window_ticks = int(self.get_safe_float(self.inp_med_win, 500))
        macro_window_ticks = int(self.get_safe_float(self.inp_macro_win, 1000))

        micro_sens = self.get_safe_float(self.inp_micro_sens, 0.02)
        med_sens = self.get_safe_float(self.inp_med_sens, 0.03)
        macro_sens = self.get_safe_float(self.inp_macro_sens, 0.05)

        micro_start_price = self.get_price_at_tick_offset(micro_window_ticks)
        mac_start_price = self.get_price_at_tick_offset(macro_window_ticks)

        if mac_start_price is None:
            return "Adatgyűjtés...<br>(Várakozás)", "#333", "NINCS JELZÉS", "#333"

        micro_slope = current_price - micro_start_price
        mac_slope = current_price - mac_start_price

        mac_pct = (mac_slope / mac_start_price) * 100
        mic_pct = (micro_slope / micro_start_price) * 100

        # --- ADAPTÍV HMM & HYSTERESIS ---
        hyst_on = self.get_safe_float(self.inp_hyst_on, 0.05)
        hyst_off = self.get_safe_float(self.inp_hyst_off, 0.03)
        vol_mult = self.get_safe_float(self.inp_vol_mult, 1.5)

        if len(self.history_prices) > macro_window_ticks:
            import numpy as np
            vol = np.std(self.history_prices[-macro_window_ticks:])
        else:
            vol = 0.01

        dyn_micro_sens = micro_sens + (vol * vol_mult)
        dyn_macro_sens = macro_sens + (vol * vol_mult)

        self.last_dyn_vol = vol
        self.last_dyn_macro_sens = dyn_macro_sens

        if not hasattr(self, 'hmm_model') or not hasattr(self, 'tick_count'):
            try:
                from hmmlearn import hmm
                self.hmm_model = hmm.GaussianHMM(n_components=3, covariance_type="diag", n_iter=10, random_state=42)
                self.hmm_available = True
            except ImportError:
                self.hmm_available = False

            self.tick_count = 0
            self.current_market_state = "RANGING"

        self.tick_count += 1

        if self.hmm_available and self.tick_count % 100 == 0 and len(self.history_prices) >= macro_window_ticks:
            import numpy as np
            prices = np.array(self.history_prices[-macro_window_ticks:])
            log_returns = np.diff(prices) / prices[:-1]
            if len(log_returns) > 0:
                features = log_returns.reshape(-1, 1)
                import warnings
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    self.hmm_model.fit(features)

        # --- HYSTERESIS LÉPTETÉS ---
        if self.current_market_state == "RANGING":
            if mac_pct > dyn_macro_sens and mic_pct > dyn_micro_sens and mac_pct > hyst_on:
                self.current_market_state = "UP"
            elif mac_pct < -dyn_macro_sens and mic_pct < -dyn_micro_sens and mac_pct < -hyst_on:
                self.current_market_state = "DOWN"

        elif self.current_market_state == "UP":
            if mac_pct < hyst_off:
                self.current_market_state = "RANGING"
        elif self.current_market_state == "DOWN":
            if mac_pct > -hyst_off:
                self.current_market_state = "RANGING"

        # SZÍNEZÉS
        if is_dead_market:
            regime_str = "HMM: FLAT (DÖGLÖTT)"
            overall_color = "#440000"
        elif self.current_market_state == "UP":
            regime_str = "HMM ADAPTIVE: TREND UP"
            overall_color = "#0f0"
        elif self.current_market_state == "DOWN":
            regime_str = "HMM ADAPTIVE: TREND DOWN"
            overall_color = "#f00"
        else:
            regime_str = "HMM ADAPTIVE: RANGING"
            overall_color = "#888"

        predict_str = "TREND STABIL"
        predict_color = "#1a1a2e"

        return regime_str, overall_color, predict_str, predict_color"""

if old_analyze:
    content = content.replace(old_analyze.group(0), new_analyze)

with open('clean_v10.py', 'w', encoding='utf-8') as f:
    f.write(content)

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "./clean_v10.py", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py"], check=True, env=env)

# Újraindítás
ssh_cmd_kill = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "pkill -f vaku3_offline_validator_VPS_V10.py || true"]
subprocess.run(ssh_cmd_kill, env=env)

ssh_cmd_start = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "export DISPLAY=:10.0 && source /home/misi/ML_Ops/venv/bin/activate && cd /home/misi/Merkava_ML_Ops && python3 vaku3_offline_validator_VPS_V10.py > /tmp/vaku10.log 2>&1 & sleep 2"]
subprocess.Popen(ssh_cmd_start, env=env)
