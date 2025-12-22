//+------------------------------------------------------------------+
//|                                          WPR_Hybrid_Showcase.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.20"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   4

//--- plot WPR
#property indicator_label1  "WPR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot UpperBand
#property indicator_label2  "UpperBand"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- plot LowerBand
#property indicator_label3  "LowerBand"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- plot SignalArrows
#property indicator_label4  "BreakoutSignal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrMagenta
#property indicator_width4  2

//--- Input parameters
input int      InpWPRPeriod   = 14;       // WPR Period
input int      InpBBPeriod    = 20;       // Bollinger Bands Period (on WPR)
input double   InpBBDev       = 2.0;      // Bollinger Bands Deviation

//--- Indicator buffers
double         WPRBuffer[];
double         UpperBandBuffer[];
double         LowerBandBuffer[];
double         SignalBuffer[]; // Breakout signals
double         StdDevBuffer[]; // Calc buffer (hidden)

//--- Global Handles
int            hWPR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,WPRBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,UpperBandBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,LowerBandBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,SignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,StdDevBuffer,INDICATOR_CALCULATIONS);

   // CRITICAL FIX: Set arrays as series (0 = Newest) for correct CopyBuffer behavior
   ArraySetAsSeries(WPRBuffer, true);
   ArraySetAsSeries(UpperBandBuffer, true);
   ArraySetAsSeries(LowerBandBuffer, true);
   ArraySetAsSeries(SignalBuffer, true);
   ArraySetAsSeries(StdDevBuffer, true);

//--- plot settings
   PlotIndexSetInteger(3,PLOT_ARROW,233); // 233=Arrow/Wing
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0.0);

//--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME,"WPR Dynamic Zones ("+string(InpWPRPeriod)+")");

//--- Get WPR Handle
   hWPR = iWPR(_Symbol, _Period, InpWPRPeriod);
   if(hWPR == INVALID_HANDLE) { Print("Failed to create WPR handle"); return(INIT_FAILED); }

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
   if(rates_total < InpWPRPeriod + InpBBPeriod) return(0);

   //--- Fill WPR Buffer
   int to_copy = (prev_calculated > 0) ? rates_total - prev_calculated + 1 : rates_total;
   if(CopyBuffer(hWPR, 0, 0, to_copy, WPRBuffer) <= 0) return(0);

   //--- Loop from Oldest (rates_total-1) to Newest (0) due to Series=true
   // Actually, SMA/StdDev doesn't strictly depend on previous state like EMA, so direction matters less,
   // but consistency is key. Let's process only updated bars.

   int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total - 1;

   // Ensure we don't go out of bounds for SMA lookback
   // If i is the current index, we need access to i+InpBBPeriod

   for(int i = limit; i >= 0; i--)
     {
      // Check if we have enough history for this bar
      if(i > rates_total - InpBBPeriod - 1) continue;

      // 1. Calculate Simple Moving Average of WPR
      // With Series=true, previous bars are i+1, i+2...
      double sum = 0.0;
      for(int j = 0; j < InpBBPeriod; j++)
         sum += WPRBuffer[i + j];
      double sma = sum / InpBBPeriod;

      // 2. Calculate Standard Deviation of WPR
      double sum_sq_diff = 0.0;
      for(int j = 0; j < InpBBPeriod; j++)
        {
         double diff = WPRBuffer[i + j] - sma;
         sum_sq_diff += diff * diff;
        }
      double std_dev = MathSqrt(sum_sq_diff / InpBBPeriod);

      // 3. Set Bands
      UpperBandBuffer[i] = sma + (InpBBDev * std_dev);
      LowerBandBuffer[i] = sma - (InpBBDev * std_dev);

      // 4. Signal Logic (Breakout Re-entry)
      SignalBuffer[i] = 0.0;

      if(i < rates_total - 2) // Need at least one prev bar
      {
         // Series: i=Current, i+1=Previous

         // Buy Re-entry: Was below lower band, now above it
         if(WPRBuffer[i+1] < LowerBandBuffer[i+1] && WPRBuffer[i] >= LowerBandBuffer[i])
         {
             SignalBuffer[i] = LowerBandBuffer[i]; // Draw arrow at lower band
         }
         // Sell Re-entry: Was above upper band, now below it
         else if(WPRBuffer[i+1] > UpperBandBuffer[i+1] && WPRBuffer[i] <= UpperBandBuffer[i])
         {
             SignalBuffer[i] = UpperBandBuffer[i]; // Draw arrow at upper band
         }
      }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
