//+------------------------------------------------------------------+
//|                                        Hybrid_MTF_Scalper.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 2.2 (Flatline Fix & Gradient) |
//|                                                                  |
//| INSTALLATION PATH: MQL5/Indicators/Hybrid_MTF_Scalper.mq5        |
//| DEPENDENCY: MQL5/Include/Amplitude_Booster.mqh                   |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property link      "https://github.com/mihaly67/EA-fejleszt-s"
#property version   "2.20"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   3

//--- Includes
#include "Amplitude_Booster.mqh"

//--- Plot 1: Hybrid Signal Line
#property indicator_label1  "Hybrid_Signal"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Trend Bias Line
#property indicator_label2  "Trend_Bias"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Gradient Histogram
#property indicator_label3  "Gradient_Hist"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
// Colors defined dynamically in OnInit

//==================================================================
// INPUT PARAMETERS (Flattened & Expanded)
//==================================================================

//--- Visibility & Timeframes
input bool           InpShowHybrid     = true;         // Show Hybrid Signal
input bool           InpShowTrend      = true;         // Show Trend Bias
input bool           InpShowHist       = true;         // Show Gradient Histogram
input ENUM_TIMEFRAMES InpFastTF        = PERIOD_M1;    // Fast Timeframe (Context)
input ENUM_TIMEFRAMES InpTrendTF       = PERIOD_M5;    // Trend Timeframe (Bias)

//--- Hybrid Signal Weights & Settings
input double         InpFastWeight     = 0.6;          // Fast Signal Weight (0.0-1.0)
input double         InpTrendWeight    = 0.4;          // Trend Signal Weight
input int            InpNormPeriod     = 50;           // Normalization Lookback
input double         InpIFTGain        = 1.5;          // IFT Gain (Signal Sharpness)

//--- Fast Signal Components (DEMA + WPR)
input int            InpFastDema1      = 12;           // Fast TF: DEMA Period 1
input int            InpFastDema2      = 26;           // Fast TF: DEMA Period 2
input int            InpFastWPR        = 14;           // Fast TF: WPR Period

//--- Trend Signal Components (MACD)
input int            InpTrendFastMA    = 12;           // Trend TF: MACD Fast MA
input int            InpTrendSlowMA    = 26;           // Trend TF: MACD Slow MA
input int            InpTrendSignalMA  = 9;            // Trend TF: MACD Signal MA

//--- Histogram Settings (Current TF MACD)
input int            InpHistFastMA     = 12;           // Hist TF: MACD Fast MA
input int            InpHistSlowMA     = 26;           // Hist TF: MACD Slow MA
input int            InpHistSignalMA   = 9;            // Hist TF: MACD Signal MA
input double         InpHistScale      = 1.0;          // Histogram Scale Multiplier (Visual)

//--- Colors
input color          InpColorHybrid    = clrDodgerBlue; // Color: Hybrid Signal
input color          InpColorTrend     = clrGray;       // Color: Trend Bias
input color          InpColorBullStrong= clrLime;       // Color: Hist Bull Strong
input color          InpColorBullWeak  = clrSeaGreen;   // Color: Hist Bull Weak
input color          InpColorBearStrong= clrRed;        // Color: Hist Bear Strong
input color          InpColorBearWeak  = clrMaroon;     // Color: Hist Bear Weak

//==================================================================
// BUFFERS & GLOBALS
//==================================================================
double         Buf_Hybrid[];
double         Buf_Trend[];
double         Buf_Hist[];
double         Buf_HistColors[]; // Color Index Buffer

// Calculation Buffers
double         Buf_FastRaw[];
double         Buf_TrendRaw[];
double         Buf_CurrentRaw[];

// Handles
int hFastDEMA1 = INVALID_HANDLE;
int hFastDEMA2 = INVALID_HANDLE;
int hWPR       = INVALID_HANDLE;
int hTrendMACD = INVALID_HANDLE;
int hHistMACD  = INVALID_HANDLE; // Current TF MACD for Histogram

