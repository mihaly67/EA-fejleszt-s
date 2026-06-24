//+------------------------------------------------------------------+
//|                                                 MACD_Squeeze.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.00"
#property description "MACD Squeeze oscillator"
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   3
//--- plot MACD
#property indicator_label1  "MACDS"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGreen,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot SqueezeIN
#property indicator_label2  "Signal IN"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot SqueezeOUT
#property indicator_label3  "Signal OUT"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
//--- input parameters
input uint           InpPeriodFastEMA     =  8;          // MACD Fast EMA period
input uint           InpPeriodSlowEMA     =  21;         // MACD Slow EMA period
input uint           InpPeriodBB          =  20;         // Bollinger Bands period
input double         InpDeviationBB       =  2.0;        // Bollinger Bands deviation
input ENUM_MA_METHOD InpMethodBB          =  MODE_EMA;   // Bollinger Bands MA method
input uint           InpPeriodKeltner     =  20;         // Keltner period
input double         InpDeviationKeltner  =  1.5;        // Keltner deviation
input uint           InpPeriodATRKeltner  =  10;         // Keltner ATR period
input ENUM_MA_METHOD InpMethodKeltner     =  MODE_EMA;   // Keltner MA method
//--- indicator buffers
double         BufferMACD[];
double         BufferColors[];
double         BufferSqueezeIN[];
double         BufferSqueezeOUT[];
double         BufferFMA[];
double         BufferSMA[];
double         BufferBBMA[];
double         BufferBBDEV[];
double         BufferKMA[];
double         BufferKATR[];
//--- global variables
int            period_fema;
int            period_sema;
int            period_bb;
int            period_klt;
int            period_katr;
int            handle_fma;
int            handle_sma;
int            handle_bbma;
int            handle_bbdev;
int            handle_kma;
int            handle_katr;
double         dev_bb;
double         dev_klt;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- set global variables
   period_fema=int(InpPeriodFastEMA<1 ? 1 : InpPeriodFastEMA);
   period_sema=int(InpPeriodSlowEMA<1 ? 1 : InpPeriodSlowEMA);
   period_bb=int(InpPeriodBB<1 ? 1 : InpPeriodBB);
   period_klt=int(InpPeriodKeltner<1 ? 1 : InpPeriodKeltner);
   period_katr=int(InpPeriodATRKeltner<1 ? 1 : InpPeriodATRKeltner);
   dev_bb=InpDeviationBB;
   dev_klt=InpDeviationKeltner;
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferMACD,INDICATOR_DATA);
   SetIndexBuffer(1,BufferColors,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,BufferSqueezeIN,INDICATOR_DATA);
   SetIndexBuffer(3,BufferSqueezeOUT,INDICATOR_DATA);
   SetIndexBuffer(4,BufferFMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,BufferSMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,BufferBBMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,BufferBBDEV,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,BufferKMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,BufferKATR,INDICATOR_CALCULATIONS);
//--- setting a code from the Wingdings charset as the property of PLOT_ARROW
   PlotIndexSetInteger(1,PLOT_ARROW,119);
   PlotIndexSetInteger(2,PLOT_ARROW,119);
//--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME,"MACD Squeeze ("+(string)period_fema+","+(string)period_sema+","+(string)period_bb+","+(string)period_klt+","+(string)period_katr+")");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferMACD,true);
   ArraySetAsSeries(BufferColors,true);
   ArraySetAsSeries(BufferSqueezeIN,true);
   ArraySetAsSeries(BufferSqueezeOUT,true);
   ArraySetAsSeries(BufferFMA,true);
   ArraySetAsSeries(BufferSMA,true);
   ArraySetAsSeries(BufferBBMA,true);
   ArraySetAsSeries(BufferBBDEV,true);
   ArraySetAsSeries(BufferKMA,true);
   ArraySetAsSeries(BufferKATR,true);
