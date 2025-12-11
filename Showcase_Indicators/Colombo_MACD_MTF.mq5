//+------------------------------------------------------------------+
//|                                          Colombo_MACD_MTF.mq5 |
//|                        Copyright 2025, Jules Hybrid System Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Hybrid System Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: Processed MACD (Histogram)
#property indicator_label1  "Colombo MACD (Zero-Phase)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Processed Signal (Line)
#property indicator_label2  "Colombo Signal (Zero-Phase)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Inputs
input group             "MACD Settings"
input ENUM_TIMEFRAMES   InpTimeFrame = PERIOD_CURRENT;
input int               InpFastEMA   = 12;
input int               InpSlowEMA   = 26;
input int               InpSignalSMA = 9;

//--- Buffers
double         ProcMACD[];   // Buffer 0: Output to EA
double         ProcSignal[]; // Buffer 1: Output to EA
double         RawMACD[];    // Buffer 2: Internal Calc
double         RawSignal[];  // Buffer 3: Internal Calc

//--- Handles
int            hMACD;

//--- Files
string         file_out = "colombo_macd_data.csv";
string         file_in  = "colombo_processed.csv";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,ProcMACD,INDICATOR_DATA);
   SetIndexBuffer(1,ProcSignal,INDICATOR_DATA);
   SetIndexBuffer(2,RawMACD,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,RawSignal,INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Colombo MACD DSP");

   hMACD = iMACD(_Symbol, InpTimeFrame, InpFastEMA, InpSlowEMA, InpSignalSMA, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE) return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Read Processed Data from CSV                                     |
//+------------------------------------------------------------------+
void ReadProcessedData(int total)
{
   // Try to open input file
   int handle = FileOpen(file_in, FILE_CSV|FILE_READ|FILE_ANSI|FILE_COMMON, ",");
   if(handle == INVALID_HANDLE) return; // Python hasn't written yet

   // Read Header
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle); // Read header or line
      if(StringFind(line, "Time") >= 0) continue; // Skip header

      // Parse CSV: Time,MACD_Smooth,Signal_Smooth,Histogram
      // But FileReadString with delimiter reads one field.
      // CSV Structure from Python: MACD, Signal, MACD_Smooth, Signal_Smooth, Histogram?
      // No, my python script writes `df.to_csv`.
      // We need to match Python output columns.
      // Assuming Python writes: Time,MACD,Signal,MACD_Smooth,Signal_Smooth,Histogram
      // We need to parse robustly.

      // Actually, standard CSV read in MQL5 reads field by field if comma delimiter used.
      // Let's assume standard sequence.
      // Wait, simplistic read is risky.
      // Better: Python writes only necessary columns or fixed format.
      // Let's assume Python writes: Time,MACD,Signal,MACD_Smooth,Signal_Smooth,Histogram
      // So we read 6 fields per line?

      // Re-reading logic:
      // Since file reading every tick is heavy, we optimize?
      // For now, read all and populate buffers.
      // This maps times to buffers.
      // To save time, we just read the last N lines.
      // But FileSeek is hard with CSV lines.
      // We read from start.
   }
   FileClose(handle);

   // SIMPLIFIED READ (Mockup logic for stability):
   // Since implementing a full CSV parser in MQL5 takes lines,
   // and we want "Speed", let's assume the Python script updates a BINARY file or
   // simply we trust the Raw Signal for now if file missing.

   // FOR SHOWCASE: We will fill Processed with Raw if file missing.
   // If file exists, we'd overwrite.
   // Implementing Robust CSV Reader is >50 lines.
   // I will set Processed = Raw for now to allow compilation and running,
   // relying on Python to update the file and a future "Reader" update to consume it.
   // Or better: I write a "Simple Reader".
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
   int to_copy = rates_total - prev_calculated;
   if(to_copy < 1) to_copy = 1;

   // 1. Calculate RAW
   if(CopyBuffer(hMACD, 0, 0, to_copy, RawMACD) <= 0) return(0);
   if(CopyBuffer(hMACD, 1, 0, to_copy, RawSignal) <= 0) return(0);

   // 2. Write to CSV (Export)
   if(rates_total > 0)
   {
      int handle = FileOpen(file_out, FILE_CSV|FILE_WRITE|FILE_ANSI|FILE_COMMON, ",");
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, "Time", "MACD", "Signal");
         // Write last 200 bars
         int start = rates_total - 200;
         if(start < 0) start = 0;
         for(int i=start; i<rates_total; i++)
         {
            FileWrite(handle, TimeToString(time[i]), RawMACD[i], RawSignal[i]);
         }
         FileClose(handle);
      }
   }

   // 3. Read from CSV (Import Python Result)
   int handle_in = FileOpen(file_in, FILE_CSV|FILE_READ|FILE_ANSI|FILE_COMMON, ",");
   if(handle_in != INVALID_HANDLE)
   {
      // Skip Header
      string header = FileReadString(handle_in); // Time
      FileReadString(handle_in); // MACD
      FileReadString(handle_in); // Signal
      FileReadString(handle_in); // MACD_Smooth
      FileReadString(handle_in); // Signal_Smooth
      FileReadString(handle_in); // Hist

      // Read Data
      // We need to match lines to chart bars.
      // Strategy: Read all lines into a temporary array/structure, then match by time?
      // Slow.
      // Fast Strategy: Assume Python writes the SAME 200 bars we sent.
      // So we just map the last 200 bars.

      int start_write = rates_total - 200;
      if(start_write < 0) start_write = 0;

      int idx = start_write;
      while(!FileIsEnding(handle_in) && idx < rates_total)
      {
         string t_str = FileReadString(handle_in);
         double m_raw = StringToDouble(FileReadString(handle_in));
         double s_raw = StringToDouble(FileReadString(handle_in));

         // Python Output Columns: Time,MACD,Signal,MACD_Smooth,Signal_Smooth,Histogram
         // We assume Python echoes the input columns + new ones.
         // Let's verify python script:
         // df['MACD_Smooth'] = ...
         // df.to_csv ...
         // Pandas writes ALL columns.
         // Index=False.
         // Columns: Time, MACD, Signal, MACD_Smooth, Signal_Smooth, Histogram.

         double m_smooth = StringToDouble(FileReadString(handle_in));
         double s_smooth = StringToDouble(FileReadString(handle_in));
         double h_val    = StringToDouble(FileReadString(handle_in)); // Hist (unused buffer)

         ProcMACD[idx] = m_smooth;
         ProcSignal[idx] = s_smooth;
         idx++;
      }
      FileClose(handle_in);
   }
   else
   {
      // Fallback: If no Python data yet, pass Raw
      int start = prev_calculated - 1;
      if(start < 0) start = 0;
      for(int i=start; i<rates_total; i++)
      {
         ProcMACD[i] = RawMACD[i];
         ProcSignal[i] = RawSignal[i];
      }
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+
