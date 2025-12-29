//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v2.5.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 2.5 (Adaptive Boost + Stoch Mix + UX Redesign)    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.5"

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 18
#property indicator_plots   5

//--- Plot 1: Histogram UP (Green)
#property indicator_label1  "Hist Up"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrForestGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 2: Histogram DOWN (Red)
#property indicator_label2  "Hist Down"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- Plot 3: Histogram NEUTRAL (Gray)
#property indicator_label3  "Hist Neutral"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrGray
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot 4: MACD Line (Blue)
#property indicator_label4  "MACD (Boosted)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- Plot 5: Signal Line (Orange)
#property indicator_label5  "Signal (Lowpass)"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrangeRed
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

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
double      HistUpBuffer[];
double      HistDownBuffer[];
double      HistNeutralBuffer[];
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
   SetIndexBuffer(0, HistUpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HistDownBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, HistNeutralBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, MacdBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SignalBuffer, INDICATOR_DATA);

   SetIndexBuffer(5, vwma_price_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, k_fast_lowpass, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, k_fast_delta, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, k_fast_out, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, k_slow_lowpass, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, k_slow_delta, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, k_slow_out, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, raw_macd_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, sig_lowpass_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, stoch_raw_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, calc_hist_buffer, INDICATOR_CALCULATIONS);

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

   // --- Plot Settings ---
   // Set Empty Value (0.0 will not be drawn)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, min_bars_required);

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
      double p_val = close[i];
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

      // Calculate Volatility of Raw MACD
      double std_dev_macd = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
      if (std_dev_macd == 0) std_dev_macd = Point();

      double final_signal = raw_macd;

      // --- Always Active Stochastic Mixing ---
      if (InpEnableBoost) {
          double norm_macd = raw_macd / std_dev_macd;
          double stoch_val = stoch_raw_buffer[rates_total - 1 - i];
          double norm_stoch = (stoch_val - 50.0) / 20.0;

          double w = InpStochMixWeight;
          double mixed_norm = (norm_macd * (1.0 - w)) + (norm_stoch * w);

          final_signal = mixed_norm * std_dev_macd;
      }

      raw_macd_buffer[i] = final_signal;

      // Signal Update
      UpdateLowpass(i, raw_macd_buffer[i], (double)InpSignalPeriod, sig_lowpass_buffer);

      // Final Normalization
      double std_dev_final = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);
      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev_final);
      SignalBuffer[i] = NormalizeTanh(sig_lowpass_buffer[i], std_dev_final);

      double hist = MacdBuffer[i] - SignalBuffer[i];
      calc_hist_buffer[i] = hist;

      // --- Visualization (Split Buffers for UX) ---
      // Reset all first
      HistUpBuffer[i] = 0.0;
      HistDownBuffer[i] = 0.0;
      HistNeutralBuffer[i] = 0.0;

      // Logic
      if (hist >= 0) {
          HistUpBuffer[i] = hist;
      } else {
          HistDownBuffer[i] = hist;
      }

      // Optional: Logic for Neutral (if required later, currently standard Up/Down)
      // Example: if (MathAbs(hist) < Threshold) HistNeutralBuffer[i] = hist; ...
   }

   return rates_total;
}
