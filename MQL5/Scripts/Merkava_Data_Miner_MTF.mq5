//+------------------------------------------------------------------+
//|                                     Merkava_Data_Miner_MTF.mq5 |
//|                                                    Jules (Agent) |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      ""
#property version   "1.01"
#property strict
#property script_show_inputs

//--- Bemeneti paraméterek
input datetime InpStartDate = D'2026.04.01 00:00:00'; // Kezdő dátum (Pl. 3 hónapra visszamenőleg)
input datetime InpEndDate   = D'2026.07.16 23:59:59'; // Záró dátum
input string   InpFileName  = "Merkava_MTF_GCE_Data.csv"; // Fájl neve a kimentéshez

// Globális változók
int file_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: Idő konvertálása olvasható formátumba (MT5 Szerveridő)    |
//+------------------------------------------------------------------+
string FormatTime(ulong time_msc)
  {
   datetime time_sec = (datetime)(time_msc / 1000);
   int msc = (int)(time_msc % 1000);
   // Eredmény pl: 2026.07.01 10:05:30.000
   return StringFormat("%s.%03d", TimeToString(time_sec, TIME_DATE|TIME_SECONDS), msc);
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("🚀 Merkava MTF Data Miner elindult. Célpont: ", _Symbol);

   // --- BIZTONSÁGI ELLENŐRZÉS: Történelem megléte ---
   // Kiterjesztjük a kezdeti dátumot 2 NAPPAL KORÁBBRA a magasabb idősíkok letöltéséhez.
   // Ez garantálja, hogy a legelső letöltött tick esetében is (pl. hétfő hajnal)
   // lesz már egy múlt pénteki / korábbi lezárt 15 perces gyertya a memóriában.
   datetime mtf_start_date = InpStartDate - (2 * 24 * 60 * 60);

   MqlRates rates_1m[], rates_5m[], rates_15m[];
   int copied_1m = CopyRates(_Symbol, PERIOD_M1, mtf_start_date, InpEndDate, rates_1m);
   int copied_5m = CopyRates(_Symbol, PERIOD_M5, mtf_start_date, InpEndDate, rates_5m);
   int copied_15m = CopyRates(_Symbol, PERIOD_M15, mtf_start_date, InpEndDate, rates_15m);

   if(copied_1m <= 0 || copied_5m <= 0 || copied_15m <= 0)
     {
      Print("❌ KRITIKUS HIBA: Nem sikerült letölteni az M1, M5 vagy M15 adatokat. Kérlek nyisd meg a chartokat és görgess vissza, hogy a terminál letöltse az adatokat a brókertől (AMP Futures)!");
      Print("Copied M1: ", copied_1m, " | M5: ", copied_5m, " | M15: ", copied_15m);
      return;
     }

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
      Print("❌ HIBA: Nem található tick adat az adott időszakra (", InpStartDate, " - ", InpEndDate, "). Valószínűleg a brókernél (AMP) csak néhány hónapnyi adat érhető el.");
      FileClose(file_handle);
      return;
     }

   Print("✅ Tick adatok sikeresen letöltve. Összesen: ", total_ticks, " darab. Feldolgozás és szinkronizáció...");

   // Mutatók a gyertyatömbökhöz
   int idx_1m = 0;
   int idx_5m = 0;
   int idx_15m = 0;

   // 1 másodperces aggregációs vödör változói
   ulong current_second_bucket = 0;
   double bucket_bid = 0.0;
   double bucket_ask = 0.0;
   ulong bucket_bid_vol = 0;
   ulong bucket_ask_vol = 0;
   ulong tick_count_in_bucket = 0;

   // Alapértelmezett kezdőárak (Ha mégis lenne rés az elején)
   double last_1m_close = rates_1m[0].close;
   double last_5m_close = rates_5m[0].close;
   double last_15m_close = rates_15m[0].close;

   for(int i = 0; i < total_ticks; i++)
     {
      if(i % 1000000 == 0 && i > 0)
        {
         Print("Feldolgozás: ", i, " / ", total_ticks, " (", (i*100)/total_ticks, "%)");
        }

      ulong tick_time_ms = tick_array[i].time_msc;
      ulong tick_second = tick_time_ms / 1000;
      datetime tick_time_sec = (datetime)tick_second;

      // MTF (M1, M5, M15) záróárak SZIGORÚ szinkronizálása a forward-fill logikával.
      // Amíg a következő gyertya nyitási ideje KISEBB VAGY EGYENLŐ, mint az aktuális tick ideje,
      // haladunk előre az indexszel.
      // FIGYELEM: A lezárt értéket a *rates[idx-1].close* fogja adni, ha szigorúan csak a lezártakat akarjuk.
      // Viszont ha a tick ideje belépett az adott gyertya időtartamába, akkor forward-fill-ként az adott gyertya nyitóját (vagy legutolsó értékét) használjuk.
      // Itt a legbiztosabb megoldás (Data Leakage elkerülésére):
      // A ciklus addig lépteti az indexet, amíg a rates[idx].time <= tick_time_sec.
      // Ha megállt (tehát megtalálta a tickhez tartozó nyitott gyertyát), akkor a rates[idx].close értékét mentjük el.
      // Ez az offline fájlban a végső záróár lesz, amit az ML modell target/konfluencia szintként kezel (múltbeli záróár).

      while(idx_1m < copied_1m - 1 && rates_1m[idx_1m + 1].time <= tick_time_sec)
        {
         idx_1m++;
         last_1m_close = rates_1m[idx_1m].close;
        }
      while(idx_5m < copied_5m - 1 && rates_5m[idx_5m + 1].time <= tick_time_sec)
        {
         idx_5m++;
         last_5m_close = rates_5m[idx_5m].close;
        }
      while(idx_15m < copied_15m - 1 && rates_15m[idx_15m + 1].time <= tick_time_sec)
        {
         idx_15m++;
         last_15m_close = rates_15m[idx_15m].close;
        }

      // Vödör lezárása és kiírása, ha másodpercet váltottunk
      if(current_second_bucket != tick_second)
        {
         if(tick_count_in_bucket > 0)
           {
            // Oszlopok: Timestamp, Bid, Ask, Bid_Volume, Ask_Volume, 1m_Close, 5m_Close, 15m_Close
            string time_str = FormatTime(current_second_bucket * 1000);
            string line = StringFormat("%s,%.5f,%.5f,%I64u,%I64u,%.5f,%.5f,%.5f",
                                       time_str,
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
      string time_str = FormatTime(current_second_bucket * 1000);
      string line = StringFormat("%s,%.5f,%.5f,%I64u,%I64u,%.5f,%.5f,%.5f",
                                 time_str,
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
