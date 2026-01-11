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
  {