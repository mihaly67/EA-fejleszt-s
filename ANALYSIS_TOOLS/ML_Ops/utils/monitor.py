import psutil
import os
import time
import logging

# Logger beállítása
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ResourceMonitor:
    """
    Folyamatosan monitorozza a RAM és CPU használatot.
    Különösen fontos az 8GB RAM-os VPS környezetben a Data Loader és Modell betanítás során.
    """

    def __init__(self, memory_warning_threshold_mb=6000):
        self.process = psutil.Process(os.getpid())
        self.memory_warning_threshold_mb = memory_warning_threshold_mb
        self.start_time = time.time()

    def log_usage(self, context="Általános"):
        """Kivágja a jelenlegi erőforrás statisztikákat."""
        mem_info = self.process.memory_info()
        rss_mb = mem_info.rss / (1024 * 1024)
        vms_mb = mem_info.vms / (1024 * 1024)
        cpu_percent = self.process.cpu_percent(interval=0.1)
        system_ram_percent = psutil.virtual_memory().percent

        logger.info(f"[{context}] RAM (Folyamat): {rss_mb:.2f} MB | RAM (Rendszer): {system_ram_percent}% | CPU (Folyamat): {cpu_percent}%")

        if rss_mb > self.memory_warning_threshold_mb:
            logger.warning(f"⚠️ KRITIKUS MEMÓRIA SZINT: A folyamat több mint {self.memory_warning_threshold_mb} MB RAM-ot eszik!")

    def check_memory_limit(self):
        """Ha a rendszer közelít az OOM (Out of Memory) halálhoz, leállást javasol."""
        system_ram_percent = psutil.virtual_memory().percent
        if system_ram_percent > 90:
             logger.error("❌ KRITIKUS: Rendszer RAM 90% felett! Azonnali OOM veszély.")
             return False
        return True

    def get_execution_time(self):
        return time.time() - self.start_time

if __name__ == "__main__":
    monitor = ResourceMonitor()
    monitor.log_usage("Teszt Run")
