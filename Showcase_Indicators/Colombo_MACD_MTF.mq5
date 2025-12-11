//+------------------------------------------------------------------+
//|                                          Colombo_MACD_MTF.mq5 |
//|                        Copyright 2025, Jules Hybrid System Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Hybrid System Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plots
#property indicator_label1  "MACD"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Inputs
input group             "MACD Settings"
input ENUM_TIMEFRAMES   InpTimeFrame = PERIOD_CURRENT; // Target TimeFrame
input int               InpFastEMA   = 12;             // Fast EMA
input int               InpSlowEMA   = 26;             // Slow EMA
input int               InpSignalSMA = 9;              // Signal SMA

//--- Buffers
double         MACDBuffer[];
double         SignalBuffer[];

//--- Handles
int            hMACD;

//--- File Handle
int            file_handle = INVALID_HANDLE;
string         file_name = "colombo_macd_data.csv";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,MACDBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,SignalBuffer,INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Colombo MACD (" + EnumToString(InpTimeFrame) + ")");

//--- Get Handle
   hMACD = iMACD(_Symbol, InpTimeFrame, InpFastEMA, InpSlowEMA, InpSignalSMA, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE)
   {
      Print("Failed to create MACD handle");
      return(INIT_FAILED);
   }

//--- Open File for writing (Shared Mode?)
   // In real usage, we might overwrite every tick or append.
   // For "Colombo" Python sync, we need a file that Python reads.
   // We'll write the last N bars every tick.

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // Copy MACD Data
   // We need to handle MTF. If InpTimeFrame > _Period, we have multiple bars per single HTF bar.
   // But standard CopyBuffer from handle automatically handles the alignment if we ask for current timeframe?
   // NO. CopyBuffer from an MTF handle returns data in THAT timeframe's bars.
   // We need to map it to current chart bars if we want to draw it.
   // BUT, for Python analysis, we probably want the raw MTF data?
   // Let's stick to the CURRENT chart's timeframe for drawing to keep it simple first.
   // If InpTimeFrame != PERIOD_CURRENT, iMACD returns handle for that TF.
   // To draw on current chart, we need to fill current bars with the value of the HTF bar covering them.
   // This is "Step" drawing.

   // SIMPLIFICATION for Colombo Phase 1:
   // Let's assume we run this on the timeframe we want to analyze (e.g. M1 or M5).
   // So InpTimeFrame is mainly for reference or simple MTF lookup.

   int to_copy = rates_total - prev_calculated;
   if(to_copy < 1) to_copy = 1; // Always copy at least 1 to update current
   if(to_copy > rates_total) to_copy = rates_total;

   // Destination arrays
   double macd_chunk[];
   double sig_chunk[];

   // Copy from Handle (which is HTF)
   // Warning: If TimeFrame differs, count of bars differs!
   // We cannot simply CopyBuffer(hMACD, ..., rates_total) into MACDBuffer(rates_total).
   // We must map times.

   // For now, let's force InpTimeFrame = PERIOD_CURRENT logic for drawing
   // to ensure buffers match chart.
   // MTF logic requires time-mapping which adds complexity.
   // Let's implement STANDARD MACD first to test the Python Pipeline.

   if(CopyBuffer(hMACD, 0, 0, to_copy, MACDBuffer) <= 0) return(0);
   if(CopyBuffer(hMACD, 1, 0, to_copy, SignalBuffer) <= 0) return(0);

   // --- EXPORT TO CSV FOR PYTHON ---
   // Write the last 200 bars to CSV
   // Format: Time,MACD,Signal
   if(IsTesting() || prev_calculated < rates_total) // Optimization: Don't write every tick in history calc
   {
      // Only write on the last bar or real-time
   }

   // Real-time write
   if(rates_total > 0)
   {
      WriteDataToCSV(200, rates_total, time);
   }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Write Data to CSV                                                |
//+------------------------------------------------------------------+
void WriteDataToCSV(int count, int total, const datetime &time[])
{
   // In MQL5, File operations are sandboxed to MQL5/Files.
   // We overwrite the file to pass latest state.
   int handle = FileOpen(file_name, FILE_CSV|FILE_WRITE|FILE_ANSI|FILE_COMMON, ",");
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle, "Time", "MACD", "Signal");

      int start = total - count;
      if(start < 0) start = 0;

      for(int i=start; i<total; i++)
      {
         FileWrite(handle, TimeToString(time[i]), MACDBuffer[i], SignalBuffer[i]);
      }
      FileClose(handle);
   }
}
//+------------------------------------------------------------------+