// Boosters
CAmplitudeBooster BoostFast;
CAmplitudeBooster BoostTrend;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- 1. Set Buffers
   SetIndexBuffer(0, Buf_Hybrid, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_Trend, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_Hist, INDICATOR_DATA);
   SetIndexBuffer(3, Buf_HistColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, Buf_FastRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, Buf_TrendRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, Buf_CurrentRaw, INDICATOR_CALCULATIONS);

   //--- 2. Configure Plots
   // Plot 0: Hybrid
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorHybrid);
   if(!InpShowHybrid) PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 1: Trend
   PlotIndexSetString(1, PLOT_LABEL, "Trend Bias");
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorTrend);
   if(!InpShowTrend) PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 2: Histogram (Color)
   PlotIndexSetString(2, PLOT_LABEL, "Gradient Hist");
   // Set Palette
   PlotIndexSetInteger(2, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, InpColorBullStrong); // Index 0
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 1, InpColorBullWeak);   // Index 1
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 2, InpColorBearStrong); // Index 2
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 3, InpColorBearWeak);   // Index 3
   if(!InpShowHist) PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   //--- 3. Levels & Ranges
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.1);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.1);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.8);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -0.8);

   //--- 4. Init Boosters
   BoostFast.Init(InpNormPeriod, true, InpIFTGain);
   BoostTrend.Init(InpNormPeriod, true, InpIFTGain);

   //--- 5. Create Handles
   // Fast TF
   hFastDEMA1 = iDEMA(NULL, InpFastTF, InpFastDema1, 0, PRICE_CLOSE);
   hFastDEMA2 = iDEMA(NULL, InpFastTF, InpFastDema2, 0, PRICE_CLOSE);
   hWPR       = iWPR(NULL, InpFastTF, InpFastWPR);

   // Trend TF
   hTrendMACD = iMACD(NULL, InpTrendTF, InpTrendFastMA, InpTrendSlowMA, InpTrendSignalMA, PRICE_CLOSE);

   // Histogram (Current TF)
   hHistMACD  = iMACD(NULL, PERIOD_CURRENT, InpHistFastMA, InpHistSlowMA, InpHistSignalMA, PRICE_CLOSE);

   if(hFastDEMA1 == INVALID_HANDLE || hFastDEMA2 == INVALID_HANDLE || hWPR == INVALID_HANDLE ||
      hTrendMACD == INVALID_HANDLE || hHistMACD == INVALID_HANDLE)
     {
      Print("Error: Failed to create indicator handles!");
      return(INIT_FAILED);
     }

   // Short Name
   string name = StringFormat("HybridScalper(F:%s, T:%s)", EnumToString(InpFastTF), EnumToString(InpTrendTF));
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hFastDEMA1 != INVALID_HANDLE) IndicatorRelease(hFastDEMA1);
   if(hFastDEMA2 != INVALID_HANDLE) IndicatorRelease(hFastDEMA2);
   if(hWPR != INVALID_HANDLE)       IndicatorRelease(hWPR);
   if(hTrendMACD != INVALID_HANDLE) IndicatorRelease(hTrendMACD);
   if(hHistMACD != INVALID_HANDLE)  IndicatorRelease(hHistMACD);
  }

//+------------------------------------------------------------------+
//| Helper: Get MTF Value by Time                                    |
//+------------------------------------------------------------------+
double GetValMTF(int handle, int buffer_num, datetime time)
{
   double buf[1];
   // CopyBuffer returns -1 on error
   if(CopyBuffer(handle, buffer_num, time, 1, buf) > 0)
      return buf[0];
   return 0.0; // Return 0.0 on failure/empty
}

