with open("vaku3_dashboard_10.py", "r") as f:
    content = f.read()

# Add the missing method back into the engine used by the dashboard
engine_code = """
    def get_micro_features(self):"""
    
new_method = """
    def update_macro_context(self, current_time_ms, price):
        self.macro_times.append(current_time_ms)
        self.macro_prices.append(price)
        
        # Tisztítjuk az ablakot (Csak az utolsó X percet tartjuk meg)
        cutoff_ms = current_time_ms - (self.macro_window_minutes * 60 * 1000)
        
        while len(self.macro_times) > 0 and self.macro_times[0] < cutoff_ms:
            self.macro_times.pop(0)
            self.macro_prices.pop(0)
            
        # Makro ER számolása az aktív gyertyán
        if len(self.macro_prices) < 2:
            return 0.0
            
        net_move = abs(self.macro_prices[-1] - self.macro_prices[0])
        gross_move = sum(abs(np.diff(self.macro_prices)))
        
        return net_move / gross_move if gross_move > 0 else 0.0

    def get_micro_features(self):"""
    
with open("vaku3_online_hybrid.py", "r") as f:
    online_content = f.read()

online_content = online_content.replace(engine_code, new_method)

with open("vaku3_online_hybrid.py", "w") as f:
    f.write(online_content)

