//+------------------------------------------------------------------+
//|                                        HybridFlowIndicator_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (MFI + Bid/Ask Delta)                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: MFI
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_level1  20
#property indicator_level2  80

//--- Plot 2: Volume Delta (Histogram)
#property indicator_label2  "Delta"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrGreen, clrRed
#property indicator_width2  2

//--- Input Parameters
input group              "=== MFI Settings ==="
input int                InpMFIPeriod          = 14;

input group              "=== Delta Settings ==="
input bool               InpUseApproxDelta     = true;   // True: Candle Analysis, False: CopyTicks (Heavy)
input int                InpDeltaSmooth        = 3;      // Smoothing for Delta

//--- Buffers
double      MFIBuffer[];
double      DeltaBuffer[];
double      DeltaColorBuffer[]; // 0=Green, 1=Red

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
   SetIndexBuffer(1, DeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, DeltaColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, RawDeltaBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Flow v1.0");

   mfi_handle = iMFI(_Symbol, _Period, InpMFIPeriod, VOLUME_TICK);
   if(mfi_handle == INVALID_HANDLE) return INIT_FAILED;

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
   if(rates_total < InpMFIPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- MFI Calculation ---
   // We simply copy the built-in MFI buffer.
   CopyBuffer(mfi_handle, 0, 0, rates_total, MFIBuffer);

   // --- Delta Calculation ---
   for(int i = start; i < rates_total; i++)
   {
       double delta = 0;

       if(InpUseApproxDelta)
       {
           // Approximation: "Bull/Bear Power" of Volume
           // If Close > Open, mostly buying?
           // Better approximation: Close relative to High/Low
           double range = high[i] - low[i];
           if(range > 0)
           {
               // Position of Close within Range (0.0 to 1.0)
               double pos = (close[i] - low[i]) / range;
               // Map to -1 to +1
               double power = (pos - 0.5) * 2.0;

               // Delta = Volume * Power
               delta = (double)tick_volume[i] * power;
           }
           else
           {
               // Doji / Flat bar
               delta = 0;
           }
       }
       else
       {
           // Here we would implement CopyTicks logic.
           // For v1.0, we stick to approximation for speed.
           // Placeholder for future expansion.
           delta = 0;
       }

       RawDeltaBuffer[i] = delta;

       // Smoothing Delta for visual clarity
       double smooth_delta = 0;
       int count = 0;
       for(int j = 0; j < InpDeltaSmooth; j++)
       {
           if(i-j >= 0) { smooth_delta += RawDeltaBuffer[i-j]; count++; }
       }
       if(count > 0) smooth_delta /= count;

       DeltaBuffer[i] = smooth_delta;
       DeltaColorBuffer[i] = (smooth_delta >= 0) ? 0 : 1;
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(mfi_handle);
}
