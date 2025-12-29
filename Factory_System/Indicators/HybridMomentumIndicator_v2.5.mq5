//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v2.5.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 2.5 (Phase Advance + Adaptive Stoch Boost Fusion)  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.5"

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 16
#property indicator_plots   3

//--- Plot 1: Histogram (MACD - Signal)
#property indicator_label1  "Phase Momentum Hist"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
// Palette defined dynamically via inputs, but default buffers need declared colors
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Plot 2: MACD Line (Kalman + Phase Boost + Stoch Correction)
#property indicator_label2  "MACD (Fused)"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
// Color set via input

//--- Plot 3: Signal Line (Lowpass)
#property indicator_label3  "Signal (Lowpass)"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
// Color set via input

//--- Input Parameters
input group              "=== Visual Settings ==="
input color              InpHistUpColor        = clrForestGreen; // Histogram Up
input color              InpHistDownColor      = clrFireBrick;   // Histogram Down
input color              InpHistWeakColor      = clrGray;        // Histogram Weak
input color              InpMacdColor          = clrDodgerBlue;  // MACD Line
input color              InpSignalColor        = clrOrangeRed;   // Signal Line

input group              "=== Momentum Settings ==="
input int                InpFastPeriod         = 5;      // Fast Period
input int                InpSlowPeriod         = 13;     // Slow Period
input int                InpSignalPeriod       = 6;      // Signal Period
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE;
input double             InpKalmanGain         = 1.0;    // Kalman Gain
input double             InpPhaseAdvance       = 0.5;    // Phase Advance (Speed Boost)

input group              "=== Stochastic Fusion (Low Volatility) ==="
input bool               InpUseStochFusion     = true;   // Enable Stoch Fusion
input int                InpStochK             = 5;      // Stoch K Period
input int                InpStochD             = 3;      // Stoch D Period
input int                InpStochSlowing       = 3;      // Stoch Slowing
input double             InpFusionBaseWeight   = 0.5;    // Base Fusion Weight (Continuous)
input bool               InpAdaptiveBoost      = true;   // Enable Adaptive Volatility Boost
input double             InpBoostSensitivity   = 2.0;    // Volatility Sensitivity (Higher = Boosts earlier)
input double             InpMaxBoostMultiplier = 3.0;    // Max Multiplier (at Zero Volatility)

input group              "=== Normalization Settings ==="
input int                InpNormPeriod         = 100;    // Normalization Lookback
input double             InpNormSensitivity    = 1.0;    // Sensitivity

input group              "=== Filter Settings ==="
input bool               InpUseVolumeFilter    = false;  // Use VWMA Pre-Filter (Disabled by default)
input int                InpVolFilterPeriod    = 20;     // Volume Filter Period
input double             InpVolThreshold       = 0.5;    // Rel. Volume Threshold

//--- Indicator Buffers
double      HistogramBuffer[];
double      ColorBuffer[];
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
double      stoch_buffer[]; // New buffer for Stoch calcs

