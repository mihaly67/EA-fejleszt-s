//+------------------------------------------------------------------+
//|                                HybridMomentumIndicator_v2.72.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 2.72 (Optimized Logic & W1/MN1 Fix)               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.72"

/*
   ===================================================================
   HYBRID MOMENTUM INDICATOR v2.72 - ÉRTELMEZÉS
   ===================================================================
   Ez az indikátor a piaci lendületet (Momentum) és a trend irányát
   méri, sztochasztikus elemekkel ötvözve.

   VÁLTOZÁSOK v2.72:
   1. W1/MN1 FIX: Megszüntetve a szigorú gyertyaszám-korlát, ami miatt
      nagy időtávon (kevés adatnál) nem rajzolt az indikátor.
   2. OPTIMALIZÁCIÓ: A Stochastic adatok (CopyBuffer) lekérése optimalizálva.
      Mostantól nem másolja feleslegesen a teljes történelmet minden ticknél,
      csak a szükséges frissítéseket. Ez csökkenti a CPU terhelést.
   3. ADAPTÍV NORMALIZÁLÁS: Rövid történelem esetén automatikusan
      csökkentett periódussal számol, hogy mindig legyen jel.
*/

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 16
#property indicator_plots   3

//--- Plot 1: Histogram (Color)
#property indicator_label1  "Momentum Hist"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrForestGreen,clrFireBrick,clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 2: MACD Line (Blue)
#property indicator_label2  "MACD (Boosted)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line (Orange)
#property indicator_label3  "Signal (Lowpass)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Levels
#property indicator_level1 0.0
#property indicator_level2 80.0
#property indicator_level3 -80.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
input group              "=== Momentum Settings ==="
input int                InpFastPeriod         = 3;      // Fast Period
input int                InpSlowPeriod         = 6;      // Slow Period
input int                InpSignalPeriod       = 13;     // Signal Period
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE;
input double             InpKalmanGain         = 1.0;    // Kalman Gain
input double             InpPhaseAdvance       = 0.5;    // Phase Advance (Speed Boost)

input group              "=== Stochastic Mixing (Always Active) ==="
input bool               InpEnableBoost        = true;   // Enable Stochastic Mix
input double             InpStochMixWeight     = 0.2;    // Mixing Weight (0.0 - 1.0)
input int                InpStochK             = 5;      // Stochastic K
input int                InpStochD             = 3;      // Stochastic D
input int                InpStochSlowing       = 3;      // Stochastic Slowing

input group              "=== Normalization Settings ==="
input int                InpNormPeriod         = 100;    // Normalization Lookback
input double             InpNormSensitivity    = 1.0;    // Sensitivity

//--- Indicator Buffers
double      HistBuffer[];       // Buffer for Histogram Values
double      HistColorBuffer[];  // Buffer for Histogram Color Index
double      MacdBuffer[];
double      SignalBuffer[];

//--- Calculation Buffers
double      vwma_price_buffer[];
double      k_fast_lowpass[];
double      k_fast_delta[];
double      k_fast_out[];
double      k_slow_lowpass[];
double      k_slow_delta[];
double      k_slow_out[];
double      raw_macd_buffer[];
double      sig_lowpass_buffer[];
double      stoch_raw_buffer[]; // Buffer for CopyBuffer
double      calc_hist_buffer[]; // Intermediate histogram values

//--- Global Variables
int         min_bars_required;
int         hStoch; // Handle for Stochastic

//+------------------------------------------------------------------+
//| Helper: Tanh Normalization                                       |
//+------------------------------------------------------------------+
double NormalizeTanh(double value, double std_dev)
{
   if(std_dev == 0.0) return 0.0;
   return 100.0 * MathTanh(value / (std_dev * InpNormSensitivity));
}

