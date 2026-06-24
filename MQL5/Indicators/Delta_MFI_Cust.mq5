//+------------------------------------------------------------------+
//|                                                    Delta_MFI.mq5 |
//|                                              Copyright 2016, Tor |
//|                                             http://einvestor.ru/ |
//+------------------------------------------------------------------+
//---- author of the indicator
#property copyright "Copyright 2016, Tor"
//---- link to the author's site
#property link      "http://einvestor.ru/"
//---- indicator version number
#property version   "1.00"
//---- drawing the indicator in a separate window
#property indicator_separate_window
//---- five buffers used for calculation and drawing of the indicator
#property indicator_buffers 5
//---- one graphic plot used
#property indicator_plots   1
//+----------------------------------------------+
//|  constant declaration                        |
//+----------------------------------------------+
#define RESET 0               // Constant for returning the recalculation command to the terminal
#define Up 0                  // Constant for growing trend
#define Pass 1                // Constant for flat
#define Down 2                // Constant for falling trend
//+----------------------------------------------+
//|  Indicator drawing parameters                |
//+----------------------------------------------+
//---- drawing the indicator as a colored histogram
#property indicator_type1 DRAW_COLOR_HISTOGRAM
//---- colors used for the histogram
#property indicator_color1 clrDodgerBlue,clrSlateGray,clrDeepPink
//---- indicator line - solid
#property indicator_style1 STYLE_SOLID
//---- indicator line width is 4
#property indicator_width1 4
//---- display of the indicator line label
#property indicator_label1  "Delta_MFI"
//+----------------------------------------------+
//|  enumeration declaration                     |
//+----------------------------------------------+
enum TypeGraph
  {
   Histogram=0,// Full Histogram
   Cute=1,     // Cute Histogram
  };
//+----------------------------------------------+
//| Indicator Input Parameters                   |
//+----------------------------------------------+
input TypeGraph            TypeGr=Histogram;       // Type graph
input ENUM_APPLIED_VOLUME VolumeType=VOLUME_TICK;  // Volume
//---
input uint                 MFIPeriod1=14;          // Fast MFI Period
//---
input uint                 MFIPeriod2=50;          // Slow MFI Period
//---
input uint                 Level=50;               // Signal Level
//---
input int                  Shift=0;                // Horizontal indicator shift in bars
//+----------------------------------------------+
//---- declaration of dynamic arrays to be used as indicator buffers
double mfi1[],mfi2[],delta[],IndBuffer[],ColorIndBuffer[];
//--- declaration of integer variables for indicator handles
int Ind1_Handle,Ind2_Handle;
//---- Declaration of integer variables for data start calculation
int min_rates_total,maxLevel,minLevel;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- getting handle for MFI 1 indicator
   Ind1_Handle=iMFI(Symbol(),PERIOD_CURRENT,MFIPeriod1,VolumeType);
   if(Ind1_Handle==INVALID_HANDLE)
     {
      Print(" Failed to get handle for MFI 1 indicator");
      return(INIT_FAILED);
     }
//--- getting handle for MFI 2 indicator
   Ind2_Handle=iMFI(Symbol(),PERIOD_CURRENT,MFIPeriod2,VolumeType);
   if(Ind2_Handle==INVALID_HANDLE)
     {
      Print(" Failed to get handle for MFI 2 indicator");
      return(INIT_FAILED);
     }

//---- Initialization of variables for data start calculation
   min_rates_total=int(MathMax(MFIPeriod1,MFIPeriod2));
   maxLevel=int(100-(100-Level));
   minLevel=int(100-Level);

//---- converting dynamic array into indicator buffer
   SetIndexBuffer(0,IndBuffer,INDICATOR_DATA);
//---- converting dynamic array into color index buffer
   SetIndexBuffer(1,ColorIndBuffer,INDICATOR_COLOR_INDEX);
//---- setting horizontal shift for indicator 1
   PlotIndexSetInteger(0,PLOT_SHIFT,Shift);
//---- setting start of drawing for the indicator
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---- setting indicator values that will not be visible on the chart
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---- converting dynamic array into buffer for data storage
   SetIndexBuffer(2,mfi1,INDICATOR_CALCULATIONS);
//---- converting dynamic array into buffer for data storage
   SetIndexBuffer(3,mfi2,INDICATOR_CALCULATIONS);
//---- converting dynamic array into buffer for data storage
   SetIndexBuffer(4,delta,INDICATOR_CALCULATIONS);

//--- indexing elements in buffer as timeseries
   ArraySetAsSeries(IndBuffer,true);
   ArraySetAsSeries(ColorIndBuffer,true);
   ArraySetAsSeries(mfi1,true);
   ArraySetAsSeries(mfi2,true);
   ArraySetAsSeries(delta,true);

//---- initialization of variable for short indicator name
   string shortname;
   StringConcatenate(shortname,"Delta_MFI(",MFIPeriod1,",",MFIPeriod2,")");
//--- creating name for display in separate subwindow and tooltip
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//--- defining precision of indicator values display
   IndicatorSetInteger(INDICATOR_DIGITS,0);
//--- completion of initialization
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(
                const int rates_total,    // amount of history in bars at current tick
                const int prev_calculated,// amount of history in bars at previous tick
                const datetime &time[],
                const double &open[],
                const double& high[],     // price array of high prices for indicator calculation
                const double& low[],      // price array of low prices for indicator calculation
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
//---- checking amount of bars for sufficiency for calculation
   if(BarsCalculated(Ind1_Handle)<rates_total
       || BarsCalculated(Ind2_Handle)<rates_total
       || rates_total<min_rates_total) return(RESET);

//---- declaration of local variables
   int limit,to_copy,bar,clr;

//---- calculating start number first for bar recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0) // check for first start of indicator calculation
     {
      limit=rates_total-min_rates_total-1; // start number for calculation of all bars
     }
   else limit=rates_total-prev_calculated; // start number for calculation of new bars

   to_copy=limit+1;

//---- copying newly appeared data into arrays
   if(CopyBuffer(Ind1_Handle,0,0,to_copy,mfi1)<=0) return(RESET);
   if(CopyBuffer(Ind2_Handle,0,0,to_copy,mfi2)<=0) return(RESET);

//---- main indicator calculation loop
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      delta[bar] = mfi1[bar]-mfi2[bar];
      if(TypeGr==Cute) IndBuffer[bar]=1;
      else IndBuffer[bar]=delta[bar];
      //----
      clr=Pass;
      if(mfi2[bar]>maxLevel && mfi1[bar]>mfi2[bar]) clr=Up;
      if(mfi2[bar]<minLevel && mfi1[bar]<mfi2[bar]) clr=Down;
      ColorIndBuffer[bar]=clr;
     }
//----
   return(rates_total);
  }
//+------------------------------------------------------------------+
