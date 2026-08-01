//+------------------------------------------------------------------+
//|                            Merkava_Master_Data_Miner_v5.mq5      |
//|                                                                  |
//| Purpose: Extracts pure M1 OHLCV combined with the CZigZagEngine  |
//|          from HybridContextIndicator_v3.28. Exports real-time    |
//|          Micro, Secondary, and Tertiary Pivot Support/Resistances|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "5.00"
#property script_show_inputs

input int InpLookbackDays = 90;  // Data history length in days (3 Months)

//+------------------------------------------------------------------+
//| ZigZag Engine Class (From HybridContextIndicator_v3.28)          |
//+------------------------------------------------------------------+
class CZigZagEngine
{
private:
   int               m_depth;
   int               m_deviation;
   int               m_backstep;

public:
                     CZigZagEngine() : m_depth(12), m_deviation(5), m_backstep(3) {}
   void              Init(int depth, int deviation, int backstep) { m_depth=depth; m_deviation=deviation; m_backstep=backstep; }

   int               Highest(const double &array[],const int depth,const int start)
   {
      if(start<0) return(0);
      double max=array[start];
      int    index=start;
      for(int i=start-1; i>start-depth && i>=0; i--)
      {
         if(array[i]>max) { index=i; max=array[i]; }
      }
      return(index);
   }

   int               Lowest(const double &array[],const int depth,const int start)
   {
      if(start<0) return(0);
      double min=array[start];
      int    index=start;
      for(int i=start-1; i>start-depth && i>=0; i--)
      {
         if(array[i]<min) { index=i; min=array[i]; }
      }
      return(index);
   }

   void              CalculateFull(const int rates_total, const double &high[], const double &low[], double &HighMapBuffer[], double &LowMapBuffer[])
   {
       ArrayInitialize(HighMapBuffer, 0.0);
       ArrayInitialize(LowMapBuffer, 0.0);

       double ZigZagBuffer[];
       ArrayResize(ZigZagBuffer, rates_total);
       ArrayInitialize(ZigZagBuffer, 0.0);

       int start = m_depth;
       int shift=0, back=0, last_high_pos=0, last_low_pos=0;
       double val=0, res=0;
       double last_high=0, last_low=0;
       int extreme_search = 0;

       for(shift=start; shift<rates_total && !IsStopped(); shift++) {
           // Low
           val = low[Lowest(low, m_depth, shift)];
           if(val == last_low) val = 0.0;
           else {
               last_low = val;
               if((low[shift] - val) > m_deviation * _Point) val = 0.0;
               else {
                   for(back=1; back<=m_backstep; back++) {
                       if(shift-back < 0) continue;
                       res = LowMapBuffer[shift-back];
                       if((res!=0) && (res>val)) LowMapBuffer[shift-back] = 0.0;
                   }
               }
           }
           if(low[shift] == val) LowMapBuffer[shift] = val; else LowMapBuffer[shift] = 0.0;

           // High
           val = high[Highest(high, m_depth, shift)];
           if(val == last_high) val = 0.0;
           else {
               last_high = val;
               if((val - high[shift]) > m_deviation * _Point) val = 0.0;
               else {
                   for(back=1; back<=m_backstep; back++) {
                       if(shift-back < 0) continue;
                       res = HighMapBuffer[shift-back];
                       if((res!=0) && (res<val)) HighMapBuffer[shift-back] = 0.0;
                   }
               }
           }
           if(high[shift] == val) HighMapBuffer[shift] = val; else HighMapBuffer[shift] = 0.0;
       }

       // Peak/Bottom resolution
       last_high = 0; last_low = 0; last_high_pos = 0; last_low_pos = 0;
       for(shift=start; shift<rates_total && !IsStopped(); shift++) {
           res = 0.0;
           switch(extreme_search) {
               case 0:
                   if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0) {
                       last_high=high[shift]; last_high_pos=shift; extreme_search=-1; ZigZagBuffer[shift]=last_high; res=1;
                   }
                   if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0) {
                       last_low=low[shift]; last_low_pos=shift; extreme_search=1; ZigZagBuffer[shift]=last_low; res=1;
                   }
                   if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]!=0.0) {
                       if(HighMapBuffer[shift]==last_high) {
                           last_low=low[shift]; last_low_pos=shift; extreme_search=1; ZigZagBuffer[shift]=last_low; res=1;
                       }
                       if(LowMapBuffer[shift]==last_low) {
                           last_high=high[shift]; last_high_pos=shift; extreme_search=-1; ZigZagBuffer[shift]=last_high; res=1;
                       }
                   }
                   break;
               case 1: // Peak search
                   if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low && HighMapBuffer[shift]==0.0) {
                       ZigZagBuffer[last_low_pos]=0.0; last_low_pos=shift; last_low=LowMapBuffer[shift]; ZigZagBuffer[shift]=last_low; res=1;
                   }
                   if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0) {
                       last_high=HighMapBuffer[shift]; last_high_pos=shift; ZigZagBuffer[shift]=last_high; extreme_search=-1; res=1;
                   }
                   break;
               case -1: // Bottom search
                   if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>last_high && LowMapBuffer[shift]==0.0) {
                       ZigZagBuffer[last_high_pos]=0.0; last_high_pos=shift; last_high=HighMapBuffer[shift]; ZigZagBuffer[shift]=last_high;
                   }
                   if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0) {
                       last_low=LowMapBuffer[shift]; last_low_pos=shift; ZigZagBuffer[shift]=last_low; extreme_search=1;
                   }
                   break;
           }
       }
   }
};

