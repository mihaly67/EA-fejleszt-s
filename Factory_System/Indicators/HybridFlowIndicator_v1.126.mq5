//+------------------------------------------------------------------+
//|                                     HybridFlowIndicator_v1.126.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.126 (3 Output Buffers: MFI, Delta, ROC)           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.126"

/*
   ===================================================================
   HYBRID FLOW INDICATOR - v1.126
   ===================================================================
   VÁLTOZÁSOK (v1.126):
   - MFI vonal egyszínű (DRAW_LINE), eltávolítva a spike színezés.
   - Delta hisztogram összevonva egyetlen DRAW_COLOR_HISTOGRAM2 plotba.
   - Hozzáadva egy DRAW_NONE típusú puffer a ROC érték számításához (EA-hoz).
   - Teljes mértékben 3 adat puffert szolgáltat az EA-nak (MFI, Delta, ROC).

   BUFFER INDEXEK (EA szempontjából, CopyBuffer-rel olvasandó):
   - 0: MFI érték (Buffer 0)
   - 2: Delta érték (Buffer 2, a DeltaEnd puffer, ami a kilengést adja az 50-es bázistól)
   - 4: ROC érték (Buffer 4, DRAW_NONE puffer)
*/

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   3

//--- REORDERED PLOTS FOR LAYERING ---

//--- Plot 1: MFI Line (DRAWN FIRST - BACKGROUND)
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Delta Histogram (DRAWN SECOND - FOREGROUND)
#property indicator_label2  "Delta"
#property indicator_type2   DRAW_COLOR_HISTOGRAM2
#property indicator_color2  clrForestGreen,clrFireBrick // 0=Up, 1=Down
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

//--- Plot 3: VROC (DRAWN NONE - INVISIBLE)
#property indicator_label3  "VROC"
#property indicator_type3   DRAW_NONE


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
input int                InpMFIPeriod          = 5;              // [MFI] Period

// VROC Settings
input bool               InpShowVROC           = true;           // [VROC] Show VROC?
input int                InpVROCPeriod         = 5;              // [VROC] Period
input double             InpVROCThreshold      = 20.0;           // [VROC] Alert Threshold %

// Delta Settings
input bool               InpUseApproxDelta     = true;           // [DELTA] Use Approx Delta
input int                InpDeltaSmooth        = 3;              // [DELTA] Smoothing
input int                InpNormalizationLen   = 100;            // [DELTA] Norm Length
input double             InpDeltaScaleFactor   = 50.0;           // [DELTA] Curve Factor
input double             InpHistogramVisualGain= 3.0;            // [DELTA] Visual Gain (Hist)

//--- Buffers (Re-mapped for v1.126)
// Buffer 0: MFI
double      MfiBuffer[];      // (Index 0) - Plot 1 (EA reads this: index 0)

// Buffer 1-3: Delta
double      DeltaStart[];     // (Index 1) - Plot 2 (Base 50.0)
double      DeltaEnd[];       // (Index 2) - Plot 2 (Value) (EA reads this: index 2)
double      DeltaColor[];     // (Index 3) - Plot 2 (Color Index)

// Buffer 4: ROC
double      RocBuffer[];      // (Index 4) - Plot 3 (EA reads this: index 4)

//--- Calculation Buffers (Visible in Data Window)
double      RawDeltaBuffer[]; // (Index 5)
double      HybridMFIBuffer[];// (Index 6)

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
   // Plot 1: MFI (Now a simple line, index 0)
   SetIndexBuffer(0, MfiBuffer, INDICATOR_DATA);

   // Plot 2: Delta (Histogram2, index 1 for start, 2 for end, 3 for color)
   SetIndexBuffer(1, DeltaStart, INDICATOR_DATA);
   SetIndexBuffer(2, DeltaEnd, INDICATOR_DATA);
   SetIndexBuffer(3, DeltaColor, INDICATOR_COLOR_INDEX);

   // Plot 3: ROC (DRAW_NONE, index 4)
   SetIndexBuffer(4, RocBuffer, INDICATOR_DATA);

   // Calc Buffers (index 5, 6)
   SetIndexBuffer(5, RawDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, HybridMFIBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.126");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   // Visual Settings
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0); // Histogram2 base

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

   // Force update of current bar (Tick-by-Tick fix for EA/CSV)
   if (prev_calculated == rates_total && start < rates_total - 1) start = rates_total - 1;

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

       // 4. Fill Delta Buffers
       // Center is 50.0
       double val_hist = 50.0 + offset_hist;

       DeltaStart[i] = 50.0;
       DeltaEnd[i] = val_hist;

       if (smooth_delta >= 0) {
           DeltaColor[i] = 0.0; // Green
       } else {
           DeltaColor[i] = 1.0; // Red
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
       double vroc = 0.0;
       if(InpShowVROC && i >= InpVROCPeriod && (double)tick_volume[i - InpVROCPeriod] > 0)
       {
           vroc = ((double)tick_volume[i] - (double)tick_volume[i - InpVROCPeriod]) / (double)tick_volume[i - InpVROCPeriod] * 100.0;
       }
       RocBuffer[i] = vroc;
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
