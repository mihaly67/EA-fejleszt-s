//+------------------------------------------------------------------+
//|                                                   DeltaForce.mq5 |
//|                      Copyright © 2004, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property  copyright "Copyright © 2004, MetaQuotes Software Corp."
#property  link      "http://www.metaquotes.net/"
//---- indicator version number
#property version   "1.01"
//---- drawing the indicator in a separate window
#property indicator_separate_window
//---- number of indicator buffers
#property indicator_buffers 4
//---- only two graphic plots used
#property indicator_plots   2
//+-----------------------------------+
//|  Indicator drawing parameters     |
//+-----------------------------------+
//---- drawing the indicator as a multicolor histogram
#property indicator_type1   DRAW_COLOR_HISTOGRAM
//---- colors used for the two-color histogram
#property indicator_color1  clrBlue,clrDodgerBlue
//---- indicator histogram - solid curve
#property indicator_style1  STYLE_SOLID
//---- indicator line width is 3
#property indicator_width1  3
//---- indicator label display
#property indicator_label1  "High"
//+-----------------------------------+
//|  Indicator drawing parameters     |
//+-----------------------------------+
//---- drawing the indicator as a multicolor histogram
#property indicator_type2   DRAW_COLOR_HISTOGRAM
//---- colors used for the two-color histogram
#property indicator_color2  clrMagenta,clrPurple
//---- indicator histogram - solid curve
#property indicator_style2  STYLE_SOLID
//---- indicator line width is 3
#property indicator_width2  3
//---- indicator label display
#property indicator_label2  "Low"

//+-----------------------------------+
//|  INDICATOR INPUT PARAMETERS       |
//+-----------------------------------+
input int Shift=0; // Horizontal indicator shift in bars
//+-----------------------------------+

//---- declaration of dynamic arrays to be used as indicator buffers
double HIndBuffer[],ColorHIndBuffer[];
double LIndBuffer[],ColorLIndBuffer[];
//---- Declaration of integer variables for data start calculation
int min_rates_total;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//---- Initialization of variables for data start calculation
   min_rates_total=2;
//---- converting dynamic array into indicator buffer
   SetIndexBuffer(0,HIndBuffer,INDICATOR_DATA);
//---- converting dynamic array into color index buffer
   SetIndexBuffer(1,ColorHIndBuffer,INDICATOR_COLOR_INDEX);
//---- setting horizontal shift for indicator 1
   PlotIndexSetInteger(0,PLOT_SHIFT,Shift);
//---- setting start of drawing for the indicator
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---- setting indicator values that will not be visible on the chart
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);

//---- converting dynamic array into indicator buffer
   SetIndexBuffer(2,LIndBuffer,INDICATOR_DATA);
//---- converting dynamic array into color index buffer
   SetIndexBuffer(3,ColorLIndBuffer,INDICATOR_COLOR_INDEX);
//---- setting horizontal shift for indicator 1
   PlotIndexSetInteger(1,PLOT_SHIFT,Shift);
//---- setting start of drawing for the indicator
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
//---- setting indicator values that will not be visible on the chart
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);

//---- creating name for display in separate subwindow and tooltip
   IndicatorSetString(INDICATOR_SHORTNAME,"DeltaForce");

//---- defining precision of indicator values display
   IndicatorSetInteger(INDICATOR_DIGITS,0);
//---- completion of initialization
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,    // amount of history in bars at current tick
                const int prev_calculated,// amount of history in bars at previous tick
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---- checking amount of bars for sufficiency for calculation
   if(rates_total<min_rates_total) return(0);

//---- Declaration of floating point variables
   double dummy; // Renamed to dummy from empty double;
//---- Declaration of integer variables and getting already calculated bars
   int first,bar;
   int diff,deltah,deltal,resh,resl;
   static int deltah_prev,deltal_prev,resh_prev,resl_prev;

//---- calculating start number first for bar recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0) // check for first start of indicator calculation
     {
      first=1; // start number for calculation of all bars
      deltah_prev=NULL;
      deltal_prev=NULL;
      resh_prev=NULL;
      resl_prev=NULL;
     }
   else first=prev_calculated-1; // start number for calculation of new bars

   deltah=deltah_prev;
   deltal=deltal_prev;
   resh=resh_prev;
   resl=resl_prev;

//---- Main indicator calculation loop
   for(bar=first; bar<rates_total && !IsStopped(); bar++)
     {
      HIndBuffer[bar]=NULL;
      LIndBuffer[bar]=NULL;

      diff=int((close[bar]-close[bar-1])/_Point);
      if(diff>0)
        {
         resl=0;
         if(!resh) deltah=NULL;
         deltah+=diff;
         resh=1;
        }
      if(!resh) deltah=NULL;
      HIndBuffer[bar]=deltah;

      if(diff<0)
        {
         resh=0;
         if(!resl) deltal=NULL;
         deltal+=diff;
         resl=1;
        }
      if(!resl) deltal=NULL;
      LIndBuffer[bar]=deltal;

      if(bar<rates_total-1)
        {
         deltah_prev=deltah;
         deltal_prev=deltal;
         resh_prev=resh;
         resl_prev=resl;
        }
     }

//---- adjusting variable first value
   if(prev_calculated>rates_total || prev_calculated<=0) // check for first start of indicator calculation
      first=min_rates_total+1; // start number for calculation of all bars

//---- Main signal line coloring loop
   for(bar=first; bar<rates_total && !IsStopped(); bar++)
     {
      ColorHIndBuffer[bar]=ColorHIndBuffer[bar-1];
      if(HIndBuffer[bar-1]<HIndBuffer[bar]) ColorHIndBuffer[bar]=0;
      else if(HIndBuffer[bar-1]>HIndBuffer[bar]) ColorHIndBuffer[bar]=1;
      //----
      ColorLIndBuffer[bar]=ColorLIndBuffer[bar-1];
      if(LIndBuffer[bar-1]>LIndBuffer[bar]) ColorLIndBuffer[bar]=0;
      else if(LIndBuffer[bar-1]<LIndBuffer[bar]) ColorLIndBuffer[bar]=1;
     }
//----
   return(rates_total);
  }
//+------------------------------------------------------------------+
