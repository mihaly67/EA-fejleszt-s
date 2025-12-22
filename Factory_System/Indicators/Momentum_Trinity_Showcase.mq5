//+------------------------------------------------------------------+
//|                                    Momentum_Trinity_Showcase.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1

//--- plot TrinitySignal
#property indicator_label1  "TrinityPulse"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input parameters
input int      InpPeriod      = 14;       // Common Period

//--- Indicator buffers
double         TrinityBuffer[]; // 1 = Buy, -1 = Sell, 0 = Neutral
double         RSIBuffer[];
double         StochBuffer[];
double         MFIBuffer[];

//--- Global Handles
int            hRSI;
int            hStoch;
int            hMFI;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,TrinityBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,RSIBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,StochBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,MFIBuffer,INDICATOR_CALCULATIONS);

   ArraySetAsSeries(TrinityBuffer, true);
   ArraySetAsSeries(RSIBuffer, true);
   ArraySetAsSeries(StochBuffer, true);
   ArraySetAsSeries(MFIBuffer, true);

   IndicatorSetString(INDICATOR_SHORTNAME,"Momentum Trinity ("+string(InpPeriod)+")");

   hRSI   = iRSI(_Symbol, _Period, InpPeriod, PRICE_CLOSE);
   hStoch = iStochastic(_Symbol, _Period, InpPeriod, 3, 3, MODE_SMA, STO_LOWHIGH);
   hMFI   = iMFI(_Symbol, _Period, InpPeriod, VOLUME_TICK);

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
   if(rates_total < InpPeriod) return(0);

   int to_copy = (prev_calculated > 0) ? rates_total - prev_calculated + 1 : rates_total;

   if(CopyBuffer(hRSI, 0, 0, to_copy, RSIBuffer) <= 0) return(0);
   if(CopyBuffer(hStoch, 0, 0, to_copy, StochBuffer) <= 0) return(0);
   if(CopyBuffer(hMFI, 0, 0, to_copy, MFIBuffer) <= 0) return(0);

   int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total - 1;

   for(int i = limit; i >= 0; i--)
     {
      bool rsiBuy = (RSIBuffer[i] < 30);
      bool rsiSell = (RSIBuffer[i] > 70);

      bool stochBuy = (StochBuffer[i] < 20);
      bool stochSell = (StochBuffer[i] > 80);

      bool mfiBuy = (MFIBuffer[i] < 20);
      bool mfiSell = (MFIBuffer[i] > 80);

      // Trinity Logic: ALL must agree for a signal
      if(rsiBuy && stochBuy && mfiBuy)
         TrinityBuffer[i] = 1.0; // Strong Buy Pulse
      else if(rsiSell && stochSell && mfiSell)
         TrinityBuffer[i] = -1.0; // Strong Sell Pulse
      else
         TrinityBuffer[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
