with open("start_gui.sh", "r") as f:
    content = f.read()

content = content.replace("python3 vaku3_dashboard.py", "python3 vaku3_dashboard_10.py")

with open("start_gui.sh", "w") as f:
    f.write(content)
