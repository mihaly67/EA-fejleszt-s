//+------------------------------------------------------------------
#property copyright   "mladen"
#property link        "mladenfx@gmail.com"
#property description "Macd high/low multi time frame version"
//+------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   7
#property indicator_label1  "Level up"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label2  "Early level up"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT
#property indicator_label3  "Zero level"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkGray
#property indicator_style3  STYLE_DOT
#property indicator_label4  "Early level down"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCrimson
#property indicator_style4  STYLE_DOT
#property indicator_label5  "Level down"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCrimson
#property indicator_label6  "Macd value"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrDarkGray,clrDodgerBlue,clrDeepSkyBlue,clrCrimson,clrRed
#property indicator_width6  3
#property indicator_label7  "Macd signal"
#property indicator_type7   DRAW_COLOR_LINE
#property indicator_color7  clrDarkGray,clrDodgerBlue,clrDeepSkyBlue,clrCrimson,clrRed
#property indicator_width7  1
//--- input parameters
enum enTimeFrames
  {
   tf_cu  = PERIOD_CURRENT, // Current time frame
   tf_m1  = PERIOD_M1,      // 1 minute
   tf_m2  = PERIOD_M2,      // 2 minutes
   tf_m3  = PERIOD_M3,      // 3 minutes
   tf_m4  = PERIOD_M4,      // 4 minutes
   tf_m5  = PERIOD_M5,      // 5 minutes
   tf_m6  = PERIOD_M6,      // 6 minutes
   tf_m10 = PERIOD_M10,     // 10 minutes
   tf_m12 = PERIOD_M12,     // 12 minutes
   tf_m15 = PERIOD_M15,     // 15 minutes
   tf_m20 = PERIOD_M20,     // 20 minutes
   tf_m30 = PERIOD_M30,     // 30 minutes
   tf_h1  = PERIOD_H1,      // 1 hour
   tf_h2  = PERIOD_H2,      // 2 hours
   tf_h3  = PERIOD_H3,      // 3 hours
   tf_h4  = PERIOD_H4,      // 4 hours
   tf_h6  = PERIOD_H6,      // 6 hours
   tf_h8  = PERIOD_H8,      // 8 hours
   tf_h12 = PERIOD_H12,     // 12 hours
   tf_d1  = PERIOD_D1,      // daily
   tf_w1  = PERIOD_W1,      // weekly
   tf_mn  = PERIOD_MN1,     // monthly
   tf_cp1 = -1,             // Next higher time frame
   tf_cp2 = -2,             // Second higher time frame
   tf_cp3 = -3              // Third higher time frame
  };
