//+------------------------------------------------------------------+
//|                                Hybrid_Microstructure_Monitor.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.0 (Wick Rejection & Tick Volume Analysis)        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"
#property description "Detects in-bar supply/demand exhaustion via Wick Rejection and Volume/Spread analysis."
#property description "Designed for Scalping (M1-M5). Focuses on the current forming candle."

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2

//--- Plot 1: Bearish Rejection (Upper Wick)
#property indicator_label1  "Bearish Rejection"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2

//--- Plot 2: Bullish Rejection (Lower Wick)
#property indicator_label2  "Bullish Rejection"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2

//--- Input Parameters
input group              "=== Signal Logic ==="
input int                InpLookback           = 3;      // Lookback (Bars) for Vol/Range comparison
input double             InpWickRatio          = 0.5;    // Min Wick Ratio (50% of range)
input double             InpVolumeFactor       = 1.2;    // Min Volume Factor (vs Avg)
input bool               InpUseAdaptive        = true;   // Adaptive Mode (Auto-adjust to volatility)

input group              "=== Tick Averaging (Noise Filter) ==="
input bool               InpUseTickAvg         = false;  // Enable Rolling Tick Average
input int                InpTickWindowSec      = 5;      // Rolling Window (seconds)

input group              "=== Visualization ==="
input int                InpSignalDist         = 10;     // Distance (points) for arrows

//--- Buffers
double      BearishBuffer[];
double      BullishBuffer[];
double      AvgRangeBuffer[]; // Calc buffer
double      AvgVolBuffer[];   // Calc buffer
double      TickAvgBuffer[];  // Calc buffer (visual debug optional)

//--- Tick Structure for Rolling Average
struct TickData {
   double price;
   long   time_msc;
};
TickData tick_buffer[]; // Circular buffer simulation

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BearishBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BullishBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, AvgRangeBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, AvgVolBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, TickAvgBuffer, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_ARROW, 242); // Down Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 241); // Up Arrow

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Microstructure v1.0");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Update Tick Buffer & Get Average                         |
//+------------------------------------------------------------------+
double UpdateTickAverage(double current_price)
{
   if (!InpUseTickAvg) return current_price;

   long current_msc = GetTickCount(); // Or SymbolInfoInteger(SYMBOL_TIME_MSC)

   // 1. Add new tick
   int size = ArraySize(tick_buffer);
   ArrayResize(tick_buffer, size + 1);
   tick_buffer[size].price = current_price;
   tick_buffer[size].time_msc = current_msc;

   // 2. Remove old ticks (outside window)
   long threshold = current_msc - (InpTickWindowSec * 1000);
   int remove_count = 0;
   for(int i=0; i<ArraySize(tick_buffer); i++) {
       if(tick_buffer[i].time_msc < threshold) remove_count++;
       else break; // Sorted by time, so we can stop
   }

   if(remove_count > 0) {
       ArrayRemove(tick_buffer, 0, remove_count);
   }

   // 3. Calculate Average
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

   // Handle Tick Average for the LIVE bar only (optimization)
   // We only run UpdateTickAverage if we are at the last bar (i == rates_total - 1)
   // and it's a real-time tick (not historical recalc).
   bool is_live = (prev_calculated == rates_total);

   for(int i = start; i < rates_total; i++)
   {
       BearishBuffer[i] = 0.0;
       BullishBuffer[i] = 0.0;

       // --- 1. Statistics (Last N bars) ---
       double sum_range = 0;
       double sum_vol = 0;
       for(int k=1; k<=InpLookback; k++) {
           sum_range += (high[i-k] - low[i-k]);
           sum_vol   += (double)tick_volume[i-k];
       }
       double avg_range = sum_range / InpLookback;
       double avg_vol   = sum_vol   / InpLookback;

       if(avg_range == 0) avg_range = Point(); // Safety

       // --- 2. Current Bar Analysis ---
       // Adaptive Logic: If InpUseAdaptive is true, we only enable TickAvg if Volatility (avg_range) is high.
       // Otherwise (low volatility/night), we stick to raw close to capture small moves.
       bool use_tick_avg = InpUseTickAvg;
       if (InpUseAdaptive) {
           // Simple heuristic: If current range is > 2x Avg Range, it's volatile -> Enable Avg.
           // Or if Spread is high (not available here easily without CopySpread).
           // Let's use ATR-like proxy: avg_range.
           // If AvgRange is very small (flat market), disable Avg to be responsive.
           if (avg_range < 5 * Point()) use_tick_avg = false; // Too flat, raw data needed
           else use_tick_avg = true; // Normal/Volatile, smooth the noise
       }

       double analyzed_close = close[i];

       if (i == rates_total - 1 && is_live && use_tick_avg) {
           analyzed_close = UpdateTickAverage(close[i]);
           TickAvgBuffer[i] = analyzed_close;
       } else {
           TickAvgBuffer[i] = close[i];
       }

       double current_range = high[i] - low[i];
       if (current_range == 0) continue;

       double body_top    = MathMax(open[i], analyzed_close);
       double body_bottom = MathMin(open[i], analyzed_close);

       double upper_wick = high[i] - body_top;
       double lower_wick = body_bottom - low[i];

       // --- 3. Logic & Filters ---

       // A. Wick Ratio Check
       double upper_ratio = upper_wick / current_range;
       double lower_ratio = lower_wick / current_range;

       // B. Volume Check (Pro-rated for time?)
       // For completed bars, simple comparison. For live bar, maybe projected?
       // Simplification: Check if current volume is already significant > Factor * Avg
       bool vol_cond = ((double)tick_volume[i] > avg_vol * InpVolumeFactor);

       // C. Range Check (Is this a tiny doji or a volatile bar?)
       // We only care if the bar has "substance" relative to history
       bool range_cond = (current_range > avg_range * 0.5);

       // --- 4. Signal Generation ---

       // Bearish Rejection (Long Upper Wick)
       if (upper_ratio > InpWickRatio && vol_cond && range_cond) {
           BearishBuffer[i] = high[i] + InpSignalDist * Point();
       }

       // Bullish Rejection (Long Lower Wick)
       if (lower_ratio > InpWickRatio && vol_cond && range_cond) {
           BullishBuffer[i] = low[i] - InpSignalDist * Point();
       }
   }

   return rates_total;
}
