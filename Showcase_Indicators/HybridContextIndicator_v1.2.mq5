//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v2.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 2.0 (Intelligent Auto-Pivot & Scalping Fibo)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.0"

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
input group              "=== Intelligent Pivot Settings ==="
input bool               InpShowPivots         = true;
input bool               InpAutoMode           = true;       // Automatikus idősík választás (M1->M15, M5->H1...)
input ENUM_TIMEFRAMES    InpManualPivotTF      = PERIOD_H4;  // Manuális beállítás ha Auto=False
input bool               InpShowSecondaryPivot = true;       // Másodlagos (Pl. H1 - Mikro Támasz)
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_H1;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Smart Fibo Settings ==="
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

//--- Global Handles
int         zigzag_handle = INVALID_HANDLE;
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//--- State Variables
ENUM_TIMEFRAMES current_pivot_tf;

//+------------------------------------------------------------------+
//| Helper: Determine Optimal Pivot Timeframe                        |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetOptimalPivotTF()
{
    if(!InpAutoMode) return InpManualPivotTF;

    // Logic: Scalping (M1-M5) needs nearby pivots (M15-M30)
    //        Day Trading (M15-H1) needs H4-D1

    if(_Period <= PERIOD_M5) return PERIOD_M30;   // M1, M5 -> M30 Pivots (Good balance)
    if(_Period <= PERIOD_M30) return PERIOD_H4;   // M15, M30 -> H4 Pivots
    if(_Period <= PERIOD_H4) return PERIOD_D1;    // H1, H4 -> D1 Pivots

    return PERIOD_W1;
}

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
    string p_name = "SecPivot_P";
    string r_name = "SecPivot_R1";
    string s_name = "SecPivot_S1";

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
//| Helper: Draw Fibo from Dynamic Pivot Source TF                   |
//+------------------------------------------------------------------+
void UpdateFibo(int rates_total, const datetime &time[])
{
   if(!InpShowFibo || zigzag_handle == INVALID_HANDLE) return;

   // Use the same timeframe as the Pivots for consistency
   ENUM_TIMEFRAMES fibo_tf = current_pivot_tf;

   double zigzag_buffer[];
   datetime zigzag_times[];

   int copied = CopyBuffer(zigzag_handle, 0, 0, 100, zigzag_buffer);
   if(copied <= 0) return;

   CopyTime(_Symbol, fibo_tf, 0, 100, zigzag_times);

   int p1_idx = -1;
   int p2_idx = -1;
   double p1_val = 0;
   double p2_val = 0;
   datetime p1_time = 0;
   datetime p2_time = 0;

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

      ObjectSetInteger(0, name, OBJPROP_TIME, 0, p2_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p2_val);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, p1_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p1_val);

      ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

      // Make line thinner for scalping clarity
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

      string desc = StringFormat("Auto Fibo (%s)", EnumToString(fibo_tf));
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v2.0 (Auto)");

   // Determine TF Logic
   current_pivot_tf = GetOptimalPivotTF();

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   if(InpShowFibo)
   {
      // ZigZag on DYNAMIC TF to match Pivots
      zigzag_handle = iCustom(_Symbol, current_pivot_tf, "Examples\\ZigZag", InpZigZagDepth, InpZigZagDev, InpZigZagBack);
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
         // Use the determined DYNAMIC TF
         if(GetPivotData(time[i], current_pivot_tf, P, R1, S1))
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
   if(InpShowFibo && prev_calculated < rates_total) // Update only on new bar
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
