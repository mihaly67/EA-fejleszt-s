//+------------------------------------------------------------------+
//|                                     Merkava_Macro_Miner.mq5      |
//|                                                                  |
//| Purpose: Extract OHLCV macro timeframe data (M1, M5, M15) for    |
//|          the structural Regime filter model.                     |
//| Output: CSV files saved to the local MT5 MQL5/Files/ directory.  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "1.00"
#property script_show_inputs

//--- input parameters
input int InpLookbackDays_M1  = 14;  // M1 Lookback (Days, e.g., 2 weeks)
input int InpLookbackDays_M5  = 30;  // M5 Lookback (Days, e.g., 1 month)
input int InpLookbackDays_M15 = 90;  // M15 Lookback (Days, e.g., 3 months)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("🚀 Starting Merkava Macro Miner...");

   string symbol = Symbol();

   // Export M1
   ExportRates(symbol, PERIOD_M1, InpLookbackDays_M1);

   // Export M5
   ExportRates(symbol, PERIOD_M5, InpLookbackDays_M5);

   // Export M15
   ExportRates(symbol, PERIOD_M15, InpLookbackDays_M15);

   Print("✅ Export Complete. Check MQL5/Files directory.");
  }

//+------------------------------------------------------------------+
//| Export specific timeframe data to CSV                            |
//+------------------------------------------------------------------+
void ExportRates(string symbol, ENUM_TIMEFRAMES tf, int days)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   datetime endTime = TimeCurrent();
   datetime startTime = endTime - (days * 24 * 60 * 60);

   int copied = CopyRates(symbol, tf, startTime, endTime, rates);
   if(copied <= 0)
     {
      Print("Error copying rates for TF: ", EnumToString(tf), " Error: ", GetLastError());
      return;
     }

   string filename = "Macro_" + symbol + "_" + EnumToString(tf) + ".csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");

   if(file_handle == INVALID_HANDLE)
     {
      Print("Error opening file: ", filename, " Error: ", GetLastError());
      return;
     }

   // Write Header
   FileWrite(file_handle, "Time", "Open", "High", "Low", "Close", "TickVolume", "RealVolume", "Spread");

   // Write Data (Iterate backwards so oldest is first, or keep descending)
   // For ML chronologic order, we usually want oldest first
   for(int i = copied - 1; i >= 0; i--)
     {
      string timeStr = TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS);

      FileWrite(file_handle,
                timeStr,
                DoubleToString(rates[i].open, _Digits),
                DoubleToString(rates[i].high, _Digits),
                DoubleToString(rates[i].low, _Digits),
                DoubleToString(rates[i].close, _Digits),
                IntegerToString(rates[i].tick_volume),
                DoubleToString(rates[i].real_volume, 0),
                IntegerToString(rates[i].spread)
                );
     }

   FileClose(file_handle);
   Print("Successfully exported ", copied, " bars to ", filename);
  }
//+------------------------------------------------------------------+
