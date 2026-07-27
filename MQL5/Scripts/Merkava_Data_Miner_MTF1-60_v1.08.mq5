//+------------------------------------------------------------------+
//|                             Merkava_Data_Miner_MTF1-60_v1.08.mq5 |
//|                                                    Jules (Agent) |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      ""
#property version   "1.08"
#property strict
#property script_show_inputs

//--- Bemeneti paraméterek
input datetime InpStartDate = D'2026.04.01 00:00:00'; // Kezdő dátum
input datetime InpEndDate   = D'2026.07.16 23:59:59'; // Záró dátum
input string   InpFileName  = "Merkava_MTF1-60_MGCQ26_Data.csv"; // Fájl neve a kimentéshez

// Globális változók
int file_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: Idő konvertálása olvasható formátumba (MT5 Szerveridő)   |
//+------------------------------------------------------------------+
string FormatTime(ulong time_msc)
  {
   datetime time_sec = (datetime)(time_msc / 1000);
   int msc = (int)(time_msc % 1000);
   return StringFormat("%s.%03d", TimeToString(time_sec, TIME_DATE|TIME_SECONDS), msc);
  }

//+------------------------------------------------------------------+
//| Biztonságos adatletöltő (History loader)                         |
//+------------------------------------------------------------------+
bool ForceLoadHistory(string symbol, ENUM_TIMEFRAMES period, datetime start_date, datetime end_date)
  {
   Print("Adat letöltés ellenőrzése: ", EnumToString(period));

   // Kényszerítsük ki a frissítést
   datetime current_time = TimeCurrent();
   int max_wait = 100;

   while(!SeriesInfoInteger(symbol, period, SERIES_SYNCHRONIZED) && max_wait > 0 && !IsStopped())
     {
      Sleep(100);
      max_wait--;
     }

   MqlRates temp[];
   int copied = CopyRates(symbol, period, start_date, end_date, temp);

   max_wait = 50;
   while(copied <= 0 && max_wait > 0 && !IsStopped())
     {
      Sleep(200);
      copied = CopyRates(symbol, period, start_date, end_date, temp);
      max_wait--;
     }

   if(copied > 0)
     {
      Print(EnumToString(period), " letöltve, sorok száma: ", copied);
      return true;
     }

   Print("❌ Sikertelen adatletöltés: ", EnumToString(period));
   return false;
  }

