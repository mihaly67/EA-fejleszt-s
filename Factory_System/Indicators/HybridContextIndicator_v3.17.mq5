//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.17.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.17 (Cascading Breakout Fix + Buffer Logic)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.17"

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
input int                InpMaxHistoryBars     = 50000; // Deep scan limit for historical levels

input group              "=== Auto Fibo Settings ==="
input bool               InpShowFibo           = false; // Master Fibo Switch (Micro Only)
input int                InpFiboMicroHistory   = 0;     // History Steps (0=Current Swing, 1=Prev, etc.)

input group              "=== Micro ZigZag (Fast) Settings ==="
input bool               InpUseMicro           = true; // Toggle Micro Pivot
input int                InpMicroDepth         = 5;
input int                InpMicroDeviation     = 5;
input int                InpMicroBackstep      = 3;
input ENUM_LINE_STYLE    InpMicroStyle         = STYLE_DOT;
input int                InpMicroWidth         = 1;
input color              InpMicroColorR1       = clrRed;
input color              InpMicroColorS1       = clrGreen;

input group              "=== Secondary ZigZag (Slow) Settings ==="
input bool               InpUseSecondary       = true; // Toggle Secondary Pivot
input int                InpSecDepth           = 30;
input int                InpSecDeviation       = 10;
input int                InpSecBackstep        = 5;
input ENUM_LINE_STYLE    InpSecStyle           = STYLE_DASHDOT;
input int                InpSecWidth           = 1; // Corrected: Must be 1 for non-solid styles in MT5
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

//--- ZigZag Helper Buffers (Internal Arrays, not indicator_buffers)
double      MicroHigh[], MicroLow[];
double      SecHigh[], SecLow[];
double      TerHigh[], TerLow[];

