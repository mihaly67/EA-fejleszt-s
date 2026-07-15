//+------------------------------------------------------------------+
//|                                       HybridFlowIndicator_v1.10.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.10 (Hybrid MFI + Delta + VROC - Auto Scale)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.10"

#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   2

// REMOVED Fixed Scale Properties to allow Auto-Scaling by default
// #property indicator_minimum -50
// #property indicator_maximum 150

//--- Plot 1: MFI (Blue Line) with VROC Color
#property indicator_label1  "Hybrid MFI"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_style1  STYLE_SOLID
// Palette defined dynamically via inputs
#property indicator_color1  clrDodgerBlue, clrDarkViolet
#property indicator_width1  2
#property indicator_level1  20
#property indicator_level2  50 // Midpoint
#property indicator_level3  80

//--- Plot 2: Volume Delta (Scaled Histogram - Center 50)
#property indicator_label2  "Scaled Delta"
#property indicator_type2   DRAW_COLOR_HISTOGRAM2
#property indicator_style2  STYLE_SOLID
// Palette defined dynamically via inputs
#property indicator_color2  clrForestGreen, clrFireBrick
#property indicator_width2  4 // Wider bars

//--- Input Parameters
input group              "=== Visual Settings ==="
input color              InpMfiColor           = clrDodgerBlue;  // MFI Normal
input color              InpVrocColor          = clrDarkViolet;  // MFI Spike (VROC)
input color              InpDeltaUpColor       = clrForestGreen; // Delta Up
input color              InpDeltaDownColor     = clrFireBrick;   // Delta Down

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
double      MFIBuffer[];
double      MFIColorBuffer[];
double      DeltaStartBuffer[]; // Buffer for "50" baseline
double      DeltaEndBuffer[];   // Buffer for Value
double      DeltaColorBuffer[];

//--- Calculation Buffers
double      RawDeltaBuffer[];
double      RawMFIBuffer[]; // Added for raw MFI storage

//--- Handles
int         mfi_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, MFIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MFIColorBuffer, INDICATOR_COLOR_INDEX);

   // Histogram2 requires two data buffers for Start and End values
   SetIndexBuffer(2, DeltaStartBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DeltaEndBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, DeltaColorBuffer, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(5, RawDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, RawMFIBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.10");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   mfi_handle = iMFI(_Symbol, _Period, InpMFIPeriod, VOLUME_TICK);
   if(mfi_handle == INVALID_HANDLE) return INIT_FAILED;

   // Set Visuals (Conditional Scaling)
   if(InpUseFixedScale) {
       IndicatorSetDouble(INDICATOR_MINIMUM, InpScaleMin);
       IndicatorSetDouble(INDICATOR_MAXIMUM, InpScaleMax);
   }
   // Else: Auto-Scale is active by default in separate window if min/max not set

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpMfiColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpVrocColor);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, InpDeltaUpColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, InpDeltaDownColor);

   return INIT_SUCCEEDED;
}

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

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- MFI Calculation ---
   // Read MFI into Raw buffer. CopyBuffer defaults to Newest-at-0 if AsSeries is false? No.
   // If AsSeries=false (default for dynamic array), CopyBuffer fills 0,1,2...
   // BUT CopyBuffer copies FROM the source. Source[0] goes to Target[0].
   // Standard Indicators are Series. So Source[0] (Newest) -> Target[0].
   // This means RawMFIBuffer[0] IS NEWEST.
   // The loop below iterates 'i' from Oldest to Newest.
   // So RawMFIBuffer[i] is accessing WRONG END (Oldest loop index accessing Newest data).

   // FIX: Set RawMFIBuffer to AsSeries to explicitly handle indexing or just rely on 'CopyBuffer' filling logic?
   // Simplest: Set AsSeries(true). CopyBuffer(..., 0, count, ...).
   // Then RawMFIBuffer[0] = Newest.
   // Loop access: RawMFIBuffer[rates_total - 1 - i].

   ArraySetAsSeries(RawMFIBuffer, true);
   if(CopyBuffer(mfi_handle, 0, 0, rates_total, RawMFIBuffer) <= 0) return 0;

   // --- Delta & VROC Calculation ---
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
               double power = (pos - 0.5) * 2.0; // -1 to +1
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
           // Ratio is approx -1 to 1
           double ratio = smooth_delta / max_vol;
           scaled_offset = ratio * InpDeltaScaleFactor;
       }

       // 4. Fill Delta Buffers (UNBOUNDED)
       DeltaStartBuffer[i] = 50.0;
       double final_val = 50.0 + scaled_offset;

       // NO CLAMPING
       DeltaEndBuffer[i] = final_val;
       DeltaColorBuffer[i] = (smooth_delta >= 0) ? 0 : 1;

       // 5. HYBRID MFI LOGIC (Inject Delta into MFI Line)
       // Standard MFI (0-100) + Offset (-50 to +50 approx)
       // Use RawMFIBuffer as source so we don't accumulate on existing MFIBuffer
       // Alignment: 'i' is Oldest (0) -> Newest. RawMFI is Series (0=Newest).
       MFIBuffer[i] = RawMFIBuffer[rates_total - 1 - i] + scaled_offset;

       // 6. VROC Logic
       if(InpShowVROC && i >= InpVROCPeriod && (double)tick_volume[i - InpVROCPeriod] > 0)
       {
           double vroc = ((double)tick_volume[i] - (double)tick_volume[i - InpVROCPeriod]) / (double)tick_volume[i - InpVROCPeriod] * 100.0;

           if(vroc > InpVROCThreshold)
               MFIColorBuffer[i] = 1; // Spike
           else
               MFIColorBuffer[i] = 0; // Normal
       }
       else
       {
           MFIColorBuffer[i] = 0;
       }
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
