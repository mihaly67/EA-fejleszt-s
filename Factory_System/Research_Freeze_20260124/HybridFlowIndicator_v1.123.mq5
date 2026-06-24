//+------------------------------------------------------------------+
//|                                     HybridFlowIndicator_v1.123.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.123 (FIX: Histogram Decoupling & Visual Gain)     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.123"

/*
   ===================================================================
   HYBRID FLOW INDICATOR - v1.123
   ===================================================================
   VÁLTOZÁSOK (v1.123):
   1. HISTOGRAM DECOUPLING (Leválasztás):
      - Bevezetve az `InpHistogramVisualGain` paraméter.
      - A Hisztogramok (Delta Barok) magassága mostantól külön skálázható,
        anélkül, hogy a Kék Görbe (Hybrid MFI) alakját módosítaná.
      - Ez lehetővé teszi, hogy a "túl lapos" barok láthatóak legyenek,
        miközben a görbe matematikai integritása megmarad.

   JAVÍTÁSOK (v1.122-ből):
   - Logic Inversion Fix (Helyes időrend).
   - Async Stability (Történeti adatok védelme).

   ===================================================================
   ÉRTELMEZÉS:
   - KÉK GÖRBE: MFI + Delta (Eredeti skálázással).
   - SIGNAL BAROK: Delta Spread (Megnövelt vizuális skálázással).
*/

#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   3

//--- Plot 1: MFI Line (Color)
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue,clrDarkViolet // 0=Normal, 1=Spike
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Delta Up (Green Histogram)
#property indicator_label2  "Delta Up"
#property indicator_type2   DRAW_HISTOGRAM2
#property indicator_color2  clrForestGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

//--- Plot 3: Delta Down (Red Histogram)
#property indicator_label3  "Delta Down"
#property indicator_type3   DRAW_HISTOGRAM2
#property indicator_color3  clrFireBrick
#property indicator_style3  STYLE_SOLID
#property indicator_width3  4

//--- Levels
#property indicator_level1 20.0
#property indicator_level2 50.0
#property indicator_level3 80.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
input group              "=== Scale Settings ==="
input bool               InpUseFixedScale      = false;          // Use Fixed Scale? (False = Auto-Scale)
input double             InpScaleMin           = -100.0;         // Fixed Min (if enabled)
input double             InpScaleMax           = 200.0;          // Fixed Max (if enabled)

input group              "=== MFI Settings ==="
input int                InpMFIPeriod          = 14;

input group              "=== VROC Settings ==="
input bool               InpShowVROC           = true;
input int                InpVROCPeriod         = 10;
input double             InpVROCThreshold      = 20.0; // % Change to trigger alert color

input group              "=== Delta Settings ==="
input bool               InpUseApproxDelta     = true;
input int                InpDeltaSmooth        = 3;
input int                InpNormalizationLen   = 100;    // Lookback for volume normalization
input double             InpDeltaScaleFactor   = 50.0;   // Curve Influence Factor (Hybrid Strength)
input double             InpHistogramVisualGain= 3.0;    // [NEW] Histogram Visual Multiplier (Doesn't affect Curve)

//--- Buffers
double      MfiBuffer[];      // Unified MFI Buffer (Index 0)
double      MfiColorBuffer[]; // Color Index (Index 1)
double      DeltaUpStart[];   // (Index 2)
double      DeltaUpEnd[];     // (Index 3)
double      DeltaDownStart[]; // (Index 4)
double      DeltaDownEnd[];   // (Index 5)

//--- Calculation Buffers (Visible in Data Window)
double      RawDeltaBuffer[]; // (Index 6)
double      HybridMFIBuffer[];// (Index 7)

//--- Internal Arrays (Dynamic, NOT in SetIndexBuffer)
double      RawMFIBuffer[];   // Stores Raw MFI Data (Series Indexing)

//--- Handles & Globals
int         mfi_handle = INVALID_HANDLE;
int         g_prev_rates_total = 0; // State tracking for History Expansion

