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
// Default styles (will be overridden by inputs)
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
// Palette placeholders
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Plot 2: MACD Line (Kalman + Phase Boost)
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

//--- Input Parameters
input group              "=== Momentum Settings (v2.5 Defaults) ==="
input int                InpFastPeriod         = 3;      // Fast Period
input int                InpSlowPeriod         = 6;      // Slow Period
input int                InpSignalPeriod       = 13;     // Signal Period
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE;
input double             InpKalmanGain         = 1.0;    // Kalman Gain
input double             InpPhaseAdvance       = 0.5;    // Phase Advance (Speed Boost)

input group              "=== Adaptive Boost (Stochastic) ==="
input bool               InpEnableBoost        = true;   // Enable Adaptive Boost
input double             InpBoostIntensity     = 1.5;    // Max Boost Multiplier
input int                InpStochK             = 5;      // Stochastic K
input int                InpStochD             = 3;      // Stochastic D
input int                InpStochSlowing       = 3;      // Stochastic Slowing
input double             InpVolThreshold       = 20.0;   // Volatility Threshold (Points)

input group              "=== Visual Styles (Customizable) ==="
input color              InpHistColorUp        = clrForestGreen; // Hist Up Color
input color              InpHistColorDown      = clrFireBrick;   // Hist Down Color
input color              InpHistColorNeutral   = clrGray;        // Hist Neutral Color
input int                InpHistWidth          = 3;              // Hist Width
input ENUM_LINE_STYLE    InpHistStyle          = STYLE_SOLID;    // Hist Style

input color              InpMacdColor          = clrDodgerBlue;  // MACD Line Color
input int                InpMacdWidth          = 2;              // MACD Width
input ENUM_LINE_STYLE    InpMacdStyle          = STYLE_SOLID;    // MACD Style

input color              InpSignalColor        = clrOrangeRed;   // Signal Line Color
input int                InpSignalWidth        = 1;              // Signal Width
input ENUM_LINE_STYLE    InpSignalStyle        = STYLE_DOT;      // Signal Style

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

   // --- Visual Styles Setup (Dynamic) ---
   // Histogram
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpHistWidth);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpHistStyle);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpHistColorUp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpHistColorDown);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpHistColorNeutral);

   // MACD Line
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMacdWidth);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMacdStyle);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMacdColor);

   // Signal Line
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpSignalWidth);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpSignalStyle);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpSignalColor);

   // --- Metadata ---
   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod + InpNormPeriod;
   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.5 (Adaptive Boost)");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);

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

   // --- Fetch Stochastic Data (Future Peek Fix) ---
   if (InpEnableBoost) {
       // Using a hidden buffer to store Stochastic values
       // We request 'rates_total' items.
       // IMPORTANT: CopyBuffer returns data in Time-Descending (Series) if ArraySetAsSeries is true,
       // or Time-Ascending if false.
       // Here we control it explicitly.

       // Use a local array for CopyBuffer first
       double local_stoch[];
       ArraySetAsSeries(local_stoch, true); // 0 = Newest

       int copied = CopyBuffer(hStoch, 0, 0, rates_total, local_stoch);
       if(copied < rates_total) return 0; // Wait for data

       // Copy to our indicator calculation buffer, ensuring Series alignment
       // But wait, our calculation loop below iterates 0..rates_total (Old..New)
       // So we need to access the Stochastic data such that index 'i' (Time-Ascending)
       // corresponds to the correct time.
       // If local_stoch is Series (0=Newest), then 'i' (Oldest, where i=0) is at index 'rates_total-1'.
       // Mapping: stoch_val = local_stoch[rates_total - 1 - i];

       // Optimization: Just CopyBuffer directly to stoch_raw_buffer and access it correctly.
       // But stoch_raw_buffer is an indicator buffer, handled by MT5.
       // If we use ArraySetAsSeries(stoch_raw_buffer, true), it aligns 0=Newest.
       // Let's do that for safety.
       ArraySetAsSeries(stoch_raw_buffer, true);
       int res = CopyBuffer(hStoch, 0, 0, rates_total, stoch_raw_buffer);
       if (res <= 0) return 0;
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

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

      // Pre-Filter (VWMA)
      vwma_price_buffer[i] = p_val; // Default
      if(i >= 3) { // Minimal check
          double sum_pv=0, sum_v=0;
          for(int k=0; k<3; k++) {
              sum_pv += close[i-k] * (double)tick_volume[i-k];
              sum_v += (double)tick_volume[i-k];
          }
          if (sum_v > 0) vwma_price_buffer[i] = sum_pv / sum_v;
      }

      // Kalman Update
      UpdateKalman(i, vwma_price_buffer[i], (double)InpFastPeriod, k_fast_lowpass, k_fast_delta, k_fast_out);
      UpdateKalman(i, vwma_price_buffer[i], (double)InpSlowPeriod, k_slow_lowpass, k_slow_delta, k_slow_out);

      raw_macd_buffer[i] = k_fast_out[i] - k_slow_out[i];

      // --- Adaptive Boost Logic ---
      if (InpEnableBoost && i > 50) {
          double std_dev_raw = CalculateStdDev(raw_macd_buffer, i, 20); // Short term volatility

          // Inverse Volatility Multiplier
          // If std_dev is Low, Multiplier is High.
          // Normalized roughly to user Threshold.
          double vol_ratio = std_dev_raw / (InpVolThreshold * Point());
          if (vol_ratio < 0.0001) vol_ratio = 0.0001;

          // Formula: Multiplier = 1 + (Max-1) * exp(-Vol)
          double boost_mult = 1.0 + (InpBoostIntensity - 1.0) * MathExp(-vol_ratio);

          // Inject Stochastic
          // Correct Indexing for Series Buffer: rates_total - 1 - i
          double stoch_val = stoch_raw_buffer[rates_total - 1 - i];
          // Normalize Stochastic (0-100) to Momentum range (approx -1 to 1 or -50 to 50?)
          // Raw MACD is in points. Stochastic is 0-100.
          // We map Stoch 50 -> 0.
          double stoch_centered = (stoch_val - 50.0) * (Point() * 2); // Scale it down to point-like range?
          // Actually, we usually boost the *existing* signal, or blend.

          // "Inject Stochastic momentum"
          // Let's add a fraction of the stochastic delta to the raw macd
          raw_macd_buffer[i] += stoch_centered * boost_mult * 0.5;

          // Also apply multiplier to the raw signal itself to "Amplify" in flat markets
          raw_macd_buffer[i] *= boost_mult;
      }

      // Signal Update (Lowpass)
      UpdateLowpass(i, raw_macd_buffer[i], (double)InpSignalPeriod, sig_lowpass_buffer);

      // Normalize
      double std_dev = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev);
      SignalBuffer[i] = NormalizeTanh(sig_lowpass_buffer[i], std_dev);

      double hist = MacdBuffer[i] - SignalBuffer[i];

      // Visualization Colors
      // Use standard up/down logic
      HistogramBuffer[i] = hist;

      // Determine color index
      if(hist >= 0) {
          ColorBuffer[i] = 0; // Up
      } else {
          ColorBuffer[i] = 1; // Down
      }

      // Optional: Check for "Weak" volume (Gray)
      // If we want to keep the "Ghost Bar" logic from v2.3
      if (i >= 20) {
          double vol_avg = 0;
          for(int k=0; k<20; k++) vol_avg += (double)tick_volume[i-k];
          vol_avg /= 20.0;
          if (tick_volume[i] < vol_avg * 0.5) {
             ColorBuffer[i] = 2; // Neutral/Gray
          }
      }
   }

   return rates_total;
}
