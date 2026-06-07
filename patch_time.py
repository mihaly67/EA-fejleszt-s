with open("vaku3_dashboard_10.py", "r") as f:
    content = f.read()

content = content.replace("time_cols = [c for c in self.df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]", "time_cols = [c for c in self.df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc', 'time']]")

with open("vaku3_dashboard_10.py", "w") as f:
    f.write(content)
