//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v2.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Verzió: 2.0 (VWMA Logic - Low Noise / High Stability) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.0"

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 9
#property indicator_plots   3

//--- Plot 1: Histogram (Normalized Momentum)
#property indicator_label1  "Momentum Hist"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
// Palette: Soft Professional (Green/Red/Gray)
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Plot 2: MACD Line (VWMA Based)
#property indicator_label2  "VWMA MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line (VWMA of MACD)
#property indicator_label3  "Signal Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input Parameters
input group              "=== VWMA MACD Settings ==="
input int                InpFastPeriod         = 12;     // Fast VWMA Period
input int                InpSlowPeriod         = 26;     // Slow VWMA Period
input int                InpSignalPeriod       = 9;      // Signal VWMA Period
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE; // Applied Price

input group              "=== Normalization Settings ==="
input int                InpNormPeriod         = 100;    // Normalization Lookback
input double             InpNormSensitivity    = 1.0;    // Sensitivity (Standard Deviation Multiplier)

input group              "=== Filter Settings ==="
input bool               InpUseVolumeFilter    = true;   // Use Volume Threshold (Ghost Bars)
input int                InpVolFilterPeriod    = 20;     // Volume Filter MA Period
input double             InpVolThreshold       = 0.5;    // Rel. Volume Threshold (0.5 = 50% of Avg)

//--- Indicator Buffers
double      HistogramBuffer[];
double      ColorBuffer[];
double      MacdBuffer[];
double      SignalBuffer[];

//--- Calculation Buffers
double      vwma_fast_buffer[];
double      vwma_slow_buffer[];
double      raw_macd_buffer[]; // Un-normalized
double      vol_ma_buffer[];   // Volume Moving Average

//--- Global Variables
int         min_bars_required;

//+------------------------------------------------------------------+
//| Helper: Tanh Normalization                                       |
//+------------------------------------------------------------------+
double NormalizeTanh(double value, double std_dev)
{
   if(std_dev == 0.0) return 0.0;
   // Tanh scales to -1..1. We multiply by 100 to get -100..100 range.
   return 100.0 * MathTanh(value / (std_dev * InpNormSensitivity));
}

