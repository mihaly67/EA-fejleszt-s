//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v2.1.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 2.1 (Nonlinear Kalman Filter - Lag-Free Hybrid)    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.1"

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 15
#property indicator_plots   3

//--- Plot 1: Histogram (Normalized Momentum)
#property indicator_label1  "Kalman Momentum Hist"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
// Palette: Soft Professional
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Plot 2: MACD Line (Kalman Filtered)
#property indicator_label2  "Kalman MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line (Kalman Filtered)
#property indicator_label3  "Signal Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input Parameters
input group              "=== Nonlinear Kalman Settings ==="
input int                InpFastPeriod         = 5;      // Fast Period (Scalper: 5)
input int                InpSlowPeriod         = 13;     // Slow Period (Scalper: 13)
input int                InpSignalPeriod       = 6;      // Signal Period (Scalper: 6)
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE; // Applied Price
input double             InpKalmanGain         = 1.0;    // Kalman Gain Adjustment

input group              "=== Normalization Settings ==="
input int                InpNormPeriod         = 100;    // Normalization Lookback
input double             InpNormSensitivity    = 1.0;    // Sensitivity

input group              "=== Filter Settings ==="
input bool               InpUseVolumeFilter    = true;   // Use VWMA Pre-Filter (Noise Reduction)
input int                InpVolFilterPeriod    = 20;     // Volume Filter MA Period
input double             InpVolThreshold       = 0.5;    // Rel. Volume Threshold

//--- Indicator Buffers
double      HistogramBuffer[];
double      ColorBuffer[];
double      MacdBuffer[];
double      SignalBuffer[];

//--- Calculation Buffers
double      vwma_price_buffer[];   // Pre-filtered price
double      k_fast_lowpass[];      // Fast Component Lowpass
double      k_fast_delta[];        // Fast Component Delta
double      k_fast_out[];          // Fast Component Result
double      k_slow_lowpass[];
double      k_slow_delta[];
double      k_slow_out[];
double      k_sig_lowpass[];
double      k_sig_delta[];
double      k_sig_out[];
double      raw_macd_buffer[];
double      vol_ma_buffer[];

//--- Global Variables
int         min_bars_required;

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
   // 1. Buffer Mapping
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
   SetIndexBuffer(11, k_sig_lowpass, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, k_sig_delta, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, k_sig_out, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, raw_macd_buffer, INDICATOR_CALCULATIONS);

   // 2. Variable Initialization
   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod + InpNormPeriod;

   // 3. Visuals
   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.1 (Kalman)");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, min_bars_required);

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Helper: Calculate Single Step of Nonlinear Kalman                |
//+------------------------------------------------------------------+
void UpdateKalman(int i, double price, double period,
                 double &lowpass[], double &delta[], double &output[])
{
    // Constants
    double a = MathExp(-M_PI / period);
    double b = 1.0 - a;

    // Init check
    if(i == 0) {
        lowpass[i] = price;
        delta[i] = 0;
        output[i] = price;
        return;
    }

    // 1. Lowpass Filter (EMA-like)
    lowpass[i] = b * lowpass[i-1] + a * price;

    // 2. Detrending (Price - Lowpass)
    double detrend = price - lowpass[i];

    // 3. Delta Filter (Trend Tracking)
    delta[i] = b * delta[i-1] + a * detrend;

    // 4. Recombine (Lag Correction)
    output[i] = lowpass[i] + delta[i] * InpKalmanGain;
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

   for(int i = start; i < rates_total; i++)
   {
      // --- A. Get Price ---
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

      // --- B. Pre-Filter (VWMA 3) to remove volume noise ---
      // Note: Simplified VWMA(3) inline for efficiency
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

      // --- C. Update Kalman Filters ---
      // Fast Line
      UpdateKalman(i, vwma_price_buffer[i], (double)InpFastPeriod, k_fast_lowpass, k_fast_delta, k_fast_out);

      // Slow Line
      UpdateKalman(i, vwma_price_buffer[i], (double)InpSlowPeriod, k_slow_lowpass, k_slow_delta, k_slow_out);

      // --- D. Raw MACD ---
      raw_macd_buffer[i] = k_fast_out[i] - k_slow_out[i];

      // --- E. Signal Line (Kalman of MACD) ---
      UpdateKalman(i, raw_macd_buffer[i], (double)InpSignalPeriod, k_sig_lowpass, k_sig_delta, k_sig_out);

      // --- F. Normalization & Output ---
      double std_dev = CalculateStdDev(raw_macd_buffer, i, InpNormPeriod);

      MacdBuffer[i]   = NormalizeTanh(raw_macd_buffer[i], std_dev);
      SignalBuffer[i] = NormalizeTanh(k_sig_out[i], std_dev);

      double hist = MacdBuffer[i] - SignalBuffer[i];

      // --- G. Visualization (Ghost Bars) ---
      // Need Volume SMA(20) for threshold
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
