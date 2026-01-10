//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.4.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.4 (Normalized Color Palette Support - Fixed Scale) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.4"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_minimum -100
#property indicator_maximum 100
#property indicator_levelcolor clrDimGray

//--- Plot 1: WVF Histogram (Color)
#property indicator_label1  "WVF Sentiment"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrForestGreen,clrFireBrick // 0=Fear(Pos), 1=Greed(Neg)
#property indicator_width1  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period
input int                InpNormalizationRange = 480;   // Range to find Max WVF for Scaling (Bars)

//--- Buffers
double      WVFBuffer[];      // Unified Buffer (Positive/Negative)
double      ColorBuffer[];    // Color Index

//--- Internal State
double      RawFear[];
double      RawGreed[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WVFBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.4");

   // Set Levels: 0, +/- 20, +/- 30
   IndicatorSetInteger(INDICATOR_LEVELS, 5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 20.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 30.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -20.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, -30.0);

   // Set All Level Colors to DimGray
   for(int i=0; i<5; i++) {
       IndicatorSetInteger(INDICATOR_LEVELCOLOR, i, clrDimGray);
   }

   return INIT_SUCCEEDED;
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
   if(rates_total < InpPeriod) return 0;

   if(ArraySize(RawFear) < rates_total) {
       ArrayResize(RawFear, rates_total);
       ArrayResize(RawGreed, rates_total);
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // 1. Calculate RAW
   for(int i = start; i < rates_total; i++)
   {
       double max_close = -DBL_MAX;
       double min_close = DBL_MAX;

       int search_start = MathMax(0, i - InpPeriod + 1);

       for(int j = search_start; j <= i; j++)
       {
           if(close[j] > max_close) max_close = close[j];
           if(close[j] < min_close) min_close = close[j];
       }

       double panic_val = 0.0;
       if(max_close > 0) panic_val = (max_close - low[i]) / max_close * 100.0;

       double greed_val = 0.0;
       if(min_close > 0) greed_val = (high[i] - min_close) / min_close * 100.0;

       RawFear[i] = panic_val;
       RawGreed[i] = greed_val;
   }

   // 2. Normalize & Plot
   for(int i = start; i < rates_total; i++)
   {
       double local_max_fear = 0.0001;
       double local_max_greed = 0.0001;

       int norm_start = MathMax(0, i - InpNormalizationRange + 1);

       for(int k = norm_start; k <= i; k++) {
           if(RawFear[k] > local_max_fear) local_max_fear = RawFear[k];
           if(RawGreed[k] > local_max_greed) local_max_greed = RawGreed[k];
       }

       double norm_fear = (RawFear[i] / local_max_fear) * 100.0;
       double norm_greed = (RawGreed[i] / local_max_greed) * 100.0;

       if(norm_fear > 100.0) norm_fear = 100.0;
       if(norm_greed > 100.0) norm_greed = 100.0;

       // Dominance Logic
       if (norm_fear > norm_greed) {
           WVFBuffer[i] = norm_fear;       // Positive (Fear)
           ColorBuffer[i] = 0.0;           // Green
       } else {
           WVFBuffer[i] = -norm_greed;     // Negative (Greed)
           ColorBuffer[i] = 1.0;           // Red
       }
   }

   return rates_total;
}