// For Fibo
double      MicroLine[], SecLine[], TerLine[];


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
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMicroColorR1);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpMicroColorS1);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpSecColorR1);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpSecColorS1);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 3. Tertiary
   SetIndexBuffer(6, TerP, INDICATOR_DATA);
   SetIndexBuffer(7, TerR1, INDICATOR_DATA);
   SetIndexBuffer(8, TerS1, INDICATOR_DATA);

   PlotIndexSetInteger(6, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(7, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpTerColorR1);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(8, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpTerColorS1);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 4. Trends
   SetIndexBuffer(9, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(10, TrendSlow, INDICATOR_DATA);

   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(10, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.17");

   //--- Initialize ZigZag Handles (Only if Enabled)
   if(InpShowPivots)
   {
      // Micro
      if(InpUseMicro)
      {
         micro_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
         if(micro_zz_handle == INVALID_HANDLE) micro_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
      }

      // Secondary
      if(InpUseSecondary)
      {
         sec_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
         if(sec_zz_handle == INVALID_HANDLE) sec_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
      }

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
double FindHistoricResistance(const double &buffer[], int start_idx, double price_level)
{
   // Loop backwards from start_idx to limit
   int limit = start_idx - InpMaxHistoryBars;
   if (limit < 0) limit = 0;

   for (int k = start_idx; k >= limit; k--)
   {
      double val = buffer[k];
      // Check if it's a valid ZigZag High (Buffer should contain only Highs or 0)
      if (val != 0 && val != EMPTY_VALUE)
      {
          // It's a Peak. Is it higher than our trigger level?
          if (val > price_level) return val;
      }
   }
   return -1.0; // Not found (ATH)
}

//+------------------------------------------------------------------+
//| Find Next Historic Support < Price                               |
//+------------------------------------------------------------------+
double FindHistoricSupport(const double &buffer[], int start_idx, double price_level)
{
   int limit = start_idx - InpMaxHistoryBars;
   if (limit < 0) limit = 0;

   for (int k = start_idx; k >= limit; k--)
   {
      double val = buffer[k];
      // Check if it's a valid ZigZag Low
      if (val != 0 && val != EMPTY_VALUE)
      {
          if (val < price_level) return val;
      }
   }
   return -1.0; // Not found (ATL)
}

//+------------------------------------------------------------------+
//| Update Auto Fibo Object                                          |
//+------------------------------------------------------------------+
void UpdateAutoFibo(const int rates_total, const datetime &time[], const double &high_buf[], const double &low_buf[], const double &close[])
{
   string name = "MicroFibo";

   if(!InpShowFibo) {
      if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
      return;
   }

   // 1. Find Points (Base Swing)
   int p2_idx = -1; // End Point (Newer)
   int p1_idx = -1; // Start Point (Older)

   // Search Backwards for Last 2 Peaks/Valleys
   int found_count = 0;
   int target_idx = InpFiboMicroHistory + 1; // 1 = Last completed leg

   // We need to merge Highs and Lows into a single timeline of "Swings"
   // Iterate backwards and pick the first valid point from EITHER buffer
   for(int i=rates_total-1; i>=0; i--) {
       bool is_high = (high_buf[i] != 0 && high_buf[i] != EMPTY_VALUE);
       bool is_low = (low_buf[i] != 0 && low_buf[i] != EMPTY_VALUE);

       if(is_high || is_low) {
           if(found_count == target_idx) {
               p2_idx = i;
           }
           else if(found_count == target_idx + 1) {
               p1_idx = i;
               break;
           }
           found_count++;
       }
   }

   if(p1_idx == -1 || p2_idx == -1) return; // Not enough history

   // 2. Determine Levels
   double level0 = 0.0;
   double level100 = 0.0;

   // Check what we found at p1_idx
   if (high_buf[p1_idx] != 0 && high_buf[p1_idx] != EMPTY_VALUE) level0 = high_buf[p1_idx];
   else level0 = low_buf[p1_idx];

   // Check what we found at p2_idx
   if (high_buf[p2_idx] != 0 && high_buf[p2_idx] != EMPTY_VALUE) level100 = high_buf[p2_idx];
   else level100 = low_buf[p2_idx];


   // 3. Logic to Extend Fibo if Price Breaks 0 or 100
   double current_price = close[rates_total-1];

   // Scenario A: Up Trend (Start=Low, End=High) -> Level0 < Level100
   if(level0 < level100) {
       // Breakout Up (Price > 100)
       if(current_price > level100) {
           // Search backwards from p2_idx-1 for a higher peak
           for(int k=p2_idx-1; k>=0; k--) {
               if(high_buf[k] != 0 && high_buf[k] != EMPTY_VALUE) {
                   if(high_buf[k] > current_price) {
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
               if(low_buf[k] != 0 && low_buf[k] != EMPTY_VALUE) {
                   if(low_buf[k] < current_price) {
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
               if(low_buf[k] != 0 && low_buf[k] != EMPTY_VALUE) {
                   if(low_buf[k] < current_price) {
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
               if(high_buf[k] != 0 && high_buf[k] != EMPTY_VALUE) {
                   if(high_buf[k] > current_price) {
                       p1_idx = k; // Move Start Point
                       break;
                   }
               }
           }
       }
   }

   // Re-read values in case index changed
   if (high_buf[p1_idx] != 0 && high_buf[p1_idx] != EMPTY_VALUE) level0 = high_buf[p1_idx]; else level0 = low_buf[p1_idx];
   if (high_buf[p2_idx] != 0 && high_buf[p2_idx] != EMPTY_VALUE) level100 = high_buf[p2_idx]; else level100 = low_buf[p2_idx];


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
   long t1 = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   long t2 = ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   double pr1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double pr2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

   if(t1 != time[p1_idx] || t2 != time[p2_idx] ||
      MathAbs(pr1 - level0) > _Point ||
      MathAbs(pr2 - level100) > _Point)
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, level0); // Start
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, time[p1_idx]);

      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, level100); // End
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
      // Resize Internal Arrays
      if(ArraySize(MicroHigh) < rates_total) {
          ArrayResize(MicroHigh, rates_total); ArrayResize(MicroLow, rates_total); ArrayResize(MicroLine, rates_total);
          ArrayResize(SecHigh, rates_total);   ArrayResize(SecLow, rates_total);   ArrayResize(SecLine, rates_total);
          if(InpUseTertiary) { ArrayResize(TerHigh, rates_total); ArrayResize(TerLow, rates_total); ArrayResize(TerLine, rates_total); }
      }

      // Copy Data (Buffer 0=Line, 1=High, 2=Low for standard ZigZag)
      if(micro_zz_handle != INVALID_HANDLE) {
          CopyBuffer(micro_zz_handle, 0, 0, rates_total, MicroLine);
          CopyBuffer(micro_zz_handle, 1, 0, rates_total, MicroHigh);
          CopyBuffer(micro_zz_handle, 2, 0, rates_total, MicroLow);
      }
      if(sec_zz_handle != INVALID_HANDLE) {
          CopyBuffer(sec_zz_handle, 0, 0, rates_total, SecLine);
          CopyBuffer(sec_zz_handle, 1, 0, rates_total, SecHigh);
          CopyBuffer(sec_zz_handle, 2, 0, rates_total, SecLow);
      }
      if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) {
          CopyBuffer(ter_zz_handle, 0, 0, rates_total, TerLine);
          CopyBuffer(ter_zz_handle, 1, 0, rates_total, TerHigh);
          CopyBuffer(ter_zz_handle, 2, 0, rates_total, TerLow);
      }

      // Loop
      int lookback = 300;
      int start = rates_total - lookback;
      if(start < 0) start = 0;
      if (prev_calculated == 0) start = 0;

      for(int i = start; i < rates_total; i++)
      {
         // --- INIT CASCADING THRESHOLDS ---
         // If a tier is disabled, the threshold passes through unchanged.
         double limit_R = close[i];
         double limit_S = close[i];

         // 1. MICRO
         if(InpUseMicro && micro_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? MicroR1[i-1] : high[i];
             double prev_s = (i > 0) ? MicroS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             // Use High/Low Buffers for Peak Detection
             // A) New Pivot formed at 'i'?
             if (MicroHigh[i] != 0 && MicroHigh[i] != EMPTY_VALUE) curr_r = MicroHigh[i];
             if (MicroLow[i]  != 0 && MicroLow[i]  != EMPTY_VALUE) curr_s = MicroLow[i];

             // Standard Breakout Logic against PRICE (limit_R/limit_S)
             if (limit_R > curr_r) {
                 double hist = FindHistoricResistance(MicroHigh, i, limit_R); // Use High Buffer
                 if (hist != -1.0) curr_r = hist; else curr_r = high[i];
             }
             if (limit_S < curr_s) {
                 double hist = FindHistoricSupport(MicroLow, i, limit_S); // Use Low Buffer
                 if (hist != -1.0) curr_s = hist; else curr_s = low[i];
             }

             MicroR1[i] = curr_r; MicroS1[i] = curr_s; MicroP[i] = (curr_r + curr_s + close[i])/3.0;

             // Update Thresholds for next tier
             limit_R = curr_r;
             limit_S = curr_s;

         } else {
             MicroR1[i] = EMPTY_VALUE; MicroS1[i] = EMPTY_VALUE; MicroP[i] = EMPTY_VALUE;
         }

         // 2. SECONDARY
         if(InpUseSecondary && sec_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? SecR1[i-1] : high[i];
             double prev_s = (i > 0) ? SecS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (SecHigh[i] != 0 && SecHigh[i] != EMPTY_VALUE) curr_r = SecHigh[i];
             if (SecLow[i]  != 0 && SecLow[i]  != EMPTY_VALUE) curr_s = SecLow[i];

             // Cascading Breakout: Must be OUTSIDE the previous tier (limit_R/limit_S)
             // Check if Secondary R is "inside" or "equal" to Micro R
             if (curr_r <= limit_R) {
                 // Push Out! Find next historic Secondary R > limit_R
                 double hist = FindHistoricResistance(SecHigh, i, limit_R); // Use High Buffer
                 if (hist != -1.0) curr_r = hist; else curr_r = limit_R + _Point; // Force separation if ATH
             }

             if (curr_s >= limit_S) { // Support is "inside" if >= Micro S
                 double hist = FindHistoricSupport(SecLow, i, limit_S); // Use Low Buffer
                 if (hist != -1.0) curr_s = hist; else curr_s = limit_S - _Point;
             }

             SecR1[i] = curr_r; SecS1[i] = curr_s; SecP[i] = (curr_r + curr_s + close[i])/3.0;

             limit_R = curr_r;
             limit_S = curr_s;

         } else {
             SecR1[i] = EMPTY_VALUE; SecS1[i] = EMPTY_VALUE; SecP[i] = EMPTY_VALUE;
         }

         // 3. TERTIARY
         if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) {
             double prev_r = (i > 0) ? TerR1[i-1] : high[i];
             double prev_s = (i > 0) ? TerS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (TerHigh[i] != 0 && TerHigh[i] != EMPTY_VALUE) curr_r = TerHigh[i];
             if (TerLow[i]  != 0 && TerLow[i]  != EMPTY_VALUE) curr_s = TerLow[i];

             if (curr_r <= limit_R) {
                 double hist = FindHistoricResistance(TerHigh, i, limit_R);
                 if (hist != -1.0) curr_r = hist; else curr_r = limit_R + _Point;
             }
             if (curr_s >= limit_S) {
                 double hist = FindHistoricSupport(TerLow, i, limit_S);
                 if (hist != -1.0) curr_s = hist; else curr_s = limit_S - _Point;
             }

             TerR1[i] = curr_r; TerS1[i] = curr_s; TerP[i] = (curr_r + curr_s + close[i])/3.0;

         } else {
             TerR1[i] = EMPTY_VALUE; TerS1[i] = EMPTY_VALUE; TerP[i] = EMPTY_VALUE;
         }
      }
   }

   //--- AUTO FIBO UPDATE (Only Last Bar/Tick)
   if(InpShowPivots) {
       UpdateAutoFibo(rates_total, time, MicroHigh, MicroLow, close); // Passed proper buffers
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

   // Clean up Internal Arrays
   ArrayFree(MicroHigh); ArrayFree(MicroLow); ArrayFree(MicroLine);
   ArrayFree(SecHigh);   ArrayFree(SecLow);   ArrayFree(SecLine);
   ArrayFree(TerHigh);   ArrayFree(TerLow);   ArrayFree(TerLine);
}
