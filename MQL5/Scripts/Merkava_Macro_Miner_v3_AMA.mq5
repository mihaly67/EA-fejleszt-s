//+------------------------------------------------------------------+
//|                             Merkava_Macro_Miner_v3_AMA.mq5       |
//|                                                                  |
//| Purpose: Extract highly synchronized M1 scalping data containing |
//|          Adaptive Moving Averages (AMA) across M1, M5, M15.      |
//| Logic: AMA adapts to volatility. Fast=2 for micro trend following|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "3.00"
#property script_show_inputs

input int InpLookbackDays = 14;  // Data history length in days

// AMA Parameters
input int InpAmaPeriod = 20;     // Efficiency Ratio Period
input int InpAmaFast = 2;        // Fast EMA Period (for explosive micro-trends)
input int InpAmaSlow = 30;       // Slow EMA Period (for flat/ranging markets)

// Handles
int handle_atr_m1;
int handle_ama_m1;
int handle_ama_m5;
int handle_ama_m15;

void OnStart()
  {
   Print("🚀 Starting Merkava AMA Macro Miner V3...");
   string symbol = Symbol();

   // 1. Initialize Indicator Handles
   handle_atr_m1 = iATR(symbol, PERIOD_M1, 14);

   // AMA across 3 Timeframes with the same structural parameters
   handle_ama_m1 = iAMA(symbol, PERIOD_M1, InpAmaPeriod, InpAmaFast, InpAmaSlow, 0, PRICE_CLOSE);
   handle_ama_m5 = iAMA(symbol, PERIOD_M5, InpAmaPeriod, InpAmaFast, InpAmaSlow, 0, PRICE_CLOSE);
   handle_ama_m15 = iAMA(symbol, PERIOD_M15, InpAmaPeriod, InpAmaFast, InpAmaSlow, 0, PRICE_CLOSE);

   if(handle_atr_m1 == INVALID_HANDLE || handle_ama_m1 == INVALID_HANDLE)
     {
      Print("❌ Error initializing indicators.");
      return;
     }

   // 2. Prepare Data Arrays
   MqlRates rates_m1[];
   ArraySetAsSeries(rates_m1, true);

   datetime endTime = TimeCurrent();
   datetime startTime = endTime - (InpLookbackDays * 24 * 60 * 60);

   int copied = CopyRates(symbol, PERIOD_M1, startTime, endTime, rates_m1);
   if(copied <= 0)
     {
      Print("❌ Error copying M1 rates.");
      return;
     }

   // 3. Open File
   string filename = "Macro_AMA_" + symbol + "_M1.csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE) return;

   // Write Header
   FileWrite(file_handle,
             "Time", "Open", "High", "Low", "Close", "TickVolume", "RealVolume",
             "ATR_M1", "AMA_M1", "AMA_M5", "AMA_M15");

   // 4. Iterate and Extract
   Print("⏳ Extracting AMA indicators... This may take a minute.");

   double buf_atr[1], buf_ama1[1], buf_ama5[1], buf_ama15[1];

   for(int i = copied - 1; i >= 0; i--)
     {
      datetime bar_time = rates_m1[i].time;

      int shift_m1 = iBarShift(symbol, PERIOD_M1, bar_time);
      int shift_m5 = iBarShift(symbol, PERIOD_M5, bar_time);
      int shift_m15 = iBarShift(symbol, PERIOD_M15, bar_time);

      if(shift_m1 < 0 || shift_m5 < 0 || shift_m15 < 0) continue;

      // Extract
      CopyBuffer(handle_atr_m1, 0, shift_m1, 1, buf_atr);
      CopyBuffer(handle_ama_m1, 0, shift_m1, 1, buf_ama1);
      CopyBuffer(handle_ama_m5, 0, shift_m5, 1, buf_ama5);
      CopyBuffer(handle_ama_m15, 0, shift_m15, 1, buf_ama15);

      // Write to CSV
      FileWrite(file_handle,
                TimeToString(bar_time, TIME_DATE|TIME_SECONDS),
                DoubleToString(rates_m1[i].open, _Digits),
                DoubleToString(rates_m1[i].high, _Digits),
                DoubleToString(rates_m1[i].low, _Digits),
                DoubleToString(rates_m1[i].close, _Digits),
                IntegerToString(rates_m1[i].tick_volume),
                DoubleToString(rates_m1[i].real_volume, 0),
                DoubleToString(buf_atr[0], _Digits),
                DoubleToString(buf_ama1[0], _Digits),
                DoubleToString(buf_ama5[0], _Digits),
                DoubleToString(buf_ama15[0], _Digits)
                );
     }

   FileClose(file_handle);
   Print("✅ AMA Export Complete. File: ", filename);
  }
