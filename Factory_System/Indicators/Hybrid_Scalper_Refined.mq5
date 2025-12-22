//+------------------------------------------------------------------+
//|                                     Hybrid_Scalper_Refined.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 4.1 (Alpha Logic + Calibrated)|
//|                                                                  |
//| LEÍRÁS:                                                          |
//| Az Alpha verzió finomított változata Tick Átlagolással.          |
//| Kalibrált "Saturation Points" bemenetekkel a könnyű hangoláshoz. |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "4.10"
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   2

//--- Includes
#include "Amplitude_Booster.mqh"

//--- Plot 1: Hybrid Signal Line
#property indicator_label1  "Hybrid_Signal"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Trend Bias Line
#property indicator_label2  "Trend_Bias"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//==================================================================
// INPUT PARAMETERS
//==================================================================
input group "Fast Signal (Current TF)"
input int      InpTickAvgTime = 10;   // Tick Átlagolás (mp) [Zajszűrés]
input int      InpFastPeriod1 = 12;   // DEMA Fast
input int      InpFastPeriod2 = 26;   // DEMA Slow
input int      InpWPRPeriod   = 14;   // WPR Period
input double   InpFastWeight  = 0.6;  // Fast Signal Weight (0.0-1.0)

// --- CALIBRATION ---
// Forex: 10, Gold: 50, Index: 20, Crypto: 100
input int      InpSaturationPoints = 20; // Telítési Pont (DEMA érzékenység)

input group "Slow Trend (Higher TF)"
input ENUM_TIMEFRAMES InpSlowTF = PERIOD_M5; // Trend Timeframe
input int      InpSlowMACD1   = 24;   // Slow MACD Fast
input int      InpSlowMACD2   = 52;   // Slow MACD Slow
input double   InpSlowWeight  = 0.4;  // Slow Signal Weight
input int      InpTrendSaturation = 50; // Trend Telítési Pont (Bias érzékenység)

input group "Common"
input int      InpNormPeriod  = 50;   // Normalization Lookback
input double   InpIFTGain     = 1.5;  // IFT Gain

//==================================================================
// BUFFERS & GLOBALS
//==================================================================
double         Buf_Hybrid[];
double         Buf_Trend[];

// Internal Calc Buffers
double         Buf_FastRaw[];
double         Buf_SlowRaw[];
double         Buf_TickAvg[]; // Tárolja a tick-átlagolt árat

// Handles
int hFastDEMA1 = INVALID_HANDLE;
int hFastDEMA2 = INVALID_HANDLE;
int hWPR       = INVALID_HANDLE;
int hSlowMACD  = INVALID_HANDLE;

// Boosters
CAmplitudeBooster BoostFast;
CAmplitudeBooster BoostSlow;

// Tick Buffer (Struct Array)
struct TickNode {
   long     msc;
   double   price;
};
TickNode       TickBuffer[];

// Derived Scales
double         dema_scale_factor;
double         trend_scale_factor;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Validate TF
   if(InpSlowTF <= Period()) {
      Print("Figyelem: A Trend TF (Slow) legyen magasabb, mint a jelenlegi chart TF!");
   }

   // Set Scales (1.0 / Saturation)
   // Ha Saturation=20, Scale=0.05. Tanh(20*0.05) = Tanh(1) = 0.76 (Erős jel)
   if(InpSaturationPoints < 1) dema_scale_factor = 1.0;
   else dema_scale_factor = 1.0 / (double)InpSaturationPoints;

   if(InpTrendSaturation < 1) trend_scale_factor = 1.0;
   else trend_scale_factor = 1.0 / (double)InpTrendSaturation;

   // Buffers
   SetIndexBuffer(0, Buf_Hybrid, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_Trend, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_FastRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, Buf_SlowRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, Buf_TickAvg, INDICATOR_CALCULATIONS);

   // Plot Names
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetString(1, PLOT_LABEL, "Trend Bias");

   // Levels
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.8);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -0.8);

   // Init Boosters
   BoostFast.Init(InpNormPeriod, true, InpIFTGain);
   BoostSlow.Init(InpNormPeriod, true, InpIFTGain);

   // Handles
   hFastDEMA1 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod1, 0, PRICE_CLOSE);
   hFastDEMA2 = iDEMA(NULL, PERIOD_CURRENT, InpFastPeriod2, 0, PRICE_CLOSE);
   hWPR       = iWPR(NULL, PERIOD_CURRENT, InpWPRPeriod);
   hSlowMACD  = iMACD(NULL, InpSlowTF, InpSlowMACD1, InpSlowMACD2, 9, PRICE_CLOSE);

   if(hFastDEMA1 == INVALID_HANDLE || hFastDEMA2 == INVALID_HANDLE ||
      hWPR == INVALID_HANDLE || hSlowMACD == INVALID_HANDLE)
     {
      Print("Hiba: Handle létrehozása sikertelen.");
      return(INIT_FAILED);
     }

   string name = StringFormat("HybridScalper(Tick:%ds, Sat:%d)", InpTickAvgTime, InpSaturationPoints);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

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
   if(hSlowMACD != INVALID_HANDLE)  IndicatorRelease(hSlowMACD);
   ArrayFree(TickBuffer);
  }

