# Autonomous Agent Skill: Self-Healing Executor
# Olyan folyamatfuttató, amely elkapja a hibákat és újrapróbálkozik
# (Self-Reflection) anélkül, hogy a DevBox hívásokat blokkolná.
import argparse
import subprocess
import time

def execute_with_reflection(script_path: str, max_retries: int = 3):
    print(f"🔁 [Self-Healing] Futtatás indítása: {script_path}")

    for attempt in range(1, max_retries + 1):
        print(f"▶️ Próbálkozás {attempt}/{max_retries}...", flush=True)

        try:
            # Rövid timeout a RAM/CPU túlterhelés elkerülésére
            result = subprocess.run(
                ["python3", script_path],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                print("✅ [Self-Healing] Siker! Nincs hiba.")
                print(f"Kimenet:\n{result.stdout}")
                return
            else:
                print(f"⚠️ [Self-Healing] Hiba történt (Kód: {result.returncode})")
                print(f"Hibaüzenet (Reflexióhoz):\n{result.stderr}")
                print("🧠 [Self-Healing] Itt az AI agentnek elemeznie kellene a stderr-t és javítani a kódot.")
                # Egy valós hurokban itt jönne a kód újraírása LLM hívással
                time.sleep(2)

        except subprocess.TimeoutExpired:
            print("❌ [Self-Healing] A script időtúllépést okozott (Timeout=30s). Optimalizáció szükséges.")
            time.sleep(2)

    print(f"🛑 [Self-Healing] Az újrapróbálkozások kimerültek.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Self-Healing Script Executor")
    parser.add_argument("--script", required=True, help="A futtatandó python script")
    parser.add_argument("--retries", type=int, default=3, help="Újrapróbálkozások száma")
    args = parser.parse_args()

    execute_with_reflection(args.script, args.retries)
