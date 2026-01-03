from datetime import datetime, timedelta

def get_start_of_bar(dt, timeframe_minutes):
    total_minutes = dt.hour * 60 + dt.minute
    start_minute = (total_minutes // timeframe_minutes) * timeframe_minutes
    return dt.replace(hour=start_minute // 60, minute=start_minute % 60, second=0, microsecond=0)

def simulate():
    # Simulation Start: 10:00 to 11:00
    base_time = datetime(2023, 10, 27, 10, 0, 0)

    print(f"{'Time':<10} | {'Pri(M15) Ref':<15} | {'Sec(M30) Ref':<15} | {'Ter(H1) Ref':<15} | {'Note'}")
    print("-" * 80)

    prev_pri = None
    prev_sec = None

    for i in range(65): # 65 minutes
        current_time = base_time + timedelta(minutes=i)

        # 1. Primary (M15)
        # In code: iBarShift(..., current_time) -> returns index of M15 bar containing current_time.
        # iTime(...) returns the OPEN time of that bar.
        t_pri = get_start_of_bar(current_time, 15)

        # 2. Secondary (M30) - Cascading Reference
        # In code: iBarShift(..., t_pri) -> returns index of M30 bar containing t_pri.
        # iTime(...) returns the OPEN time of that bar.
        t_sec = get_start_of_bar(t_pri, 30)

        # 3. Tertiary (H1) - Cascading Reference
        t_ter = get_start_of_bar(t_pri, 60)

        # Formatting
        time_s = current_time.strftime("%H:%M")
        pri_s = t_pri.strftime("%H:%M")
        sec_s = t_sec.strftime("%H:%M")
        ter_s = t_ter.strftime("%H:%M")

        note = ""
        if pri_s != prev_pri and prev_pri is not None:
            note = "<< Pri Step"
        if sec_s != prev_sec and prev_sec is not None:
            note += " << Sec Step"

        print(f"{time_s:<10} | {pri_s:<15} | {sec_s:<15} | {ter_s:<15} | {note}")

        prev_pri = pri_s
        prev_sec = sec_s

simulate()
