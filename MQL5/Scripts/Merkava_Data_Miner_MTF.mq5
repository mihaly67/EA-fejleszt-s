//+------------------------------------------------------------------+
//|                                     Merkava_Data_Miner_MTF.mq5 |
//|                                                    Jules (Agent) |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      ""
#property version   "1.04"
#property strict
#property script_show_inputs

//--- Bemeneti paraméterek
input datetime InpStartDate = D'2026.04.01 00:00:00'; // Kezdő dátum
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
   return StringFormat("%s.%03d", TimeToString(time_sec, TIME_DATE|TIME_SECONDS), msc);
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("🚀 Merkava MTF Data Miner elindult. Célpont: ", _Symbol);

   // A letöltést kiterjesztjük 2 nappal korábbra a biztonság kedvéért.
   datetime mtf_start_date = InpStartDate - (2 * 24 * 60 * 60);

   MqlRates rates_1m[], rates_5m[], rates_15m[];
   int copied_1m = CopyRates(_Symbol, PERIOD_M1, mtf_start_date, InpEndDate, rates_1m);
   int copied_5m = CopyRates(_Symbol, PERIOD_M5, mtf_start_date, InpEndDate, rates_5m);
   int copied_15m = CopyRates(_Symbol, PERIOD_M15, mtf_start_date, InpEndDate, rates_15m);

   if(copied_1m <= 0 || copied_5m <= 0 || copied_15m <= 0)
     {
      Print("❌ KRITIKUS HIBA: Nem sikerült letölteni az M1, M5 vagy M15 adatokat.");
      return;
     }

   file_handle = FileOpen(InpFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE)
     {
      Print("❌ Hiba: Nem sikerült megnyitni a fájlt írásra: ", InpFileName);
      return;
     }

   FileWrite(file_handle, "Timestamp", "Bid", "Ask", "Bid_Volume", "Ask_Volume", "1m_Close", "5m_Close", "15m_Close");

   MqlTick tick_array[];
   int total_ticks = CopyTicksRange(_Symbol, tick_array, COPY_TICKS_ALL, (ulong)InpStartDate*1000, (ulong)InpEndDate*1000);

   if(total_ticks <= 0)
     {
      Print("❌ HIBA: Nem található tick adat az adott időszakra.");
      FileClose(file_handle);
      return;
     }

   int idx_1m = 0;
   int idx_5m = 0;
   int idx_15m = 0;

   ulong current_second_bucket = 0;
   double bucket_bid = 0.0;
   double bucket_ask = 0.0;

   // FIX: Volumen változók Double típusra (double volume_real támogatáshoz)
   double bucket_bid_vol = 0.0;
   double bucket_ask_vol = 0.0;

   ulong tick_count_in_bucket = 0;

   double last_1m_close = rates_1m[0].close;
   double last_5m_close = rates_5m[0].close;
   double last_15m_close = rates_15m[0].close;

   for(int i = 0; i < total_ticks; i++)
     {
      ulong tick_time_ms = tick_array[i].time_msc;
      ulong tick_second = tick_time_ms / 1000;
      datetime tick_time_sec = (datetime)tick_second;

      // MTF szinkronizáció
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

      if(current_second_bucket != tick_second)
        {
         if(tick_count_in_bucket > 0)
           {
            // Oszlop formátumok javítása %.8f-re a volume miatt (pl. 1.00000000)
            string time_str = FormatTime(current_second_bucket * 1000);
            string line = StringFormat("%s,%.5f,%.5f,%.8f,%.8f,%.5f,%.5f,%.5f",
                                       time_str, bucket_bid, bucket_ask,
                                       bucket_bid_vol, bucket_ask_vol,
                                       last_1m_close, last_5m_close, last_15m_close);
            FileWrite(file_handle, line);
           }

         current_second_bucket = tick_second;
         bucket_bid = tick_array[i].bid;
         bucket_ask = tick_array[i].ask;
         bucket_bid_vol = 0.0;
         bucket_ask_vol = 0.0;
         tick_count_in_bucket = 0;
        }

      if(tick_array[i].bid > 0) bucket_bid = tick_array[i].bid;
      if(tick_array[i].ask > 0) bucket_ask = tick_array[i].ask;

      // FIX: Szuperszigorú Trade Tick Volume (Double - volume_real)
      double trade_vol = tick_array[i].volume_real;

      if (trade_vol > 0.0 && (tick_array[i].flags & TICK_FLAG_VOLUME) != 0)
        {
         if ((tick_array[i].flags & TICK_FLAG_BUY) != 0)
           {
            bucket_ask_vol += trade_vol; // Market Buy (vételi nyomás)
           }
         else if ((tick_array[i].flags & TICK_FLAG_SELL) != 0)
           {
            bucket_bid_vol += trade_vol; // Market Sell (eladási nyomás)
           }
        }

      tick_count_in_bucket++;
     }

   if(tick_count_in_bucket > 0)
     {
      string time_str = FormatTime(current_second_bucket * 1000);
      string line = StringFormat("%s,%.5f,%.5f,%.8f,%.8f,%.5f,%.5f,%.5f",
                                 time_str, bucket_bid, bucket_ask,
                                 bucket_bid_vol, bucket_ask_vol,
                                 last_1m_close, last_5m_close, last_15m_close);
      FileWrite(file_handle, line);
     }

   FileClose(file_handle);
   Print("✨ Művelet sikeresen befejeződött. Adatok elmentve: ", InpFileName);
  }
//+------------------------------------------------------------------+
