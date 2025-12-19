//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v1.1.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.1 (Enhanced Pivot, Auto-Fibo, Trend EMA)           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.1"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Pivot Levels
#property indicator_label1  "Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrGreen
#property indicator_width3  1

//--- Plot 4-5: Trend EMAs
#property indicator_label4  "Trend EMA Fast"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_color4  clrOrange
#property indicator_width4  2

#property indicator_label5  "Trend EMA Slow"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_color5  clrDarkTurquoise
#property indicator_width5  2

//--- Input Parameters
input group              "=== Pivot Settings ==="
input bool               InpShowPivots         = true;
input ENUM_TIMEFRAMES    InpPivotTF            = PERIOD_D1;  // Pivot Timeframe
input ENUM_APPLIED_PRICE InpPivotPrice         = PRICE_CLOSE;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Auto-Fibo Settings ==="
input bool               InpShowFibo           = true;
input int                InpZigZagDepth        = 12;
input int                InpZigZagDev          = 5;
input int                InpZigZagBack         = 3;
input color              InpFiboColor          = clrGoldenrod;

//--- Buffers
double      PivotPBuffer[];
double      PivotR1Buffer[];
double      PivotS1Buffer[];
double      TrendFastBuffer[];
double      TrendSlowBuffer[];

//--- Hidden Calculation Buffers (ZigZag)
double      ZigZagBuffer[];
double      ZigZagHighBuffer[];
double      ZigZagLowBuffer[];

//--- Global Handles
int         zigzag_handle = INVALID_HANDLE;
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF                                  |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, double &P, double &R1, double &S1)
{
   // Find the start time of the HTF bar covering 'time'
   datetime htf_time = iTime(_Symbol, InpPivotTF, iBarShift(_Symbol, InpPivotTF, time));

   // We need the PREVIOUS completed HTF bar for calculation
   int shift = iBarShift(_Symbol, InpPivotTF, htf_time) + 1;

   if(shift < 0) return false;

   double high = iHigh(_Symbol, InpPivotTF, shift);
   double low  = iLow(_Symbol, InpPivotTF, shift);
   double close = iClose(_Symbol, InpPivotTF, shift);

   if(high == 0 || low == 0) return false;

   // Classic Pivot Formula
   P = (high + low + close) / 3.0;
   R1 = (2.0 * P) - low;
   S1 = (2.0 * P) - high;

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Draw Fibo Object                                         |
//+------------------------------------------------------------------+
void UpdateFibo(int rates_total, const datetime &time[], const double &zigzag[])
{
   if(!InpShowFibo) return;

   // Find last two ZigZag points
   int p1_idx = -1;
   int p2_idx = -1;
   double p1_val = 0;
   double p2_val = 0;

   for(int i = rates_total - 1; i >= 0; i--)
   {
      if(zigzag[i] != 0 && zigzag[i] != EMPTY_VALUE)
      {
         if(p1_idx == -1) { p1_idx = i; p1_val = zigzag[i]; }
         else if(p2_idx == -1) { p2_idx = i; p2_val = zigzag[i]; break; }
      }
   }

   if(p1_idx != -1 && p2_idx != -1)
   {
      string name = "HybridAutoFibo";
      if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_TIME, 0, time[p2_idx]);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p2_val);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, time[p1_idx]);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p1_val);

      ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      // Ensure visibility on current timeframe
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PivotPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PivotR1Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, PivotS1Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, TrendFastBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, TrendSlowBuffer, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v1.1");

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   if(InpShowFibo)
   {
      // Using built-in ZigZag for simplicity
      zigzag_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpZigZagDepth, InpZigZagDev, InpZigZagBack);
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
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- 1. Pivots ---
   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         double P, R1, S1;
         if(GetPivotData(time[i], P, R1, S1))
         {
            PivotPBuffer[i] = P;
            PivotR1Buffer[i] = R1;
            PivotS1Buffer[i] = S1;
         }
         else
         {
             // Fallback to previous known or 0
             if(i > 0) {
                 PivotPBuffer[i] = PivotPBuffer[i-1];
                 PivotR1Buffer[i] = PivotR1Buffer[i-1];
                 PivotS1Buffer[i] = PivotS1Buffer[i-1];
             }
         }
      }
   }

   // --- 2. Trends ---
   if(InpShowTrends)
   {
      // Optimization: Only copy what is needed if possible, but CopyBuffer handles logic well.
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFastBuffer);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlowBuffer);
   }

   // --- 3. Fibo (ZigZag based) ---
   if(InpShowFibo && zigzag_handle != INVALID_HANDLE)
   {
      double zigzags[];
      CopyBuffer(zigzag_handle, 0, 0, rates_total, zigzags);

      // Update object only on last bar update to save resources
      if(prev_calculated < rates_total)
      {
          UpdateFibo(rates_total, time, zigzags);
      }
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(InpShowFibo) ObjectDelete(0, "HybridAutoFibo");
   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
   if(zigzag_handle != INVALID_HANDLE) IndicatorRelease(zigzag_handle);
}
