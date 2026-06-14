import re

with open("vaku3_online_hybrid_v9.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Clock text visibility (make it black instead of #E0E0E0)
content = content.replace('self.lbl_clock.setStyleSheet("font-size: 16px; font-weight: bold; color: #E0E0E0;")',
                          'self.lbl_clock.setStyleSheet("font-size: 18px; font-weight: bold; color: #000000; padding-bottom: 5px;")')

# 2. Re-enable Context menu
content = content.replace("self.p1.setMenuEnabled(False)", "self.p1.setMenuEnabled(True)")
content = content.replace("self.p2.setMenuEnabled(False)", "self.p2.setMenuEnabled(True)")

# 3. Add Auto-Scrolling / Right margin spacing inside update_gui_charts
# Currently it just sets data, but doesn't handle viewbox range
auto_scroll = """        self.curve_risk.setData(x_draw, self.risk_data[-draw_len:])

        # Auto-scrolling X-Axis with a 15% right margin (so the "current line" isn't glued to the absolute right edge)
        latest_time = x_draw[-1]
        earliest_time = x_draw[0]
        time_span = latest_time - earliest_time

        # Prevent zero span issues early on
        if time_span == 0: time_span = 1000

        # Auto-pan: Keep current time near the right, but leave 15% empty space ahead
        x_min = earliest_time
        x_max = latest_time + (time_span * 0.15)

        self.p1.setXRange(x_min, x_max, padding=0)
"""
content = content.replace("        self.curve_risk.setData(x_draw, self.risk_data[-draw_len:])", auto_scroll)

with open("vaku3_online_hybrid_v9.py", "w", encoding="utf-8") as f:
    f.write(content)