//--- create MA's handles
   ResetLastError();
   handle_fma=iMA(NULL,PERIOD_CURRENT,period_fema,0,MODE_EMA,PRICE_CLOSE);
   if(handle_fma==INVALID_HANDLE)
     {
      Print(__LINE__,": The iMA(",(string)period_fema,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }
   handle_sma=iMA(NULL,PERIOD_CURRENT,period_sema,0,MODE_EMA,PRICE_CLOSE);
   if(handle_sma==INVALID_HANDLE)
     {
      Print(__LINE__,": The iMA(",(string)period_sema,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }
   handle_bbma=iMA(NULL,PERIOD_CURRENT,period_bb,0,InpMethodBB,PRICE_CLOSE);
   if(handle_bbma==INVALID_HANDLE)
     {
      Print(__LINE__,": The iMA(",(string)period_bb,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }
   handle_bbdev=iStdDev(NULL,PERIOD_CURRENT,period_bb,0,MODE_SMA,PRICE_CLOSE);
   if(handle_bbdev==INVALID_HANDLE)
     {
      Print(__LINE__,": The iStdDev(",(string)period_bb,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }

   handle_kma=iMA(NULL,PERIOD_CURRENT,period_klt,0,InpMethodKeltner,PRICE_CLOSE);
   if(handle_kma==INVALID_HANDLE)
     {
      Print(__LINE__,": The iMA(",(string)period_klt,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }

   handle_katr=iATR(NULL,PERIOD_CURRENT,period_katr);
   if(handle_katr==INVALID_HANDLE)
     {
      Print(__LINE__,": The iATR(",(string)period_katr,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }

//---
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
//--- Checking and calculating the number of calculated bars
   if(rates_total<4) return 0;
//--- Checking and calculating the number of calculated bars
   int limit=rates_total-prev_calculated;
   if(limit>1)
     {
      limit=rates_total-2;
      ArrayInitialize(BufferMACD,EMPTY_VALUE);
      ArrayInitialize(BufferSqueezeIN,EMPTY_VALUE);
      ArrayInitialize(BufferSqueezeOUT,EMPTY_VALUE);
      ArrayInitialize(BufferFMA,0);
      ArrayInitialize(BufferSMA,0);
      ArrayInitialize(BufferBBMA,0);
      ArrayInitialize(BufferBBDEV,0);
      ArrayInitialize(BufferKMA,0);
      ArrayInitialize(BufferKATR,0);
     }
//--- Preparing data
   int count=(limit>1 ? rates_total : 1),copied=0;
   copied=CopyBuffer(handle_fma,0,0,count,BufferFMA);
   if(copied!=count) return 0;
   copied=CopyBuffer(handle_sma,0,0,count,BufferSMA);
   if(copied!=count) return 0;
   copied=CopyBuffer(handle_bbma,0,0,count,BufferBBMA);
   if(copied!=count) return 0;
   copied=CopyBuffer(handle_bbdev,0,0,count,BufferBBDEV);
   if(copied!=count) return 0;
   copied=CopyBuffer(handle_kma,0,0,count,BufferKMA);
   if(copied!=count) return 0;
   copied=CopyBuffer(handle_katr,0,0,count,BufferKATR);
   if(copied!=count) return 0;

//--- Calculation of the indicator
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      BufferMACD[i]=BufferFMA[i]-BufferSMA[i];
      BufferColors[i]=(BufferMACD[i]<BufferMACD[i+1] ? 1 : 0);

      double BB_MA=BufferBBMA[i];
      double BB_StdDev=BufferBBDEV[i];
      double BTL=BB_MA+BB_StdDev*InpDeviationBB;
      double BBL=BB_MA-BB_StdDev*InpDeviationBB;

      double K_MA=BufferKMA[i];
      double K_ATR=BufferKATR[i];
      double KTL=K_MA+K_ATR*InpDeviationKeltner;
      double KBL=K_MA-K_ATR*InpDeviationKeltner;

      if(BTL<KTL && BBL>KBL)
        {
         BufferSqueezeOUT[i]=EMPTY_VALUE;
         BufferSqueezeIN[i]=0;
        }
      else
        {
         BufferSqueezeIN[i]=EMPTY_VALUE;
         BufferSqueezeOUT[i]=0;
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
