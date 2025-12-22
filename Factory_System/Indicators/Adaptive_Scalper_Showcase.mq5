//+------------------------------------------------------------------+
//|                                   Adaptive_Scalper_Showcase.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- plot ScalperLine
#property indicator_label1  "ScalperLine"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot CycleSignal
#property indicator_label2  "CycleSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrMagenta
#property indicator_width2  2

//--- Input parameters
input int      InpPeriod      = 10;       // Adaptive Period
input double   InpSensitivity = 1.0;      // Sensitivity (Step Size)

//--- Indicator buffers
double         ScalperBuffer[];
double         SignalBuffer[];
double         AMA_Buffer[]; // Adaptive MA Buffer
double         StdDev_Buffer[];

//--- Global Handles
int            hAMA;
int            hStdDev;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,ScalperBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,SignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,AMA_Buffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,StdDev_Buffer,INDICATOR_CALCULATIONS);

   ArraySetAsSeries(ScalperBuffer, true);
   ArraySetAsSeries(SignalBuffer, true);
   ArraySetAsSeries(AMA_Buffer, true);
   ArraySetAsSeries(StdDev_Buffer, true);

   PlotIndexSetInteger(1,PLOT_ARROW,233);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);

   IndicatorSetString(INDICATOR_SHORTNAME,"Adaptive Scalper ("+string(InpPeriod)+")");

   // Using AMA (Kaufman) as base for adaptive logic
   hAMA = iAMA(_Symbol, _Period, 9, 2, 30, 0, PRICE_CLOSE);
   hStdDev = iStdDev(_Symbol, _Period, InpPeriod, 0, MODE_EMA, PRICE_CLOSE);

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
   if(rates_total < InpPeriod) return(0);

   int to_copy = (prev_calculated > 0) ? rates_total - prev_calculated + 1 : rates_total;

   if(CopyBuffer(hAMA, 0, 0, to_copy, AMA_Buffer) <= 0) return(0);
   if(CopyBuffer(hStdDev, 0, 0, to_copy, StdDev_Buffer) <= 0) return(0);

   int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total - 1;

   for(int i = limit; i >= 0; i--)
     {
      // Adaptive Logic:
      // Create a "Step" line that only moves when price deviates significantly (measured by StdDev)
      // from the Adaptive MA.

      double ama = AMA_Buffer[i];
      double dev = StdDev_Buffer[i] * InpSensitivity;

      // Initialize
      if(i == rates_total - 1) {
         ScalperBuffer[i] = ama;
         continue;
      }

      double prev = ScalperBuffer[i+1];

      // Step Logic
      if(ama > prev + dev)
         ScalperBuffer[i] = ama; // Step Up
      else if(ama < prev - dev)
         ScalperBuffer[i] = ama; // Step Down
      else
         ScalperBuffer[i] = prev; // Flat

      // Signal: Change of Step Level
      SignalBuffer[i] = 0.0;
      if(ScalperBuffer[i] != prev)
      {
         SignalBuffer[i] = ScalperBuffer[i]; // Arrow on change
      }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