//+------------------------------------------------------------------+
//| Helper: Standard Deviation                                       |
//+------------------------------------------------------------------+
double CalculateStdDev(const double &data[], int index, int period)
{
   // Safe period clamping (Adaptive)
   int safe_period = period;
   if (index < period) safe_period = index; // Use available data if less than period
   if (safe_period < 1) return 1.0;

   double sum = 0.0, sum_sq = 0.0;
   for(int i=0; i<safe_period; i++) {
      double val = data[index-i];
      sum += val;
      sum_sq += val * val;
   }
   double mean = sum / safe_period;
   double variance = (sum_sq / safe_period) - (mean * mean);
   return (variance > 0) ? MathSqrt(variance) : 1.0;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Buffers Mapping ---
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, MacdBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SignalBuffer, INDICATOR_DATA);

   SetIndexBuffer(4, vwma_price_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, k_fast_lowpass, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, k_fast_delta, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, k_fast_out, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, k_slow_lowpass, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, k_slow_delta, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, k_slow_out, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, raw_macd_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, sig_lowpass_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, stoch_raw_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, calc_hist_buffer, INDICATOR_CALCULATIONS);

   // --- Stochastic Handle ---
   if (InpEnableBoost) {
      hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
      if (hStoch == INVALID_HANDLE) {
         Print("Failed to create Stochastic handle");
         return(INIT_FAILED);
      }
   }

   // --- Metadata ---
   // FIX: Relaxed requirement.
   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + 1;

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.72");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   // --- Levels Logic ---
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 80.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -80.0);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrDimGray);

   // --- Plot Settings ---
   // FIX: Draw from the beginning
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFastPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpFastPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpFastPeriod);

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Helper: Nonlinear Kalman Update                                  |
//+------------------------------------------------------------------+
void UpdateKalman(int i, double price, double period,
                 double &lowpass[], double &delta[], double &output[])
{
    double a = 2.0 / (period + 1.0);
    double b = 1.0 - a;

    if(i == 0) {
        lowpass[i] = price;
        delta[i] = 0;
        output[i] = price;
        return;
    }

    lowpass[i] = b * lowpass[i-1] + a * price;
    double detrend = price - lowpass[i];
    delta[i] = b * delta[i-1] + a * detrend;

    // Output with Phase Advance
    output[i] = lowpass[i] + delta[i] * InpKalmanGain + (delta[i] * InpPhaseAdvance);
}

