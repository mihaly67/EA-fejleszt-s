//+------------------------------------------------------------------+
//|                                     HybridFlowIndicator_v1.125.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.125 (FIX: Layering - MFI Curve on Top)            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.125"

/*
   ===================================================================
   HYBRID FLOW INDICATOR - v1.125
   ===================================================================
   VÁLTOZÁSOK (v1.125):
   1. VISUAL LAYERING (Rétegezés):
      - Megcseréltük a kirajzolási sorrendet (Z-Order).
      - Az MFI Görbe (DRAW_COLOR_LINE) most az UTOLSÓ helyen van definiálva.
      - Ez biztosítja, hogy a görbe a Delta Hisztogramok FÖLÖTT jelenjen meg,
        és ne takarják ki.

   BUFFER INDEX VÁLTOZÁS:
   - Index 0-1: Delta Up
   - Index 2-3: Delta Down
   - Index 4-5: MFI Line (Color)

   EA FIGYELEM:
   - A Mimic_Trap_Research_EA-t frissíteni kell az új buffer indexekhez!
*/

#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   3

//--- REORDERED PLOTS FOR LAYERING ---

//--- Plot 1: Delta Up (Green Histogram) - DRAWN FIRST (BACKGROUND)
#property indicator_label1  "Delta Up"
#property indicator_type1   DRAW_HISTOGRAM2
#property indicator_color1  clrForestGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4

//--- Plot 2: Delta Down (Red Histogram) - DRAWN SECOND (BACKGROUND)
#property indicator_label2  "Delta Down"
#property indicator_type2   DRAW_HISTOGRAM2
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

//--- Plot 3: MFI Line (Color) - DRAWN LAST (FOREGROUND)
#property indicator_label3  "MFI"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrDodgerBlue,clrDarkViolet // 0=Normal, 1=Spike
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Levels
#property indicator_level1 20.0
#property indicator_level2 50.0
#property indicator_level3 80.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
// Scale Settings
input bool               InpUseFixedScale      = false;          // [SCALE] Use Fixed Scale?
input double             InpScaleMin           = -100.0;         // [SCALE] Fixed Min
input double             InpScaleMax           = 200.0;          // [SCALE] Fixed Max

// MFI Settings
input int                InpMFIPeriod          = 14;             // [MFI] Period

// VROC Settings
input bool               InpShowVROC           = true;           // [VROC] Show VROC?
input int                InpVROCPeriod         = 10;             // [VROC] Period
input double             InpVROCThreshold      = 20.0;           // [VROC] Alert Threshold %

// Delta Settings
input bool               InpUseApproxDelta     = true;           // [DELTA] Use Approx Delta
input int                InpDeltaSmooth        = 3;              // [DELTA] Smoothing
input int                InpNormalizationLen   = 100;            // [DELTA] Norm Length
input double             InpDeltaScaleFactor   = 50.0;           // [DELTA] Curve Factor
input double             InpHistogramVisualGain= 3.0;            // [DELTA] Visual Gain (Hist)

//--- Buffers (Re-mapped)
double      DeltaUpStart[];   // (Index 0) - Plot 1
double      DeltaUpEnd[];     // (Index 1) - Plot 1
double      DeltaDownStart[]; // (Index 2) - Plot 2
double      DeltaDownEnd[];   // (Index 3) - Plot 2
double      MfiBuffer[];      // (Index 4) - Plot 3
double      MfiColorBuffer[]; // (Index 5) - Plot 3

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
   // MAPPING UPDATED FOR Z-ORDER

   // Plot 1: Delta Up
   SetIndexBuffer(0, DeltaUpStart, INDICATOR_DATA);
   SetIndexBuffer(1, DeltaUpEnd, INDICATOR_DATA);

   // Plot 2: Delta Down
   SetIndexBuffer(2, DeltaDownStart, INDICATOR_DATA);
   SetIndexBuffer(3, DeltaDownEnd, INDICATOR_DATA);

   // Plot 3: MFI (Top Layer)
   SetIndexBuffer(4, MfiBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, MfiColorBuffer, INDICATOR_COLOR_INDEX);

   // Calc Buffers (Unchanged indices)
   SetIndexBuffer(6, RawDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, HybridMFIBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.125");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   // Visual Settings
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0); // Histogram2 base (Up)
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0); // Histogram2 base (Down)

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
