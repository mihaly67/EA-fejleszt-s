//+------------------------------------------------------------------+
//|                                                Data_Exporter.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 1.0 (CSV Export for Optimizer)|
//|                                                                  |
//| LEÍRÁS:                                                          |
//| Lementi az utolsó 1 nap M1 adatait (vagy Tickeket) CSV-be.       |
//| A fájl a MQL5/Files mappába kerül.                               |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "1.00"
#property script_show_inputs

input int      InpDaysToExport = 1;     // Exportált napok száma
input bool     InpExportTicks  = false; // Tick adatok (True) vagy M1 Barok (False)
input string   InpFileName     = "";    // Fájlnév (Üres = Auto: Symbol_Date.csv)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // 1. Define Range
   datetime end = TimeCurrent();
   datetime start = end - (InpDaysToExport * 24 * 3600);

   // 2. Generate Filename
   string filename = InpFileName;
   if(filename == "") {
      string type = InpExportTicks ? "Ticks" : "M1";
      filename = StringFormat("%s_%s_%dDay.csv", _Symbol, type, InpDaysToExport);
   }

   Print("Exportálás indul: ", filename);

   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   if(handle == INVALID_HANDLE) {
      Print("Hiba a fájl megnyitásakor! ", GetLastError());
      return;
   }

   if(InpExportTicks) {
      // --- TICK EXPORT ---
      FileWrite(handle, "Time", "Bid", "Ask", "Flags");

      MqlTick ticks[];
      int total = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, start * 1000, end * 1000);

      if(total > 0) {
         PrintFormat("%d tick letöltve. Írás...", total);
         for(int i=0; i<total; i++) {
            FileWrite(handle, ticks[i].time, ticks[i].bid, ticks[i].ask, ticks[i].flags);
         }
      } else {
         Print("Nem sikerült tickeket letölteni (vagy nincs adat).");
      }
   }
   else {
      // --- BAR EXPORT (M1) ---
      FileWrite(handle, "Time", "Open", "High", "Low", "Close", "Volume");

      MqlRates rates[];
      int total = CopyRates(_Symbol, PERIOD_M1, start, end, rates);

      if(total > 0) {
         PrintFormat("%d M1 bar letöltve. Írás...", total);
         for(int i=0; i<total; i++) {
            FileWrite(handle, rates[i].time, rates[i].open, rates[i].high, rates[i].low, rates[i].close, rates[i].tick_volume);
         }
      } else {
         Print("Nem sikerült M1 adatokat letölteni.");
      }
   }

   FileClose(handle);
   Print("Sikeres export! Fájl helye: MQL5/Files/", filename);
  }
