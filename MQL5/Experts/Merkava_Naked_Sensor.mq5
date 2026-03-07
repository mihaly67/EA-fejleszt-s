//+------------------------------------------------------------------+
//|                                        Merkava_Naked_Sensor.mq5  |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                         Phase: NÉMA SZÍNHÁZ (v1) |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "1.00"
#property strict

// Nincs Trade, nincs Stealth, nincs MDAS.
// Kizárólag adatrögzítés a jövőbeli FinRL / Anomaly Detection számára.

int g_csv_handle = INVALID_HANDLE;
string g_csv_filename = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[NÉMA SZÍNHÁZ] Merkava Naked Sensor inicializálása...");

   // Fájlnév generálás (pl. Merkava_Sensor_EURUSD_20260307.csv)
   string date_str = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(date_str, ".", "");
   g_csv_filename = "Merkava_Sensor_" + _Symbol + "_" + date_str + ".csv";

   // Fájl megnyitása (vagy létrehozása) írásra, közös olvasási joggal (FILE_SHARE_READ), hogy Python script tudja olvasni menet közben
   g_csv_handle = FileOpen(g_csv_filename, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, ",");

   if (g_csv_handle == INVALID_HANDLE)
   {
      Print("[!] HIBA: Nem sikerült létrehozni a CSV fájlt: ", g_csv_filename, " Hiba kód: ", GetLastError());
      return INIT_FAILED;
   }

   // CSV Fejléc kiírása (Ha a fájl üres)
   if (FileSize(g_csv_handle) == 0)
   {
       FileWrite(g_csv_handle, "TimeMsc", "Bid", "Ask", "Spread", "TickVolume", "Ping");
       FileFlush(g_csv_handle);
   }
   else
   {
       FileSeek(g_csv_handle, 0, SEEK_END); // Ha már létezik, a végéhez fűzzük
   }

   Print("[+] CSV Sensor Aktív: ", g_csv_filename, " (A Terminal/Common/Files mappában)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if (g_csv_handle != INVALID_HANDLE)
   {
       FileClose(g_csv_handle);
       Print("[NÉMA SZÍNHÁZ] Sensor leállítva, CSV lezárva.");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (g_csv_handle == INVALID_HANDLE) return;

   MqlTick tick;
   if (!SymbolInfoTick(_Symbol, tick)) return;

   // 1. TimeMsc (Időbélyeg milliszekundum pontossággal)
   long time_msc = tick.time_msc;

   // 2. Árak
   double bid = tick.bid;
   double ask = tick.ask;

   // 3. Spread (Bróker manipulációjának fő terepe)
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // Pontban kifejezve

   // 4. Tick Volume
   long tick_volume = tick.volume;

   // 5. Ping (Bróker válaszideje ms-ban, "Lag" detektáláshoz)
   long ping_ms = TerminalInfoInteger(TERMINAL_PING_LAST);

   // CSV sor írása
   FileWrite(g_csv_handle, time_msc, DoubleToString(bid, _Digits), DoubleToString(ask, _Digits), spread, tick_volume, ping_ms);

   // Azonnali flush, hogy áramszünet vagy WINE crash esetén se vesszen el adat, és a Python folyamatosan tudja olvasni
   FileFlush(g_csv_handle);
}
//+------------------------------------------------------------------+