input enTimeFrames       inpTimeFrame      = tf_cu;       // Time frame
input int                inpFastPeriod     = 19;          // Fast DEMA period
input int                inpSlowPeriod     = 39;          // Slow DEMA period
input int                inpSignalPeriod   = 9;           // Signal period
input int                inpLookBackPeriod = 50;          // Lookback period
input double             inpEarlyLevel     = 25;          // Early levels %
input ENUM_APPLIED_PRICE inpPrice          = PRICE_CLOSE; // Price
input bool               inpInterpolate    = true;        // Interpolate in multi time frame mode?
//--- buffers declarations
double val[],valc[],signal[],signalc[],levelm[],levelu1[],levelu2[],leveld1[],leveld2[],count[];
//--- mtf handling stuff
int     _mtfHandle=INVALID_HANDLE; ENUM_TIMEFRAMES timeFrame;
#define _mtfCall iCustom(_Symbol,timeFrame,getIndicatorName(),0,inpFastPeriod,inpSlowPeriod,inpSignalPeriod,inpLookBackPeriod,inpEarlyLevel,inpPrice)
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,levelu2,INDICATOR_DATA);
   SetIndexBuffer(1,levelu1,INDICATOR_DATA);
   SetIndexBuffer(2,levelm,INDICATOR_DATA);
   SetIndexBuffer(3,leveld1,INDICATOR_DATA);
   SetIndexBuffer(4,leveld2,INDICATOR_DATA);
   SetIndexBuffer(5,val,INDICATOR_DATA);
   SetIndexBuffer(6,valc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7,signal,INDICATOR_DATA);
   SetIndexBuffer(8,signalc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(9,count,INDICATOR_CALCULATIONS);
   for(int i=0; i<5; i++) PlotIndexSetInteger(i,PLOT_SHOW_DATA,false);
//---
   timeFrame=MathMax(timeFrameGet((int)inpTimeFrame),_Period);
   if(timeFrame!=_Period)
     {
      _mtfHandle = _mtfCall; if(_mtfHandle==INVALID_HANDLE) return(INIT_FAILED);
     }
//---
   IndicatorSetString(INDICATOR_SHORTNAME,timeFrameToString(timeFrame)+" Macd high/low ("+(string)inpFastPeriod+","+(string)inpSlowPeriod+","+(string)inpSignalPeriod+","+(string)inpLookBackPeriod+")");
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
   if(timeFrame!=_Period)
     {
      double result[];
      if(BarsCalculated(_mtfHandle)<0)                     return(prev_calculated);
      if(!timeFrameCheck((ENUM_TIMEFRAMES)timeFrame,time)) return(prev_calculated);
      if(CopyBuffer(_mtfHandle,9,0,1,result)==-1)          return(prev_calculated);

      //
      //---
      //

      #define _mtfRatio PeriodSeconds((ENUM_TIMEFRAMES)timeFrame)/PeriodSeconds(_Period)
      int k,n,i=MathMin(MathMax(prev_calculated-1,0),MathMax(rates_total-(int)result[0]*_mtfRatio-1,0)),_prevMark=0,_seconds=PeriodSeconds(timeFrame);
      for(; i<rates_total && !_StopFlag; i++)
        {
         int _currMark = int(time[i]/_seconds);
         if (_currMark!=_prevMark)
         {
            _prevMark = _currMark;
            #define _mtfCopy(_buff,_buffNo) if(CopyBuffer(_mtfHandle,_buffNo,time[i],1,result)==-1) break; _buff[i]=result[0]
                    _mtfCopy(levelu2,0);
                    _mtfCopy(levelu1,1);
                    _mtfCopy(levelm ,2);
                    _mtfCopy(leveld1,3);
                    _mtfCopy(leveld2,4);
                    _mtfCopy(val    ,5);
                    _mtfCopy(valc   ,6);
                    _mtfCopy(signal ,7);
         }
         else
         {
            levelu2[i] = levelu2[i-1];
            levelu1[i] = levelu1[i-1];
            levelm[i]  = levelm[i-1];
            leveld1[i] = leveld1[i-1];
            leveld2[i] = leveld2[i-1];
            val[i]     = val[i-1];
            valc[i]    = valc[i-1];
            signal[i]  = signal[i-1];
         }
         signalc[i] = valc[i];

         //
         //---
         //

         if (!inpInterpolate)  continue;
            int _nextMark = (i<rates_total-1) ? int(time[i+1]/_seconds) : _prevMark+1; if (_nextMark == _prevMark) continue;
            for(n=1; (i-n)> 0 && time[i-n] >= (_prevMark)*_seconds; n++) continue;
            for(k=1; (i-k)>=0 && k<n; k++)
            {
               #define _mtfInterpolate(_buff) _buff[i-k]=_buff[i]+(_buff[i-n]-_buff[i])*k/n
                       _mtfInterpolate(levelu2);
                       _mtfInterpolate(levelu1);
                       _mtfInterpolate(levelm);
                       _mtfInterpolate(leveld1);
                       _mtfInterpolate(leveld2);
                       _mtfInterpolate(val);
                       _mtfInterpolate(signal);
            }
        }
      return(i);
     }
   //
   //---
   //
   int i=(int)MathMax(prev_calculated-1,0); for(; i<rates_total && !_StopFlag; i++)
     {
      double _price=getPrice(inpPrice,open,close,high,low,i,rates_total);
      val[i]    = iEma(_price,inpFastPeriod,i,rates_total,0)-iEma(_price,inpSlowPeriod,i,rates_total,1);
      signal[i] = iEma(val[i],inpSignalPeriod,i,rates_total,2);
      int _start = MathMax(i-inpLookBackPeriod,0); // shifted by 1 to the past on purpose, no error
      int _count = MathMin(_start+1,inpLookBackPeriod);
      double max = val[ArrayMaximum(val,_start,_count)];
      double min = val[ArrayMinimum(val,_start,_count)];
      levelu2[i] = max;
      leveld2[i] = min;
      levelm[i]  = (max+min)/2.0;
      levelu1[i] = levelm[i]+(levelu2[i]-levelm[i])*inpEarlyLevel/100.0;
      leveld1[i] = levelm[i]-(levelm[i]-leveld2[i])*inpEarlyLevel/100.0;
      valc[i]    = (val[i]>signal[i]) ?(val[i]>levelu2[i]) ? 2 :(val[i])>levelm[i]? 1 : 0 :(val[i]<signal[i]) ? val[i]<leveld2[i]? 4 :(val[i]<levelm[i]) ? 3 : 0 :(i>0) ? valc[i-1]: 0;
      signalc[i] = valc[i];
     }
   count[rates_total-1]=MathMax(rates_total-prev_calculated+1,1);
   return (i);
  }