//+------------------------------------------------------------------+
//| Helper: Soft Normalization (Tanh approximation)                  |
//| Scales arbitrary input to roughly -1..1                          |
//+------------------------------------------------------------------+
double SoftNormalize(double x, double scale_factor)
{
   // Simple IFT-like sigmoid but without centering shift if x is already 0-centered
   // Tanh(x) = (e^2x - 1) / (e^2x + 1)
   double val = x * scale_factor;
   double e2x = MathExp(2.0 * val);
   // Prevent overflow
   if(DoubleToString(e2x) == "inf") return (val > 0) ? 1.0 : -1.0;
   return (e2x - 1.0) / (e2x + 1.0);
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
   if(rates_total < InpNormPeriod) return 0;

   //--- Start Index
   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   //--- Critical History Reset
   // If we are recalculating from the beginning, we MUST reset the Booster state.
   // The Booster depends on sequential updates.
   if(start == 0) {
      BoostFast.Init(InpNormPeriod, true, InpIFTGain);
      BoostTrend.Init(InpNormPeriod, true, InpIFTGain);
   }

   //--- Main Loop
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];

      //---------------------------------------------------------
      // 1. MACD Histogram (Gradient & Normalization)
      //---------------------------------------------------------
      // Get Main and Signal lines of MACD to calculate histogram manually or get buffer 0?
      // iMACD Mode MAIN=0, SIGNAL=1. Histogram = Main - Signal? Or just get the lines.
      // Usually MT5 iMACD buffer 0 is Main Line, buffer 1 is Signal Line.
      // Wait, standard MACD indicator: buffer 0 = Main, buffer 1 = Signal.
      // Histogram is difference.

      double macd_main = GetValMTF(hHistMACD, 0, t);
      double macd_sig  = GetValMTF(hHistMACD, 1, t);
      double hist_raw  = (macd_main - macd_sig);

      // Normalize
      // Scale factor: Tune this so typical MACD range fits into -1..1
      // Typical MACD on H1 might be 0.0005. 0.0005 * 200 = 0.1. Too small.
      // Need dynamic or aggressive scaling.
      // User requested "Manual Multiplier" -> InpHistScale.
      // Let's also divide by Point to make it symbol-independent.
      double hist_norm = SoftNormalize(hist_raw / _Point, 0.01 * InpHistScale);

      Buf_Hist[i] = hist_norm;

      // Gradient Coloring
      double prev_hist = (i > 0) ? Buf_Hist[i-1] : 0.0;
      int color_idx = 0;

      if(hist_norm >= 0) {
         // Bullish
         if(hist_norm >= prev_hist) color_idx = 0; // Rising Strong (Lime)
         else                       color_idx = 1; // Falling Weak (SeaGreen)
      } else {
         // Bearish
         if(hist_norm <= prev_hist) color_idx = 2; // Falling Strong (Red) (More negative)
         else                       color_idx = 3; // Rising Weak (Maroon) (Less negative)
      }
      Buf_HistColors[i] = color_idx;


      //---------------------------------------------------------
      // 2. Fast Signal (MTF)
      //---------------------------------------------------------
      double f_d1 = GetValMTF(hFastDEMA1, 0, t);
      double f_d2 = GetValMTF(hFastDEMA2, 0, t);
      double f_wpr = GetValMTF(hWPR, 0, t); // -100..0

      // Mix: DEMA Cross + WPR
      // DEMA Cross = (d1 - d2). WPR normalized to -0.5..+0.5
      double dema_diff = (f_d1 - f_d2) / _Point; // Points
      double wpr_norm  = (f_wpr + 50.0) / 50.0;    // -1..1

      // Raw Fast Signal
      double fast_raw = (dema_diff * 0.5) + (wpr_norm * 0.5); // Simple weighted mix
      Buf_FastRaw[i] = fast_raw;

      //---------------------------------------------------------
      // 3. Trend Signal (MTF)
      //---------------------------------------------------------
      double t_macd = GetValMTF(hTrendMACD, 0, t);
      Buf_TrendRaw[i] = t_macd / _Point; // Store in points for consistency

      //---------------------------------------------------------
      // 4. Amplitude Booster (The Magic)
      //---------------------------------------------------------
      double fast_boosted = 0.0;
      double trend_boosted = 0.0;

      // Determine if we are on the OPEN (forming) bar
      bool is_forming_bar = (i == rates_total - 1);

      // CRITICAL LOGIC:
      // To prevent flatline, we must feed data sequentially.
      // On the forming bar, we use UpdateLast() to NOT advance the internal cursor permanently.
      // On historical bars, we use Update() to advance the cursor.

      if(is_forming_bar) {
         // If we are recalculating the same bar multiple times (tick updates)
         fast_boosted = BoostFast.UpdateLast(fast_raw);
         trend_boosted = BoostTrend.UpdateLast(t_macd / _Point);
      } else {
         // We are on a finalized historical bar.
         // Note: In OnCalculate, 'i' iterates through history once.
         // But wait! If 'start' was prev_calculated-1, we might be re-processing the LAST confirmed bar?
         // No, prev_calculated is usually the count of bars.
         // If prev_calc=100, rates_total=101. start=99. i=99 (old last), i=100 (new current).
         // We must be careful not to call Update() twice for the same bar index.

         // Fix: AmplitudeBooster is simple. It pushes to a circular buffer.
         // If we call Update() multiple times for the same bar, we corrupt the buffer.
         // BUT standard OnCalculate loop logic:
         // If prev_calculated == rates_total, we only process i = rates_total-1 (update last).
         // If prev_calculated < rates_total, we process new bars.

         // We rely on the fact that 'start' is correctly set to only process NEW or CHANGED bars.
         // However, 'prev_calculated - 1' means we re-process the last bar.
         // If that last bar was previously 'forming' (UpdateLast), and now is 'history' (Update),
         // we need to transition.
         // The Booster class logic: Update() pushes NEW value. UpdateLast() overwrites LATEST value.
         // So:
         // History bar (i < rates_total-1): Always Update().
         // Current bar (i == rates_total-1): Always UpdateLast().

         // WAIT! If we re-run history (start=0), we Reset() state. Then Loop i=0..total-2 calls Update().
         // i=total-1 calls UpdateLast(). This is CORRECT.

         // What if normal tick? prev=100, total=100. start=99.
         // i=99. is_forming=true. UpdateLast(). Correct.

         // What if new bar? prev=100, total=101. start=99.
         // i=99. is_forming=false. Update(). Correct?
         // YES, because previously (at total=100), i=99 was forming, so we did UpdateLast.
         // Now it is closed. We call Update() on it.
         // WAIT. Update() pushes a NEW value. UpdateLast overwrites current head.
         // If we called UpdateLast on index 99... head is filled with 99's data.
         // If we now call Update() on index 99... we push a NEW value (index 100).
         // This is WRONG. We would duplicate index 99 data if we treated it as "New".

         // Correction of Booster Logic:
         // Update() -> Advances Head, Writes. (New Bar)
         // UpdateLast() -> Writes at Head. (Same Bar)

         // Scenario: Bar 99 is forming. We call UpdateLast(val99). Buffer head has val99.
         // ... Bar 99 closes. Bar 100 opens.
         // OnCalculate runs. prev=100, total=101. start=99.
         // Loop i=99: is_forming=false. Call Update(val99)?
         // If we call Update(), we advance head and write val99.
         // But head ALREADY has val99 from previous UpdateLast calls!
         // So we would have two copies of val99.

         // SOLUTION:
         // We only call Update() when we move to a TRULY NEW index.
         // But OnCalculate doesn't tell us "this is a new bar" explicitly, just indices.
         // We need to track the "Last Boosted Bar Index".

         // BUT, we can't store state easily in simple indicator without static/global members.
         // Actually, `Amplitude_Booster` class should handle this? No, it's a simple buffer.

         // ALTERNATIVE SAFE APPROACH (Used in robust indicators):
         // Only Recalculate History on Init.
         // On Tick:
         // If (rates_total > prev_calculated) -> New Bar Event.
         //    Call Boost.Update(val_of_previous_finished_bar).
         //    Then Boost.UpdateLast(val_of_new_current_bar).
         // Else -> Same Bar.
         //    Boost.UpdateLast(val_of_current_bar).

         // Let's implement this strictly.
         // We need to distinguish the loop behavior.

         // If start == 0:
         //    Full Rebuild. Init().
         //    Loop 0 to rates_total-2: Update().
         //    i = rates_total-1: UpdateLast(). (Actually Update() followed by internal logic? No)
         //    Use Update() for 0..total-1. UpdateLast for total-1?
         //    Let's stick to: Init sets head=-1.
         //    Update() increments head, writes.

         // Re-Build Logic:
         // Boost.Init() -> count=0.
         // Loop i=0 to rates_total-2: Boost.Update(val[i]).
         // i=rates_total-1: Boost.Update(val[i]). (First time seeing this bar)

         // Normal Tick Logic (rates_total == prev_calculated):
         // We only process i = rates_total-1.
         // Boost.UpdateLast(val[i]).

         // New Bar Logic (rates_total > prev_calculated):
         // We have new bars. Usually 1.
         // The previous bar (prev_calculated-1) was updated via UpdateLast.
         // Now it is finalized.
         // DO WE NEED TO DO ANYTHING?
         // The buffer HEAD contains the value of (prev-1).
         // We just need to ADVANCE to the new bar.
         // So for the NEW bar `i`, we call Update(val[i]).

         // BUT wait. If we used UpdateLast() on the previous bar, the value is properly stored at Head.
         // So when New Bar arrives, we just call Update() with the NEW bar's value.
         // It advances Head (locking in the previous value) and writes the new one.

         // PROBLEM: The `start` index in OnCalculate includes the previous bar (prev-1).
         // If we process `i = prev-1` again... and call Update()... we duplicate it.
         // If we process `i = prev-1` and call UpdateLast()... we just refresh it (fine).

         // ALGO:
         // 1. If start == 0:
         //    Init().
         //    Loop i = 0 to rates_total-1:
         //       Boost.Update(val[i]).
         //       (Note: For the very last one, it's effectively an Update, we act as if it's new).

         // 2. If start > 0:
         //    Loop i = start to rates_total-1:
         //       If i >= prev_calculated: // This is a NEW bar index we haven't seen in 'prev' count
         //           Boost.Update(val[i])
         //       Else: // This is an existing bar index (likely rates_total-1)
         //           Boost.UpdateLast(val[i])

         if(start == 0) {
            // Full History Rebuild
            fast_boosted = BoostFast.Update(fast_raw);
            trend_boosted = BoostTrend.Update(t_macd / _Point);
         } else {
            // Incremental
            if(i >= prev_calculated) {
               // New Bar Index -> Push New
               fast_boosted = BoostFast.Update(fast_raw);
               trend_boosted = BoostTrend.Update(t_macd / _Point);
            } else {
               // Existing Bar Index (Recalc) -> Overwrite Last
               fast_boosted = BoostFast.UpdateLast(fast_raw);
               trend_boosted = BoostTrend.UpdateLast(t_macd / _Point);
            }
         }
      }

      // Fusion
      Buf_Hybrid[i] = (fast_boosted * InpFastWeight) + (trend_boosted * InpTrendWeight);
      Buf_Trend[i]  = trend_boosted;
     }

   return(rates_total);
  }
