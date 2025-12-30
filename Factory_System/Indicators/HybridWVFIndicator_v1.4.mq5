//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.4.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.4 (Native Color Palette Support)                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.4"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1

//--- Plot 1: WVF Histogram (Color)
#property indicator_label1  "WVF Sentiment"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrForestGreen,clrFireBrick // 0=Euphoria (Up), 1=Panic (Down)
#property indicator_width1  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period
input double             InpMultiplier         = 1.0;   // Scaling Multiplier (Default 1.0 = Percent)

//--- Buffers
double      WVFBuffer[];      // Unified Buffer (Positive/Negative)
double      ColorBuffer[];    // Color Index

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WVFBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.4");

   // Set levels for reference
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 30);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -20); // Downside reference

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

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
       // Find Highest Close and Lowest Close in Lookback Period
       double max_close = -DBL_MAX;
       double min_close = DBL_MAX;

       int search_start = MathMax(0, i - InpPeriod + 1);

       for(int j = search_start; j <= i; j++)
       {
           if(close[j] > max_close) max_close = close[j];
           if(close[j] < min_close) min_close = close[j];
       }

       // 1. Calculate Downside WVF (Panic)
       // Formula: (HighestClose - Low) / HighestClose * 100
       double down_wvf = 0.0;
       if(max_close > 0)
       {
           down_wvf = (max_close - low[i]) / max_close * 100.0 * InpMultiplier;
       }

       // 2. Calculate Upside WVF (Euphoria)
       // Formula: (High - LowestClose) / LowestClose * 100
       double up_wvf = 0.0;
       if(min_close > 0)
       {
           up_wvf = (high[i] - min_close) / min_close * 100.0 * InpMultiplier;
       }

       // Map to Unified Buffer
       // Dominance Logic: Which emotion is stronger?
       // Usually, Panic spikes are sharper. We prioritize display based on magnitude.
       // Or we display both by alternating? No, histogram has one value per bar.
       // Solution: Sign-based. Up = Euphoria, Down = Panic.

       if (up_wvf > down_wvf) {
           WVFBuffer[i] = up_wvf;       // Positive
           ColorBuffer[i] = 0.0;        // Green
       } else {
           WVFBuffer[i] = -down_wvf;    // Negative
           ColorBuffer[i] = 1.0;        // Red
       }
   }

   return rates_total;
}
