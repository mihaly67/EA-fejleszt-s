import re

with open("vaku3_offline_validator_local_2.py", "r", encoding="utf-8") as f:
    content = f.read()

# Keresünk a write string blockra, és ott írjuk felül a jelentést, mert egy file handler menti ki a végén
file_write_old = """    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("=========================================================================\n")
        f.write("🔍 VAKU 3.0 OFFLINE VALIDÁTOR (HMM) RIPORT\n")
        f.write("=========================================================================\n\n")

        f.write("💡 HMM Szemantikus Térkép elkészült (Tiszta Log-ER alapján)!\n")
        for name, sid in validator.state_map.items():
            f.write(f"  -> {name} "
                    f"(Manipuláció) Állapot ID: {sid} | " if name == 'Theater' else f"  -> {name} "
                    f"(Tiszta Trend) Állapot ID: {sid} | " if name == 'Concrete' else f"  -> {name} "
                    f"(Flat) Állapot ID: {sid} | ")
            f.write(f"Jellemzők -> LogER: {validator.model.means_[sid][0]:.2f}, "
                    f"Spread: {validator.model.means_[sid][1]:.2f}x\n")

        f.write("\n--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---\n")
        f.write(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db\n")
        if total_target_1 > 0:
            for sid in range(3):
                state_name = list(validator.state_map.keys())[list(validator.state_map.values()).index(sid)]
                count = (df[df['Target'] == 1]['HMM_State_ID'] == sid).sum()
                pct = count / total_target_1 * 100.0
                marker = " <--- (Ez a mi kijelölt 'Theater' állapotunk)" if state_name == 'Theater' else ""
                f.write(f"  -> {state_name} (Állapot ID: {sid}) találati aránya a trükkök előtt: {count} db ({pct:.1f}%){marker}\n")

        f.write("\n--- KONTROLL CSOPORT (Target=0 Tiszta Piac, Trade Nyitás/Zárás) ---\n")
        f.write(f"Összes megjelölt Tiszta Trade: {total_target_0} db\n")
        if total_target_0 > 0:
            for sid in range(3):
                state_name = list(validator.state_map.keys())[list(validator.state_map.values()).index(sid)]
                count = (df[df['Target'] == 0]['HMM_State_ID'] == sid).sum()
                pct = count / total_target_0 * 100.0
                f.write(f"  -> {state_name} (Állapot ID: {sid}) jelenléte tiszta piacon: {count} db ({pct:.1f}%)\n")"""


file_write_new = """    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("=========================================================================\n")
        f.write("🔍 VAKU 3.0 OFFLINE VALIDÁTOR (HMM) RIPORT + PREDIKCIÓ\n")
        f.write("=========================================================================\n\n")

        f.write("💡 HMM Szemantikus Térkép elkészült (Tiszta Log-ER alapján)!\n")
        for name, sid in validator.state_map.items():
            f.write(f"  -> {name} "
                    f"(Manipuláció) Állapot ID: {sid} | " if name == 'Theater' else f"  -> {name} "
                    f"(Tiszta Trend) Állapot ID: {sid} | " if name == 'Concrete' else f"  -> {name} "
                    f"(Flat) Állapot ID: {sid} | ")
            f.write(f"Jellemzők -> LogER: {validator.model.means_[sid][0]:.2f}, "
                    f"Spread: {validator.model.means_[sid][1]:.2f}x\n")

        f.write("\n--- 🔮 PREDIKTÍV ELŐREJELZÉS (VITERBI + TRANSMAT) ---\n")
        early_warnings = 0
        if total_target_1 > 0:
            target_indices = df[df['Target'] == 1].index
            for t_idx in target_indices:
                start_idx = max(0, t_idx - 3)
                if 'Theater_Risk_Pct' in df.columns and not df.loc[start_idx:t_idx-1, 'Theater_Risk_Pct'].empty:
                    if df.loc[start_idx:t_idx-1, 'Theater_Risk_Pct'].max() > 20.0: # 20% rizikó küszöb
                        early_warnings += 1
            f.write(f"Viterbi Jövőkutatás (Risk > 20% a trükk előtt): {early_warnings} db ({early_warnings/total_target_1*100:.1f}%) felismert jövőbeli manipuláció.\n")

        f.write("\n--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---\n")
        f.write(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db\n")
        if total_target_1 > 0:
            for sid in range(3):
                state_name = list(validator.state_map.keys())[list(validator.state_map.values()).index(sid)]
                count = (df[df['Target'] == 1]['HMM_State_ID'] == sid).sum()
                pct = count / total_target_1 * 100.0
                marker = " <--- (Ez a mi kijelölt 'Theater' állapotunk)" if state_name == 'Theater' else ""
                f.write(f"  -> {state_name} (Állapot ID: {sid}) JELENIDEJŰ találati aránya a trükkök előtt: {count} db ({pct:.1f}%){marker}\n")

        f.write("\n--- KONTROLL CSOPORT (Target=0 Tiszta Piac, Trade Nyitás/Zárás) ---\n")
        f.write(f"Összes megjelölt Tiszta Trade: {total_target_0} db\n")
        if total_target_0 > 0:
            for sid in range(3):
                state_name = list(validator.state_map.keys())[list(validator.state_map.values()).index(sid)]
                count = (df[df['Target'] == 0]['HMM_State_ID'] == sid).sum()
                pct = count / total_target_0 * 100.0
                f.write(f"  -> {state_name} (Állapot ID: {sid}) jelenléte tiszta piacon: {count} db ({pct:.1f}%)\n")"""

content = content.replace(file_write_old, file_write_new)

with open("vaku3_offline_validator_local_final.py", "w", encoding="utf-8") as f:
    f.write(content)

