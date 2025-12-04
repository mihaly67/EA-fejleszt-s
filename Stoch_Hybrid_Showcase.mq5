//+------------------------------------------------------------------+
//|                                        Stoch_Hybrid_Showcase.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.20"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   2

//--- plot StochTEMA
#property indicator_label1  "StochTEMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot SignalArrows
#property indicator_label2  "TradeSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGold
#property indicator_width2  2

//--- Input parameters
input int      InpKPeriod     = 5;        // K Period
input int      InpDPeriod     = 3;        // D Period
input int      InpSlowing     = 3;        // Slowing
input int      InpTEMAPeriod  = 5;        // TEMA Smoothing Period
input int      InpATRPeriod   = 14;       // ATR Period for Volatility Filter
input double   InpATRThreshold= 0.0001;   // Min Volatility Threshold
input int      InpTrendPeriod = 200;      // Trend Filter EMA Period
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Stochastic MA Method
input ENUM_STO_PRICE InpPriceField = STO_LOWHIGH; // Price Field

//--- Indicator buffers
double         StochTEMABuffer[];
double         SignalBuffer[];
double         StochBuffer[];
double         ATRBuffer[];
double         TrendMABuffer[];

//--- TEMA Calculation Buffers
double         Ema1Buffer[];
double         Ema2Buffer[];
double         Ema3Buffer[];

//--- Global Handles
int            hStoch;
int            hATR;
int            hTrendMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,StochTEMABuffer,INDICATOR_DATA);
   SetIndexBuffer(1,SignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,StochBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ATRBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,TrendMABuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,Ema1Buffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,Ema2Buffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,Ema3Buffer,INDICATOR_CALCULATIONS);

   // CRITICAL FIX: Set arrays as series (0 = Newest) for correct CopyBuffer behavior
   ArraySetAsSeries(StochTEMABuffer, true);
   ArraySetAsSeries(SignalBuffer, true);
   ArraySetAsSeries(StochBuffer, true);
   ArraySetAsSeries(ATRBuffer, true);
   ArraySetAsSeries(TrendMABuffer, true);
   ArraySetAsSeries(Ema1Buffer, true);
   ArraySetAsSeries(Ema2Buffer, true);
   ArraySetAsSeries(Ema3Buffer, true);

//--- plot settings
   PlotIndexSetInteger(1,PLOT_ARROW,159); // 159=Dot/Circle
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);

//--- name
   IndicatorSetString(INDICATOR_SHORTNAME,"Stoch Hybrid TEMA ("+string(InpKPeriod)+")");

//--- Get Handles
   hStoch = iStochastic(_Symbol, _Period, InpKPeriod, InpDPeriod, InpSlowing, InpMAMethod, InpPriceField);
   if(hStoch == INVALID_HANDLE) { Print("Failed to create Stochastic handle"); return(INIT_FAILED); }

   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(hATR == INVALID_HANDLE) { Print("Failed to create ATR handle"); return(INIT_FAILED); }

   hTrendMA = iMA(_Symbol, _Period, InpTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(hTrendMA == INVALID_HANDLE) { Print("Failed to create Trend MA handle"); return(INIT_FAILED); }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate EMA for a single step                          |
//+------------------------------------------------------------------+
double CalculateEMA(double price, double prevEMA, double alpha)
{
   if(prevEMA == 0.0 || prevEMA == EMPTY_VALUE) return price;
   return prevEMA + alpha * (price - prevEMA);
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
   if(rates_total < InpKPeriod + InpTEMAPeriod + InpTrendPeriod) return(0);

   int calcStoch = BarsCalculated(hStoch);
   int calcATR = BarsCalculated(hATR);
   int calcMA = BarsCalculated(hTrendMA);

   if(calcStoch < rates_total || calcATR < rates_total || calcMA < rates_total) return(0);

   //--- Fill External Indicator Buffers
   // CopyBuffer copies to [0] = Newest when ArraySetAsSeries is true
   int to_copy = (prev_calculated > 0) ? rates_total - prev_calculated + 1 : rates_total;

   if(CopyBuffer(hStoch, 0, 0, to_copy, StochBuffer) <= 0) return(0);
   if(CopyBuffer(hATR, 0, 0, to_copy, ATRBuffer) <= 0) return(0);
   if(CopyBuffer(hTrendMA, 0, 0, to_copy, TrendMABuffer) <= 0) return(0);

   //--- Calculation Loop
   // We iterate from Oldest (rates_total-1) to Newest (0) because TEMA relies on previous state (i+1 since Series=true)

   int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total - 1;

   double alpha = 2.0 / (InpTEMAPeriod + 1.0);

   for(int i = limit; i >= 0; i--)
     {
      double rawVal = StochBuffer[i];

      // Initialize if first bar (oldest in history)
      if(i == rates_total - 1)
      {
         Ema1Buffer[i] = rawVal;
         Ema2Buffer[i] = rawVal;
         Ema3Buffer[i] = rawVal;
         StochTEMABuffer[i] = rawVal;
      }
      else
      {
         // i+1 is the older bar (Previous)
         Ema1Buffer[i] = CalculateEMA(rawVal, Ema1Buffer[i+1], alpha);
         Ema2Buffer[i] = CalculateEMA(Ema1Buffer[i], Ema2Buffer[i+1], alpha);
         Ema3Buffer[i] = CalculateEMA(Ema2Buffer[i], Ema3Buffer[i+1], alpha);

         StochTEMABuffer[i] = (3 * Ema1Buffer[i]) - (3 * Ema2Buffer[i]) + Ema3Buffer[i];
      }

      // --- Signal Logic ---
      SignalBuffer[i] = 0.0;

      if(i < rates_total - 2)
      {
         bool isVolatile = (ATRBuffer[i] > InpATRThreshold);
         // Access Close price directly. Since OnCalculate arrays like 'close' are NOT Series by default unless set,
         // but 'time', 'open' etc are often passed as is.
         // Safer to assume 'close' follows standard array indexing unless ArraySetAsSeries called on it.
         // However, standard MQL5 'close[]' passed to OnCalculate is NOT series.
         // BUT we can use iClose or access via rates_total-1-i if we want to align with our Series buffers.
         // OR simpler: Set as series for the passed arrays too? No, we can't change them.
         // Let's use the explicit index for 'close': 'rates_total - 1 - i' corresponds to our Series 'i'.

         double closePrice = close[rates_total - 1 - i];

         bool isUptrend = (closePrice > TrendMABuffer[i]);
         bool isDowntrend = (closePrice < TrendMABuffer[i]);

         // Cross logic (Series: i=Current, i+1=Previous)
         bool crossUp20 = (StochTEMABuffer[i+1] < 20.0 && StochTEMABuffer[i] >= 20.0);
         bool crossDown80 = (StochTEMABuffer[i+1] > 80.0 && StochTEMABuffer[i] <= 80.0);

         if(isVolatile)
         {
            if(crossUp20 && isUptrend)
            {
               SignalBuffer[i] = StochTEMABuffer[i];
            }
            else if(crossDown80 && isDowntrend)
            {
               SignalBuffer[i] = StochTEMABuffer[i];
            }
         }
      }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
