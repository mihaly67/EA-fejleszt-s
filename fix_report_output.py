import re

with open("vaku3_offline_validator_local.py", "r", encoding="utf-8") as f:
    content = f.read()

# Fix the report print block as it seems it was overwritten or not properly appended previously.
report_old = """    print("--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
    print(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db")"""

report_new = """    print("--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
    print(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db")
    
    # PREDICTIVE CHECK
    early_warnings = 0
    if total_target_1 > 0:
        target_indices = df[df['Target'] == 1].index
        for t_idx in target_indices:
            start_idx = max(0, t_idx - 3)
            # If the max theater risk in the 3 ticks prior was > 40%
            if 'Theater_Risk_Pct' in df.columns and not df.loc[start_idx:t_idx-1, 'Theater_Risk_Pct'].empty:
                if df.loc[start_idx:t_idx-1, 'Theater_Risk_Pct'].max() > 40.0:
                    early_warnings += 1
        
        print(f"  -> 🔮 PREDIKTÍV ELŐREJELZÉS (Risk > 40% a trükk előtt 3 ticken belül): {early_warnings} db ({early_warnings/total_target_1*100:.1f}%)")"""

if "PREDIKTÍV ELŐREJELZÉS" not in content:
    content = content.replace(report_old, report_new)

with open("vaku3_offline_validator_local_2.py", "w", encoding="utf-8") as f:
    f.write(content)

