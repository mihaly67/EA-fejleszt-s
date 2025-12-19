//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v1.2.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.2 (Multi-TF Pivot & HTF Fibo)                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.2"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Main Pivot (Primary)
#property indicator_label1  "Primary Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Primary Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Primary Pivot S1"
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
input group              "=== Pivot Hierarchy ==="
input bool               InpShowPivots         = true;
input ENUM_TIMEFRAMES    InpPrimaryPivotTF     = PERIOD_H4;  // Fő Pivot (Pl. H4 - Erős Támasz)
input bool               InpShowSecondaryPivot = true;       // Másodlagos (Pl. H1 - Mikro Támasz)
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_H1;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Smart Fibo Settings ==="
input bool               InpShowFibo           = true;
input ENUM_TIMEFRAMES    InpFiboSourceTF       = PERIOD_M15; // Melyik idősík hullámait nézzük? (Pl. M15 zajszűréshez)
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

//--- Global Handles
int         zigzag_handle = INVALID_HANDLE;
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF                                  |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, ENUM_TIMEFRAMES tf, double &P, double &R1, double &S1)
{
   datetime htf_time = iTime(_Symbol, tf, iBarShift(_Symbol, tf, time));
   int shift = iBarShift(_Symbol, tf, htf_time) + 1; // Previous completed bar

   if(shift < 0) return false;

   double high = iHigh(_Symbol, tf, shift);
   double low  = iLow(_Symbol, tf, shift);
   double close = iClose(_Symbol, tf, shift);

   if(high == 0 || low == 0) return false;

   P = (high + low + close) / 3.0;
   R1 = (2.0 * P) - low;
   S1 = (2.0 * P) - high;

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Draw Secondary Pivot Lines (Objects)                     |
//+------------------------------------------------------------------+
void UpdateSecondaryPivot(datetime time, double P, double R1, double S1)
{
    // Draw horizontal lines for secondary pivot levels using Objects (to avoid buffer limits)
    // We update them to the current bar's levels
    string p_name = "SecPivot_P";
    string r_name = "SecPivot_R1";
    string s_name = "SecPivot_S1";

    // Create or Move
    if(ObjectFind(0, p_name) < 0) ObjectCreate(0, p_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, p_name, OBJPROP_PRICE, P);
    ObjectSetInteger(0, p_name, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, p_name, OBJPROP_STYLE, STYLE_DOT);

    if(ObjectFind(0, r_name) < 0) ObjectCreate(0, r_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, r_name, OBJPROP_PRICE, R1);
    ObjectSetInteger(0, r_name, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, r_name, OBJPROP_STYLE, STYLE_DOT);

    if(ObjectFind(0, s_name) < 0) ObjectCreate(0, s_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, s_name, OBJPROP_PRICE, S1);
    ObjectSetInteger(0, s_name, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, s_name, OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Helper: Draw Fibo from HTF ZigZag                                |
//+------------------------------------------------------------------+
void UpdateFibo(int rates_total, const datetime &time[])
{
   if(!InpShowFibo || zigzag_handle == INVALID_HANDLE) return;

   // We need to fetch ZigZag data from the SOURCE TF, not current TF
   // This is tricky because buffers are aligned to Source TF bars.
   // We must CopyBuffer from the handle (which is on InpFiboSourceTF)
   // and map the times to current chart.

   double zigzag_buffer[];
   datetime zigzag_times[];

   int copied = CopyBuffer(zigzag_handle, 0, 0, 100, zigzag_buffer); // Copy last 100 bars of HTF
   if(copied <= 0) return;

   // We also need times of HTF bars to map them
   CopyTime(_Symbol, InpFiboSourceTF, 0, 100, zigzag_times);

   // Find last two non-zero ZigZag points in HTF data
   int p1_idx = -1;
   int p2_idx = -1;
   double p1_val = 0;
   double p2_val = 0;
   datetime p1_time = 0;
   datetime p2_time = 0;

   // Iterate backwards through HTF buffer
   for(int i = copied - 1; i >= 0; i--)
   {
       if(zigzag_buffer[i] != 0 && zigzag_buffer[i] != EMPTY_VALUE)
       {
           if(p1_idx == -1) {
               p1_idx = i;
               p1_val = zigzag_buffer[i];
               p1_time = zigzag_times[i];
           }
           else if(p2_idx == -1) {
               p2_idx = i;
               p2_val = zigzag_buffer[i];
               p2_time = zigzag_times[i];
               break;
           }
       }
   }

   if(p1_idx != -1 && p2_idx != -1)
   {
      string name = "HybridSmartFibo";
      if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);

      // Use the TIME from HTF to place object on Current Chart
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, p2_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p2_val);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, p1_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p1_val);

      ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

      // Add description
      string desc = StringFormat("Fibo (%s)", EnumToString(InpFiboSourceTF));
      ObjectSetString(0, name, OBJPROP_TEXT, desc);
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v1.2");

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   if(InpShowFibo)
   {
      // ZigZag on Specified Source TF (e.g., M15) to filter noise
      zigzag_handle = iCustom(_Symbol, InpFiboSourceTF, "Examples\\ZigZag", InpZigZagDepth, InpZigZagDev, InpZigZagBack);
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

   // --- 1. Primary Pivots (Buffer based) ---
   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         double P, R1, S1;
         if(GetPivotData(time[i], InpPrimaryPivotTF, P, R1, S1))
         {
            PivotPBuffer[i] = P;
            PivotR1Buffer[i] = R1;
            PivotS1Buffer[i] = S1;
         }
         else if(i > 0)
         {
             PivotPBuffer[i] = PivotPBuffer[i-1];
             PivotR1Buffer[i] = PivotR1Buffer[i-1];
             PivotS1Buffer[i] = PivotS1Buffer[i-1];
         }
      }

      // Secondary Pivot (Visual Only - Last Bar)
      if(InpShowSecondaryPivot)
      {
          double P2, R12, S12;
          if(GetPivotData(time[rates_total-1], InpSecondaryPivotTF, P2, R12, S12))
          {
              UpdateSecondaryPivot(time[rates_total-1], P2, R12, S12);
          }
      }
   }

   // --- 2. Trends ---
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFastBuffer);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlowBuffer);
   }

   // --- 3. Smart Fibo ---
   if(InpShowFibo && prev_calculated < rates_total) // Update only on new bar to save CPU
   {
       UpdateFibo(rates_total, time);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(InpShowFibo) ObjectDelete(0, "HybridSmartFibo");
   if(InpShowSecondaryPivot)
   {
       ObjectDelete(0, "SecPivot_P");
       ObjectDelete(0, "SecPivot_R1");
       ObjectDelete(0, "SecPivot_S1");
   }

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
   if(zigzag_handle != INVALID_HANDLE) IndicatorRelease(zigzag_handle);
}
