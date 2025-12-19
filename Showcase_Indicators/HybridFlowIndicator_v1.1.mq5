//+------------------------------------------------------------------+
//|                                        HybridFlowIndicator_v1.4.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.4 (MFI + Boosted Delta)                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.4"

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   2

// Force Fixed Range 0-100 for MFI Visibility
#property indicator_minimum 0
#property indicator_maximum 100

//--- Plot 1: MFI (Blue Line)
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_level1  20
#property indicator_level2  50 // Midpoint
#property indicator_level3  80

//--- Plot 2: Volume Delta (Scaled Histogram - Center 50)
#property indicator_label2  "Scaled Delta"
#property indicator_type2   DRAW_COLOR_HISTOGRAM2
#property indicator_style2  STYLE_SOLID
#property indicator_color2  C'0,100,0', C'100,0,0' // Dark Green, Dark Red
#property indicator_width2  4 // Wider bars

//--- Input Parameters
input group              "=== MFI Settings ==="
input int                InpMFIPeriod          = 14;

input group              "=== Delta Settings ==="
input bool               InpUseApproxDelta     = true;
input int                InpDeltaSmooth        = 3;
input int                InpNormalizationLen   = 100;    // Lookback for volume normalization
input double             InpDeltaScaleFactor   = 50.0;   // Boosted to 50.0 (fills 0-100 range)

//--- Buffers
double      MFIBuffer[];
double      DeltaStartBuffer[]; // Buffer for "50" baseline
double      DeltaEndBuffer[];   // Buffer for Value
double      DeltaColorBuffer[];

//--- Calculation Buffers
double      RawDeltaBuffer[];

//--- Handles
int         mfi_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, MFIBuffer, INDICATOR_DATA);

   // Histogram2 requires two data buffers for Start and End values
   SetIndexBuffer(1, DeltaStartBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, DeltaEndBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DeltaColorBuffer, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(4, RawDeltaBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.4");

   mfi_handle = iMFI(_Symbol, _Period, InpMFIPeriod, VOLUME_TICK);
   if(mfi_handle == INVALID_HANDLE) return INIT_FAILED;

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
   if(rates_total < InpMFIPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- MFI Calculation ---
   CopyBuffer(mfi_handle, 0, 0, rates_total, MFIBuffer);

   // --- Delta Calculation ---
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

       // 4. Fill Draw Buffers
       // Start at 50, End at 50 + offset
       DeltaStartBuffer[i] = 50.0;
       double final_val = 50.0 + scaled_offset;

       // Clamp strict limits if needed
       if(final_val > 110) final_val = 110;
       if(final_val < -10) final_val = -10;

       DeltaEndBuffer[i] = final_val;

       // Color: Positive = 0 (Green), Negative = 1 (Red)
       DeltaColorBuffer[i] = (smooth_delta >= 0) ? 0 : 1;
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