//+------------------------------------------------------------------+
//| Helper: Simple Lowpass Update                                    |
//+------------------------------------------------------------------+
void UpdateLowpass(int i, double src_val, double period, double &buffer[])
{
    double a = 2.0 / (period + 1.0);
    double b = 1.0 - a;

    if(i == 0) {
        buffer[i] = src_val;
        return;
    }
    buffer[i] = b * buffer[i-1] + a * src_val;
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

   // --- Fetch Stochastic Data (Optimization) ---
   if (InpEnableBoost) {
       ArraySetAsSeries(stoch_raw_buffer, true); // Series: 0 = Newest

       int calculated = prev_calculated;
       if (calculated > rates_total || calculated < 0) calculated = 0;

       // Calculate how many bars we need to copy
       // If full recalc (calculated == 0), copy everything.
       // If incremental (calculated > 0), copy the difference + safety margin (e.g. 2 bars)
       int to_copy;
       if (calculated == 0) {
           to_copy = rates_total;
       } else {
           to_copy = (rates_total - calculated) + 1; // +1 to ensure overlap/update of last bar
           if (to_copy > rates_total) to_copy = rates_total;
       }

       // Perform optimized copy
       // Note: CopyBuffer with (start_pos=0) copies the NEWEST 'to_copy' bars.
       int res = CopyBuffer(hStoch, 0, 0, to_copy, stoch_raw_buffer);

       // Critical Check: If copy fails, we can't calculate correctly.
       if (res <= 0) return 0;
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

   for(int i = start; i < rates_total; i++)
   {
      double p_val = close[i];
      switch(InpAppliedPrice) {
         case PRICE_CLOSE: p_val = close[i]; break;
         case PRICE_OPEN:  p_val = open[i]; break;
         case PRICE_HIGH:  p_val = high[i]; break;
         case PRICE_LOW:   p_val = low[i]; break;
         case PRICE_MEDIAN: p_val = (high[i]+low[i])/2.0; break;
         case PRICE_TYPICAL: p_val = (high[i]+low[i])/3.0; break;
         case PRICE_WEIGHTED: p_val = (high[i]+low[i]+2*close[i])/4.0; break;
         default: p_val = close[i];
      }

      // Pre-Filter
      vwma_price_buffer[i] = p_val;

      // Kalman Update
      UpdateKalman(i, vwma_price_buffer[i], (double)InpFastPeriod, k_fast_lowpass, k_fast_delta, k_fast_out);
      UpdateKalman(i, vwma_price_buffer[i], (double)InpSlowPeriod, k_slow_lowpass, k_slow_delta, k_slow_out);

      double raw_macd = k_fast_out[i] - k_slow_out[i];

      // Calculate Volatility of Raw MACD
      // Adaptive Period Logic:
      int current_norm_period = InpNormPeriod;
      // If history is too short, scale down the period to 50% of available history (or min 10)
      if (rates_total < InpNormPeriod + 10) {
          current_norm_period = MathMax(10, rates_total / 2);
      }

      double std_dev_macd = CalculateStdDev(raw_macd_buffer, i, current_norm_period);
      if (std_dev_macd == 0) std_dev_macd = Point();

      double final_signal = raw_macd;

      // --- Always Active Stochastic Mixing ---
      if (InpEnableBoost) {
          double norm_macd = raw_macd / std_dev_macd;

          // Stochastic Buffer Access (Series: 0 = Newest)
          // i is Normal index (0 = Oldest)
          // Mapping: rates_total - 1 - i
          int stoch_idx = rates_total - 1 - i;

          // Check bounds (Crucial when optimized CopyBuffer is used)
          // Since stoch_raw_buffer might hold ONLY the copied amount (e.g. 2 bars),
          // we must map the index relative to the COPIED buffer size IF CopyBuffer didn't resize it to rates_total.
          // HOWEVER, CopyBuffer in MT5 resizes dynamic arrays automatically.
          // BUT: If we only copy 'to_copy' elements, the array size will be 'to_copy'.
          // So index 0 is newest.

          // CORRECTION for Optimized CopyBuffer:
          // If we use CopyBuffer(..., to_copy, ...), stoch_raw_buffer size becomes 'to_copy'.
          // The newest element (Bar[rates_total-1]) is at index 0 in stoch_raw_buffer.
          // The element at Bar[i] corresponds to index: (rates_total - 1 - i).
          // BUT if array is small (only recent bars), we can only access recent bars.

          // PROBLEM: If we are in the main loop (calculated=0), we have full array.
          // If we are updating last bar (calculated>0), we have small array.
          // This creates complexity.

          // SIMPLER OPTIMIZATION STRATEGY for this specific code structure:
          // Since the logic relies on accessing 'stoch_raw_buffer' via Global Index mapping,
          // it's safest to maintain the buffer size = rates_total.
          // But CopyBuffer(..., to_copy) will shrink it!

          // SOLUTION: Use the standard full copy for simplicity and safety in this specific context,
          // OR handle the index offset.
          // Given the user wants SAFETY and NO LAG, but also CPU optimization:
          // Let's stick to full copy BUT with a check to avoid crashing.
          // The CPU cost of copying 1000 doubles is negligible. The cost comes from indicator CALCULATION inside MT5.
          // So the 'CopyBuffer' optimization is minor compared to 'min_bars_required' fix.

          // Reverting to FULL COPY for safety to ensure index 'rates_total - 1 - i' is always valid
          // relative to a full-sized series array.
          // (Partial copy would require complex offset logic which is prone to bugs).

          // However, we already optimized 'to_copy' logic above. Let's adjust it to be SAFE.
          // If we copy partial, ArraySize is small.
          // stoch_idx (logic) = rates_total - 1 - i (distance from newest).
          // If stoch_raw_buffer is Series, index 0 is newest.
          // So stoch_raw_buffer[0] IS the value for rates_total-1.
          // stoch_raw_buffer[1] IS the value for rates_total-2.
          // So the index 'rates_total - 1 - i' IS CORRECT even for partial arrays!
          // EXAMPLE: rates_total=100. i=99 (newest). Index = 100-1-99 = 0. Exists.
          // i=98. Index = 100-1-98 = 1. Exists (if we copied at least 2 bars).
          // So partial copy works perfectly with Series arrays and this indexing logic!

          if (stoch_idx >= 0 && stoch_idx < ArraySize(stoch_raw_buffer)) {
              double stoch_val = stoch_raw_buffer[stoch_idx];
              double norm_stoch = (stoch_val - 50.0) / 20.0;

              double w = InpStochMixWeight;
              double mixed_norm = (norm_macd * (1.0 - w)) + (norm_stoch * w);

              final_signal = mixed_norm * std_dev_macd;
          } else {
             final_signal = raw_macd;
          }
      }

      raw_macd_buffer[i] = final_signal;

      // Signal Update
      UpdateLowpass(i, raw_macd_buffer[i], (double)InpSignalPeriod, sig_lowpass_buffer);

      // Final Normalization
      double std_dev_final = CalculateStdDev(raw_macd_buffer, i, current_norm_period);
      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev_final);
      SignalBuffer[i] = NormalizeTanh(sig_lowpass_buffer[i], std_dev_final);

      double hist = MacdBuffer[i] - SignalBuffer[i];
      HistBuffer[i] = hist; // Unified Value Buffer

      // --- Color Logic ---
      if (hist >= 0) {
          HistColorBuffer[i] = 0.0; // Green
      } else {
          HistColorBuffer[i] = 1.0; // Red
      }
   }

   return rates_total;
}
