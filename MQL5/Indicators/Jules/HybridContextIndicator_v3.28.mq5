//+------------------------------------------------------------------+
//|                                HybridContextIndicator_v3.28.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.28 (4 EMA hozzáadva: 25, 50, 150, 300)             |
//|      Logic: All DATA buffers (0-9) first, CALC buffers (10-12) last|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.28"

#property indicator_chart_window
// 13 Buffers Total
// NEW ORDER:
// 0: MicroR (Data)
// 1: MicroS (Data)
// 2: SecR (Data)
// 3: SecS (Data)
// 4: TerR (Data)
// 5: TerS (Data)
// 6: TrendFast (Data)   (EMA 25)
// 7: TrendMedium (Data) (EMA 50)
// 8: TrendSlow (Data)   (EMA 150)
// 9: TrendSuper (Data)  (EMA 300)
// 10: MicroP (Calc)
// 11: SecP (Calc)
// 12: TerP (Calc)

#property indicator_buffers 13
#property indicator_plots   10

//--- PLOT 1: Micro R1 (Buffer 0) -> STYLE FIX: DOT
#property indicator_label1  "Micro Pivot R1"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrRed
#property indicator_width1  1

//--- PLOT 2: Micro S1 (Buffer 1) -> STYLE FIX: DOT
#property indicator_label2  "Micro Pivot S1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrGreen
#property indicator_width2  1

//--- PLOT 3: Secondary R1 (Buffer 2)
#property indicator_label3  "Secondary Pivot R1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DASHDOT
#property indicator_color3  clrRed
#property indicator_width3  1

//--- PLOT 4: Secondary S1 (Buffer 3)
#property indicator_label4  "Secondary Pivot S1"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_DASHDOT
#property indicator_color4  clrGreen
#property indicator_width4  1

//--- PLOT 5: Tertiary R1 (Buffer 4)
#property indicator_label5  "Tertiary Pivot R1"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_color5  clrRed
#property indicator_width5  1

//--- PLOT 6: Tertiary S1 (Buffer 5)
#property indicator_label6  "Tertiary Pivot S1"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_SOLID
#property indicator_color6  clrGreen
#property indicator_width6  1

//--- PLOT 7: Trend EMA Fast (Buffer 6)
#property indicator_label7  "Trend EMA Fast (25)"
#property indicator_type7   DRAW_LINE
#property indicator_style7  STYLE_SOLID
#property indicator_color7  clrOrange
#property indicator_width7  1

//--- PLOT 8: Trend EMA Medium (Buffer 7)
#property indicator_label8  "Trend EMA Medium (50)"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_SOLID
#property indicator_color8  clrDarkTurquoise
#property indicator_width8  1

//--- PLOT 9: Trend EMA Slow (Buffer 8)
#property indicator_label9  "Trend EMA Slow (150)"
#property indicator_type9   DRAW_LINE
#property indicator_style9  STYLE_SOLID
#property indicator_color9  clrDodgerBlue
#property indicator_width9  2

//--- PLOT 10: Trend EMA SuperSlow (Buffer 9)
#property indicator_label10 "Trend EMA SuperSlow (300)"
#property indicator_type10  DRAW_LINE
#property indicator_style10 STYLE_SOLID
#property indicator_color10 clrRoyalBlue
#property indicator_width10 2

//--- Input Parameters (Strictly Linear - NO GROUPS)
input bool               InpShowPivots         = true;
input bool               InpShowTrends         = true;
input int                InpMaxHistoryBars     = 50000;

input bool               InpShowFibo           = false;
input int                InpFiboMicroHistory   = 0;

input bool               InpUseMicro           = true;
input int                InpMicroDepth         = 3;
input int                InpMicroDeviation     = 5;
input int                InpMicroBackstep      = 3;
input ENUM_LINE_STYLE    InpMicroStyle         = STYLE_DOT; // DEFAULT FIX
input int                InpMicroWidth         = 1;
input color              InpMicroColorR1       = clrRed;
input color              InpMicroColorS1       = clrGreen;

input bool               InpUseSecondary       = true;
input int                InpSecDepth           = 10;
input int                InpSecDeviation       = 10;
input int                InpSecBackstep        = 5;
input ENUM_LINE_STYLE    InpSecStyle           = STYLE_DASHDOT;
input int                InpSecWidth           = 1;
input color              InpSecColorR1         = clrRed;
input color              InpSecColorS1         = clrGreen;

input bool               InpUseTertiary        = true;
input int                InpTerDepth           = 20;
input int                InpTerDeviation       = 10;
input int                InpTerBackstep        = 5;
input ENUM_LINE_STYLE    InpTerStyle           = STYLE_SOLID;
input int                InpTerWidth           = 1;
input color              InpTerColorR1         = clrRed;
input color              InpTerColorS1         = clrGreen;

