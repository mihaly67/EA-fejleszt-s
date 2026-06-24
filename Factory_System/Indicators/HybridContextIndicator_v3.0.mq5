//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v3.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.0 (Manual Lock Fibo, 3-Tier Pivots, Inverse Fibo)  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.0"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Main Pivot (Primary - Micro)
#property indicator_label1  "Micro Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrBlue
#property indicator_width1  1

#property indicator_label2  "Micro Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Micro Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrGreen
#property indicator_width3  1

//--- Plot 4-5: Trend EMAs (Optional Visual)
#property indicator_label4  "Trend EMA Fast"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_color4  clrOrange
#property indicator_width4  1

#property indicator_label5  "Trend EMA Slow"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_color5  clrDarkTurquoise
#property indicator_width5  1

//--- Input Parameters
input group              "=== Intelligent Pivot System (3-Tier) ==="
input bool               InpShowPivots         = true;
// Tier 1: Micro (M1/M5 Scalping)
input ENUM_TIMEFRAMES    InpMicroPivotTF       = PERIOD_M15;
// Tier 2: Secondary (Support/Resistance)
input bool               InpShowSecondaryPivot = true;
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_H1;
// Tier 3: Tertiary (Big Picture Bias)
input bool               InpShowTertiaryPivot  = true;
input ENUM_TIMEFRAMES    InpTertiaryPivotTF    = PERIOD_H4;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Smart Fibo Settings ==="
input bool               InpShowFibo           = true;
input bool               InpInverseFibo        = false;      // Swap 0 and 100 levels
input int                InpSwingLookback      = 20;         // Lookback for High/Low
input color              InpFiboColor          = clrGoldenrod;

