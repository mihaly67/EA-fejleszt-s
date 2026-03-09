//+------------------------------------------------------------------+
//|                                     Hybrid_Momentum_WPR_Stoch.mq5|
//|                                  Copyright 2026, BlackOps System |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, BlackOps System"
#property description "Hybrid Momentum Indicator: Combines WPR (Line) and Stochastic (Histogram)"

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- plot 1: Stochastic Histogram (K-line)
#property indicator_label1  "Stoch Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrForestGreen, clrFireBrick
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot 2: WPR Line
#property indicator_label2  "WPR Adjusted"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue // Hibrid Flow görbe színe
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Levels
#property indicator_level1  20.0
#property indicator_level2  50.0
#property indicator_level3  80.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_maximum 100.0
#property indicator_minimum 0.0

//--- input parameters
input int InpWPRPeriod   = 14; // WPR Period
input int InpKPeriod     = 5;  // Stochastic %K Period
input int InpSlowing     = 3;  // Stochastic Slowing
input int InpDPeriod     = 3;  // Stochastic %D Period (Not displayed, but needed for algorithm)

//--- indicator buffers
double    ExtStochBuffer[];
double    ExtStochColors[];
double    ExtWPRBuffer[];

//--- internal buffers for stochastic calculation
double    ExtHighestBuffer[];
double    ExtLowestBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, ExtStochBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtStochColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtWPRBuffer,   INDICATOR_DATA);
   SetIndexBuffer(3, ExtHighestBuffer, INDICATOR_CALCULATIONS);

   // We dynamically allocate the lowest buffer to save buffer count
   ArrayResize(ExtLowestBuffer, 1);
   ArraySetAsSeries(ExtLowestBuffer, false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   string short_name = StringFormat("Hybrid Mom(W:%d, S:%d,%d)", InpWPRPeriod, InpKPeriod, InpSlowing);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   return(INIT_SUCCEEDED);
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
   if(rates_total < MathMax(InpWPRPeriod, InpKPeriod + InpSlowing))
      return(0);

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   // Resize internal buffer if needed
   if(ArraySize(ExtLowestBuffer) < rates_total)
      ArrayResize(ExtLowestBuffer, rates_total);

   //------------------------------------------------------------------
   // 1. Calculate Highest/Lowest for Stochastic
   //------------------------------------------------------------------
   int stoch_start = start;
   if(stoch_start < InpKPeriod - 1) stoch_start = InpKPeriod - 1;

   for(int i = stoch_start; i < rates_total && !IsStopped(); i++)
     {
      double dmin = 1000000.0;
      double dmax = -1000000.0;
      for(int k = i - InpKPeriod + 1; k <= i; k++)
        {
         if(dmin > low[k])  dmin = low[k];
         if(dmax < high[k]) dmax = high[k];
        }
      ExtLowestBuffer[i]  = dmin;
      ExtHighestBuffer[i] = dmax;
     }

   //------------------------------------------------------------------
   // 2. Calculate Stochastic %K (with slowing)
   //------------------------------------------------------------------
   stoch_start = start;
   if(stoch_start < InpKPeriod - 1 + InpSlowing - 1)
       stoch_start = InpKPeriod - 1 + InpSlowing - 1;

   for(int i = stoch_start; i < rates_total && !IsStopped(); i++)
     {
      double sum_low  = 0.0;
      double sum_high = 0.0;

      for(int k = (i - InpSlowing + 1); k <= i; k++)
        {
         sum_low  += (close[k] - ExtLowestBuffer[k]);
         sum_high += (ExtHighestBuffer[k] - ExtLowestBuffer[k]);
        }

      if(sum_high == 0.0)
         ExtStochBuffer[i] = 100.0;
      else
         ExtStochBuffer[i] = sum_low / sum_high * 100.0;

      // Determine Color (ForestGreen=0, FireBrick=1)
      if(i > 0)
        {
         if(ExtStochBuffer[i] > ExtStochBuffer[i-1])
            ExtStochColors[i] = 0; // Rising -> Green
         else if(ExtStochBuffer[i] < ExtStochBuffer[i-1])
            ExtStochColors[i] = 1; // Falling -> Red
         else
            ExtStochColors[i] = ExtStochColors[i-1]; // Same as previous
        }
      else
        {
         ExtStochColors[i] = 0;
        }
     }

   //------------------------------------------------------------------
   // 3. Calculate WPR (Shifted to 0-100 scale)
   // Standard WPR formula: -100 * (MaxHigh - Close) / (MaxHigh - MinLow)
   // Shifted WPR = Standard WPR + 100
   //------------------------------------------------------------------
   int wpr_start = start;
   if(wpr_start < InpWPRPeriod - 1) wpr_start = InpWPRPeriod - 1;

   for(int i = wpr_start; i < rates_total && !IsStopped(); i++)
     {
      double dmax = high[i];
      double dmin = low[i];

      for(int k = 1; k < InpWPRPeriod; k++)
        {
         if(high[i-k] > dmax) dmax = high[i-k];
         if(low[i-k] < dmin)  dmin = low[i-k];
        }

      double wpr_val = 0.0;
      if(dmax != dmin)
         wpr_val = -100.0 * (dmax - close[i]) / (dmax - dmin);

      // Transform to 0-100 scale
      ExtWPRBuffer[i] = wpr_val + 100.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+