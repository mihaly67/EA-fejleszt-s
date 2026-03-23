//+------------------------------------------------------------------+
//|                                     DataMiner_TickExporter_v1_00.mq5 |
//|                                     Copyright 2026, Jules        |
//|                                     https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules"
#property link      "https://www.mql5.com"
#property version   "1.00"

// Script modban fut (OnStart), hogy akar hetvegen, zart piacon is
// le lehessen kerni az adatokat.
#property script_show_inputs

//--- Bemeneti parameterek
input datetime InpStartDate = D'2026.03.01 00:00'; // Kezdodatum (Start Date)
input datetime InpEndDate   = D'2026.03.05 23:59'; // Vegdatum (End Date)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("--------------------------------------------------");
   Print("[DataMiner] Tick Exporter v1.00 inditasa...");
   Print("[DataMiner] Instrumentum: ", Symbol());
   Print("[DataMiner] Idoszak: ", TimeToString(InpStartDate), " - ", TimeToString(InpEndDate));

   // Ellenorzes: Helyes-e a datum?
   if(InpStartDate >= InpEndDate)
     {
      Print("[HIBA] A Kezdodatum nem lehet nagyobb vagy egyenlo a Vegdatumnal!");
      return;
     }

   // 1. Tick adatok lekérése a brókertől a memóriába (CopyTicksRange)
   MqlTick tick_array[];

   // Datum konverzio milliszekundumba a CopyTicksRange szamara
   ulong start_msc = (ulong)InpStartDate * 1000;
   ulong end_msc   = (ulong)InpEndDate * 1000;

   Print("[DataMiner] Tortenelmi tickek lekerese a brokerszerverrol... Kerlek varj, ez eltarthat par masodpercig.");

   // COPY_TICKS_ALL: Minden tick (Bid, Ask, Last, Volume)
   int copied = CopyTicksRange(Symbol(), tick_array, COPY_TICKS_ALL, start_msc, end_msc);

   // A memoriaban levo ML utasitasok alapjan:
   // A CopyTicksRange fuggveny 0-t (nem -1-et) ad vissza, ha nincs tortenelmi adat.
   // Ezt expliciten kezelni kell az ures CSV generalas elkerulese vegett.
   if(copied <= 0)
     {
      Print("[HIBA] Nem sikerult tick adatokat lekerni! A broker nem szolgaltatott adatot erre az idoszakra. (Kod: ", GetLastError(), ")");
      return;
     }

   Print("[DataMiner] Sikeres lekerdezes! Lekert tickek szama: ", copied);

   // 2. CSV Fajl Letrehozasa
   // Fajlnev: Symbol_Ticks_YYYYMMDD_YYYYMMDD.csv
   string start_str = TimeToString(InpStartDate, TIME_DATE);
   StringReplace(start_str, ".", "");
   string end_str = TimeToString(InpEndDate, TIME_DATE);
   StringReplace(end_str, ".", "");

   string file_name = StringFormat("%s_Global_Ticks_%s_%s.csv", Symbol(), start_str, end_str);

   // Megnyitas irasra (FILE_CSV, FILE_ANSI).
   // A fajlt kozvetlenul a Files mappaba (MQL5\Files) mentjuk, almappa nelkul!
   int file_handle = FileOpen(file_name, FILE_WRITE | FILE_CSV | FILE_ANSI);
   if(file_handle == INVALID_HANDLE)
     {
      Print("[HIBA] Nem sikerult letrehozni a fajlt: ", file_name, " (Kod: ", GetLastError(), ")");
      return;
     }

   Print("[DataMiner] CSV Fajl megnyitva: ", file_name);
   Print("[DataMiner] Fajl irasa folyamatban (villamgyors mod)...");

   // Fejlec irasa
   FileWrite(file_handle, "TimeMsc,Bid,Ask");

   // Adatok irasa egy nagy teljesitmenyu ciklusban
   // A memoriaban levo teljesitmeny-szabaly alapjan:
   // SOHA ne hivj FileFlush()-t a nagy iteracios ciklusban, mert megoli az I/O-t.
   for(int i = 0; i < copied; i++)
     {
      // Formazas: TimeMsc, Bid (5 tizedes), Ask (5 tizedes)
      // Bizonyos instrumentumoknal (pl XAUUSD) lehet, hogy kevesebb tizedes kell,
      // de a %f (Float) biztonsagosan kimenti az erteket.
      string line = StringFormat("%llu,%.5f,%.5f",
                                 tick_array[i].time_msc,
                                 tick_array[i].bid,
                                 tick_array[i].ask);

      FileWrite(file_handle, line);
     }

   // 3. Fajl bezarasa a ciklus utan
   FileClose(file_handle);

   Print("--------------------------------------------------");
   Print("[Sikeres] Tick exportalas befejezve!");
   Print("[Sikeres] Fajl helye: MQL5\\Files\\", file_name);
   Print("--------------------------------------------------");
  }
//+------------------------------------------------------------------+