void OnStart()
  {
   Print("🚀 Merkava MTF Data Miner elindult. Célpont: ", _Symbol);

   // A letöltést kiterjesztjük 2 nappal korábbra a biztonság kedvéért.
   datetime mtf_start_date = InpStartDate - (2 * 24 * 60 * 60);

   MqlTick tick_array[];
   int total_ticks = CopyTicksRange(_Symbol, tick_array, COPY_TICKS_ALL, (ulong)InpStartDate*1000, (ulong)InpEndDate*1000);

   ForceLoadHistory(_Symbol, PERIOD_M1, mtf_start_date, InpEndDate);
   ForceLoadHistory(_Symbol, PERIOD_M5, mtf_start_date, InpEndDate);
   ForceLoadHistory(_Symbol, PERIOD_M10, mtf_start_date, InpEndDate);
   ForceLoadHistory(_Symbol, PERIOD_M15, mtf_start_date, InpEndDate);
   ForceLoadHistory(_Symbol, PERIOD_M30, mtf_start_date, InpEndDate);
   ForceLoadHistory(_Symbol, PERIOD_H1, mtf_start_date, InpEndDate);

   MqlRates rates_1m[], rates_5m[], rates_10m[], rates_15m[], rates_30m[], rates_60m[];
   int copied_1m = CopyRates(_Symbol, PERIOD_M1, mtf_start_date, InpEndDate, rates_1m);
   int copied_5m = CopyRates(_Symbol, PERIOD_M5, mtf_start_date, InpEndDate, rates_5m);
   int copied_10m = CopyRates(_Symbol, PERIOD_M10, mtf_start_date, InpEndDate, rates_10m);
   int copied_15m = CopyRates(_Symbol, PERIOD_M15, mtf_start_date, InpEndDate, rates_15m);
   int copied_30m = CopyRates(_Symbol, PERIOD_M30, mtf_start_date, InpEndDate, rates_30m);
   int copied_60m = CopyRates(_Symbol, PERIOD_H1, mtf_start_date, InpEndDate, rates_60m);

   PrintFormat("✅ Letöltött adatok: M1=%d, M5=%d, M10=%d, M15=%d, M30=%d, H1=%d, Ticks=%d",
               copied_1m, copied_5m, copied_10m, copied_15m, copied_30m, copied_60m, total_ticks);

   if(copied_1m <= 0 || copied_5m <= 0 || copied_10m <= 0 || copied_15m <= 0 || copied_30m <= 0 || copied_60m <= 0)
     {
      Print("❌ KRITIKUS HIBA: Nem sikerült letölteni valamelyik makro adatot (M1-H1).");
      return;
     }

   file_handle = FileOpen(InpFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE)
     {
      Print("❌ Hiba: Nem sikerült megnyitni a fájlt írásra: ", InpFileName);
      return;
     }

   FileWrite(file_handle, "Timestamp", "Bid", "Ask", "Bid_Volume", "Ask_Volume",
             "1m_Close", "5m_Close", "10m_Close", "15m_Close", "30m_Close", "60m_Close");

   if(total_ticks <= 0)
     {
      Print("❌ HIBA: Nem található tick adat az adott időszakra.");
      FileClose(file_handle);
      return;
     }

   ArraySetAsSeries(rates_1m, false);
   ArraySetAsSeries(rates_5m, false);
   ArraySetAsSeries(rates_10m, false);
   ArraySetAsSeries(rates_15m, false);
   ArraySetAsSeries(rates_30m, false);
   ArraySetAsSeries(rates_60m, false);

   int idx_1m = 0;
   int idx_5m = 0;
   int idx_10m = 0;
   int idx_15m = 0;
   int idx_30m = 0;
   int idx_60m = 0;

   ulong current_second_bucket = 0;
   double bucket_bid = 0.0;
   double bucket_ask = 0.0;

   double bucket_bid_vol = 0.0;
   double bucket_ask_vol = 0.0;

   ulong tick_count_in_bucket = 0;

   double last_1m_close = rates_1m[0].close;
   double last_5m_close = rates_5m[0].close;
   double last_10m_close = rates_10m[0].close;
   double last_15m_close = rates_15m[0].close;
   double last_30m_close = rates_30m[0].close;
   double last_60m_close = rates_60m[0].close;

   for(int i = 0; i < total_ticks; i++)
     {
      ulong tick_time_ms = tick_array[i].time_msc;
      ulong tick_second = tick_time_ms / 1000;
      datetime tick_time_sec = (datetime)tick_second;

      // MTF szinkronizáció - Szuperszigorú gyorsítótár
      while(idx_1m < copied_1m - 1 && (rates_1m[idx_1m + 1].time + 60) <= tick_time_sec) idx_1m++;
      last_1m_close = rates_1m[idx_1m].close;

      while(idx_5m < copied_5m - 1 && (rates_5m[idx_5m + 1].time + 300) <= tick_time_sec) idx_5m++;
      last_5m_close = rates_5m[idx_5m].close;

      while(idx_10m < copied_10m - 1 && (rates_10m[idx_10m + 1].time + 600) <= tick_time_sec) idx_10m++;
      last_10m_close = rates_10m[idx_10m].close;

      while(idx_15m < copied_15m - 1 && (rates_15m[idx_15m + 1].time + 900) <= tick_time_sec) idx_15m++;
      last_15m_close = rates_15m[idx_15m].close;

      while(idx_30m < copied_30m - 1 && (rates_30m[idx_30m + 1].time + 1800) <= tick_time_sec) idx_30m++;
      last_30m_close = rates_30m[idx_30m].close;

      while(idx_60m < copied_60m - 1 && (rates_60m[idx_60m + 1].time + 3600) <= tick_time_sec) idx_60m++;
      last_60m_close = rates_60m[idx_60m].close;

      if(current_second_bucket != tick_second)
        {
         if(tick_count_in_bucket > 0)
           {
            string time_str = FormatTime(current_second_bucket * 1000);
            string line = StringFormat("%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f",
                                       time_str, bucket_bid, bucket_ask,
                                       bucket_bid_vol, bucket_ask_vol,
                                       last_1m_close, last_5m_close, last_10m_close, last_15m_close, last_30m_close, last_60m_close);
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

      double trade_vol = tick_array[i].volume_real;

      if (trade_vol > 0.0 && (tick_array[i].flags & TICK_FLAG_VOLUME) != 0)
        {
         if ((tick_array[i].flags & TICK_FLAG_BUY) != 0)
           {
            bucket_ask_vol += trade_vol;
           }
         else if ((tick_array[i].flags & TICK_FLAG_SELL) != 0)
           {
            bucket_bid_vol += trade_vol;
           }
        }

      tick_count_in_bucket++;
     }

   if(tick_count_in_bucket > 0)
     {
      string time_str = FormatTime(current_second_bucket * 1000);
      string line = StringFormat("%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f",
                                 time_str, bucket_bid, bucket_ask,
                                 bucket_bid_vol, bucket_ask_vol,
                                 last_1m_close, last_5m_close, last_10m_close, last_15m_close, last_30m_close, last_60m_close);
      FileWrite(file_handle, line);
     }

   FileClose(file_handle);
   Print("✨ Művelet sikeresen befejeződött. Adatok elmentve: ", InpFileName);
  }