//--- Global Variables
int         min_bars_required;
int         hStoch;

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
   if(index < period) return 1.0;
   double sum = 0.0, sum_sq = 0.0;
   int count = 0;
   for(int i=0; i<period && (index-i)>=0; i++) {
      double val = data[index-i];
      sum += val;
      sum_sq += val * val;
      count++;
   }
   if(count == 0) return 1.0;
   double mean = sum / count;
   double variance = (sum_sq / count) - (mean * mean);
   return (variance > 0) ? MathSqrt(variance) : 1.0;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, HistogramBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
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
   SetIndexBuffer(13, stoch_buffer, INDICATOR_CALCULATIONS);

   // Initialize Stochastic Handle
   if(InpUseStochFusion) {
      hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
      if(hStoch == INVALID_HANDLE) {
         Print("Failed to create Stochastic handle");
         return(INIT_FAILED);
      }
   }

   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod + InpNormPeriod;

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.5 (Adaptive)");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required); // Plot 1 = MACD
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required); // Plot 2 = Signal

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);

   // Set Dynamic Colors
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpHistUpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpHistDownColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpHistWeakColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMacdColor); // Plot 1 = MACD
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpSignalColor); // Plot 2 = Signal

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Helper: Nonlinear Kalman Update (Standard)                       |
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

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

   // Pre-fill Stochastic Buffer
   double stoch_temp[];
   if(InpUseStochFusion) {
      int to_copy = rates_total - start;
      if(CopyBuffer(hStoch, 0, 0, to_copy, stoch_temp) <= 0) {
         Print("Warning: Stoch CopyBuffer failed");
      }
   }

   for(int i = start; i < rates_total; i++)
   {
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

      // Pre-Filter
      if(InpUseVolumeFilter && i >= 3) {
          double sum_pv=0, sum_v=0;
          for(int k=0; k<3; k++) {
              sum_pv += close[i-k] * (double)tick_volume[i-k];
              sum_v += (double)tick_volume[i-k];
          }
          vwma_price_buffer[i] = (sum_v > 0) ? sum_pv / sum_v : p_val;
      } else {
          vwma_price_buffer[i] = p_val;
      }

      // Kalman Update
      UpdateKalman(i, vwma_price_buffer[i], (double)InpFastPeriod, k_fast_lowpass, k_fast_delta, k_fast_out);
      UpdateKalman(i, vwma_price_buffer[i], (double)InpSlowPeriod, k_slow_lowpass, k_slow_delta, k_slow_out);

      raw_macd_buffer[i] = k_fast_out[i] - k_slow_out[i];

      // --- FUSION LOGIC START (ADAPTIVE BOOST) ---
      if(InpUseStochFusion && i > 0) {
             double stoch_val = 50.0; // Default Neutral
             int stoch_idx = i - start;
             if(stoch_idx >= 0 && stoch_idx < ArraySize(stoch_temp)) {
                 stoch_val = stoch_temp[stoch_idx];
             }

             // Normalize Stoch to [-1, 1] range
             double stoch_norm = (stoch_val - 50.0) / 50.0;

             // Get Current MACD scale (StdDev) to map Stoch into Points
             double vol_scale = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
             if(vol_scale < _Point) vol_scale = _Point; // Prevent zero

             // Calculate Boost Factor based on Volatility
             double boost_multiplier = 1.0;
             if(InpAdaptiveBoost) {
                 // Inverse Relationship: Low Volatility -> High Boost
                 // We normalize Volatility relative to a baseline or simply use Tanh decay
                 // Volatility of 0 should give MaxBoost.
                 // Volatility of 'Average' should give 1.0.

                 // Heuristic: Normalize vol_scale by price to get % volatility
                 double vol_pct = (p_val > 0) ? vol_scale / p_val : 0;

                 // Apply sensitivity. If Sensitivity is high, small volatility kills the boost.
                 // Formula: Multiplier = 1 + (Max - 1) * exp(-Sensitivity * Volatility_Factor)
                 // We need a stable volatility factor. Maybe just raw point volatility relative to pip?
                 double vol_factor = vol_scale / (_Point * 100); // Volatility in 'pips' approx

                 boost_multiplier = 1.0 + (InpMaxBoostMultiplier - 1.0) * MathExp(-vol_factor / InpBoostSensitivity);
             }

             // Final Weight = BaseWeight * Multiplier
             double final_weight = InpFusionBaseWeight * boost_multiplier;

             // Calculate Correction Term
             // Note: vol_scale is multiplied here so the correction matches the indicator's magnitude (points)
             double correction = stoch_norm * vol_scale * final_weight;

             // Inject Correction into Raw MACD
             raw_macd_buffer[i] += correction;
      }
      // --- FUSION LOGIC END ---

      // Signal Update (Lowpass)
      UpdateLowpass(i, raw_macd_buffer[i], (double)InpSignalPeriod, sig_lowpass_buffer);

      // Normalize
      double std_dev = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev);
      SignalBuffer[i] = NormalizeTanh(sig_lowpass_buffer[i], std_dev);

      double hist = MacdBuffer[i] - SignalBuffer[i];

      // Visualization
      double vol_avg = 0;
      if(i >= InpVolFilterPeriod) {
         for(int k=0; k<InpVolFilterPeriod; k++) vol_avg += (double)tick_volume[i-k];
         vol_avg /= InpVolFilterPeriod;
      }
      bool is_weak = (vol_avg > 0 && tick_volume[i] < vol_avg * InpVolThreshold);

      if(is_weak && InpUseVolumeFilter) {
          HistogramBuffer[i] = hist * 0.3;
          ColorBuffer[i] = 2; // Gray
      } else {
          HistogramBuffer[i] = hist;
          ColorBuffer[i] = (hist >= 0) ? 0 : 1;
      }
   }

   return rates_total;
}
