//+------------------------------------------------------------------+
//|                                     HybridFlowIndicator_v1.121.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.121 (Fix Levels & Comments)                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.121"

/*
   ===================================================================
   HYBRID FLOW INDICATOR - ÉRTELMEZÉS
   ===================================================================
   Ez az indikátor a pénzáramlást (Money Flow) és a volumen alapú
   nyomást (Buying/Selling Pressure) méri. A klasszikus MFI és a
   volumen-delta elemzés hibridje.

   1. SZINTEK (Levels):
      - 20.0: Túladott (Oversold) zóna határa.
              (Ha a vonal ez alatt van, az eladók kimerülhettek -> Vétel esélye).
      - 50.0: Egyensúlyi szint (Középvonal).
              (Felette a vevők, alatta az eladók dominálnak).
      - 80.0: Túlvett (Overbought) zóna határa.
              (Ha a vonal e felett van, a vevők kimerülhettek -> Eladás esélye).

   2. VISUALS (Megjelenés):
      - MFI Vonal (Színes):
        Kék = Normál állapot.
        Lila = Spike (Hirtelen volumen megugrás -> VROC > Threshold).
      - Hisztogramok (Delta):
        Zöld (Delta Up) = Vételi nyomás dominál.
        Piros (Delta Down) = Eladási nyomás dominál.
        A hisztogramok a középvonalról (50.0) indulnak.

   3. HASZNÁLAT:
      - Trendkövetés:
        Ha az indikátor tartósan 50 felett van + Zöld hisztogram -> UpTrend.
        Ha az indikátor tartósan 50 alatt van + Piros hisztogram -> DownTrend.
      - Fordulatok:
        Extrém értékek (20 alatt / 80 felett) elérése és onnan való visszatérés.
      - Volumen Tüskék (Lila):
        Gyakran jelzik a mozgás végét vagy egy erős kitörés kezdetét.
*/

#property indicator_separate_window
#property indicator_buffers 11
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
input double             InpDeltaScaleFactor   = 50.0;   // Boosted to 50.0

//--- Buffers
double      MfiBuffer[];      // Unified MFI Buffer
double      MfiColorBuffer[]; // Color Index
double      DeltaUpStart[];
double      DeltaUpEnd[];
double      DeltaDownStart[];
double      DeltaDownEnd[];

//--- Calculation Buffers
double      RawDeltaBuffer[];
double      RawMFIBuffer[]; // For Raw MFI
double      HybridMFIBuffer[]; // Calculated Hybrid MFI

//--- Handles
int         mfi_handle = INVALID_HANDLE;

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
   SetIndexBuffer(7, RawMFIBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, HybridMFIBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.121");
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

   // Correct Indexing for External Data
   ArraySetAsSeries(RawMFIBuffer, true);
   if(CopyBuffer(mfi_handle, 0, 0, rates_total, RawMFIBuffer) <= 0) return 0;

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
       double scaled_offset = 0.0;

       if(max_vol > 0)
       {
           double ratio = smooth_delta / max_vol;
           scaled_offset = ratio * InpDeltaScaleFactor;
       }

       // 4. Fill Delta Buffers (Split for UX)
       // Center is 50.0
       double final_val = 50.0 + scaled_offset;

       // Reset all
       DeltaUpStart[i] = 0.0; DeltaUpEnd[i] = 0.0;
       DeltaDownStart[i] = 0.0; DeltaDownEnd[i] = 0.0;

       if (smooth_delta >= 0) {
           DeltaUpStart[i] = 50.0;
           DeltaUpEnd[i] = final_val;
           // Ensure Down is 0/Empty (or 50/50 invisible)
           DeltaDownStart[i] = 50.0;
           DeltaDownEnd[i] = 50.0;
       } else {
           DeltaDownStart[i] = 50.0;
           DeltaDownEnd[i] = final_val;
           DeltaUpStart[i] = 50.0;
           DeltaUpEnd[i] = 50.0;
       }

       // 5. HYBRID MFI LOGIC
       double raw_mfi_val = RawMFIBuffer[rates_total - 1 - i];
       double hybrid_val = raw_mfi_val + scaled_offset;
       MfiBuffer[i] = hybrid_val;

       // 6. VROC Logic (Color Switch)
       bool is_spike = false;
       if(InpShowVROC && i >= InpVROCPeriod && (double)tick_volume[i - InpVROCPeriod] > 0)
       {
           double vroc = ((double)tick_volume[i] - (double)tick_volume[i - InpVROCPeriod]) / (double)tick_volume[i - InpVROCPeriod] * 100.0;
           if(vroc > InpVROCThreshold) is_spike = true;
       }

       if (is_spike) {
           MfiColorBuffer[i] = 1.0; // Violet (Spike)
       } else {
           MfiColorBuffer[i] = 0.0; // Blue (Normal)
       }
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
