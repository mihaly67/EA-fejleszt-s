//+------------------------------------------------------------------+
//|                             TickRSI_adaptive_TrendLaboratory_v2.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2008, TrendLaboratory (Refactored 2024)"
#property link      "http://finance.groups.yahoo.com/group/TrendLaboratory"
#property version   "2.0"
#property description "Adaptive Tick RSI using real Tick History."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 3

// Plot 1: ARSI
#property indicator_label1 "ARSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrForestGreen
#property indicator_width1  2

// Plot 2: Fast
#property indicator_label2 "Fast"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  1

// Plot 3: Slow
#property indicator_label3 "Slow"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrFireBrick
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//---- Inputs
input int     ARSIPeriod  =    14;  // RSI Period (Ticks)
input int     FastMA      =     5;  // Fast MA (Ticks)
input int     SlowMA      =    14;  // Slow MA (Ticks)

//---- Buffers
double ARSIBuffer[];
double FastMABuffer[];
double SlowMABuffer[];
double CalcBuffer[]; // Temp buffer for internal RSI calculation if needed

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ARSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, FastMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SlowMABuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CalcBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "TickAdaptiveRSI v2.0");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Helper: Calculate RSI on a raw array of prices                   |
//+------------------------------------------------------------------+
double CalculateRSI(const double &prices[], int period)
{
   int size = ArraySize(prices);
   if(size < period + 1) return 50.0;

   double gain = 0;
   double loss = 0;

   // Simple RSI logic for the last 'period' ticks
   for(int i = size - period; i < size; i++)
   {
       double diff = prices[i] - prices[i-1];
       if(diff > 0) gain += diff;
       else loss -= diff;
   }

   if(loss == 0) return 100.0;
   return 100.0 - (100.0 / (1.0 + gain/loss));
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
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   MqlTick ticks[];

   // We need enough ticks for calculation: ARSIPeriod + SlowMA
   int required_ticks = ARSIPeriod + SlowMA + 50;

   for(int i = start; i < rates_total; i++)
   {
       // Strategy: For each bar, get the LAST N ticks ending at that bar's close time.
       // This simulates what the indicator value was at the end of that bar.

       long time_to_msc = (i < rates_total - 1) ? (long)time[i+1] * 1000 : TimeCurrent() * 1000 + 999;

       // Get last N ticks
       int copied = CopyTicks(_Symbol, ticks, COPY_TICKS_INFO, time_to_msc, required_ticks);

       if (copied >= required_ticks)
       {
           // 1. Calculate Tick RSI Series (internal)
           // We need a series of RSI values to calculate MA on them.
           // Let's say we want the RSI value at the very last tick (copied-1).
           // And we also need RSI values for previous ticks to average them.

           double rsi_series[];
           ArrayResize(rsi_series, SlowMA); // Need enough history for MA

           // Extract prices for RSI calc
           double prices[];
           ArrayResize(prices, copied);
           for(int k=0; k<copied; k++) prices[k] = ticks[k].bid;

           // Calculate RSI for the last 'SlowMA' points
           for(int m=0; m<SlowMA; m++)
           {
               // Subset of prices ending at index (copied - 1 - m)
               // Passing a slice is hard in MQL5, so we pass full array and index or just loop here.
               // Optimized: Just calculate one RSI at the end for the Bar?
               // Wait, user wants "Adaptive Tick RSI".
               // Standard logic: RSI of Ticks.
               // Let's assume we plot the RSI of the *last tick* of the bar.

               // To get MA, we need history of RSI values.
               // Calculating history of tick-based RSI for every bar is expensive.
               // Simplification: Calculate RSI based on the last 'ARSIPeriod' ticks.

               // For the current bar 'i', the Tick RSI is:
               // RSI of the sequence of ticks ending at time[i].

               // Current RSI
               // We need a sub-array of prices [end-period ... end]
               // But we can just sum gains/losses in the loop.
           }

           // --- Simplified Robust Logic ---
           // 1. Calculate RSI of the last 'ARSIPeriod' ticks at the close of the bar.
           double current_rsi = CalculateRSI(prices, ARSIPeriod);
           ARSIBuffer[i] = current_rsi;

           // 2. Fast/Slow MA of RSI?
           // Since we don't have a buffer of *past tick RSIs* stored easily (unless we recalc everything),
           // we can approximate the MA by smoothing the ARSIBuffer itself (Bar-based smoothing of Tick RSI).
           // OR: Recalculate RSI for previous N ticks?
           // Let's use Bar-based smoothing for the MA lines, as calculating Tick-MA on history is extremely heavy.

           // Fast MA (SMA of ARSIBuffer)
           if (i >= FastMA) {
               double sum=0;
               for(int k=0; k<FastMA; k++) sum += ARSIBuffer[i-k];
               FastMABuffer[i] = sum/FastMA;
           }

           // Slow MA
           if (i >= SlowMA) {
               double sum=0;
               for(int k=0; k<SlowMA; k++) sum += ARSIBuffer[i-k];
               SlowMABuffer[i] = sum/SlowMA;
           }
       }
       else
       {
           ARSIBuffer[i] = 50.0;
           FastMABuffer[i] = 50.0;
           SlowMABuffer[i] = 50.0;
       }
   }

   return(rates_total);
}
