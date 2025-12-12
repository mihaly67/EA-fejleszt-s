//+------------------------------------------------------------------+
//|                                        Hybrid_MTF_Scalper.mq5 |
//|                                            Jules Assistant |
//|                                   Deep Research: MTF & Hybrid Logic |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property link      "https://github.com/mihaly67/EA-fejleszt-s"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   2

//--- Plot settings
#property indicator_label1  "Hybrid_Signal"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Trend_Bias"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Inputs
input group "Fast Signal (Current TF)"
input int      InpFastPeriod1 = 12;   // DEMA Fast
input int      InpFastPeriod2 = 26;   // DEMA Slow
input int      InpWPRPeriod   = 14;   // WPR Period
input double   InpFastWeight  = 0.6;  // Fast Signal Weight (0.0-1.0)

input group "Slow Trend (Higher TF)"
input ENUM_TIMEFRAMES InpSlowTF = PERIOD_M5; // Trend Timeframe
input int      InpSlowMACD1   = 24;   // Slow MACD Fast
input int      InpSlowMACD2   = 52;   // Slow MACD Slow
input double   InpSlowWeight  = 0.4;  // Slow Signal Weight

input group "Common"
input int      InpNormPeriod  = 50;   // Normalization Lookback
input double   InpIFTGain     = 1.5;  // IFT Gain

//--- Buffers
double         Buf_Hybrid[];
double         Buf_Trend[];
double         Buf_FastRaw[];
double         Buf_SlowRaw[];
double         Buf_TimeMap[]; // Cache for optimization

//--- Handles
int hFastDEMA1 = INVALID_HANDLE;
int hFastDEMA2 = INVALID_HANDLE;
int hWPR       = INVALID_HANDLE;
int hSlowMACD  = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Validate TF
   if(InpSlowTF <= Period())
     {
      Print("Error: Slow Timeframe must be higher than current chart timeframe.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- Buffers
   SetIndexBuffer(0, Buf_Hybrid, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_Trend, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_FastRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, Buf_SlowRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, Buf_TimeMap, INDICATOR_CALCULATIONS);

   //--- Plot Names
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetString(1, PLOT_LABEL, "Trend Bias (M5)");

   //--- Levels
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.8);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -0.8);

   //--- Create Handles (Global)
   hFastDEMA1 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod1, 0, PRICE_CLOSE);
   hFastDEMA2 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod2, 0, PRICE_CLOSE);
   hWPR       = iWPR(NULL, PERIOD_CURRENT, InpWPRPeriod);

   // Slow handle on InpSlowTF
   hSlowMACD  = iMACD(NULL, InpSlowTF, InpSlowMACD1, InpSlowMACD2, 9, PRICE_CLOSE);

   if(hFastDEMA1 == INVALID_HANDLE || hFastDEMA2 == INVALID_HANDLE ||
      hWPR == INVALID_HANDLE || hSlowMACD == INVALID_HANDLE)
     {
      Print("Failed to create handles.");
      return(INIT_FAILED);
     }

   string name = StringFormat("HybridMTF(%s, W:%.1f/%.1f)", EnumToString(InpSlowTF), InpFastWeight, InpSlowWeight);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hFastDEMA1 != INVALID_HANDLE) IndicatorRelease(hFastDEMA1);
   if(hFastDEMA2 != INVALID_HANDLE) IndicatorRelease(hFastDEMA2);
   if(hWPR != INVALID_HANDLE)       IndicatorRelease(hWPR);
   if(hSlowMACD != INVALID_HANDLE)  IndicatorRelease(hSlowMACD);
  }

//+------------------------------------------------------------------+
//| Math: IFT                                                        |
//+------------------------------------------------------------------+
double IFT(double x)
  {
   double e2x = MathExp(2 * x * InpIFTGain);
   return (e2x - 1) / (e2x + 1);
  }

//+------------------------------------------------------------------+
//| Math: Normalize (Stoch-like)                                     |
//+------------------------------------------------------------------+
double Normalize(double val, double min, double max)
  {
   if(max - min <= 0) return 0;
   double norm = (val - min) / (max - min); // 0..1
   return (norm - 0.5) * 4.0; // -2..2 approx for IFT
  }

