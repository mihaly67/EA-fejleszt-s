//+------------------------------------------------------------------+
//|                                Hybrid_Microstructure_Monitor.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.4 (Zero-Based Pressure + Optimized Colors)       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.4"
#property description "Visualizes Microstructure: Positive/Negative Pressure Histogram."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: Spread (Base Line) - Optional
#property indicator_label1  "Spread (Points)"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Rejection Pressure (Histogram)
#property indicator_label2  "Rejection Pressure"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  clrForestGreen, clrFireBrick
#property indicator_width2  3

//--- Input Parameters
input group              "=== Signal Logic ==="
input int                InpLookback           = 3;      // Lookback (Bars) for Vol/Range comparison
input double             InpWickRatio          = 0.4;    // Min Wick Ratio (40% of range)
input bool               InpUseAdaptive        = true;   // Adaptive Mode (Auto-adjust to volatility)

input group              "=== Tick Averaging ==="
input bool               InpUseTickAvg         = true;   // Enable Rolling Tick Average
input int                InpTickWindowSec      = 5;      // Rolling Window (seconds)

input group              "=== Visuals ==="
input bool               InpShowSpread         = false;  // Show Spread Line (Default: False)

//--- Buffers
double      SpreadBuffer[];
double      PressureBuffer[];
double      PressureColorBuffer[];
double      TickAvgBuffer[];

//--- Tick Structure
struct TickData {
   double price;
   long   time_msc;
};
TickData tick_buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, SpreadBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PressureBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, PressureColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, TickAvgBuffer, INDICATOR_CALCULATIONS);

   if (InpShowSpread) {
       PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
       PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
       PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrSilver);
   } else {
       PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Microstructure v1.4");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Update Tick Buffer                                       |
//+------------------------------------------------------------------+
double UpdateTickAverage(double current_price)
{
   if (!InpUseTickAvg) return current_price;

   long current_msc = GetTickCount();

   int size = ArraySize(tick_buffer);
   ArrayResize(tick_buffer, size + 1);
   tick_buffer[size].price = current_price;
   tick_buffer[size].time_msc = current_msc;

   long threshold = current_msc - (InpTickWindowSec * 1000);
   int split_index = -1;
   for(int i=0; i<size; i++) {
       if(tick_buffer[i].time_msc >= threshold) {
           split_index = i;
           break;
       }
   }

   if (split_index == -1 && size > 0) {
       if(tick_buffer[size].time_msc < threshold) ArrayFree(tick_buffer);
   } else if (split_index > 0) {
       ArrayRemove(tick_buffer, 0, split_index);
   }

   double sum = 0;
   int count = ArraySize(tick_buffer);
   if(count == 0) return current_price;

   for(int i=0; i<count; i++) sum += tick_buffer[i].price;
   return sum / count;
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
   if(rates_total < InpLookback + 1) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpLookback;
   bool is_live = (prev_calculated == rates_total);

   for(int i = start; i < rates_total; i++)
   {
       SpreadBuffer[i] = (double)spread[i];

       double avg_range = 0;
       for(int k=1; k<=InpLookback; k++) avg_range += (high[i-k] - low[i-k]);
       avg_range /= InpLookback;
       if(avg_range == 0) avg_range = Point();

       bool use_tick_avg = InpUseTickAvg;
       if (InpUseAdaptive) {
           if (avg_range < 5 * Point()) use_tick_avg = false;
           else use_tick_avg = true;
       }

       double analyzed_close = close[i];
       if (i == rates_total - 1 && is_live && use_tick_avg) {
           analyzed_close = UpdateTickAverage(close[i]);
       }
       TickAvgBuffer[i] = analyzed_close;

       // --- Pressure Calculation (Zero-Based) ---
       double current_range = high[i] - low[i];
       PressureBuffer[i] = 0.0;
       PressureColorBuffer[i] = 0.0;

       if (current_range > 0) {
           double body_top    = MathMax(open[i], analyzed_close);
           double body_bottom = MathMin(open[i], analyzed_close);

           double upper_wick = high[i] - body_top;
           double lower_wick = body_bottom - low[i];

           double upper_ratio = upper_wick / current_range;
           double lower_ratio = lower_wick / current_range;

           // Visual Logic: Green = Up (Positive), Red = Down (Negative)
           if (lower_ratio > InpWickRatio && lower_ratio > upper_ratio) {
               // Bullish Rejection (Long Lower Wick -> Price pushed UP)
               double strength = (lower_ratio * current_range) / Point();
               PressureBuffer[i] = strength;
               PressureColorBuffer[i] = 0.0; // Green
           }
           else if (upper_ratio > InpWickRatio && upper_ratio > lower_ratio) {
               // Bearish Rejection (Long Upper Wick -> Price pushed DOWN)
               double strength = (upper_ratio * current_range) / Point();
               PressureBuffer[i] = -strength; // NEGATIVE value
               PressureColorBuffer[i] = 1.0; // Red
           }
       }
   }

   return rates_total;
}
