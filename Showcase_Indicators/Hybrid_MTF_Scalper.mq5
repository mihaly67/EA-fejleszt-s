//+------------------------------------------------------------------+
//|                                        Hybrid_MTF_Scalper.mq5 |
//|                                            Jules Assistant |
//|                                   Deep Research: MTF & Hybrid Logic |
//|                                                                  |
//| INSTALLATION PATH: MQL5/Indicators/Hybrid_MTF_Scalper.mq5        |
//| DEPENDENCY: MQL5/Include/Amplitude_Booster.mqh                   |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property link      "https://github.com/mihaly67/EA-fejleszt-s"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   3

// Use angle brackets < > to search in MQL5/Include/
// Use quotes " " to search in the SAME folder as this indicator
#include "Amplitude_Booster.mqh"

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

#property indicator_label3  "Current_MACD_Hist"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Inputs
input group "Visibility"
input bool     InpShowHybrid  = true; // Show Hybrid Signal
input bool     InpShowTrend   = true; // Show Trend Bias
input bool     InpShowHist    = true; // Show Current Histogram

input group "Timeframes (Sandwich Logic)"
input ENUM_TIMEFRAMES InpFastTF     = PERIOD_M1;  // Lower/Fast TF (Context)
input ENUM_TIMEFRAMES InpTrendTF    = PERIOD_M5;  // Higher/Trend TF (Bias)

input group "Signal Settings"
input int      InpFastPeriod1 = 12;   // DEMA Fast
input int      InpFastPeriod2 = 26;   // DEMA Slow
input int      InpWPRPeriod   = 14;   // WPR Period
input double   InpFastWeight  = 0.6;  // Fast Signal Weight (0.0-1.0)
input double   InpTrendWeight = 0.4;  // Trend Signal Weight

input group "Common"
input int      InpNormPeriod  = 50;   // Normalization Lookback
input double   InpIFTGain     = 1.5;  // IFT Gain

//--- Buffers
double         Buf_Hybrid[];
double         Buf_Trend[];
double         Buf_Hist[];
double         Buf_FastRaw[];
double         Buf_TrendRaw[];
double         Buf_CurrentRaw[];
double         Buf_TimeMap[]; // Unused but kept for structure

//--- Handles
int hFastDEMA1 = INVALID_HANDLE;
int hFastDEMA2 = INVALID_HANDLE;
int hWPR       = INVALID_HANDLE;
int hTrendMACD = INVALID_HANDLE; // Higher TF
int hCurrDEMA1 = INVALID_HANDLE; // Current TF
int hCurrDEMA2 = INVALID_HANDLE; // Current TF

//--- Boosters
CAmplitudeBooster BoostFast;
CAmplitudeBooster BoostTrend;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Buffers
   SetIndexBuffer(0, Buf_Hybrid, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_Trend, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_Hist, INDICATOR_DATA);
   SetIndexBuffer(3, Buf_FastRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, Buf_TrendRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, Buf_CurrentRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, Buf_TimeMap, INDICATOR_CALCULATIONS);

   //--- Plot Names
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetString(1, PLOT_LABEL, "Trend Bias");
   PlotIndexSetString(2, PLOT_LABEL, "Current MACD");

   //--- Levels
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.8);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -0.8);

   //--- Init Boosters
   BoostFast.Init(InpNormPeriod, true, InpIFTGain);
   BoostTrend.Init(InpNormPeriod, true, InpIFTGain);

   //--- Create Handles
   // 1. Fast TF (Lower)
   hFastDEMA1 = iDEMA(NULL, InpFastTF, InpFastPeriod1, 0, PRICE_CLOSE);
   hFastDEMA2 = iDEMA(NULL, InpFastTF, InpFastPeriod2, 0, PRICE_CLOSE);
   hWPR       = iWPR(NULL, InpFastTF, InpWPRPeriod);

   // 2. Trend TF (Higher)
   hTrendMACD = iMACD(NULL, InpTrendTF, 12, 26, 9, PRICE_CLOSE); // Standard MACD for Trend

   // 3. Current TF (For Histogram)
   hCurrDEMA1 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod1, 0, PRICE_CLOSE);
   hCurrDEMA2 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod2, 0, PRICE_CLOSE);

   if(hFastDEMA1 == INVALID_HANDLE || hTrendMACD == INVALID_HANDLE || hCurrDEMA1 == INVALID_HANDLE)
     {
      Print("Failed to create handles. Check Timeframe inputs.");
      return(INIT_FAILED);
     }

   string name = StringFormat("HybridMTF(F:%s, T:%s)", EnumToString(InpFastTF), EnumToString(InpTrendTF));
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   //--- Visibility Control
   if(!InpShowHybrid) PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowTrend)  PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowHist)   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hFastDEMA1 != INVALID_HANDLE) IndicatorRelease(hFastDEMA1);
   if(hFastDEMA2 != INVALID_HANDLE) IndicatorRelease(hFastDEMA2);
   if(hWPR != INVALID_HANDLE)       IndicatorRelease(hWPR);
   if(hTrendMACD != INVALID_HANDLE) IndicatorRelease(hTrendMACD);
   if(hCurrDEMA1 != INVALID_HANDLE) IndicatorRelease(hCurrDEMA1);
   if(hCurrDEMA2 != INVALID_HANDLE) IndicatorRelease(hCurrDEMA2);
  }