//+------------------------------------------------------------------+
//| Custom Indicator Iteration                                       |
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
   if(rates_total < InpNormPeriod * 2) return 0;

   //--- Define Calculation Range
   int limit;
   if(prev_calculated == 0)
      limit = 0;
   else
      limit = prev_calculated - 1;

   //--- Copy FAST Data (Current TF)
   double d1[], d2[], wpr[];
   int to_copy = rates_total - limit;

   if(CopyBuffer(hFastDEMA1, 0, limit, to_copy, d1) < to_copy) return 0;
   if(CopyBuffer(hFastDEMA2, 0, limit, to_copy, d2) < to_copy) return 0;
   if(CopyBuffer(hWPR, 0, limit, to_copy, wpr) < to_copy) return 0;

   //--- Calculate FAST Raw Signal Loop
   for(int i = 0; i < to_copy; i++)
     {
      int idx = limit + i;
      double macd_zero = d1[i] - d2[i]; // ZeroLag MACD

      // Normalize WPR from 0..-100 to -1..1
      // 0 -> 1, -50 -> 0, -100 -> -1
      double wpr_norm = 1.0 + (wpr[i] / 50.0);

      // Combine raw fast signal
      Buf_FastRaw[idx] = macd_zero + wpr_norm;
     }

   //--- SLOW (MTF) Data Handling
   // We need Slow MACD values corresponding to Current Time.
   // Efficient pattern: For each 'new' bar on current TF, check what the slow TF bar index is.

   // We can't easily copy a huge chunk of MTF data aligned to current bars without iBarShift loop.
   // But calling iBarShift 1000 times is slow.
   // Better: Copy the last N bars of Slow Data, then map.

   // For the 'limit' loop, we need to find the corresponding times.
   // Since 'limit' is usually just the last few bars, we can afford iBarShift or CopyBuffer with time.

   for(int i = limit; i < rates_total; i++)
     {
      datetime t = time[i];

      // Get Slow MACD for this time
      // Using CopyBuffer with time start/end.
      // We ask for 1 bar starting at 't'. MQL5 returns the bar covering that time.
      double s_macd[1];
      if(CopyBuffer(hSlowMACD, 0, t, 1, s_macd) > 0)
        {
         Buf_SlowRaw[i] = s_macd[0];
        }
      else
        {
         if(i > 0) Buf_SlowRaw[i] = Buf_SlowRaw[i-1]; // Fallback
         else Buf_SlowRaw[i] = 0;
        }
     }

   //--- Final Normalization & Fusion Loop
   // We need 'InpNormPeriod' history to normalize.

   int norm_limit = limit;
   if(norm_limit < InpNormPeriod) norm_limit = InpNormPeriod;

   for(int i = norm_limit; i < rates_total; i++)
     {
      // 1. Normalize Fast Raw
      double min_f = Buf_FastRaw[i], max_f = Buf_FastRaw[i];
      for(int k=1; k<InpNormPeriod; k++) {
         if(Buf_FastRaw[i-k] < min_f) min_f = Buf_FastRaw[i-k];
         if(Buf_FastRaw[i-k] > max_f) max_f = Buf_FastRaw[i-k];
      }
      double fast_norm_val = Normalize(Buf_FastRaw[i], min_f, max_f);
      double fast_ift = IFT(fast_norm_val);

      // 2. Normalize Slow Raw
      double min_s = Buf_SlowRaw[i], max_s = Buf_SlowRaw[i];
      for(int k=1; k<InpNormPeriod; k++) {
         if(Buf_SlowRaw[i-k] < min_s) min_s = Buf_SlowRaw[i-k];
         if(Buf_SlowRaw[i-k] > max_s) max_s = Buf_SlowRaw[i-k];
      }
      double slow_norm_val = Normalize(Buf_SlowRaw[i], min_s, max_s);
      double slow_ift = IFT(slow_norm_val);

      // 3. Fusion
      double hybrid = (fast_ift * InpFastWeight) + (slow_ift * InpSlowWeight);

      // Clamp
      if(hybrid > 1.0) hybrid = 1.0;
      if(hybrid < -1.0) hybrid = -1.0;

      Buf_Hybrid[i] = hybrid;
      Buf_Trend[i]  = slow_ift; // Visualize trend bias separately
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
