//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.16.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.16 (Historical Breakout Search)                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.16"

#property indicator_chart_window
// 3 Tiers * 3 Lines = 9 Buffers + 2 Trends = 11 Buffers
#property indicator_buffers 11
#property indicator_plots   11

//--- 1. MICRO PIVOT (ZigZag Fast) - DOT
#property indicator_label1  "Micro Pivot P (Hidden)"
#property indicator_type1   DRAW_NONE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrNONE
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

//--- 2. SECONDARY PIVOT (ZigZag Slow) - DASHDOT
#property indicator_label4  "Secondary Pivot P (Hidden)"
#property indicator_type4   DRAW_NONE
#property indicator_style4  STYLE_DASHDOT
#property indicator_color4  clrNONE
#property indicator_width4  1

#property indicator_label5  "Secondary Pivot R1"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_DASHDOT
#property indicator_color5  clrRed
#property indicator_width5  1

#property indicator_label6  "Secondary Pivot S1"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_DASHDOT
#property indicator_color6  clrGreen
#property indicator_width6  1

//--- 3. TERTIARY PIVOT (ZigZag Trend) - SOLID
#property indicator_label7  "Tertiary Pivot P (Hidden)"
#property indicator_type7   DRAW_NONE
#property indicator_style7  STYLE_SOLID
#property indicator_color7  clrNONE
#property indicator_width7  1

#property indicator_label8  "Tertiary Pivot R1"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_SOLID
#property indicator_color8  clrRed
#property indicator_width8  1

#property indicator_label9  "Tertiary Pivot S1"
#property indicator_type9   DRAW_LINE
#property indicator_style9  STYLE_SOLID
#property indicator_color9  clrGreen
#property indicator_width9  1

//--- 4. TRENDS
#property indicator_label10 "Trend EMA Fast"
#property indicator_type10  DRAW_LINE
#property indicator_style10 STYLE_SOLID
#property indicator_color10 clrOrange
#property indicator_width10 1

#property indicator_label11 "Trend EMA Slow"
#property indicator_type11  DRAW_LINE
#property indicator_style11 STYLE_SOLID
#property indicator_color11 clrDarkTurquoise
#property indicator_width11 1

//--- Input Parameters
input group              "=== Global Switches ==="
input bool               InpShowPivots         = true; // Master Switch: Enable/Disable All Pivots
input bool               InpShowTrends         = true; // Master Switch: Enable/Disable EMAs
input int                InpMaxHistoryBars     = 5000; // Deep scan limit for historical levels

input group              "=== Auto Fibo Settings ==="
input bool               InpShowFibo           = false; // Master Fibo Switch (Micro Only)
input int                InpFiboMicroHistory   = 0;     // History Steps (0=Current Swing, 1=Prev, etc.)

input group              "=== Micro ZigZag (Fast) Settings ==="
input int                InpMicroDepth         = 5;
input int                InpMicroDeviation     = 5;
input int                InpMicroBackstep      = 3;
input ENUM_LINE_STYLE    InpMicroStyle         = STYLE_DOT;
input int                InpMicroWidth         = 1;
input color              InpMicroColorR1       = clrRed;
input color              InpMicroColorS1       = clrGreen;

input group              "=== Secondary ZigZag (Slow) Settings ==="
input int                InpSecDepth           = 30;
input int                InpSecDeviation       = 10;
input int                InpSecBackstep        = 5;
input ENUM_LINE_STYLE    InpSecStyle           = STYLE_DASHDOT;
input int                InpSecWidth           = 2; // Increased visibility
input color              InpSecColorR1         = clrRed;
input color              InpSecColorS1         = clrGreen;

input group              "=== Tertiary ZigZag (Trend) Settings ==="
input bool               InpUseTertiary        = true; // Toggle Third Pivot
input int                InpTerDepth           = 60;
input int                InpTerDeviation       = 10;
input int                InpTerBackstep        = 5;
input ENUM_LINE_STYLE    InpTerStyle           = STYLE_SOLID;
input int                InpTerWidth           = 1;
input color              InpTerColorR1         = clrRed;
input color              InpTerColorS1         = clrGreen;

input group              "=== Trend Settings ==="
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers
double      MicroP[], MicroR1[], MicroS1[];
double      SecP[], SecR1[], SecS1[];
double      TerP[], TerR1[], TerS1[];
double      TrendFast[], TrendSlow[];

//--- ZigZag Helper Buffers (Internal)
double      MicroZZBuffer[];
double      SecZZBuffer[];
double      TerZZBuffer[];