//--- Buffers
double      PivotPBuffer[];
double      PivotR1Buffer[];
double      PivotS1Buffer[];
double      TrendFastBuffer[];
double      TrendSlowBuffer[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//--- State Variables
bool        m_manual_lock = false; // If true, auto-update is paused
string      fibo_name = "HybridSmartFibo";

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF                                  |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, ENUM_TIMEFRAMES tf, double &P, double &R1, double &S1)
{
   datetime htf_time = iTime(_Symbol, tf, iBarShift(_Symbol, tf, time));
   int shift = iBarShift(_Symbol, tf, htf_time) + 1;

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
//| Helper: Draw Pivot Lines (Objects)                               |
//+------------------------------------------------------------------+
void UpdatePivotObject(string prefix, datetime time, double P, double R1, double S1, ENUM_LINE_STYLE style, int width)
{
    string p_name = prefix + "_P";
    string r_name = prefix + "_R1";
    string s_name = prefix + "_S1";

    // P
    if(ObjectFind(0, p_name) < 0) ObjectCreate(0, p_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, p_name, OBJPROP_PRICE, P);
    ObjectSetInteger(0, p_name, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, p_name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, p_name, OBJPROP_WIDTH, width);

    // R1
    if(ObjectFind(0, r_name) < 0) ObjectCreate(0, r_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, r_name, OBJPROP_PRICE, R1);
    ObjectSetInteger(0, r_name, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, r_name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, r_name, OBJPROP_WIDTH, width);

    // S1
    if(ObjectFind(0, s_name) < 0) ObjectCreate(0, s_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, s_name, OBJPROP_PRICE, S1);
    ObjectSetInteger(0, s_name, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, s_name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, s_name, OBJPROP_WIDTH, width);
}

//+------------------------------------------------------------------+
//| Helper: Update Fibo (Automated)                                  |
//+------------------------------------------------------------------+
void UpdateFiboNative(const datetime &time[])
{
   if(!InpShowFibo) return;

   // Check Manual Lock
   if(m_manual_lock)
   {
       // Ensure description shows locked status
       if(ObjectFind(0, fibo_name) >= 0)
       {
           string current_desc = ObjectGetString(0, fibo_name, OBJPROP_TEXT);
           if(StringFind(current_desc, "[MANUAL]") < 0)
               ObjectSetString(0, fibo_name, OBJPROP_TEXT, current_desc + " [MANUAL]");
       }
       return;
   }

   // 1. Get HTF Data (Highs/Lows) - Using MicroPivotTF as baseline for swings
   int lookback = InpSwingLookback * 2;
   double highs[];
   double lows[];
   datetime times[];

   if(CopyHigh(_Symbol, InpMicroPivotTF, 0, lookback, highs) <= 0) return;
   if(CopyLow(_Symbol, InpMicroPivotTF, 0, lookback, lows) <= 0) return;
   if(CopyTime(_Symbol, InpMicroPivotTF, 0, lookback, times) <= 0) return;

   // 2. Simple Swing Detection
   int hh_idx = -1;
   int ll_idx = -1;
   double max_h = -DBL_MAX;
   double min_l = DBL_MAX;

   // Search recent history
   for(int i = 0; i < lookback; i++)
   {
       if(highs[i] > max_h) { max_h = highs[i]; hh_idx = i; }
       if(lows[i] < min_l)  { min_l = lows[i];  ll_idx = i; }
   }

   // 3. Determine Direction
   if(hh_idx != -1 && ll_idx != -1 && hh_idx != ll_idx)
   {
       datetime t1, t2;
       double p1, p2;

       if(hh_idx > ll_idx) // Recent High, Old Low -> Uptrend
       {
           // Normal: 0 at Low, 100 at High (Retracement goes down)
           // Inverse: 0 at High, 100 at Low (Extension goes up)
           if (!InpInverseFibo)
           {
               t1 = times[ll_idx]; p1 = min_l; // 100% (Start)
               t2 = times[hh_idx]; p2 = max_h; // 0% (End)
           }
           else
           {
               t1 = times[hh_idx]; p1 = max_h;
               t2 = times[ll_idx]; p2 = min_l;
           }
       }
       else // Recent Low, Old High -> Downtrend
       {
            if (!InpInverseFibo)
            {
               t1 = times[hh_idx]; p1 = max_h;
               t2 = times[ll_idx]; p2 = min_l;
            }
            else
            {
               t1 = times[ll_idx]; p1 = min_l;
               t2 = times[hh_idx]; p2 = max_h;
            }
       }

       if(ObjectFind(0, fibo_name) < 0) ObjectCreate(0, fibo_name, OBJ_FIBO, 0, 0, 0);

       ObjectSetInteger(0, fibo_name, OBJPROP_TIME, 0, t1);
       ObjectSetDouble(0, fibo_name, OBJPROP_PRICE, 0, p1);
       ObjectSetInteger(0, fibo_name, OBJPROP_TIME, 1, t2);
       ObjectSetDouble(0, fibo_name, OBJPROP_PRICE, 1, p2);

       ObjectSetInteger(0, fibo_name, OBJPROP_COLOR, InpFiboColor);
       ObjectSetInteger(0, fibo_name, OBJPROP_RAY_RIGHT, true);
       ObjectSetInteger(0, fibo_name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
       ObjectSetInteger(0, fibo_name, OBJPROP_WIDTH, 1);
       // Levels Color manual set required sometimes for visibility
       ObjectSetInteger(0, fibo_name, OBJPROP_LEVELCOLOR, InpFiboColor);

       string desc = StringFormat("Auto Fibo (%s)", EnumToString(InpMicroPivotTF));
       if(InpInverseFibo) desc += " [INV]";
       ObjectSetString(0, fibo_name, OBJPROP_TEXT, desc);
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.0");

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   // Enable Chart Events for Manual Override
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, true);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ChartEvent Handler for Manual Lock                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Detect Dragging or Selection of Fibo
    if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
    {
        if(sparam == fibo_name)
        {
            if(!m_manual_lock)
            {
                Print("HybridContext: Manual Fibo Override Activated.");
                m_manual_lock = true;
                ObjectSetString(0, fibo_name, OBJPROP_TEXT, "Fibo [MANUAL LOCK]");
            }
        }
    }

    // Reset Logic: Click on a specific button or key?
    // For now, simpler: Double Click on the Fibo to unlock?
    // CHARTEVENT_OBJECT_CLICK is unreliable for Fibo lines.
    // Let's use a key press 'R' (Reset) if mouse is on chart.
    if(id == CHARTEVENT_KEYDOWN)
    {
        if(lparam == 'R' || lparam == 'r') // Key Code
        {
             if(m_manual_lock)
             {
                 Print("HybridContext: Manual Fibo Lock RELEASED.");
                 m_manual_lock = false;
                 // Force update next tick
             }
        }
    }
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

   // --- 1. Micro Pivots (Buffer based - Main Charts) ---
   // Using Micro Pivot TF settings
   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         double P, R1, S1;
         if(GetPivotData(time[i], InpMicroPivotTF, P, R1, S1))
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

      // Secondary (Objects)
      if(InpShowSecondaryPivot)
      {
          double P2, R12, S12;
          // Calculate only for latest bar to update lines
          if(GetPivotData(time[rates_total-1], InpSecondaryPivotTF, P2, R12, S12))
          {
              UpdatePivotObject("SecPivot", time[rates_total-1], P2, R12, S12, STYLE_DASH, 1);
          }
      }

      // Tertiary (Objects)
      if(InpShowTertiaryPivot)
      {
          double P3, R13, S13;
          if(GetPivotData(time[rates_total-1], InpTertiaryPivotTF, P3, R13, S13))
          {
              UpdatePivotObject("TerPivot", time[rates_total-1], P3, R13, S13, STYLE_DASHDOT, 1);
          }
      }
   }

   // --- 2. Trends ---
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFastBuffer);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlowBuffer);
   }

   // --- 3. Smart Fibo (Native + Manual Lock) ---
   // Update logic only if not locked
   if(InpShowFibo)
   {
       UpdateFiboNative(time);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   // Cleanup
   if(InpShowFibo) ObjectDelete(0, fibo_name);

   if(InpShowSecondaryPivot)
   {
       ObjectDelete(0, "SecPivot_P");
       ObjectDelete(0, "SecPivot_R1");
       ObjectDelete(0, "SecPivot_S1");
   }
   if(InpShowTertiaryPivot)
   {
       ObjectDelete(0, "TerPivot_P");
       ObjectDelete(0, "TerPivot_R1");
       ObjectDelete(0, "TerPivot_S1");
   }

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}
