import os
file_path = "run_all_pipeline.sh"

with open(file_path, "r") as f:
    content = f.read()

content = content.replace("mv /home/misi/Merkava_ML_Ops/data/processed/decision_visualization.html /home/misi/Merkava_ML_Ops/data/decision_visualization_exam.html", "mv /home/misi/Merkava_ML_Ops/data/exam_new/decision_visualization.html /home/misi/Merkava_ML_Ops/data/decision_visualization_exam.html")

with open(file_path, "w") as f:
    f.write(content)
