//+------------------------------------------------------------------
#property copyright   "mladen"
#property link        "mladenfx@gmail.com"
#property link        "https://www.mql5.com"
#property description "Macd DEMA"
//+------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_label1  "Macd dema filling"
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
input int                inpFastPeriod   = 19;          // Fast DEMA period
input int                inpSlowPeriod   = 39;          // Slow DEMA period
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
   IndicatorSetString(INDICATOR_SHORTNAME,"Macd DEMA ("+(string)inpFastPeriod+","+(string)inpSlowPeriod+","+(string)inpSignalPeriod+")");
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
      val[i]    = iDema(_price,inpFastPeriod,i,rates_total,0)-iDema(_price,inpSlowPeriod,i,rates_total,1);
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
double workDema[][4];
#define _dema1 0
#define _dema2 1
//
double iDema(double price,double period,int r,int bars,int instanceNo=0)
  {
   if(period<=1) return(price);
   if(ArrayRange(workDema,0)!=bars) ArrayResize(workDema,bars); instanceNo*=2;
//
   workDema[r][_dema1+instanceNo] = price;
   workDema[r][_dema2+instanceNo] = price;
   double alpha=2.0/(1.0+period);
   if(r>0)
     {
      workDema[r][_dema1+instanceNo]=workDema[r-1][_dema1+instanceNo]+alpha*(price                         -workDema[r-1][_dema1+instanceNo]);
      workDema[r][_dema2+instanceNo]=workDema[r-1][_dema2+instanceNo]+alpha*(workDema[r][_dema1+instanceNo]-workDema[r-1][_dema2+instanceNo]);
     }
   return(workDema[r][_dema1+instanceNo]*2.0-workDema[r][_dema2+instanceNo]);
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