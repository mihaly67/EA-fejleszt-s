//+------------------------------------------------------------------+
//|                                            MACD Histogram MC.mq5 |
//|                                           Copyright © 2010, AK20 |
//|                                             traderak20@gmail.com |
//|                                                                  |
//|                                                        Based on: |
//|                                                         MACD.mq5 |
//|                        Copyright 2009, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2010, traderak20@gmail.com"
#property description "Moving Average Convergence/Divergence, Histogram, Multi-color"
#property   version     "1.32"
/*--------------------------------------------------------------------
2010 10 20: v04   Fixed bug with the colors of the histogram

2010 09 26: v03   Added MODE_SMMA and MODE_LWMA as MA methods for Signal line
                  Made ENUM_APPLIED_PRICE to the end of the input parameter list
----------------------------------------------------------------------*/
//#include <MovingAverages.mqh>
#include <MovingAverages.mqh>
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   3
//--- indicator plots
#property indicator_level1 0
#property indicator_level2 0.3
#property indicator_level3 -0.3
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_color1  RoyalBlue
#property indicator_color2  Goldenrod
#property indicator_color3  LimeGreen,C'83,0,0',Red,C'0,66,0'
#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2
#property indicator_label1  "MACD"
#property indicator_label2  "Signal"
#property indicator_label3  "Histogram"
//--- enum variables
enum colorswitch                                         // use single or multi-color display of Histogram
  {
   MultiColor=0,
   SingleColor=1
  };

//--- input parameters
input int                  InpFastEMA=7;                // Fast EMA period
input int                  InpSlowEMA=28;                // Slow EMA period
input int                  InpSignalMA=9;                // Signal MA period
input ENUM_MA_METHOD       InpAppliedSignalMA=MODE_SMA;  // Applied MA method for signal line
input colorswitch          InpUseMultiColor=MultiColor;  // Use multi-color or single-color histogram
input ENUM_APPLIED_PRICE   InpAppliedPrice=PRICE_CLOSE;  // Applied price
//--- indicator buffers
double                     ExtMacdBuffer[];
double                     ExtSignalBuffer[];
double                     ExtHistogramBuffer[];
double                     ExtHistogramColorBuffer[];
double                     ExtFastMaBuffer[];
double                     ExtSlowMaBuffer[];
//--- global variables
int                        weightsum_global;             // used for calculation of LWMA
//--- indicator handles
int                        ExtFastMaHandle;
int                        ExtSlowMaHandle;
//--- turn on/off error messages
bool                       ShowErrorMessages=true;       // turn on/off error messages for debugging
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtMacdBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtSignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtHistogramBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtHistogramColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,ExtFastMaBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,ExtSlowMaBuffer,INDICATOR_CALCULATIONS);

//--- set buffers as series, most recent entry at index [0]
   ArraySetAsSeries(ExtMacdBuffer,true);
   ArraySetAsSeries(ExtSignalBuffer,true);
   ArraySetAsSeries(ExtHistogramBuffer,true);
   ArraySetAsSeries(ExtHistogramColorBuffer,true);
   ArraySetAsSeries(ExtFastMaBuffer,true);
   ArraySetAsSeries(ExtSlowMaBuffer,true);

//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpSlowEMA-1);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpSlowEMA+InpSignalMA-1);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,InpSlowEMA+InpSignalMA-1);

//--- name for indicator
   IndicatorSetString(INDICATOR_SHORTNAME,"MACD("+string(InpFastEMA)+","+string(InpSlowEMA)+","+string(InpSignalMA)+")");

//--- get MA handles
   ExtFastMaHandle=iMA(NULL,0,InpFastEMA,0,MODE_EMA,InpAppliedPrice);
   ExtSlowMaHandle=iMA(NULL,0,InpSlowEMA,0,MODE_EMA,InpAppliedPrice);

//--- initialize global variable used for LWMA
   weightsum_global=0;

//--- initialization done
  }