//--- Global Handles
int         micro_zz_handle = INVALID_HANDLE;
int         sec_zz_handle   = INVALID_HANDLE;
int         ter_zz_handle   = INVALID_HANDLE;
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Micro
   SetIndexBuffer(0, MicroP, INDICATOR_DATA);
   SetIndexBuffer(1, MicroR1, INDICATOR_DATA);
   SetIndexBuffer(2, MicroS1, INDICATOR_DATA);

   // Apply Inputs
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMicroWidth);

   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMicroColorR1);

   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpMicroColorS1);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0.0);

   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSecWidth);

   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpSecColorR1);

   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpSecColorS1);

   // 3. Tertiary
   SetIndexBuffer(6, TerP, INDICATOR_DATA);
   SetIndexBuffer(7, TerR1, INDICATOR_DATA);
   SetIndexBuffer(8, TerS1, INDICATOR_DATA);

   PlotIndexSetInteger(6, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpTerWidth);

   PlotIndexSetInteger(7, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpTerColorR1);

   PlotIndexSetInteger(8, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpTerColorS1);

   // 4. Trends
   SetIndexBuffer(9, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(10, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.16");

   //--- Initialize ZigZag Handles (Only if Enabled)
   if(InpShowPivots)
   {
      // Micro
      micro_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
      if(micro_zz_handle == INVALID_HANDLE) micro_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);

      // Secondary
      sec_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
      if(sec_zz_handle == INVALID_HANDLE) sec_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);

      // Tertiary
      if(InpUseTertiary)
      {
         ter_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpTerDepth, InpTerDeviation, InpTerBackstep);
         if(ter_zz_handle == INVALID_HANDLE) ter_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpTerDepth, InpTerDeviation, InpTerBackstep);
      }
   }

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Find Next Historic Resistance > Price                            |
//+------------------------------------------------------------------+
double FindHistoricResistance(const double &buffer[], const double &high[], int start_idx, double price_level)
{
   // Loop backwards from start_idx to limit
   int limit = start_idx - InpMaxHistoryBars;
   if (limit < 0) limit = 0;

   for (int k = start_idx; k >= limit; k--)
   {
      double val = buffer[k];
      // Check if it's a valid ZigZag High
      if (val != 0 && val != EMPTY_VALUE)
      {
          // Is it a High? (Match with High price)
          if(MathAbs(val - high[k]) < _Point)
          {
             // Is it higher than our breakout price?
             if (val > price_level) return val;
          }
      }
   }
   return -1.0; // Not found (ATH)
}

//+------------------------------------------------------------------+
//| Find Next Historic Support < Price                               |
//+------------------------------------------------------------------+
double FindHistoricSupport(const double &buffer[], const double &low[], int start_idx, double price_level)
{
   int limit = start_idx - InpMaxHistoryBars;
   if (limit < 0) limit = 0;

   for (int k = start_idx; k >= limit; k--)
   {
      double val = buffer[k];
      // Check if it's a valid ZigZag Low
      if (val != 0 && val != EMPTY_VALUE)
      {
          // Is it a Low?
          if(MathAbs(val - low[k]) < _Point)
          {
             // Is it lower than our breakdown price?
             if (val < price_level) return val;
          }
      }
   }
   return -1.0; // Not found (ATL)
}