//+------------------------------------------------------------------+
//| Helper: Get Max Volume in window                                 |
//+------------------------------------------------------------------+
double GetMaxVolume(const long &vol[], int index, int len)
{
    double max_v = 1.0;
    int start = MathMax(0, index - len + 1);
    for(int i = start; i <= index; i++)
    {
        if((double)vol[i] > max_v) max_v = (double)vol[i];
    }
    return max_v;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // MFI Plots (Color Line)
   SetIndexBuffer(0, MfiBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MfiColorBuffer, INDICATOR_COLOR_INDEX);

   // Delta Plots (Split Histogram2)
   SetIndexBuffer(2, DeltaUpStart, INDICATOR_DATA);
   SetIndexBuffer(3, DeltaUpEnd, INDICATOR_DATA);
   SetIndexBuffer(4, DeltaDownStart, INDICATOR_DATA);
   SetIndexBuffer(5, DeltaDownEnd, INDICATOR_DATA);

   // Calc Buffers
   SetIndexBuffer(6, RawDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, HybridMFIBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.123");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   // Visual Settings
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0); // Histogram2 base
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   // Set Levels (Explicit)
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 50);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 80);

   // Enforce DimGray Color
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrDimGray);


   mfi_handle = iMFI(_Symbol, _Period, InpMFIPeriod, VOLUME_TICK);
   if(mfi_handle == INVALID_HANDLE) return INIT_FAILED;

   if(InpUseFixedScale) {
       IndicatorSetDouble(INDICATOR_MINIMUM, InpScaleMin);
       IndicatorSetDouble(INDICATOR_MAXIMUM, InpScaleMax);
   }

   g_prev_rates_total = 0; // Reset history tracker

   return INIT_SUCCEEDED;
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
   if(rates_total < InpMFIPeriod || rates_total < InpVROCPeriod) return 0;

   // --- HISTORY CONSISTENCY CHECK ---
   if (g_prev_rates_total > 0 && (rates_total > g_prev_rates_total + 10)) {
       g_prev_rates_total = rates_total;
       return 0; // Force Full Recalc (History Update Detected)
   }
   g_prev_rates_total = rates_total;

   // --- FETCH EXTERNAL DATA (SYNC CHECK) ---
   ArraySetAsSeries(RawMFIBuffer, true);
   int res = CopyBuffer(mfi_handle, 0, 0, rates_total, RawMFIBuffer);

   if(res <= 0) return 0;
   if(res < rates_total - 5) return 0; // Async Load Protection

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
       // 1. Calculate Raw Delta
       double delta = 0;
       if(InpUseApproxDelta)
       {
           double range = high[i] - low[i];
           if(range > 0)
           {
               double pos = (close[i] - low[i]) / range;
               double power = (pos - 0.5) * 2.0;
               delta = (double)tick_volume[i] * power;
           }
       }
       RawDeltaBuffer[i] = delta;

       // 2. Smooth Delta
       double smooth_delta = 0;
       int count = 0;
       for(int j = 0; j < InpDeltaSmooth; j++)
       {
           if(i-j >= 0) { smooth_delta += RawDeltaBuffer[i-j]; count++; }
       }
       if(count > 0) smooth_delta /= count;

       // 3. Scaling Logic (Center at 50)
       double max_vol = GetMaxVolume(tick_volume, i, InpNormalizationLen);

       double offset_curve = 0.0;
       double offset_hist = 0.0;

       if(max_vol > 0)
       {
           double ratio = smooth_delta / max_vol;

           // A: Curve Offset (Uses original ScaleFactor)
           offset_curve = ratio * InpDeltaScaleFactor;

           // B: Histogram Offset (Uses EXTRA Visual Gain)
           offset_hist = offset_curve * InpHistogramVisualGain;
       }

       // 4. Fill Delta Buffers (Split for UX)
       // Center is 50.0
       double val_hist = 50.0 + offset_hist;

       // Reset all
       DeltaUpStart[i] = 0.0; DeltaUpEnd[i] = 0.0;
       DeltaDownStart[i] = 0.0; DeltaDownEnd[i] = 0.0;

       if (smooth_delta >= 0) {
           DeltaUpStart[i] = 50.0;
           DeltaUpEnd[i] = val_hist;
           // Hide Down
           DeltaDownStart[i] = 50.0;
           DeltaDownEnd[i] = 50.0;
       } else {
           DeltaDownStart[i] = 50.0;
           DeltaDownEnd[i] = val_hist;
           // Hide Up
           DeltaUpStart[i] = 50.0;
           DeltaUpEnd[i] = 50.0;
       }

       // 5. HYBRID MFI LOGIC
       int series_idx = rates_total - 1 - i;
       double raw_mfi_val = 50.0;
       if (series_idx >= 0 && series_idx < res) {
           raw_mfi_val = RawMFIBuffer[series_idx];
       }

       // Note: Curve uses 'offset_curve' (Unboosted), NOT 'offset_hist'
       double hybrid_val = raw_mfi_val + offset_curve;

       MfiBuffer[i] = hybrid_val;
       HybridMFIBuffer[i] = hybrid_val;

       // 6. VROC Logic
       bool is_spike = false;
       if(InpShowVROC && i >= InpVROCPeriod && (double)tick_volume[i - InpVROCPeriod] > 0)
       {
           double vroc = ((double)tick_volume[i] - (double)tick_volume[i - InpVROCPeriod]) / (double)tick_volume[i - InpVROCPeriod] * 100.0;
           if(vroc > InpVROCThreshold) is_spike = true;
       }

       if (is_spike) MfiColorBuffer[i] = 1.0;
       else MfiColorBuffer[i] = 0.0;
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
