//+------------------------------------------------------------------
#property copyright   "mladen"
#property link        "mladenfx@gmail.com"
#property link        "https://www.mql5.com"
#property description "Macd TEMA"
//+------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_label1  "Macd tema filling"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'218,231,226',C'255,221,217'
#property indicator_label2  "Macd value"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrDarkGray,clrDodgerBlue,clrCrimson
#property indicator_width2  2
#property indicator_label3  "Macd signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_width3  1

//--- input parameters
input int                inpFastPeriod   = 19;          // Fast TEMA period
input int                inpSlowPeriod   = 39;          // Slow TEMA period
input int                inpSignalPeriod = 9;           // Signal period
input ENUM_APPLIED_PRICE inpPrice        = PRICE_CLOSE; // Price
//--- buffers declarations
double fillu[],filld[],val[],valc[],signal[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,fillu,INDICATOR_DATA);
   SetIndexBuffer(1,filld,INDICATOR_DATA);
   SetIndexBuffer(2,val,INDICATOR_DATA);
   SetIndexBuffer(3,valc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,signal,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_SHOW_DATA,false);
//---
   IndicatorSetString(INDICATOR_SHORTNAME,"Macd TEMA ("+(string)inpFastPeriod+","+(string)inpSlowPeriod+","+(string)inpSignalPeriod+")");
//---
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator de-initialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(Bars(_Symbol,_Period)<rates_total) return(prev_calculated);

   int i=(int)MathMax(prev_calculated-1,1); for(; i<rates_total && !_StopFlag; i++)
     {
      double _price=getPrice(inpPrice,open,close,high,low,i,rates_total);
      val[i]    = iTema(_price,inpFastPeriod,i,rates_total,0)-iTema(_price,inpSlowPeriod,i,rates_total,1);
      signal[i] = iEma(val[i],inpSignalPeriod,i,rates_total,0);
      fillu[i]  = val[i];
      filld[i]  = signal[i];
      valc[i]= (val[i]>signal[i]) ? 1 :(val[i]<signal[i]) ? 2 : (i>0) ? valc[i-1]: 0;
     }
   return (i);
  }
//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
double workEma[][1];
//
double iEma(double price,double period,int r,int _bars,int instanceNo=0)
  {
   if(ArrayRange(workEma,0)!=_bars) ArrayResize(workEma,_bars);

   workEma[r][instanceNo]=price;
   if(r>0 && period>1)
      workEma[r][instanceNo]=workEma[r-1][instanceNo]+(2.0/(1.0+period))*(price-workEma[r-1][instanceNo]);
   return(workEma[r][instanceNo]);
  }
//
//
//
double workTema[][6];
#define _tema1 0
#define _tema2 1
#define _tema3 2
//
double iTema(double price, double period, int r, int bars, int instanceNo=0)
{
   if (period<=1) return(price);
   if (ArrayRange(workTema,0)!= bars) ArrayResize(workTema,bars); instanceNo*=3;

   //
   //
   //
   //
   //

   workTema[r][_tema1+instanceNo] = price;
   workTema[r][_tema2+instanceNo] = price;
   workTema[r][_tema3+instanceNo] = price;
   double alpha = 2.0 / (1.0+period);
   if (r>0)
   {
          workTema[r][_tema1+instanceNo] = workTema[r-1][_tema1+instanceNo]+alpha*(price                         -workTema[r-1][_tema1+instanceNo]);
          workTema[r][_tema2+instanceNo] = workTema[r-1][_tema2+instanceNo]+alpha*(workTema[r][_tema1+instanceNo]-workTema[r-1][_tema2+instanceNo]);
          workTema[r][_tema3+instanceNo] = workTema[r-1][_tema3+instanceNo]+alpha*(workTema[r][_tema2+instanceNo]-workTema[r-1][_tema3+instanceNo]); }
   return(workTema[r][_tema3+instanceNo]+3.0*(workTema[r][_tema1+instanceNo]-workTema[r][_tema2+instanceNo]));
}
//
//
//
double getPrice(ENUM_APPLIED_PRICE tprice,const double &open[],const double &close[],const double &high[],const double &low[],int i,int _bars)
  {
   switch(tprice)
     {
      case PRICE_CLOSE:     return(close[i]);
      case PRICE_OPEN:      return(open[i]);
      case PRICE_HIGH:      return(high[i]);
      case PRICE_LOW:       return(low[i]);
      case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
      case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
      case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
     }
   return(0);
  }
//+------------------------------------------------------------------+