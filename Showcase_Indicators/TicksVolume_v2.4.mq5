//+------------------------------------------------------------------+
//|                                           TicksVolume_v2.4.mq5   |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "2.4"
#property description "Ticks Volume Indicator (Bidirectional)"
#property description "Visualizes Pips and Tick Counts per bar (Up/Down) using tick data."
#property description "Includes Scaler for Tick visibility and History Limit."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- plot UpBuffer (Pips Up)
#property indicator_label1  "Pips Up"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrForestGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  6

//--- plot UpTick (Tick Up)
#property indicator_label2  "Tick Up"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- plot DnBuffer (Pips Down)
#property indicator_label3  "Pips Down"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrFireBrick
#property indicator_style3  STYLE_SOLID
#property indicator_width3  6

//--- plot DnTick (Tick Down)
#property indicator_label4  "Tick Down"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrDimGray
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- plot level line
#property indicator_level1      0
#property indicator_levelcolor  clrWhite
#property indicator_levelstyle  STYLE_DOT

//--- Inputs
input int    InpMaxHistoryBars  = 500; // Max History Bars (0 = All)
input double InpOutlierMultiplier = 0.0; // Smart Clipping Multiplier (0 = Disabled)
input double InpTickScale       = 5.0; // Tick Bar Scaling Factor (Visibility Boost)

//--- Indicator buffers
double    UpBuffer[];
double    DnBuffer[];
double    UpTick[];
double    DnTick[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, UpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, UpTick,   INDICATOR_DATA);
   SetIndexBuffer(2, DnBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DnTick,   INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "TicksVolume v2.4");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

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
   //--- Array Setup
   ArraySetAsSeries(UpBuffer, true);
   ArraySetAsSeries(DnBuffer, true);
   ArraySetAsSeries(UpTick,   true);
   ArraySetAsSeries(DnTick,   true);
   ArraySetAsSeries(time,     true);

   //--- Determine Calculation Range
   int limit = rates_total - prev_calculated;

   // Recalculate last bar to ensure tick updates are captured
   if(prev_calculated > 0) limit++;

   // Apply History Limit
   if (InpMaxHistoryBars > 0 && limit > InpMaxHistoryBars)
      limit = InpMaxHistoryBars;

   // Bounds Check
   if (limit >= rates_total) limit = rates_total - 1;

   //--- 1. Calculate Raw Values
   for(int i = limit; i >= 0; i--)
     {
      // Determine Time Range for CopyTicks
      datetime start_time = time[i];
      // For the newest bar (i=0), we want ticks up to now.
      // For historical bars (i>0), we want ticks up to the next bar's start.
      // CopyTicksRange 'to' is exclusive usually, but let's use 0 for "now" or next bar time.
      long t_start = (long)start_time * 1000;
      long t_end   = (i == 0) ? 0 : (long)time[i - 1] * 1000;

      MqlTick ticks[];
      int received = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, t_start, t_end);

      double p_up = 0;
      double p_dn = 0;
      double t_up = 0;
      double t_dn = 0;

      if(received > 1)
        {
         double prev_bid = ticks[0].bid;
         double prev_ask = ticks[0].ask;

         for(int k = 1; k < received; k++)
           {
            double bid = ticks[k].bid;
            double ask = ticks[k].ask;

            // Logic: Up Move
            if(bid > prev_bid || (bid == prev_bid && ask > prev_ask))
              {
               p_up += (bid - prev_bid);
               t_up += 1.0;
              }
            // Logic: Down Move
            else if(bid < prev_bid || (bid == prev_bid && ask < prev_ask))
              {
               p_dn += (prev_bid - bid);
               t_dn += 1.0;
              }

            prev_bid = bid;
            prev_ask = ask;
           }
        }

      // Store Raw Values (Pips are /_Point)
      // IMPORTANT: Down values are NEGATIVE for display below zero
      // Apply Scaling to Tick Counts
      UpBuffer[i] = p_up / _Point;
      DnBuffer[i] = -1.0 * (p_dn / _Point);
      UpTick[i]   = t_up * InpTickScale;
      DnTick[i]   = -1.0 * t_dn * InpTickScale;
     }

   //--- 2. Apply Outlier Clipping (Post-Process)
   // We use MathAbs to handle the negative values correctly
   if(InpOutlierMultiplier > 0.0) // Only if enabled
   {
      double sum_pips = 0;
      int count = 0;

      int scan_start = 0;
      int scan_end = MathMin(rates_total-1, InpMaxHistoryBars);

      for(int k=scan_start; k<scan_end; k++) {
         double activity = MathAbs(UpBuffer[k]) + MathAbs(DnBuffer[k]); // Total Pips Vol (Abs)
         if(activity > 0) {
            sum_pips += activity;
            count++;
         }
      }

      if(count > 0) {
         double avg_pips = sum_pips / count;
         double limit_pips = avg_pips * InpOutlierMultiplier;

         // Apply Clipping to display buffers (Checking Abs values)
         for(int i = limit; i >= 0; i--) {
            // Clip Up
            if(UpBuffer[i] > limit_pips) UpBuffer[i] = limit_pips;

            // Clip Down (Negative values, so check if LESS than negative limit)
            if(DnBuffer[i] < -limit_pips) DnBuffer[i] = -limit_pips;
         }
      }
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+