//+------------------------------------------------------------------+
//| Moving Averages Convergence/Divergence                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
  {
//--- check for data
   if(rates_total<InpSignalMA)
      return(0);

//--- not all data may be calculated
   int calculated;

   calculated=BarsCalculated(ExtFastMaHandle);
   if(calculated<rates_total)
     {
      if(ShowErrorMessages) Print("Not all data of ExtFastMaHandle has been calculated (",calculated,"bars ). Error",GetLastError());
      return(0);
     }

   calculated=BarsCalculated(ExtSlowMaHandle);
   if(calculated<rates_total)
     {
      if(ShowErrorMessages) Print("Not all data of ExtSlowMaHandle has been calculated (",calculated,"bars ). Error",GetLastError());
      return(0);
     }

//--- calculate how many bars need to be recalculated
   int to_copy;
   if(prev_calculated>rates_total || prev_calculated<0)
      to_copy=rates_total;
   else
     {
      to_copy=rates_total-prev_calculated;
      if(prev_calculated>0)
         to_copy++;
     }

//--- get fast MA buffer values
   if(CopyBuffer(ExtFastMaHandle,0,0,to_copy,ExtFastMaBuffer)<=0)
     {
      if(ShowErrorMessages) Print("Getting fast EMA failed! Error",GetLastError());
      return(0);
     }

//--- get slow MA buffer values
   if(CopyBuffer(ExtSlowMaHandle,0,0,to_copy,ExtSlowMaBuffer)<=0)
     {
      if(ShowErrorMessages) Print("Getting slow SMA failed! Error",GetLastError());
      return(0);
     }

//--- set limit for which bars need to be (re)calculated
   int limit;
   if(prev_calculated==0 || prev_calculated<0 || prev_calculated>rates_total)
      limit=rates_total-1;
   else
      limit=rates_total-prev_calculated;
//--- older bars ([1]) are needed to set the color of the current bar
   if(limit>rates_total-1-1) limit=rates_total-1-1;

//--- calculate MACD buffer
   for(int i=limit;i>=0;i--)
      ExtMacdBuffer[i]=ExtFastMaBuffer[i]-ExtSlowMaBuffer[i];

//--- calculate Signal buffer
   if(InpAppliedSignalMA==MODE_SMA)
      SimpleMAOnBuffer(rates_total,prev_calculated,0,InpSignalMA,ExtMacdBuffer,ExtSignalBuffer);
   if(InpAppliedSignalMA==MODE_EMA)
      ExponentialMAOnBuffer(rates_total,prev_calculated,0,InpSignalMA,ExtMacdBuffer,ExtSignalBuffer);
   if(InpAppliedSignalMA==MODE_SMMA)
      SmoothedMAOnBuffer(rates_total,prev_calculated,0,InpSignalMA,ExtMacdBuffer,ExtSignalBuffer);
   if(InpAppliedSignalMA==MODE_LWMA)
      LinearWeightedMAOnBuffer(rates_total,prev_calculated,0,InpSignalMA,ExtMacdBuffer,ExtSignalBuffer,weightsum_global);

   for(int i=limit;i>=0;i--)
     {
      //--- calculate Histogram buffer
      ExtHistogramBuffer[i]=ExtMacdBuffer[i]-ExtSignalBuffer[i];
      //--- set color Histogram
      if(InpUseMultiColor==MultiColor)
        {
         if(ExtHistogramBuffer[i]>ExtHistogramBuffer[i+1])
         {
            if(ExtHistogramBuffer[i]>0) ExtHistogramColorBuffer[i]=0;
            else ExtHistogramColorBuffer[i]=3;
         }   
         if(ExtHistogramBuffer[i]<ExtHistogramBuffer[i+1])
         {
            if(ExtHistogramBuffer[i]<0) ExtHistogramColorBuffer[i]=2;
            else ExtHistogramColorBuffer[i]=1;
         }

        }
      if(InpUseMultiColor==SingleColor)
         ExtHistogramColorBuffer[i]=0;
     }

//--- return value of rates_total, will be used as prev_calculated in next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
