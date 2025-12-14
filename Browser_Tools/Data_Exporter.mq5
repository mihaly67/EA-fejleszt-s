//+------------------------------------------------------------------+
//|                                                Data_Exporter.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 1.1 (Weekend/No-Data Fix)     |
//|                                                                  |
//| LEÍRÁS:                                                          |
//| Lementi az utolsó N nap M1 adatait (vagy Tickeket) CSV-be.       |
//| JAVÍTÁS: Nem a szerver időt nézi, hanem az utolsó ismert BAR-t.  |
//| Így hétvégén is működik (a pénteki adatokat tölti le).           |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "1.10"
#property script_show_inputs

input int      InpDaysToExport = 1;     // Exportált kereskedési napok száma
input bool     InpExportTicks  = false; // Tick adatok (True) vagy M1 Barok (False)
input string   InpFileName     = "";    // Fájlnév (Üres = Auto)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // 1. Find the Anchor Point (Last known data time)
   // We use iTime to get the opening time of the last bar on M1.
   datetime last_bar_time = iTime(_Symbol, PERIOD_M1, 0);

   if(last_bar_time == 0) {
      Print("Hiba: Nem sikerült lekérdezni az utolsó bar idejét. Nincs adat a charton?");
      return;
   }

   // End time is the close of the last bar (approx) or just Current Time if valid.
   // Safer: Use TimeCurrent() if market is open, or last_bar_time + period if closed.
   // Actually, CopyRates 'to' parameter is exclusive? Or inclusive?
   // CopyRates(..., start, end) -> Copies from start to end.

   // Let's set 'end' to the very latest known moment.
   datetime end = TimeCurrent();

   // If TimeCurrent is far ahead of last_bar_time (e.g. Weekend),
   // it doesn't hurt CopyRates (it just won't find data in the gap).
   // BUT, to calculate 'start', we must count back from the DATA, not the CLOCK.

   // Ha hétvége van (vasárnap), és 1 napot kérünk:
   // TimeCurrent = Vasárnap. Start = Szombat. CopyRates(Szombat, Vasárnap) -> Üres.
   // Ez volt a hiba!

   // Megoldás: Az 'end' legyen az utolsó Bar ideje + 1 perc (hogy beleférjen).
   // Vagy inkább: Keressük meg a tartományt a BAROK száma alapján?
   // Nem, mert tickeket is akarhatunk idő alapján.

   // Korrigált logika:
   // End = last_bar_time + 60 (hogy a legutolsó bar is benne legyen).
   // Start = End - (Napok * 86400).
   // Így ha LastBar = Péntek 23:59, akkor Start = Csütörtök 23:59. Ez 1 napnyi adat.

   end = last_bar_time + 60;
   datetime start = end - (InpDaysToExport * 24 * 3600);

   PrintFormat("Időtartomány keresése (LastBar alapú): %s -> %s", TimeToString(start), TimeToString(end));

   // 2. Generate Filename
   string filename = InpFileName;
   if(filename == "") {
      string type = InpExportTicks ? "Ticks" : "M1";
      filename = StringFormat("%s_%s_%dDay.csv", _Symbol, type, InpDaysToExport);
   }

   // 3. Open File
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   if(handle == INVALID_HANDLE) {
      Print("Hiba a fájl megnyitásakor! Kód: ", GetLastError());
      return;
   }

   int total_written = 0;

   if(InpExportTicks) {
      // --- TICK EXPORT ---
      FileWrite(handle, "Time", "Bid", "Ask", "Flags");

      MqlTick ticks[];
      // CopyTicksRange is precise with MSC.
      int total = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, start * 1000, end * 1000);

      if(total > 0) {
         PrintFormat("%d tick letöltve. Írás folyamatban...", total);
         for(int i=0; i<total; i++) {
            FileWrite(handle, ticks[i].time, ticks[i].bid, ticks[i].ask, ticks[i].flags);
         }
         total_written = total;
      } else {
         Print("Hiba: 0 tick érkezett. Ellenőrizd, hogy a bróker szolgáltat-e tick history-t.");
      }
   }
   else {
      // --- BAR EXPORT (M1) ---
      FileWrite(handle, "Time", "Open", "High", "Low", "Close", "Volume");

      MqlRates rates[];
      int total = CopyRates(_Symbol, PERIOD_M1, start, end, rates);

      if(total > 0) {
         PrintFormat("%d M1 bar letöltve. Írás folyamatban...", total);
         for(int i=0; i<total; i++) {
            FileWrite(handle, rates[i].time, rates[i].open, rates[i].high, rates[i].low, rates[i].close, rates[i].tick_volume);
         }
         total_written = total;
      } else {
         Print("Hiba: 0 M1 bar érkezett. Kód: ", GetLastError());
      }
   }

   FileClose(handle);

   if(total_written > 0) {
      Print("Sikeres export! Fájl: MQL5/Files/", filename);
   } else {
      Print("Sikertelen export (üres fájl). Törlés...");
      FileDelete(filename);
   }
  }
