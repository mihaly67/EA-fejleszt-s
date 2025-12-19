//+------------------------------------------------------------------+
//|                                   HybridVolatilityIndicator_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (BB + Keltner Squeeze)                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

//--- Plot 1: BB Upper
#property indicator_label1  "BB Upper"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrAqua
#property indicator_width1  1

//--- Plot 2: BB Lower
#property indicator_label2  "BB Lower"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrAqua
#property indicator_width2  1

//--- Plot 3: Keltner Upper
#property indicator_label3  "KC Upper"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrOrange
#property indicator_width3  1

//--- Plot 4: Keltner Lower
#property indicator_label4  "KC Lower"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_DOT
#property indicator_color4  clrOrange
#property indicator_width4  1

//--- Input Parameters
input group              "=== Bollinger Settings ==="
input int                InpBBPeriod           = 20;
input double             InpBBDev              = 2.0;

input group              "=== Keltner Settings ==="
input int                InpKCPeriod           = 20;
input double             InpKCMultiplier       = 1.5;

input group              "=== Visual Settings ==="
input bool               InpShowSqueezeDots    = true; // Show dots on squeeze? (Not implemented in chart window yet)

//--- Buffers
double      BBUpperBuffer[];
double      BBLowerBuffer[];
double      KCUpperBuffer[];
double      KCLowerBuffer[];
double      SqueezeBuffer[]; // 1 = Squeeze, 0 = No

//--- Handles
int         bb_handle = INVALID_HANDLE;
int         atr_handle = INVALID_HANDLE;
int         ma_handle = INVALID_HANDLE; // For Keltner Center

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BBUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BBLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, KCUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, KCLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SqueezeBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Volatility v1.0");

   // Initialize Built-in Indicators
   bb_handle = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, InpKCPeriod);
   ma_handle = iMA(_Symbol, _Period, InpKCPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(bb_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE || ma_handle == INVALID_HANDLE)
       return INIT_FAILED;

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
   if(rates_total < InpBBPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // Copy Buffers
   double bb_upper[], bb_lower[];
   double atr_val[], ma_val[];

   CopyBuffer(bb_handle, 1, 0, rates_total, bb_upper); // 1 = Upper
   CopyBuffer(bb_handle, 2, 0, rates_total, bb_lower); // 2 = Lower
   CopyBuffer(atr_handle, 0, 0, rates_total, atr_val);
   CopyBuffer(ma_handle, 0, 0, rates_total, ma_val);

   for(int i = start; i < rates_total; i++)
   {
       // Fill Visual Buffers
       BBUpperBuffer[i] = bb_upper[i];
       BBLowerBuffer[i] = bb_lower[i];

       double kc_width = atr_val[i] * InpKCMultiplier;
       KCUpperBuffer[i] = ma_val[i] + kc_width;
       KCLowerBuffer[i] = ma_val[i] - kc_width;

       // Squeeze Detection: BB inside Keltner
       // Condition: BB Upper < KC Upper AND BB Lower > KC Lower
       if(BBUpperBuffer[i] < KCUpperBuffer[i] && BBLowerBuffer[i] > KCLowerBuffer[i])
       {
           SqueezeBuffer[i] = 1.0;
           // Visual cue could be changing line color, but MQL5 DRAW_LINE is single color per buffer.
           // Advanced visualization would require DRAW_COLOR_LINE or objects.
           // For v1.0, the crossing lines are the visual cue.
       }
       else
       {
           SqueezeBuffer[i] = 0.0;
       }
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(bb_handle);
   IndicatorRelease(atr_handle);
   IndicatorRelease(ma_handle);
}