//+------------------------------------------------------------------+
//| Helper: Soft Normalization                                       |
//+------------------------------------------------------------------+
double SoftNormalize(double x, double scale_factor)
{
   double val = x * scale_factor;
   double e2x = MathExp(2.0 * val);
   if(DoubleToString(e2x) == "inf") return (val > 0) ? 1.0 : -1.0;
   return (e2x - 1.0) / (e2x + 1.0);
}

//+------------------------------------------------------------------+
//| Helper: Get MTF Value (Safe)                                     |
//+------------------------------------------------------------------+
double GetValMTF(int handle, int buffer_num, datetime time)
{
   double buf[1];
   if(CopyBuffer(handle, buffer_num, time, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Helper: Get Latest Value (For Current Bar Ticks)                 |
//+------------------------------------------------------------------+
double GetValLatest(int handle, int buffer_num)
{
   double buf[1];
   if(CopyBuffer(handle, buffer_num, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Helper: Update Tick Average                                      |
//+------------------------------------------------------------------+
double UpdateTickAverage(double current_price)
{
   long sym_time = SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC);

   // Add
   int size = ArraySize(TickBuffer);
   ArrayResize(TickBuffer, size + 1);
   TickBuffer[size].msc = sym_time;
   TickBuffer[size].price = current_price;

   // Remove Old
   long cutoff = sym_time - (InpTickAvgTime * 1000);
   int remove_cnt = 0;
   for(int i=0; i<ArraySize(TickBuffer); i++) {
      if(TickBuffer[i].msc < cutoff) remove_cnt++;
      else break;
   }
   if(remove_cnt > 0) ArrayRemove(TickBuffer, 0, remove_cnt);

   // Avg
   size = ArraySize(TickBuffer);
   if(size == 0) return current_price;
   double sum = 0;
   for(int i=0; i<size; i++) sum += TickBuffer[i].price;
   return sum / size;
}

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
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

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   //--- History Reset Logic
   if(start == 0) {
      BoostFast.Init(InpNormPeriod, true, InpIFTGain);
      BoostSlow.Init(InpNormPeriod, true, InpIFTGain);
   }

   for(int i = start; i < rates_total; i++)
     {
      bool is_forming = (i == rates_total - 1);

      // 1. Tick Average (Live only) - For Visual Verification
      if(is_forming) {
         Buf_TickAvg[i] = UpdateTickAverage(close[i]);
      } else {
         Buf_TickAvg[i] = (high[i]+low[i]+close[i])/3.0;
      }

      // 2. Fast Signal (Alpha: DEMA Diff + WPR)
      double d1_buf[1], d2_buf[1], wpr_buf[1];
      double d1=0, d2=0, wpr=0;

      if(CopyBuffer(hFastDEMA1, 0, rates_total-1-i, 1, d1_buf)>0) d1 = d1_buf[0];
      if(CopyBuffer(hFastDEMA2, 0, rates_total-1-i, 1, d2_buf)>0) d2 = d2_buf[0];
      if(CopyBuffer(hWPR, 0, rates_total-1-i, 1, wpr_buf)>0)      wpr = wpr_buf[0];

      // ZeroLag MACD (Points)
      double macd_raw = d1 - d2;

      // Normalize using Calibrated Scale (SaturationPoints)
      // Input is Points (e.g. 20 * _Point). Divide by _Point first.
      double macd_points = macd_raw / _Point;
      double macd_norm = SoftNormalize(macd_points, dema_scale_factor);

      // WPR Normalize (-100..0 -> -1..1)
      // Original logic: 1 + (WPR / 50).
      // If WPR=-100 -> 1-2 = -1. If WPR=0 -> 1.
      double wpr_norm = 1.0 + (wpr / 50.0);

      // Mix
      double fast_raw = (macd_norm * (1.0 - InpFastWeight)) + (wpr_norm * InpFastWeight);
      Buf_FastRaw[i] = fast_raw;

      // 3. Slow Signal (MTF)
      datetime t = time[i];
      double slow_macd_raw = 0.0;

      if(is_forming) {
         // Live: Get Latest (Index 0) to avoid lag
         slow_macd_raw = GetValLatest(hSlowMACD, 0);
      } else {
         // History: Time-based mapping
         slow_macd_raw = GetValMTF(hSlowMACD, 0, t);
      }

      // Normalize Trend
      double slow_norm = SoftNormalize(slow_macd_raw / _Point, trend_scale_factor);
      Buf_SlowRaw[i] = slow_norm;

      // 4. Booster Logic
      double fast_boosted = 0;
      double slow_boosted = 0;

      if(start == 0) {
         fast_boosted = BoostFast.Update(fast_raw);
         slow_boosted = BoostSlow.Update(slow_norm);
      } else {
         if(i >= prev_calculated) {
             fast_boosted = BoostFast.Update(fast_raw);
             slow_boosted = BoostSlow.Update(slow_norm);
         } else {
             fast_boosted = BoostFast.UpdateLast(fast_raw);
             slow_boosted = BoostSlow.UpdateLast(slow_norm);
         }
      }

      // 5. Final Output
      // Hybrid Fusion (Alpha Logic): Combine Fast (Current TF) + Slow (Trend TF)
      double hybrid = (fast_boosted * InpFastWeight) + (slow_boosted * InpSlowWeight);

      // Clamp to prevent overshoot
      if(hybrid > 1.05) hybrid = 1.05;
      if(hybrid < -1.05) hybrid = -1.05;

      Buf_Hybrid[i] = hybrid;
      Buf_Trend[i]  = slow_boosted;
     }

   return(rates_total);
  }