input int                InpTrendFastPeriod    = 25;
input int                InpTrendMediumPeriod  = 50;
input int                InpTrendSlowPeriod    = 150;
input int                InpTrendSuperPeriod   = 300;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers (Reordered)
double      MicroR1[], MicroS1[];
double      SecR1[], SecS1[];
double      TerR1[], TerS1[];
double      TrendFast[], TrendMedium[], TrendSlow[], TrendSuper[];
// Calculations (Moved to end)
double      MicroP[], SecP[], TerP[];

//--- ZigZag Helper Buffers
double      MicroHigh[], MicroLow[];
double      SecHigh[], SecLow[];
double      TerHigh[], TerLow[];
double      MicroLine[], SecLine[], TerLine[];

//--- Global Handles
int         ema_fast_handle   = INVALID_HANDLE;
int         ema_medium_handle = INVALID_HANDLE;
int         ema_slow_handle   = INVALID_HANDLE;
int         ema_super_handle  = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| ZigZag Engine Class                                              |
//+------------------------------------------------------------------+
class CZigZagEngine
{
private:
   int               m_depth;
   int               m_deviation;
   int               m_backstep;
   int               m_recalc;

public:
                     CZigZagEngine() : m_depth(12), m_deviation(5), m_backstep(3), m_recalc(3) {}
   void              Init(int depth, int deviation, int backstep) { m_depth=depth; m_deviation=deviation; m_backstep=backstep; }

   int               Highest(const double &array[],const int depth,const int start)
   {
      if(start<0) return(0);
      double max=array[start];
      int    index=start;
      for(int i=start-1; i>start-depth && i>=0; i--)
      {
         if(array[i]>max) { index=i; max=array[i]; }
      }
      return(index);
   }

   int               Lowest(const double &array[],const int depth,const int start)
   {
      if(start<0) return(0);
      double min=array[start];
      int    index=start;
      for(int i=start-1; i>start-depth && i>=0; i--)
      {
         if(array[i]<min) { index=i; min=array[i]; }
      }
      return(index);
   }

   void              Calculate(const int rates_total, const int prev_calculated, const double &high[], const double &low[], double &ZigZagBuffer[], double &HighMapBuffer[], double &LowMapBuffer[])
   {
       if(rates_total<100) return;

       int i=0;
       int start=0, extreme_counter=0, extreme_search=0;
       int shift=0, back=0, last_high_pos=0, last_low_pos=0;
       double val=0, res=0;
       double curlow=0, curhigh=0, last_high=0, last_low=0;

       if(prev_calculated==0) {
           ArrayInitialize(ZigZagBuffer, 0.0);
           ArrayInitialize(HighMapBuffer, 0.0);
           ArrayInitialize(LowMapBuffer, 0.0);
           start = m_depth;
       }

       if(prev_calculated > 0) {
           i = rates_total - 1;
           while(extreme_counter < m_recalc && i > rates_total - 100) {
               res = ZigZagBuffer[i];
               if(res != 0.0) extreme_counter++;
               i--;
           }
           i++;
           start = i;

           if(LowMapBuffer[i] != 0.0) {
               curlow = LowMapBuffer[i];
               extreme_search = 1; // Peak
           } else {
               curhigh = HighMapBuffer[i];
               extreme_search = -1; // Bottom
           }

           for(i = start + 1; i < rates_total; i++) {
               ZigZagBuffer[i] = 0.0;
               LowMapBuffer[i] = 0.0;
               HighMapBuffer[i] = 0.0;
           }
       }

       // Loop 1
       for(shift=start; shift<rates_total && !IsStopped(); shift++) {
           // Low
           val = low[Lowest(low, m_depth, shift)];
           if(val == last_low) val = 0.0;
           else {
               last_low = val;
               if((low[shift] - val) > m_deviation * _Point) val = 0.0;
               else {
                   for(back=1; back<=m_backstep; back++) {
                       if(shift-back < 0) continue;
                       res = LowMapBuffer[shift-back];
                       if((res!=0) && (res>val)) LowMapBuffer[shift-back] = 0.0;
                   }
               }
           }
           if(low[shift] == val) LowMapBuffer[shift] = val; else LowMapBuffer[shift] = 0.0;

           // High
           val = high[Highest(high, m_depth, shift)];
           if(val == last_high) val = 0.0;
           else {
               last_high = val;
               if((val - high[shift]) > m_deviation * _Point) val = 0.0;
               else {
                   for(back=1; back<=m_backstep; back++) {
                       if(shift-back < 0) continue;
                       res = HighMapBuffer[shift-back];
                       if((res!=0) && (res<val)) HighMapBuffer[shift-back] = 0.0;
                   }
               }
           }
           if(high[shift] == val) HighMapBuffer[shift] = val; else HighMapBuffer[shift] = 0.0;
       }

       // Final Selection
       if(extreme_search == 0) { last_low=0.0; last_high=0.0; }
       else { last_low=curlow; last_high=curhigh; }

       for(shift=start; shift<rates_total && !IsStopped(); shift++) {
           res = 0.0;
           switch(extreme_search) {
               case 0: // Extremum
                   if(last_low==0.0 && last_high==0.0) {
                       if(HighMapBuffer[shift]!=0) {
                           last_high=high[shift]; last_high_pos=shift; extreme_search=-1; ZigZagBuffer[shift]=last_high; res=1;
                       }
                       if(LowMapBuffer[shift]!=0.0) {
                           last_low=low[shift]; last_low_pos=shift; extreme_search=1; ZigZagBuffer[shift]=last_low; res=1;
                       }
                   }
                   break;
               case 1: // Peak
                   if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low && HighMapBuffer[shift]==0.0) {
                       ZigZagBuffer[last_low_pos]=0.0; last_low_pos=shift; last_low=LowMapBuffer[shift]; ZigZagBuffer[shift]=last_low; res=1;
                   }
                   if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0) {
                       last_high=HighMapBuffer[shift]; last_high_pos=shift; ZigZagBuffer[shift]=last_high; extreme_search=-1; res=1;
                   }
                   break;
               case -1: // Bottom
                   if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>last_high && LowMapBuffer[shift]==0.0) {
                       ZigZagBuffer[last_high_pos]=0.0; last_high_pos=shift; last_high=HighMapBuffer[shift]; ZigZagBuffer[shift]=last_high;
                   }
                   if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0) {
                       last_low=LowMapBuffer[shift]; last_low_pos=shift; ZigZagBuffer[shift]=last_low; extreme_search=1;
                   }
                   break;
           }
       }
   }
};