//+------------------------------------------------------------------+
//| Helper: Standard Deviation                                       |
//+------------------------------------------------------------------+
double CalculateStdDev(const double &data[], int index, int period)
{
   if(index < period) return 1.0;

   double sum = 0.0;
   double sum_sq = 0.0;

   for(int i=0; i<period; i++) {
      double val = data[index-i];
      sum += val;
      sum_sq += val * val;
   }

   double mean = sum / period;
   double variance = (sum_sq / period) - (mean * mean);
   return (variance > 0) ? MathSqrt(variance) : 1.0;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Buffer Mapping
   SetIndexBuffer(0, HistogramBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, MacdBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SignalBuffer, INDICATOR_DATA);

   SetIndexBuffer(4, vwma_fast_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, vwma_slow_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, raw_macd_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, vol_ma_buffer, INDICATOR_CALCULATIONS);

   // 2. Variable Initialization
   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod + InpNormPeriod;

   // 3. Visuals
   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.0 (VWMA)");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, min_bars_required);

   // Fixed Range for normalized oscillator
   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

   // Levels
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);

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
   if(rates_total < min_bars_required) return 0;

   // Start index
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

   // --- 1. Main Calculation Loop ---
   for(int i = start; i < rates_total; i++)
   {
      // A. Get Price
      double p_val;
      switch(InpAppliedPrice) {
         case PRICE_CLOSE: p_val = close[i]; break;
         case PRICE_OPEN:  p_val = open[i]; break;
         case PRICE_HIGH:  p_val = high[i]; break;
         case PRICE_LOW:   p_val = low[i]; break;
         case PRICE_MEDIAN: p_val = (high[i]+low[i])/2.0; break;
         case PRICE_TYPICAL: p_val = (high[i]+low[i]+close[i])/3.0; break;
         case PRICE_WEIGHTED: p_val = (high[i]+low[i]+2*close[i])/4.0; break;
         default: p_val = close[i];
      }

      // B. Calc Volume MA (Simple) for Filter
      if(InpUseVolumeFilter) {
          double v_sum = 0;
          for(int k=0; k<InpVolFilterPeriod; k++) {
              if(i-k >= 0) v_sum += (double)tick_volume[i-k];
          }
          vol_ma_buffer[i] = v_sum / InpVolFilterPeriod;
      }

      // C. Calculate VWMA Components

      // Safe check for lookback
      if(i < InpSlowPeriod) {
         vwma_fast_buffer[i] = p_val;
         vwma_slow_buffer[i] = p_val;
         raw_macd_buffer[i] = 0;
         continue;
      }

      // VWMA FAST
      double sum_pv_f = 0, sum_v_f = 0;
      for(int k=0; k<InpFastPeriod; k++) {
         double h_p;
         // Recalculate historical price (cheap op)
         int idx = i-k;
         // Proper switch for history:
         if(InpAppliedPrice==PRICE_CLOSE) h_p=close[idx];
         else if(InpAppliedPrice==PRICE_OPEN) h_p=open[idx];
         else if(InpAppliedPrice==PRICE_HIGH) h_p=high[idx];
         else if(InpAppliedPrice==PRICE_LOW) h_p=low[idx];
         else if(InpAppliedPrice==PRICE_MEDIAN) h_p=(high[idx]+low[idx])/2.0;
         else if(InpAppliedPrice==PRICE_TYPICAL) h_p=(high[idx]+low[idx]+close[idx])/3.0;
         else if(InpAppliedPrice==PRICE_WEIGHTED) h_p=(high[idx]+low[idx]+2*close[idx])/4.0;
         else h_p = close[idx];

         double h_v = (double)tick_volume[idx];
         sum_pv_f += h_p * h_v;
         sum_v_f += h_v;
      }
      vwma_fast_buffer[i] = (sum_v_f > 0) ? sum_pv_f / sum_v_f : p_val;

      // VWMA SLOW
      double sum_pv_s = 0, sum_v_s = 0;
      for(int k=0; k<InpSlowPeriod; k++) {
         double h_p;
         int idx = i-k;
         if(InpAppliedPrice==PRICE_CLOSE) h_p=close[idx];
         else if(InpAppliedPrice==PRICE_OPEN) h_p=open[idx];
         else if(InpAppliedPrice==PRICE_HIGH) h_p=high[idx];
         else if(InpAppliedPrice==PRICE_LOW) h_p=low[idx];
         else if(InpAppliedPrice==PRICE_MEDIAN) h_p=(high[idx]+low[idx])/2.0;
         else if(InpAppliedPrice==PRICE_TYPICAL) h_p=(high[idx]+low[idx]+close[idx])/3.0;
         else if(InpAppliedPrice==PRICE_WEIGHTED) h_p=(high[idx]+low[idx]+2*close[idx])/4.0;
         else h_p = close[idx];

         double h_v = (double)tick_volume[idx];
         sum_pv_s += h_p * h_v;
         sum_v_s += h_v;
      }
      vwma_slow_buffer[i] = (sum_v_s > 0) ? sum_pv_s / sum_v_s : p_val;

      // D. Raw MACD
      raw_macd_buffer[i] = vwma_fast_buffer[i] - vwma_slow_buffer[i];

      // E. Signal Line (VWMA of Raw MACD)
      double sum_pv_sig = 0, sum_v_sig = 0;
      if(i >= InpSlowPeriod + InpSignalPeriod) {
         for(int k=0; k<InpSignalPeriod; k++) {
             double h_macd = raw_macd_buffer[i-k];
             double h_v = (double)tick_volume[i-k];
             sum_pv_sig += h_macd * h_v;
             sum_v_sig += h_v;
         }
      }
      double raw_signal = (sum_v_sig > 0) ? sum_pv_sig / sum_v_sig : raw_macd_buffer[i];

      // F. Normalization (Tanh)
      // Calculate StdDev of RAW MACD
      double std_dev = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);

      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev);
      SignalBuffer[i] = NormalizeTanh(raw_signal, std_dev);

      // G. Histogram & Coloring
      double hist = MacdBuffer[i] - SignalBuffer[i];

      // Filter Logic (Ghost Bars)
      bool is_weak = false;
      if(InpUseVolumeFilter && vol_ma_buffer[i] > 0) {
          if(tick_volume[i] < vol_ma_buffer[i] * InpVolThreshold) is_weak = true;
      }

      if(is_weak) {
          HistogramBuffer[i] = hist * 0.3; // Dimmed
          ColorBuffer[i] = 2; // Gray (Index 2 in property)
      } else {
          HistogramBuffer[i] = hist;
          // Color: 0=Green (Up), 1=Red (Down)
          ColorBuffer[i] = (hist >= 0) ? 0 : 1;
      }
   }

   return rates_total;
}