CZigZagEngine microZigZag;
CZigZagEngine secZigZag;
CZigZagEngine terZigZag;

void OnStart()
  {
   Print("🚀 Starting Merkava Master M1 Data Miner V5 (ZigZag Pivots)...");
   string symbol = Symbol();

   // Configure ZigZag Layers
   microZigZag.Init(12, 5, 3);
   secZigZag.Init(48, 15, 6);
   terZigZag.Init(200, 30, 12);

   // 1. Prepare Data Arrays
   MqlRates rates[];
   ArraySetAsSeries(rates, false); // Important: ZigZag calculation is easier front-to-back

   datetime endTime = TimeCurrent();
   datetime startTime = endTime - (InpLookbackDays * 24 * 60 * 60);

   int copied = CopyRates(symbol, PERIOD_M1, startTime, endTime, rates);
   if(copied <= 100)
     {
      Print("❌ Error copying M1 rates.");
      return;
     }

   double high[], low[];
   ArrayResize(high, copied);
   ArrayResize(low, copied);

   for(int i=0; i<copied; i++) {
       high[i] = rates[i].high;
       low[i] = rates[i].low;
   }

   // 2. Calculate ZigZag Peaks (Highs/Lows)
   Print("⏳ Calculating ZigZag Structures...");
   double microHigh[], microLow[];
   double secHigh[], secLow[];
   double terHigh[], terLow[];

   ArrayResize(microHigh, copied); ArrayResize(microLow, copied);
   ArrayResize(secHigh, copied); ArrayResize(secLow, copied);
   ArrayResize(terHigh, copied); ArrayResize(terLow, copied);

   microZigZag.CalculateFull(copied, high, low, microHigh, microLow);
   secZigZag.CalculateFull(copied, high, low, secHigh, secLow);
   terZigZag.CalculateFull(copied, high, low, terHigh, terLow);

   // 3. Open File
   string filename = "Master_ZigZag_" + symbol + "_M1.csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE) return;

   FileWrite(file_handle, "Time", "Open", "High", "Low", "Close", "TickVolume", "RealVolume",
             "Micro_R", "Micro_S", "Sec_R", "Sec_S", "Ter_R", "Ter_S");

   // 4. Iterate and Extend Pivots Forward
   Print("⏳ Extending Pivot Lines to current prices...");

   double active_micro_r = rates[0].high, active_micro_s = rates[0].low;
   double active_sec_r = rates[0].high, active_sec_s = rates[0].low;
   double active_ter_r = rates[0].high, active_ter_s = rates[0].low;

   for(int i = 0; i < copied; i++)
     {
      // Update active pivots if a new one is found at this bar
      if(microHigh[i] > 0) active_micro_r = microHigh[i];
      if(microLow[i] > 0)  active_micro_s = microLow[i];

      if(secHigh[i] > 0) active_sec_r = secHigh[i];
      if(secLow[i] > 0)  active_sec_s = secLow[i];

      if(terHigh[i] > 0) active_ter_r = terHigh[i];
      if(terLow[i] > 0)  active_ter_s = terLow[i];

      // Breakouts: if price closes above resistance, that resistance breaks (becomes dynamic support or just follows price)
      // To keep it simple, we just export the active levels. The Python model will measure distance to them.

      FileWrite(file_handle,
                TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS),
                DoubleToString(rates[i].open, _Digits),
                DoubleToString(rates[i].high, _Digits),
                DoubleToString(rates[i].low, _Digits),
                DoubleToString(rates[i].close, _Digits),
                IntegerToString(rates[i].tick_volume),
                DoubleToString(rates[i].real_volume, 0),
                DoubleToString(active_micro_r, _Digits),
                DoubleToString(active_micro_s, _Digits),
                DoubleToString(active_sec_r, _Digits),
                DoubleToString(active_sec_s, _Digits),
                DoubleToString(active_ter_r, _Digits),
                DoubleToString(active_ter_s, _Digits)
                );
     }

   FileClose(file_handle);
   Print("✅ Master ZigZag Export Complete. Saved to MQL5/Files/", filename);
  }