CZigZagEngine microZigZag;
CZigZagEngine secZigZag;
CZigZagEngine terZigZag;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- MAPPING FIX: DATA BUFFERS FIRST (0-7) ---

   // 0: Micro R1 (Data)
   SetIndexBuffer(0, MicroR1, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpMicroColorR1);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   // 1: Micro S1 (Data)
   SetIndexBuffer(1, MicroS1, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMicroColorS1);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   // 2: Sec R1 (Data)
   SetIndexBuffer(2, SecR1, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpSecColorR1);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   // 3: Sec S1 (Data)
   SetIndexBuffer(3, SecS1, INDICATOR_DATA);
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpSecColorS1);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   // 4: Ter R1 (Data)
   SetIndexBuffer(4, TerR1, INDICATOR_DATA);
   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpTerColorR1);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);

   // 5: Ter S1 (Data)
   SetIndexBuffer(5, TerS1, INDICATOR_DATA);
   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpTerColorS1);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0.0);

   // 6: Trend Fast (Data)
   SetIndexBuffer(6, TrendFast, INDICATOR_DATA);
   PlotIndexSetInteger(6, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, clrOrange);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 7: Trend Medium (Data)
   SetIndexBuffer(7, TrendMedium, INDICATOR_DATA);
   PlotIndexSetInteger(7, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, clrDarkTurquoise);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 8: Trend Slow (Data)
   SetIndexBuffer(8, TrendSlow, INDICATOR_DATA);
   PlotIndexSetInteger(8, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, clrDodgerBlue);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 9: Trend SuperSlow (Data)
   SetIndexBuffer(9, TrendSuper, INDICATOR_DATA);
   PlotIndexSetInteger(9, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(9, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, clrRoyalBlue);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // --- CALCULATIONS LAST (10-12) ---
   SetIndexBuffer(10, MicroP, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, SecP, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, TerP, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.28");

   if(InpShowPivots)
   {
      if(InpUseMicro) microZigZag.Init(InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
      if(InpUseSecondary) secZigZag.Init(InpSecDepth, InpSecDeviation, InpSecBackstep);
      if(InpUseTertiary) terZigZag.Init(InpTerDepth, InpTerDeviation, InpTerBackstep);
   }

   if(InpShowTrends)
   {
      ema_fast_handle   = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_medium_handle = iMA(_Symbol, _Period, InpTrendMediumPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle   = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_super_handle  = iMA(_Symbol, _Period, InpTrendSuperPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Find Next Historic Resistance > Price                            |
//+------------------------------------------------------------------+
double FindHistoricResistance(const double &buffer[], int start_idx, double price_level)
{
   int limit = start_idx - InpMaxHistoryBars;
   if (limit < 0) limit = 0;

   for (int k = start_idx; k >= limit; k--)
   {
      double val = buffer[k];
      if (val != 0 && val != EMPTY_VALUE)
      {
          if (val > price_level) return val;
      }
   }
   return -1.0;
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
      if (val != 0 && val != EMPTY_VALUE)
      {
          if (val < price_level) return val;
      }
   }
   return -1.0;
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

   int p2_idx = -1;
   int p1_idx = -1;

   int found_count = 0;
   int target_idx = InpFiboMicroHistory + 1;

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

   if(p1_idx == -1 || p2_idx == -1) return;

   double level0 = 0.0;
   double level100 = 0.0;

   if (high_buf[p1_idx] != 0 && high_buf[p1_idx] != EMPTY_VALUE) level0 = high_buf[p1_idx];
   else level0 = low_buf[p1_idx];

   if (high_buf[p2_idx] != 0 && high_buf[p2_idx] != EMPTY_VALUE) level100 = high_buf[p2_idx];
   else level100 = low_buf[p2_idx];

   double current_price = close[rates_total-1];

   if(level0 < level100) {
       if(current_price > level100) {
           for(int k=p2_idx-1; k>=0; k--) {
               if(high_buf[k] != 0 && high_buf[k] != EMPTY_VALUE) {
                   if(high_buf[k] > current_price) {
                       p2_idx = k; break;
                   }
               }
           }
       }
       if(current_price < level0) {
           for(int k=p1_idx-1; k>=0; k--) {
               if(low_buf[k] != 0 && low_buf[k] != EMPTY_VALUE) {
                   if(low_buf[k] < current_price) {
                       p1_idx = k; break;
                   }
               }
           }
       }
   }
   else {
       if(current_price < level100) {
           for(int k=p2_idx-1; k>=0; k--) {
               if(low_buf[k] != 0 && low_buf[k] != EMPTY_VALUE) {
                   if(low_buf[k] < current_price) {
                       p2_idx = k; break;
                   }
               }
           }
       }
       if(current_price > level0) {
            for(int k=p1_idx-1; k>=0; k--) {
               if(high_buf[k] != 0 && high_buf[k] != EMPTY_VALUE) {
                   if(high_buf[k] > current_price) {
                       p1_idx = k; break;
                   }
               }
           }
       }
   }

   if (high_buf[p1_idx] != 0 && high_buf[p1_idx] != EMPTY_VALUE) level0 = high_buf[p1_idx]; else level0 = low_buf[p1_idx];
   if (high_buf[p2_idx] != 0 && high_buf[p2_idx] != EMPTY_VALUE) level100 = high_buf[p2_idx]; else level100 = low_buf[p2_idx];

   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_LEVELS, 6);
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 0, "0.0 (Start)");
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 0.236); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 1, "23.6");
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.382); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 2, "38.2");
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.500); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 3, "50.0");
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 0.618); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 4, "61.8");
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.0); ObjectSetString(0, name, OBJPROP_LEVELTEXT, 5, "100.0 (End)");
   }

   long t1_obj = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   long t2_obj = ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   double pr1_obj = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double pr2_obj = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

   if(t1_obj != time[p1_idx] || t2_obj != time[p2_idx] ||
      MathAbs(pr1_obj - level0) > _Point ||
      MathAbs(pr2_obj - level100) > _Point)
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, level0);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, time[p1_idx]);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, level100);
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

   if(InpShowPivots)
   {
      if(ArraySize(MicroHigh) < rates_total) {
          ArrayResize(MicroHigh, rates_total); ArrayResize(MicroLow, rates_total); ArrayResize(MicroLine, rates_total);
          ArrayResize(SecHigh, rates_total);   ArrayResize(SecLow, rates_total);   ArrayResize(SecLine, rates_total);
          if(InpUseTertiary) { ArrayResize(TerHigh, rates_total); ArrayResize(TerLow, rates_total); ArrayResize(TerLine, rates_total); }
      }

      if(InpUseMicro) microZigZag.Calculate(rates_total, prev_calculated, high, low, MicroLine, MicroHigh, MicroLow);
      if(InpUseSecondary) secZigZag.Calculate(rates_total, prev_calculated, high, low, SecLine, SecHigh, SecLow);
      if(InpUseTertiary) terZigZag.Calculate(rates_total, prev_calculated, high, low, TerLine, TerHigh, TerLow);

      int lookback = 300;
      int start = rates_total - lookback;
      if(start < 0) start = 0;
      if (prev_calculated == 0) start = 0;

      for(int i = start; i < rates_total; i++)
      {
         double limit_R = close[i];
         double limit_S = close[i];

         // 1. MICRO
         if(InpUseMicro) {
             double prev_r = (i > 0) ? MicroR1[i-1] : high[i];
             double prev_s = (i > 0) ? MicroS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (MicroHigh[i] != 0 && MicroHigh[i] != EMPTY_VALUE) curr_r = MicroHigh[i];
             if (MicroLow[i]  != 0 && MicroLow[i]  != EMPTY_VALUE) curr_s = MicroLow[i];

             if (limit_R > curr_r) {
                 double hist = FindHistoricResistance(MicroHigh, i, limit_R);
                 if (hist != -1.0) curr_r = hist; else curr_r = high[i];
             }
             if (limit_S < curr_s) {
                 double hist = FindHistoricSupport(MicroLow, i, limit_S);
                 if (hist != -1.0) curr_s = hist; else curr_s = low[i];
             }

             // NEW BUFFER ASSIGNMENT
             MicroR1[i] = curr_r; // Buffer 0
             MicroS1[i] = curr_s; // Buffer 1
             MicroP[i] = (curr_r + curr_s + close[i])/3.0; // Buffer 8

             limit_R = curr_r; limit_S = curr_s;
         } else {
             MicroR1[i] = 0.0; MicroS1[i] = 0.0; MicroP[i] = 0.0;
         }

         // 2. SECONDARY
         if(InpUseSecondary) {
             double prev_r = (i > 0) ? SecR1[i-1] : high[i];
             double prev_s = (i > 0) ? SecS1[i-1] : low[i];
             double curr_r = prev_r;
             double curr_s = prev_s;

             if (SecHigh[i] != 0 && SecHigh[i] != EMPTY_VALUE) curr_r = SecHigh[i];
             if (SecLow[i]  != 0 && SecLow[i]  != EMPTY_VALUE) curr_s = SecLow[i];

             if (curr_r <= limit_R) {
                 double hist = FindHistoricResistance(SecHigh, i, limit_R);
                 if (hist != -1.0) curr_r = hist; else curr_r = limit_R + _Point;
             }
             if (curr_s >= limit_S) {
                 double hist = FindHistoricSupport(SecLow, i, limit_S);
                 if (hist != -1.0) curr_s = hist; else curr_s = limit_S - _Point;
             }

             SecR1[i] = curr_r; // Buffer 2
             SecS1[i] = curr_s; // Buffer 3
             SecP[i] = (curr_r + curr_s + close[i])/3.0; // Buffer 9

             limit_R = curr_r; limit_S = curr_s;
         } else {
             SecR1[i] = 0.0; SecS1[i] = 0.0; SecP[i] = 0.0;
         }

         // 3. TERTIARY
         if(InpUseTertiary) {
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

             TerR1[i] = curr_r; // Buffer 4
             TerS1[i] = curr_s; // Buffer 5
             TerP[i] = (curr_r + curr_s + close[i])/3.0; // Buffer 10
         } else {
             TerR1[i] = 0.0; TerS1[i] = 0.0; TerP[i] = 0.0;
         }
      }
   }

   if(InpShowPivots) {
       UpdateAutoFibo(rates_total, time, MicroHigh, MicroLow, close);
   }

   if(InpShowTrends)
   {
      int to_copy = rates_total;
      if(prev_calculated > 0) to_copy = rates_total - prev_calculated + 1;

      if(ema_fast_handle   != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, to_copy, TrendFast);   // Buffer 6
      if(ema_medium_handle != INVALID_HANDLE) CopyBuffer(ema_medium_handle, 0, 0, to_copy, TrendMedium); // Buffer 7
      if(ema_slow_handle   != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, to_copy, TrendSlow);   // Buffer 8
      if(ema_super_handle  != INVALID_HANDLE) CopyBuffer(ema_super_handle, 0, 0, to_copy, TrendSuper);  // Buffer 9
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(ema_fast_handle   != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_medium_handle != INVALID_HANDLE) IndicatorRelease(ema_medium_handle);
   if(ema_slow_handle   != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
   if(ema_super_handle  != INVALID_HANDLE) IndicatorRelease(ema_super_handle);
   ObjectDelete(0, "MicroFibo");
   ArrayFree(MicroHigh); ArrayFree(MicroLow); ArrayFree(MicroLine);
   ArrayFree(SecHigh);   ArrayFree(SecLow);   ArrayFree(SecLine);
   ArrayFree(TerHigh);   ArrayFree(TerLow);   ArrayFree(TerLine);
}
