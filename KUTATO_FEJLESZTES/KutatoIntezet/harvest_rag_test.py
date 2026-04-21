import json
import os
from harvest_knowledge import harvest

files = ["KUTATO_FEJLESZTES/KutatoIntezet/level_0_rag.json"]
harvest(files, "KUTATO_FEJLESZTES/KutatoIntezet/HARVESTED_RAG.md")
