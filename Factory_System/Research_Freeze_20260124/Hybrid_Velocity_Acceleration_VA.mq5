//+------------------------------------------------------------------+
//|                                                           VA.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.00"
#property description "Velocity/Acceleration"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2
//--- plot V
#property indicator_label1  "Velocity"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot A
#property indicator_label2  "Acceleration"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- input parameters
input uint                 InpPeriodV        =  14;            // Velocity period
input uint                 InpPeriodA        =  10;            // Acceleration period
input ENUM_APPLIED_PRICE   InpAppliedPrice   =  PRICE_CLOSE;   // Applied price
//--- indicator buffers
double         BufferV[];
double         BufferA[];
double         BufferMA[];
//--- global variables
int            period_v;
int            period_a;
int            handle_ma;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- set global variables
   period_v=int(InpPeriodV<1 ? 1 : InpPeriodV);
   period_a=int(InpPeriodA<1 ? 1 : InpPeriodA);
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferV,INDICATOR_DATA);
   SetIndexBuffer(1,BufferA,INDICATOR_DATA);
   SetIndexBuffer(2,BufferMA,INDICATOR_CALCULATIONS);
//--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME,"VA("+(string)period_v+","+(string)period_a+")");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferV,true);
   ArraySetAsSeries(BufferA,true);
   ArraySetAsSeries(BufferMA,true);
//--- create MA handle
   ResetLastError();
   handle_ma=iMA(NULL,PERIOD_CURRENT,1,0,MODE_SMA,InpAppliedPrice);
   if(handle_ma==INVALID_HANDLE)
     {
      Print("The iMA(1) object was not created: Error ",GetLastError());
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
//--- Проверка на минимальное колиество баров для расчёта
   int max=fmax(period_a,period_v);
   if(rates_total<max) return 0;
//--- Проверка и расчёт количества просчитываемых баров
   int limit=rates_total-prev_calculated;
   if(limit>1)
     {
      limit=rates_total-max-1;
      ArrayInitialize(BufferV,EMPTY_VALUE);
      ArrayInitialize(BufferA,EMPTY_VALUE);
      ArrayInitialize(BufferMA,0);
     }
//--- Подготовка данных
   int copied=0,count=(limit==0 ? 1 : rates_total);
   copied=CopyBuffer(handle_ma,0,0,count,BufferMA);
   if(copied!=count) return 0;
//--- Расчёт индикатора
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      double v=BufferMA[i+period_v];
      double a=BufferV[i+period_a];
      BufferV[i]=(100*BufferMA[i]/(v!=0 ? v : DBL_MIN));
      BufferA[i]=100*BufferV[i]/(a!=0 ? a : DBL_MIN);
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
