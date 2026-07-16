//+------------------------------------------------------------------+
//|                                     Merkava_Data_Miner_MTF.mq5 |
//|                                                    Jules (Agent) |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      ""
#property version   "1.00"
#property strict
#property script_show_inputs

//--- Bemeneti paraméterek
input datetime InpStartDate = D'2026.07.01 00:00:00'; // Kezdő dátum
input datetime InpEndDate   = D'2026.07.15 23:59:59'; // Záró dátum
input string   InpFileName  = "Merkava_MTF_Data.csv"; // Fájl neve a kimentéshez

// Globális változók
int file_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("🚀 Merkava MTF Data Miner elindult. Zárt piacokon (hétvégén) is működik.");

   // Fájl megnyitása
   file_handle = FileOpen(InpFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE)
     {
      Print("❌ Hiba: Nem sikerült megnyitni a fájlt írásra: ", InpFileName);
      return;
     }

   // Fejléc írása
   FileWrite(file_handle, "Timestamp", "Bid", "Ask", "Bid_Volume", "Ask_Volume", "1m_Close", "5m_Close", "15m_Close");

   Print("📥 Tick adatok letöltése folyamatban... Ez a folyamat több percet is igénybe vehet.");

   // Történelmi tickek lekérése
   MqlTick tick_array[];
   int total_ticks = CopyTicksRange(_Symbol, tick_array, COPY_TICKS_ALL, (ulong)InpStartDate*1000, (ulong)InpEndDate*1000);

   if(total_ticks <= 0)
     {
      Print("❌ Hiba: Nem található tick adat a megadott időszakra! Tölteni kell az MT5 history-ból.");
      FileClose(file_handle);
      return;
     }

   Print("✅ Tick adatok sikeresen letöltve. Összesen: ", total_ticks, " darab. Feldolgozás és MTF szinkronizáció...");

   // Történelmi MTF gyertyák előzetes letöltése cache-be
   MqlRates rates_1m[], rates_5m[], rates_15m[];
   int copied_1m = CopyRates(_Symbol, PERIOD_M1, InpStartDate, InpEndDate, rates_1m);
   int copied_5m = CopyRates(_Symbol, PERIOD_M5, InpStartDate, InpEndDate, rates_5m);
   int copied_15m = CopyRates(_Symbol, PERIOD_M15, InpStartDate, InpEndDate, rates_15m);

   if(copied_1m <= 0 || copied_5m <= 0 || copied_15m <= 0)
     {
      Print("⚠️ Figyelmeztetés: Magasabb idősík adatok letöltése részlegesen sikertelen.");
     }

   int idx_1m = 0;
   int idx_5m = 0;
   int idx_15m = 0;

   // 1 másodperces vödör változói
   ulong current_second_bucket = 0;
   double bucket_bid = 0.0;
   double bucket_ask = 0.0;
   ulong bucket_bid_vol = 0;
   ulong bucket_ask_vol = 0;
   ulong tick_count_in_bucket = 0;

   double last_1m_close = 0.0;
   double last_5m_close = 0.0;
   double last_15m_close = 0.0;

   // Hogy elkerüljük az UI teljes fagyását egy végtelen ciklus miatt (Watchdog)
   uint last_time = GetTickCount();

   for(int i = 0; i < total_ticks; i++)
     {
      // Log progress without spamming
      if(i % 500000 == 0)
        {
         Print("Feldolgozás: ", i, " / ", total_ticks, " (", (i*100)/total_ticks, "%)");
        }

      ulong tick_time_ms = tick_array[i].time_msc;
      ulong tick_second = tick_time_ms / 1000;

      // MTF (M1, M5, M15) záróárak szinkronizálása a forward-fill logikával
      // Addig iteráljuk a gyertyákat előre, amíg a gyertya ideje KISEBB VAGY EGYENLŐ a tick idejével.
      // Tehát a tick pillanatában az *éppen megnyitott gyertya utolsó ismert close* értékét (ami valójában a live ár lenne) fogjuk be,
      // DE a legfontosabb, hogy a nyers MTF struktúrát Forward Fill-el kitöltsük. Mivel az MqlRates-ben a close változik amíg nyitva van,
      // visszamenőleg a történelmi fájlban a 'close' a végleges záróár. Ezt kell hozzáilleszteni a múltbeli tickhez.
      while(idx_1m < copied_1m && rates_1m[idx_1m].time <= tick_array[i].time)
        {
         last_1m_close = rates_1m[idx_1m].close;
         idx_1m++;
        }
      while(idx_5m < copied_5m && rates_5m[idx_5m].time <= tick_array[i].time)
        {
         last_5m_close = rates_5m[idx_5m].close;
         idx_5m++;
        }
      while(idx_15m < copied_15m && rates_15m[idx_15m].time <= tick_array[i].time)
        {
         last_15m_close = rates_15m[idx_15m].close;
         idx_15m++;
        }

      // Vödör lezárása és kiírása, ha másodpercet váltottunk
      if(current_second_bucket != tick_second)
        {
         if(tick_count_in_bucket > 0)
           {
            string line = StringFormat("%I64u,%.5f,%.5f,%I64u,%I64u,%.5f,%.5f,%.5f",
                                       current_second_bucket * 1000,
                                       bucket_bid,
                                       bucket_ask,
                                       bucket_bid_vol,
                                       bucket_ask_vol,
                                       last_1m_close,
                                       last_5m_close,
                                       last_15m_close);
            FileWrite(file_handle, line);
           }

         current_second_bucket = tick_second;
         bucket_bid = tick_array[i].bid;
         bucket_ask = tick_array[i].ask;
         bucket_bid_vol = 0;
         bucket_ask_vol = 0;
         tick_count_in_bucket = 0;
        }

      if(tick_array[i].bid > 0) bucket_bid = tick_array[i].bid;
      if(tick_array[i].ask > 0) bucket_ask = tick_array[i].ask;

      // Trade Tick Volume kalkulációja a BUY/SELL flag alapján
      if((tick_array[i].flags & TICK_FLAG_BUY) == TICK_FLAG_BUY)
        {
         bucket_ask_vol += tick_array[i].volume; // Market Buy -> felemésztette az Ask volument
        }
      else if((tick_array[i].flags & TICK_FLAG_SELL) == TICK_FLAG_SELL)
        {
         bucket_bid_vol += tick_array[i].volume; // Market Sell -> felemésztette a Bid volument
        }

      tick_count_in_bucket++;
     }

   // Az utolsó vödör kiírása a ciklus után
   if(tick_count_in_bucket > 0)
     {
      string line = StringFormat("%I64u,%.5f,%.5f,%I64u,%I64u,%.5f,%.5f,%.5f",
                                 current_second_bucket * 1000,
                                 bucket_bid,
                                 bucket_ask,
                                 bucket_bid_vol,
                                 bucket_ask_vol,
                                 last_1m_close,
                                 last_5m_close,
                                 last_15m_close);
      FileWrite(file_handle, line);
     }

   FileClose(file_handle);
   Print("✨ Művelet sikeresen befejeződött. Adatok elmentve: ", InpFileName);
  }
//+------------------------------------------------------------------+
