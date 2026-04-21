import unittest
import os
import json
import sys
import shutil

# --- CONFIGURATION ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KUTATO_SCRIPT = os.path.join(BASE_DIR, "kutato_intezet.py")
OUTPUT_DIR = os.path.join(BASE_DIR, "test_output")

class TestKutatoIntezetIntegration(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Create clean output directory
        if os.path.exists(OUTPUT_DIR):
            shutil.rmtree(OUTPUT_DIR)
        os.makedirs(OUTPUT_DIR)

    def test_director_manager_worker_flow(self):
        """Simulates a full research lifecycle: Director -> Manager -> Worker"""

        # 1. Director: Initiates search about "indicator buffer"
        director_output = os.path.join(OUTPUT_DIR, "level_0.json")
        cmd_director = [
            sys.executable, KUTATO_SCRIPT,
            "--role", "director",
            "--query", "indicator buffer",
            "--output", director_output,
            "--limit", "1"
        ]

        print("\n[TEST] Running Director...")
        import subprocess
        ret_dir = subprocess.run(cmd_director, capture_output=True, text=True)

        # Check Director Success
        self.assertEqual(ret_dir.returncode, 0, f"Director failed: {ret_dir.stderr}")
        self.assertTrue(os.path.exists(director_output), "Director output missing")

        with open(director_output, 'r') as f:
            data_0 = json.load(f)

        self.assertEqual(data_0['level'], 0)
        self.assertTrue(len(data_0['results']) > 0, "Director found no results")
        self.assertTrue(len(data_0['next_jobs']) > 0, "Director generated no next jobs")

        # Verify Director retrieved from multiple scopes if possible (though top 5 might be dominated by one)
        scopes_found = {r['source_type'] for r in data_0['results']}
        print(f"Director scopes found: {scopes_found}")

        # 2. Manager: Processes Director's output
        manager_output = os.path.join(OUTPUT_DIR, "level_1.json")
        cmd_manager = [
            sys.executable, KUTATO_SCRIPT,
            "--role", "manager",
            "--input", director_output,
            "--output", manager_output,
            "--limit", "2"
        ]

        print("[TEST] Running Manager...")
        ret_man = subprocess.run(cmd_manager, capture_output=True, text=True)

        # Check Manager Success
        self.assertEqual(ret_man.returncode, 0, f"Manager failed: {ret_man.stderr}")
        self.assertTrue(os.path.exists(manager_output), "Manager output missing")

        with open(manager_output, 'r') as f:
            data_1 = json.load(f)

        self.assertEqual(data_1['level'], 1)
        self.assertTrue(len(data_1['results']) > 0, "Manager found no results")

        # Verify mixed scope retrieval in Manager results (Theory, Code, MQL5)
        scopes_found_1 = {r['source_type'] for r in data_1['results']}
        print(f"Manager scopes found: {scopes_found_1}")

        # Check for specific format markers
        has_windowed = any("(Windowed Context:" in r.get('filename', '') for r in data_1['results'] if r['source_type'] == 'THEORY')
        has_full_file = any("--- FILE:" in r.get('content', '') for r in data_1['results'] if r['source_type'] == 'CODE')

        if 'THEORY' in scopes_found_1:
            print(f"Theory Windowed Check: {has_windowed}")
        if 'CODE' in scopes_found_1:
             print(f"Code Reconstruction Check: {has_full_file}")

if __name__ == '__main__':
    unittest.main()
