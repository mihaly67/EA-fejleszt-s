//+------------------------------------------------------------------+
//|                                                  TicksVolume_v2.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.1"
#property description "Tick Volume Analysis (Up/Down) using CopyTicksRange."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- plot UpBuffer (Price Pips)
#property indicator_label1 "Pips Up"
#property indicator_type1  DRAW_HISTOGRAM
#property indicator_color1 clrForestGreen
#property indicator_style1 STYLE_SOLID
#property indicator_width1 4

//--- plot UpTick (Count)
#property indicator_label2 "Tick Up"
#property indicator_type2  DRAW_HISTOGRAM
#property indicator_color2 clrLime
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1

//--- plot DnBuffer (Price Pips)
#property indicator_label3 "Pips Down"
#property indicator_type3  DRAW_HISTOGRAM
#property indicator_color3 clrFireBrick
#property indicator_style3 STYLE_SOLID
#property indicator_width3 4

//--- plot DnTick (Count)
#property indicator_label4 "Tick Down"
#property indicator_type4  DRAW_HISTOGRAM
#property indicator_color4 clrTomato
#property indicator_style4 STYLE_SOLID
#property indicator_width4 1

//--- Buffers
double   UpBuffer[];
double   DnBuffer[];
double   UpTick[];
double   DnTick[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, UpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, UpTick, INDICATOR_DATA);
   SetIndexBuffer(2, DnBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DnTick, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "TicksVolume v2.1");
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
   // Performance Optimization: Limit history on first run
   int limit = 1000;
   int start;

   if (prev_calculated == 0) {
       start = (rates_total > limit) ? rates_total - limit : 0;
       // Initialize buffers before start
       ArrayInitialize(UpBuffer, 0);
       ArrayInitialize(DnBuffer, 0);
       ArrayInitialize(UpTick, 0);
       ArrayInitialize(DnTick, 0);
   } else {
       start = prev_calculated - 1;
   }

   MqlTick ticks[];

   for(int i = start; i < rates_total; i++)
   {
       UpBuffer[i] = 0;
       DnBuffer[i] = 0;
       UpTick[i] = 0;
       DnTick[i] = 0;

       long time_from = (long)time[i] * 1000;
       long time_to = (i < rates_total - 1) ? (long)time[i+1] * 1000 : TimeCurrent() * 1000 + 999;

       // Only fetch if meaningful time range
       if (time_to <= time_from) continue;

       int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, time_from, time_to);

       if (copied > 1)
       {
           double prev_bid = ticks[0].bid;
           double price_up = 0;
           double price_dn = 0;
           double tick_up = 0;
           double tick_dn = 0;

           for(int k=1; k<copied; k++)
           {
               if (ticks[k].bid > prev_bid) {
                   price_up += (ticks[k].bid - prev_bid);
                   tick_up++;
               } else if (ticks[k].bid < prev_bid) {
                   price_dn += (prev_bid - ticks[k].bid);
                   tick_dn++;
               }
               prev_bid = ticks[k].bid;
           }

           UpBuffer[i] = price_up / Point();
           DnBuffer[i] = price_dn / Point();
           UpTick[i] = tick_up;
           DnTick[i] = tick_dn;
       }
   }

   return(rates_total);
}
