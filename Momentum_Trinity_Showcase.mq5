//+------------------------------------------------------------------+
//|                                     Momentum_Trinity_Showcase.mq5|
//|                             Copyright 2024, Gemini & User Collaboration |
//|                                       Verzió: 1.0 (Concept 1)    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot settings
#property indicator_label1  "Momentum Trinity"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input parameters
input int      InpWPRPeriod   = 14;    // WPR Period
input int      InpRSIPeriod   = 14;    // RSI Period
input int      InpStochK      = 5;     // Stochastic K
input int      InpStochD      = 3;     // Stochastic D
input int      InpStochSlowing= 3;     // Stochastic Slowing
input double   InpOverbought  = 70.0;  // Overbought Level (Combined)
input double   InpOversold    = 30.0;  // Oversold Level (Combined)

//--- Indicator Buffers
double         TrinityBuffer[];
double         ColorBuffer[];

//--- Indicator Handles
int            hWPR;
int            hRSI;
int            hStoch;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Indicator buffers mapping
   SetIndexBuffer(0, TrinityBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

//--- Plot settings
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(0, PLOT_LABEL, "Trinity Score");

//--- Fixed Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpOversold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpOverbought);

//--- Create Indicator Handles
   hWPR = iWPR(_Symbol, _Period, InpWPRPeriod);
   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);

   if(hWPR == INVALID_HANDLE || hRSI == INVALID_HANDLE || hStoch == INVALID_HANDLE)
     {
      Print("Error creating indicator handles!");
      return(INIT_FAILED);
     }

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
   int start;
   if(prev_calculated == 0) start = 0;
   else start = prev_calculated - 1;

   //--- Buffers for source indicators
   double wpr_vals[], rsi_vals[], stoch_vals[];
   ArraySetAsSeries(wpr_vals, true); // Not strictly necessary if we copy by index, but good habit
   ArraySetAsSeries(rsi_vals, true);
   ArraySetAsSeries(stoch_vals, true);

   // We need to calculate for the range [start ... rates_total-1]
   // But CopyBuffer uses 'count' and 'start_pos'.
   // It's easier to copy specific chunks or just loop carefully.
   // Let's loop and copy 1-by-1 or small chunks? No, batch copy is better.

   // Calculate number of bars to process
   int to_copy = rates_total - start;
   if (to_copy <= 0) return prev_calculated;

   double wpr[], rsi[], stoch[];

   // Copy data from indicators
   if(CopyBuffer(hWPR, 0, 0, to_copy, wpr) < to_copy) return 0;
   if(CopyBuffer(hRSI, 0, 0, to_copy, rsi) < to_copy) return 0;
   if(CopyBuffer(hStoch, 0, 0, to_copy, stoch) < to_copy) return 0;

   // Main Loop
   for(int i = 0; i < to_copy; i++)
     {
      // Calculate buffer index (relative to the whole chart)
      int idx = start + i;

      // 1. WPR: -100 to 0. Add 100 to get 0-100.
      double wpr_norm = wpr[i] + 100.0;

      // 2. RSI: 0-100.
      double rsi_norm = rsi[i];

      // 3. Stoch: 0-100.
      double stoch_norm = stoch[i];

      // Average
      double trinity = (wpr_norm + rsi_norm + stoch_norm) / 3.0;
      TrinityBuffer[idx] = trinity;

      // Color Logic
      // 0: Gray (Neutral), 1: Lime (Bullish Agreement), 2: Red (Bearish Agreement)
      if (trinity > InpOverbought)
         ColorBuffer[idx] = 1.0; // Lime (Overbought zone - potentially strong trend or reversal, lets call it 'Hot' zone)
      else if (trinity < InpOversold)
         ColorBuffer[idx] = 2.0; // Red (Oversold zone)
      else
         ColorBuffer[idx] = 0.0; // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hWPR);
   IndicatorRelease(hRSI);
   IndicatorRelease(hStoch);
  }
//+------------------------------------------------------------------+
