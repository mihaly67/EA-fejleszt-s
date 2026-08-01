//+------------------------------------------------------------------+
//|                                  Merkava_Macro_Miner_v2.mq5      |
//|                                                                  |
//| Purpose: Extract highly synchronized M1 scalping data containing |
//|          multi-timeframe structural indicators (M1, M5, M15).    |
//| Replaces CCI with pure Momentum/ROC.                             |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "2.00"
#property script_show_inputs

input int InpLookbackDays = 14;  // Data history length in days

// Handles for Indicators
int handle_atr_m1;
int handle_roc_m1;
int handle_ema13_m5;
int handle_ema34_m5;
int handle_adx_m5;
int handle_donchian_max_m15;
int handle_donchian_min_m15;

void OnStart()
  {
   Print("🚀 Starting Merkava Macro Miner V2 (Scalper Edition)...");
   string symbol = Symbol();

   // 1. Initialize Indicator Handles
   handle_atr_m1 = iATR(symbol, PERIOD_M1, 14);
   handle_roc_m1 = iMomentum(symbol, PERIOD_M1, 3, PRICE_CLOSE);

   handle_ema13_m5 = iMA(symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema34_m5 = iMA(symbol, PERIOD_M5, 34, 0, MODE_EMA, PRICE_CLOSE);
   handle_adx_m5   = iADX(symbol, PERIOD_M5, 14);

   // MT5 doesn't have a native Donchian indicator, we use Highest/Lowest
   // For Donchian on M15 over say, 40 periods (10 hours of structural limits)
   // We will calculate this manually during the loop using iHighest/iLowest

   if(handle_atr_m1 == INVALID_HANDLE || handle_ema13_m5 == INVALID_HANDLE)
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
   string filename = "Macro_Scalper_" + symbol + "_M1.csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE) return;

   // Write Header
   FileWrite(file_handle,
             "Time", "Open", "High", "Low", "Close", "TickVolume", "RealVolume",
             "ATR_M1", "ROC_M1", "EMA13_M5", "EMA34_M5", "ADX_M5", "DI_Plus_M5", "DI_Minus_M5",
             "Donchian_High_M15", "Donchian_Low_M15");

   // 4. Iterate and Extract (Save oldest first for ML)
   Print("⏳ Extracting multi-timeframe indicators... This may take a minute.");

   double buf_atr[1], buf_roc[1], buf_ema13[1], buf_ema34[1];
   double buf_adx_main[1], buf_adx_plus[1], buf_adx_minus[1];

   for(int i = copied - 1; i >= 0; i--)
     {
      datetime bar_time = rates_m1[i].time;

      // Get exact shift index for higher timeframes corresponding to this M1 bar time
      int shift_m1 = iBarShift(symbol, PERIOD_M1, bar_time);
      int shift_m5 = iBarShift(symbol, PERIOD_M5, bar_time);
      int shift_m15 = iBarShift(symbol, PERIOD_M15, bar_time);

      if(shift_m1 < 0 || shift_m5 < 0 || shift_m15 < 0) continue;

      // Extract M1 Indicators
      CopyBuffer(handle_atr_m1, 0, shift_m1, 1, buf_atr);
      CopyBuffer(handle_roc_m1, 0, shift_m1, 1, buf_roc);

      // Extract M5 Indicators
      CopyBuffer(handle_ema13_m5, 0, shift_m5, 1, buf_ema13);
      CopyBuffer(handle_ema34_m5, 0, shift_m5, 1, buf_ema34);
      CopyBuffer(handle_adx_m5, 0, shift_m5, 1, buf_adx_main);   // MAIN ADX
      CopyBuffer(handle_adx_m5, 1, shift_m5, 1, buf_adx_plus);   // +DI
      CopyBuffer(handle_adx_m5, 2, shift_m5, 1, buf_adx_minus);  // -DI

      // Extract M15 Donchian (Highest/Lowest over last 40 M15 bars)
      int h_idx = iHighest(symbol, PERIOD_M15, MODE_HIGH, 40, shift_m15);
      int l_idx = iLowest(symbol, PERIOD_M15, MODE_LOW, 40, shift_m15);

      double donchian_high = 0;
      double donchian_low = 0;

      if (h_idx >= 0 && l_idx >= 0) {
         double h_arr[1], l_arr[1];
         CopyHigh(symbol, PERIOD_M15, h_idx, 1, h_arr);
         CopyLow(symbol, PERIOD_M15, l_idx, 1, l_arr);
         donchian_high = h_arr[0];
         donchian_low = l_arr[0];
      }

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
                DoubleToString(buf_roc[0], 4),
                DoubleToString(buf_ema13[0], _Digits),
                DoubleToString(buf_ema34[0], _Digits),
                DoubleToString(buf_adx_main[0], 2),
                DoubleToString(buf_adx_plus[0], 2),
                DoubleToString(buf_adx_minus[0], 2),
                DoubleToString(donchian_high, _Digits),
                DoubleToString(donchian_low, _Digits)
                );
     }

   FileClose(file_handle);
   Print("✅ Export Complete. File: ", filename);
  }
