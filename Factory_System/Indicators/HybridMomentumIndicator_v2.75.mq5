//+------------------------------------------------------------------+
//|                                HybridMomentumIndicator_v2.75.mq5 |
//|                     Copyright 2026, Jules Agent & User           |
//|        Verzió: 2.75 (FIX: History Consistency Enforcement)       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "2.75"

/*
   ===================================================================
   HYBRID MOMENTUM INDICATOR v2.75 - JAVÍTÁSOK
   ===================================================================
   Ez a verzió javítja a görbe inkonzisztenciáját idősík-váltáskor.

   PROBLÉMA (v2.74):
   Amikor a felhasználó idősíkot vált (pl. W1 -> M1), az MT5 letölti a hiányzó
   history adatokat. A v2.74 ilyenkor csak a "végéhez" fűzte hozzá az új számítást,
   de a múltbeli értékeket (amiket korábban kevesebb adatból számolt) nem frissítette.
   Mivel a normalizálás (StdDev) függ a teljes adathossztól, ez "törést" okozott
   a görbében.

   MEGOLDÁS (v2.75):
   "History Consistency Check": Ha az indikátor észleli, hogy a rates_total
   jelentősen megváltozott (több mint 10 gyertyával bővült a history),
   azonnal kényszeríti a TELJES újraszámolást (return 0).
   Ez garantálja, hogy a görbe mindig egységes és determinisztikus legyen,
   függetlenül attól, hogy milyen sorrendben töltődtek be az adatok.
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
double      calc_hist_buffer[]; // Intermediate

//--- Global Variables
int         min_bars_required;
int         hStoch; // Handle for Stochastic
int         g_prev_rates_total = 0; // State tracking for History Expansion

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
   int safe_period = period;
   if (index < period) safe_period = index;
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

   min_bars_required = MathMax(InpFastPeriod, InpSlowPeriod) + 1;

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v2.75");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 80.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -80.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrDimGray);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFastPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpFastPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpFastPeriod);

   IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

   g_prev_rates_total = 0; // Reset history tracker

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

   // --- HISTORY CONSISTENCY CHECK (Fix v2.75) ---
   // Ha a history jelentősen bővült (több mint 10 gyertya), akkor
   // az MT5 letöltötte a múltat. Kényszerítjük a teljes újraszámolást,
   // hogy a normalizálás (StdDev) konzisztens legyen a teljes adathalmazra.
   if (g_prev_rates_total > 0 && (rates_total > g_prev_rates_total + 10)) {
       g_prev_rates_total = rates_total;
       return 0; // Force Full Recalc
   }
   g_prev_rates_total = rates_total;

   // --- Fetch Stochastic Data with SYNC CHECK ---
   bool fully_synced = true;

   if (InpEnableBoost) {
       ArraySetAsSeries(stoch_raw_buffer, true);

       int res = CopyBuffer(hStoch, 0, 0, rates_total, stoch_raw_buffer);

       if (res <= 0) return 0; // Fatal error, retry

       // CRITICAL FIX v2.74:
       // Ha még mindig tölti a history-t, ne mentsük el az állapotot.
       if (res < rates_total - 5) {
          fully_synced = false;
       }
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

      // Adaptive Normalization Period
      int current_norm_period = InpNormPeriod;
      if (rates_total < InpNormPeriod + 10) {
          current_norm_period = MathMax(10, rates_total / 2);
      }

      double std_dev_macd = CalculateStdDev(raw_macd_buffer, i, current_norm_period);
      if (std_dev_macd == 0) std_dev_macd = Point();

      double final_signal = raw_macd;

      // --- Stochastic Mixing with Bounds Check ---
      if (InpEnableBoost) {
          double norm_macd = raw_macd / std_dev_macd;

          // Mapping: rates_total - 1 - i
          int stoch_idx = rates_total - 1 - i;

          if (stoch_idx >= 0 && stoch_idx < ArraySize(stoch_raw_buffer)) {
              double stoch_val = stoch_raw_buffer[stoch_idx];

              if (stoch_val != 0.0) {
                 double norm_stoch = (stoch_val - 50.0) / 20.0;
                 double w = InpStochMixWeight;
                 double mixed_norm = (norm_macd * (1.0 - w)) + (norm_stoch * w);
                 final_signal = mixed_norm * std_dev_macd;
              }
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
      HistBuffer[i] = hist;

      // --- Color Logic ---
      if (hist >= 0) {
          HistColorBuffer[i] = 0.0; // Green
      } else {
          HistColorBuffer[i] = 1.0; // Red
      }
   }

   // FORCE RECALCULATION CHECK (Sync):
   if (!fully_synced) {
       return 0;
   }

   return rates_total;
}