//+------------------------------------------------------------------+
//| Update Auto Fibo Object                                          |
//+------------------------------------------------------------------+
void UpdateAutoFibo(const int rates_total, const datetime &time[], const double &zz_buffer[], const double &close[])
{
   string name = "MicroFibo";

   if(!InpShowFibo) {
      if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
      return;
   }

   // 1. Find Points (Base Swing)
   int p2_idx = -1; // End Point (Newer)
   int p1_idx = -1; // Start Point (Older)
   int found_count = 0;

   int target_idx = InpFiboMicroHistory + 1; // +1 to skip active leg

   for(int i=rates_total-1; i>=0; i--) {
      double val = zz_buffer[i];
      if(val != 0 && val != EMPTY_VALUE) {
         if(found_count == target_idx) {
             p2_idx = i;
         }
         if(found_count == target_idx + 1) {
             p1_idx = i;
             break;
         }
         found_count++;
      }
   }

   if(p1_idx == -1 || p2_idx == -1) return; // Not enough history

   // 2. Logic to Extend Fibo if Price Breaks 0 or 100
   double level0 = zz_buffer[p1_idx];
   double level100 = zz_buffer[p2_idx];
   double current_price = close[rates_total-1];

   // Scenario A: Up Trend (Start=Low, End=High) -> Level0 < Level100
   if(level0 < level100) {
       // Breakout Up (Price > 100)
       if(current_price > level100) {
           // Search backwards from p2_idx-1 for a higher peak
           for(int k=p2_idx-1; k>=0; k--) {
               if(zz_buffer[k] != 0 && zz_buffer[k] != EMPTY_VALUE) {
                   if(zz_buffer[k] > current_price) {
                       // Found a higher historic peak that encloses price
                       p2_idx = k; // Move End Point
                       break;
                   }
               }
           }
       }
       // Breakdown Down (Price < 0)
       if(current_price < level0) {
           // Search backwards from p1_idx-1 for a lower valley
           for(int k=p1_idx-1; k>=0; k--) {
               if(zz_buffer[k] != 0 && zz_buffer[k] != EMPTY_VALUE) {
                   if(zz_buffer[k] < current_price) {
                       p1_idx = k; // Move Start Point
                       break;
                   }
               }
           }
       }
   }
   // Scenario B: Down Trend (Start=High, End=Low) -> Level0 > Level100
   else {
       // Breakout Down (Price < 100) - Remember 100 is Low here
       if(current_price < level100) {
           // Search backwards from p2_idx-1 for a lower valley
           for(int k=p2_idx-1; k>=0; k--) {
               if(zz_buffer[k] != 0 && zz_buffer[k] != EMPTY_VALUE) {
                   if(zz_buffer[k] < current_price) {
                       p2_idx = k; // Move End Point
                       break;
                   }
               }
           }
       }
       // Breakout Up (Price > 0) - Remember 0 is High here
       if(current_price > level0) {
            // Search backwards from p1_idx-1 for a higher peak
            for(int k=p1_idx-1; k>=0; k--) {
               if(zz_buffer[k] != 0 && zz_buffer[k] != EMPTY_VALUE) {
                   if(zz_buffer[k] > current_price) {
                       p1_idx = k; // Move Start Point
                       break;
                   }
               }
           }
       }
   }

   // Create if missing
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Ray Right Enabled

      // Set Levels (Fixed 0..100 logic)
      ObjectSetInteger(0, name, OBJPROP_LEVELS, 6);

      // Start = 0.0
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 0, "0.0 (Start)");

      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 0.236);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 1, "23.6");

      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.382);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 2, "38.2");

      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.500);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 3, "50.0");

      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 0.618);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 4, "61.8");

      // End = 1.0
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.0);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 5, "100.0 (End)");
   }

   // Update Coordinates
   // P1 = Start (Time A, Price A)
   // P2 = End (Time B, Price B)
   // This aligns with Level 0.0 at P1 and 1.0 at P2 ?
   // Verification: In MT5, Level values are coefficients of vector P1->P2.
   // So Value 0.0 is at P1, Value 1.0 is at P2. Correct.

   long t1 = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   long t2 = ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   double pr1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double pr2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

   // Only update if changed to avoid flickering/CPU load
   if(t1 != time[p1_idx] || t2 != time[p2_idx] ||
      MathAbs(pr1 - zz_buffer[p1_idx]) > _Point ||
      MathAbs(pr2 - zz_buffer[p2_idx]) > _Point)
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, zz_buffer[p1_idx]); // Start
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, time[p1_idx]);

      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, zz_buffer[p2_idx]); // End
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, time[p2_idx]);

      ChartRedraw();
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
   if(rates_total < InpTerDepth + 100) return 0;

   //--- PIVOT CALCULATION (Only if Enabled)
   if(InpShowPivots)
   {
      // Resize
      if(ArraySize(MicroZZBuffer) < rates_total) ArrayResize(MicroZZBuffer, rates_total);
      if(ArraySize(SecZZBuffer) < rates_total) ArrayResize(SecZZBuffer, rates_total);
      if(InpUseTertiary && ArraySize(TerZZBuffer) < rates_total) ArrayResize(TerZZBuffer, rates_total);

      // Copy Data
      if(micro_zz_handle != INVALID_HANDLE) CopyBuffer(micro_zz_handle, 0, 0, rates_total, MicroZZBuffer);
      if(sec_zz_handle != INVALID_HANDLE) CopyBuffer(sec_zz_handle, 0, 0, rates_total, SecZZBuffer);
      if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) CopyBuffer(ter_zz_handle, 0, 0, rates_total, TerZZBuffer);

      // Loop
      int lookback = 300;
      int start = rates_total - lookback;
      if(start < 0) start = 0;
      if (prev_calculated == 0) start = 0;

      for(int i = start; i < rates_total; i++)
      {
         // 1. MICRO
         if(micro_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? MicroR1[i-1] : high[i];
             double prev_s = (i > 0) ? MicroS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             // Logic: If close breaks R, search up. If close breaks S, search down.
             // Also always check if a NEW local ZigZag pivot formed at 'i' (MicroZZBuffer[i]).

             // A) New Pivot formed at 'i'? Update immediately.
             if (MicroZZBuffer[i] != 0 && MicroZZBuffer[i] != EMPTY_VALUE) {
                 if (MathAbs(MicroZZBuffer[i] - high[i]) < _Point) curr_r = MicroZZBuffer[i]; // New High
                 if (MathAbs(MicroZZBuffer[i] - low[i]) < _Point)  curr_s = MicroZZBuffer[i]; // New Low
             }

             // B) Breakout Check (Override)
             if (close[i] > curr_r) {
                 // Breakout Up -> Find Historic Higher
                 double hist = FindHistoricResistance(MicroZZBuffer, high, i, close[i]);
                 if (hist != -1.0) curr_r = hist;
                 else curr_r = high[i]; // Trail if ATH
             }

             if (close[i] < curr_s) {
                 // Breakdown Down -> Find Historic Lower
                 double hist = FindHistoricSupport(MicroZZBuffer, low, i, close[i]);
                 if (hist != -1.0) curr_s = hist;
                 else curr_s = low[i]; // Trail if ATL
             }

             MicroR1[i] = curr_r; MicroS1[i] = curr_s; MicroP[i] = (curr_r + curr_s + close[i])/3.0;
         }

         // 2. SECONDARY
         if(sec_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? SecR1[i-1] : high[i];
             double prev_s = (i > 0) ? SecS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (SecZZBuffer[i] != 0 && SecZZBuffer[i] != EMPTY_VALUE) {
                 if (MathAbs(SecZZBuffer[i] - high[i]) < _Point) curr_r = SecZZBuffer[i];
                 if (MathAbs(SecZZBuffer[i] - low[i]) < _Point)  curr_s = SecZZBuffer[i];
             }

             if (close[i] > curr_r) {
                 double hist = FindHistoricResistance(SecZZBuffer, high, i, close[i]);
                 if (hist != -1.0) curr_r = hist; else curr_r = high[i];
             }
             if (close[i] < curr_s) {
                 double hist = FindHistoricSupport(SecZZBuffer, low, i, close[i]);
                 if (hist != -1.0) curr_s = hist; else curr_s = low[i];
             }

             SecR1[i] = curr_r; SecS1[i] = curr_s; SecP[i] = (curr_r + curr_s + close[i])/3.0;
         }

         // 3. TERTIARY
         if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? TerR1[i-1] : high[i];
             double prev_s = (i > 0) ? TerS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (TerZZBuffer[i] != 0 && TerZZBuffer[i] != EMPTY_VALUE) {
                 if (MathAbs(TerZZBuffer[i] - high[i]) < _Point) curr_r = TerZZBuffer[i];
                 if (MathAbs(TerZZBuffer[i] - low[i]) < _Point)  curr_s = TerZZBuffer[i];
             }

             if (close[i] > curr_r) {
                 double hist = FindHistoricResistance(TerZZBuffer, high, i, close[i]);
                 if (hist != -1.0) curr_r = hist; else curr_r = high[i];
             }
             if (close[i] < curr_s) {
                 double hist = FindHistoricSupport(TerZZBuffer, low, i, close[i]);
                 if (hist != -1.0) curr_s = hist; else curr_s = low[i];
             }

             TerR1[i] = curr_r; TerS1[i] = curr_s; TerP[i] = (curr_r + curr_s + close[i])/3.0;
         }
      }
   }

   //--- AUTO FIBO UPDATE (Only Last Bar/Tick)
   // Call this outside the loop, once per tick, after buffers are populated
   if(InpShowPivots) {
       UpdateAutoFibo(rates_total, time, MicroZZBuffer, close);
   }

   //--- 3. Trends (Standard EMA)
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFast);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlow);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
   if(micro_zz_handle != INVALID_HANDLE) IndicatorRelease(micro_zz_handle);
   if(sec_zz_handle   != INVALID_HANDLE) IndicatorRelease(sec_zz_handle);
   if(ter_zz_handle   != INVALID_HANDLE) IndicatorRelease(ter_zz_handle);

   // Clean up Fibo
   ObjectDelete(0, "MicroFibo");

   ArrayFree(MicroZZBuffer);
   ArrayFree(SecZZBuffer);
   ArrayFree(TerZZBuffer);
}
