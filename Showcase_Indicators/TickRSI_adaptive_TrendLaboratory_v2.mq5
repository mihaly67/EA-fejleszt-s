//+------------------------------------------------------------------+
//|                             TickRSI_adaptive_TrendLaboratory_v2.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2008, TrendLaboratory (Refactored 2024)"
#property link      "http://finance.groups.yahoo.com/group/TrendLaboratory"
#property version   "2.1"
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
double CalcBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ARSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, FastMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SlowMABuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CalcBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "TickAdaptiveRSI v2.1");

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
   // Performance Limit: Max 1000 bars history on init
   int limit = 1000;
   int start;

   if (prev_calculated == 0) {
       start = (rates_total > limit) ? rates_total - limit : 0;
       ArrayInitialize(ARSIBuffer, 50.0);
       ArrayInitialize(FastMABuffer, 50.0);
       ArrayInitialize(SlowMABuffer, 50.0);
   } else {
       start = prev_calculated - 1;
   }

   MqlTick ticks[];
   int required_ticks = ARSIPeriod + SlowMA + 50;

   for(int i = start; i < rates_total; i++)
   {
       long time_to_msc = (i < rates_total - 1) ? (long)time[i+1] * 1000 : TimeCurrent() * 1000 + 999;

       int copied = CopyTicks(_Symbol, ticks, COPY_TICKS_INFO, time_to_msc, required_ticks);

       if (copied >= required_ticks)
       {
           double prices[];
           ArrayResize(prices, copied);
           for(int k=0; k<copied; k++) prices[k] = ticks[k].bid;

           double current_rsi = CalculateRSI(prices, ARSIPeriod);
           ARSIBuffer[i] = current_rsi;

           // Fast MA (SMA of ARSIBuffer)
           if (i >= FastMA) {
               double sum=0;
               for(int k=0; k<FastMA; k++) sum += ARSIBuffer[i-k];
               FastMABuffer[i] = sum/FastMA;
           } else FastMABuffer[i] = current_rsi;

           // Slow MA
           if (i >= SlowMA) {
               double sum=0;
               for(int k=0; k<SlowMA; k++) sum += ARSIBuffer[i-k];
               SlowMABuffer[i] = sum/SlowMA;
           } else SlowMABuffer[i] = current_rsi;
       }
       else
       {
           // Not enough ticks, maintain previous or neutral
           ARSIBuffer[i] = (i>0) ? ARSIBuffer[i-1] : 50.0;
           FastMABuffer[i] = ARSIBuffer[i];
           SlowMABuffer[i] = ARSIBuffer[i];
       }
   }

   return(rates_total);
}
