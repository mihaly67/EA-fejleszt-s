//|                                             Psychology_Index.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
#property link      "https://mql5.com"
#property version   "1.00"
#property description "Psychology Index"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
//--- plot PI
#property indicator_label1  "Psy Index"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- input parameters
input uint     InpPeriod   =  12;   // Period
//--- indicator buffers
double         BufferPI[];
double         BufferUpD[];
//--- global variables
int            period_ind;
//--- includes
#include <MovingAverages.mqh>
//| Custom indicator initialization function                         |
int OnInit()
  {des
#include <MovingAverages.mqh>
//| Custom indicator initialization function                         |
int OnInit()
  {
//--- set global variables
   period_ind=int(InpPeriod<1 ? 1 : InpPeriod);
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferPI,INDICATOR_DATA);
   SetIndexBuffer(1,BufferUpD,INDICATOR_CALCULATIONS);
//--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME,"PsyIndex("+(string)period_ind+")");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferPI,true);
   ArraySetAsSeries(BufferUpD,true);
//---
   return(INIT_SUCCEEDED);
  }
//| Custom indicator iteration function                              |
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],me &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Проверка на минимальное колиество баров для расчёта
   if(rates_total<period_ind) return 0;
//--- Установка массивов буферов как таймсерий
   ArraySetAsSeries(close,true);
//--- Проверка и расчёт количества просчитываемых баров
   int limit=rates_total-prev_calculated;
   if(limit>1)
     {
      limit=rates_total-2;
      ArrayInitialize(BufferPI,EMPTY_VALUE);
      ArrayInitialize(BufferUpD,0);
     }
//--- Подготовка данных
   for(int i=limit; i>=0 && !IsStopped(); i--)
      BufferUpD[i]=(close[i]>close[i+1] ? 1 : 0);
//--- Расчёт индикатора
   SimpleMAOnBuffer(rates_total,prev_calculated,0,period_ind,BufferUpD,BufferPI);Расчёт индикатора
   SimpleMAOnBuffer(rates_total,prev_calculated,0,period_ind,BufferUpD,BufferPI);
//--- return value of prev_calculated for next call
   return(rates_total);
  }
