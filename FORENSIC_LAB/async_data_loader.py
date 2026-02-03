import asyncio
import pandas as pd
import time

# Simulation of a Real-Time Event Engine (inspired by Nautilus Trader)
# We stream the CSV rows as if they are incoming Tick events.

class AsyncForensicEngine:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.event_queue = asyncio.Queue()
        self.is_running = False

    def load_data(self):
        print(f"Loading historical data from {self.file_path}...")
        self.df = pd.read_csv(self.file_path)
        # Sort to simulate time flow
        if 'Time' in self.df.columns:
            self.df['Time'] = pd.to_datetime(self.df['Time'])
            self.df = self.df.sort_values('Time')
        print(f"Loaded {len(self.df)} events.")

    async def stream_events(self):
        """Producer: Pushes rows to the queue as events."""
        print("Starting Event Stream (Simulation)...")
        start_time = time.time()

        for index, row in self.df.iterrows():
            if not self.is_running: break

            event = {
                'type': 'TICK',
                'time': row.get('Time'),
                'bid': row.get('Bid'),
                'velocity': row.get('Velocity', 0),
                'pl': row.get('Floating_PL', 0)
            }

            await self.event_queue.put(event)

            # Simulate slight delay every 100 ticks to not choke the consumer
            if index % 1000 == 0:
                await asyncio.sleep(0.001)

        await self.event_queue.put(None) # Sentinel
        end_time = time.time()
        print(f"Stream finished. Duration: {end_time - start_time:.4f}s")

    async def analyze_stream(self):
        """Consumer: Processes events in real-time."""
        print("Starting Forensic Analyzer...")
        count = 0
        hesitation_ticks = 0

        while True:
            event = await self.event_queue.get()
            if event is None: break # Sentinel received

            count += 1

            # --- REAL-TIME LOGIC ---
            # Check Hesitation: In Profit + Low Velocity
            # Simple threshold check for demo
            try:
                vel = float(event['velocity'])
                pl = float(event['pl'])

                if pl > 0 and vel < 25.0:
                    hesitation_ticks += 1
                    # In a real system, we would trigger an Alert here
            except:
                pass

            if count % 2000 == 0:
                print(f"Processed {count} events... (Hesitations: {hesitation_ticks})")

        print(f"Analysis Complete. Total Events: {count}. Hesitation Signals: {hesitation_ticks}")

    async def run(self):
        self.load_data()
        self.is_running = True

        # Run Producer and Consumer concurrently
        await asyncio.gather(
            self.stream_events(),
            self.analyze_stream()
        )

if __name__ == "__main__":
    engine = AsyncForensicEngine("FORENSIC_LAB/data/Mimic_Research_GOLD_20260202_141322.csv")
    asyncio.run(engine.run())
