with open("start_gui.sh", "r") as f:
    content = f.read()

content = content.replace("python3 vaku3_dashboard_10.py > /home/misi/Merkava_ML_Ops/gui_startup.log 2>&1", "rm -f /home/misi/Merkava_ML_Ops/gui_startup.log\npython3 vaku3_dashboard_10.py > /home/misi/Merkava_ML_Ops/gui_startup.log 2>&1")

with open("start_gui.sh", "w") as f:
    f.write(content)