//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
double workEma[][3];
//
//---
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
//---
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
//
//---
//
ENUM_TIMEFRAMES _tfsPer[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
string          _tfsStr[]={"1 minute","2 minutes","3 minutes","4 minutes","5 minutes","6 minutes","10 minutes","12 minutes","15 minutes","20 minutes","30 minutes","1 hour","2 hours","3 hours","4 hours","6 hours","8 hours","12 hours","daily","weekly","monthly"};
//
//---
//
string timeFrameToString(int period)
  {
   if(period==PERIOD_CURRENT)
      period=_Period;
   int i; for(i=0;i<ArraySize(_tfsPer);i++) if(period==_tfsPer[i]) break;
   return(_tfsStr[i]);
  }
//
//---
//
ENUM_TIMEFRAMES timeFrameGet(int period)
  {
   int _shift=(period<0?MathAbs(period):0);
   if(_shift>0 || period==tf_cu) period=_Period;
   int i; for(i=0;i<ArraySize(_tfsPer);i++) if(period==_tfsPer[i]) break;

   return(_tfsPer[(int)MathMin(i+_shift,ArraySize(_tfsPer)-1)]);
  }
//
//---
//
string getIndicatorName()
  {
   string _path=MQL5InfoString(MQL5_PROGRAM_PATH);
   string _partsA[];
   ushort _partsS=StringGetCharacter("\\",0);
   int _partsN = StringSplit(_path,_partsS,_partsA);
   string name = _partsA[_partsN-1]; for(int n=_partsN-2; n>=0 && _toLower(_partsA[n])!="indicators"; n--) name = _partsA[n]+"\\"+name;
   return(name);
  }
string _toLower(string _toConvert) { StringToLower(_toConvert); return(_toConvert); }
//
//---
//
bool timeFrameCheck(ENUM_TIMEFRAMES _timeFrame,const datetime &time[])
  {
   static bool warned=false;
   if(time[0]<SeriesInfoInteger(_Symbol,_timeFrame,SERIES_FIRSTDATE))
     {
      datetime startTime,testTime[];
      if(SeriesInfoInteger(_Symbol,PERIOD_M1,SERIES_TERMINAL_FIRSTDATE,startTime))
      if(startTime>0)                       { CopyTime(_Symbol,_timeFrame,time[0],1,testTime); SeriesInfoInteger(_Symbol,_timeFrame,SERIES_FIRSTDATE,startTime); }
      if(startTime<=0 || startTime>time[0]) { Comment(MQL5InfoString(MQL5_PROGRAM_NAME)+"\nMissing data for "+timeFrameToString(_timeFrame)+" time frame\nRe-trying on next tick"); warned=true; return(false); }
     }
   if(warned) { Comment(""); warned=false; }
   return(true);
  }
//+------------------------------------------------------------------+