//+------------------------------------------------------------------+
//| Get Value from Handle (Safe)                                     |
//+------------------------------------------------------------------+
double GetVal(int handle, int buffer_num, int index)
{
   double buf[1];
   if(CopyBuffer(handle, buffer_num, index, 1, buf) > 0)
      return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get Time-Aligned Value (MTF)                                     |
//+------------------------------------------------------------------+
double GetValMTF(int handle, int buffer_num, datetime time)
{
   // CopyBuffer with datetime automatically finds the bar covering that time
   double buf[1];
   if(CopyBuffer(handle, buffer_num, time, 1, buf) > 0)
      return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculation                                                      |
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
   if(rates_total < InpNormPeriod) return 0;

   //--- Define Range
   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   // Performance Optimization:
   // Amplitude Booster is stateful (circular buffer).
   // If we re-calculate history (start=0), we must Reset boosters.
   if(start == 0) {
      BoostFast.Init(InpNormPeriod, true, InpIFTGain);
      BoostTrend.Init(InpNormPeriod, true, InpIFTGain);
   }

   // Loop
   for(int i = start; i < rates_total; i++)
     {
      // 1. Current Histogram (No Boost, just visual)
      double c_dema1 = GetVal(hCurrDEMA1, 0, rates_total - 1 - i); // Note: CopyBuffer index is reverse of i?
      // WAIT. CopyBuffer with start pos: '0' is NEWEST. 'rates_total-1' is OLDEST.
      // OnCalculate 'i': 0 is OLDEST.
      // So to get matching data from CopyBuffer(handle, 0, 0, len, arr) -> arr[0] is Oldest.
      // BUT GetVal uses CopyBuffer(h, b, index, 1). 'index' in CopyBuffer is 'shift' (0=Newest).
      // So we must convert i (Oldest=0) to shift (Newest=0).
      int shift = rates_total - 1 - i;

      double c_d1 = GetVal(hCurrDEMA1, 0, shift);
      double c_d2 = GetVal(hCurrDEMA2, 0, shift);

      double hist_raw = (c_d1 - c_d2);

      // Auto-Scale Histogram to fit in window (e.g., max height 0.5)
      // Simple heuristic: Normalize by recent ATR or just simple Price scale factor?
      // Better: Since Hybrid is -1..1, we can just use a fixed multiplier for visual,
      // or track max history.
      // For this showcase, we use a static scaling factor derived from price (Percent).
      // Or safer: Normalize by TickSize * Period?
      // Simplest Visual Fix: Use IFT on Histogram too, but with lower gain.

      double hist_scaled = IFT(hist_raw / _Point * 0.1); // Quick scaling attempt
      Buf_Hist[i] = hist_scaled * 0.5; // Cap at 0.5 visual height

      // 2. Fast Signal (From InpFastTF)
      // Map Current Time -> Fast TF Time
      // CopyBuffer by Time is safest for MTF/Sandwich
      datetime t = time[i];

      double f_d1 = GetValMTF(hFastDEMA1, 0, t);
      double f_d2 = GetValMTF(hFastDEMA2, 0, t);
      double f_wpr = GetValMTF(hWPR, 0, t); // -100..0

      double fast_raw = (f_d1 - f_d2) + (1.0 + f_wpr/50.0); // Simple Mix
      Buf_FastRaw[i] = fast_raw;

      // 3. Trend Signal (From InpTrendTF)
      double t_macd = GetValMTF(hTrendMACD, 0, t);
      Buf_TrendRaw[i] = t_macd;

      // 4. Boost & Fusion
      double fast_boosted = 0;
      double trend_boosted = 0;

      // Handle Re-calculation of the last bar (Tick Update)
      if(i == rates_total - 1 && prev_calculated > rates_total - 2) {
         // We are updating the current forming bar.
         // Use UpdateLast to overwrite the booster's last value
         fast_boosted = BoostFast.UpdateLast(fast_raw);
         trend_boosted = BoostTrend.UpdateLast(t_macd);
      } else {
         // New bar (or full recalc)
         fast_boosted = BoostFast.Update(fast_raw);
         trend_boosted = BoostTrend.Update(t_macd);
      }

      Buf_Hybrid[i] = (fast_boosted * InpFastWeight) + (trend_boosted * InpTrendWeight);
      Buf_Trend[i]  = trend_boosted;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
