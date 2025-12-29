//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v2.5.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 2.5 (Adaptive Boost + Stochastic Fusion)          |
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
// Standard Palette (User Editable in Colors Tab)
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Plot 2: MACD Line (Boosted)
#property indicator_label2  "MACD (Boosted)"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
#property indicator_color2  clrDodgerBlue

//--- Plot 3: Signal Line (Lowpass)
#property indicator_label3  "Signal (Lowpass)"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
#property indicator_color3  clrOrangeRed

//--- Levels
#property indicator_level1 0.0
#property indicator_levelcolor clrGray
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
double      stoch_raw_buffer[]; // Buffer for CopyBuffer

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
   if(index < period) return 1.0;
   double sum = 0.0, sum_sq = 0.0;
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
   // --- Buffers Mapping ---
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
   SetIndexBuffer(13, stoch_raw_buffer, INDICATOR_CALCULATIONS);

   // --- Stochastic Handle ---
   if (InpEnableBoost) {
      hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
      if (hStoch == INVALID_HANDLE) {
         Print("Failed to create Stochastic handle");
         return(INIT_FAILED);
      }
   }

   // --- Metadata ---
   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod + InpNormPeriod;
   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.5");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

   // Note: We do NOT use PlotIndexSetInteger here for Colors/Styles
   // to allow the user to use the "Colors" tab in the property dialog.

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

   // --- Fetch Stochastic Data (Series Aligned) ---
   if (InpEnableBoost) {
       ArraySetAsSeries(stoch_raw_buffer, true); // Set target to Series
       int res = CopyBuffer(hStoch, 0, 0, rates_total, stoch_raw_buffer);
       if (res <= 0) return 0;
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

   for(int i = start; i < rates_total; i++)
   {
      double p_val = close[i]; // Default to Close if not handling others for brevity or use switch if critical
      // (Using simple close for price source for now, or keep the switch from v2.3 if space allows)
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
      vwma_price_buffer[i] = p_val;

      // Kalman Update
      UpdateKalman(i, vwma_price_buffer[i], (double)InpFastPeriod, k_fast_lowpass, k_fast_delta, k_fast_out);
      UpdateKalman(i, vwma_price_buffer[i], (double)InpSlowPeriod, k_slow_lowpass, k_slow_delta, k_slow_out);

      double raw_macd = k_fast_out[i] - k_slow_out[i];

      // Calculate Volatility of Raw MACD (for Normalization)
      double std_dev_macd = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
      // Fallback if std_dev is 0
      if (std_dev_macd == 0) std_dev_macd = Point();

      double final_signal = raw_macd;

      // --- Always Active Stochastic Mixing ---
      if (InpEnableBoost) {
          // 1. Normalize MACD (Z-Score approximation)
          double norm_macd = raw_macd / std_dev_macd;

          // 2. Fetch Stoch & Normalize to approx same range (-2 to +2)
          double stoch_val = stoch_raw_buffer[rates_total - 1 - i];
          double norm_stoch = (stoch_val - 50.0) / 20.0; // 50->0, 90->2, 10->-2

          // 3. Mix
          double w = InpStochMixWeight;
          double mixed_norm = (norm_macd * (1.0 - w)) + (norm_stoch * w);

          // 4. Denormalize (Scale back to MACD points domain) for consistent display
          // This ensures the signal line logic (which runs next) sees "Price Points" units.
          final_signal = mixed_norm * std_dev_macd;
      }

      raw_macd_buffer[i] = final_signal;

      // Signal Update (Lowpass on the MIXED signal)
      UpdateLowpass(i, raw_macd_buffer[i], (double)InpSignalPeriod, sig_lowpass_buffer);

      // Final Display Normalization (Tanh)
      // Recalculate StdDev on the MIXED buffer?
      // Actually, since we denormalized, the std_dev_macd is still roughly valid,
      // but let's re-calc for precision if buffer was updated.
      // But calculating StdDev of the *just updated* buffer is tricky in a single loop
      // (lookback needs past values).
      // Since 'raw_macd_buffer' stores the Mixed value now, 'CalculateStdDev' will use
      // Mixed values from the past and the Current Mixed value.
      double std_dev_final = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);

      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev_final);
      SignalBuffer[i] = NormalizeTanh(sig_lowpass_buffer[i], std_dev_final);

      double hist = MacdBuffer[i] - SignalBuffer[i];

      // Visualization
      HistogramBuffer[i] = hist;

      // Color Logic (Index 0, 1, 2)
      // 0 = Up (Green), 1 = Down (Red), 2 = Neutral (Gray)
      if (hist >= 0) ColorBuffer[i] = 0;
      else ColorBuffer[i] = 1;

      // Optional: Weak Signal (Gray) logic could go here if requested
      // For now, sticking to standard Up/Down
   }

   return rates_total;
}
