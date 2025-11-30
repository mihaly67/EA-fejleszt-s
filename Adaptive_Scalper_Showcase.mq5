//+------------------------------------------------------------------+
//|                                    Adaptive_Scalper_Showcase.mq5 |
//|                             Copyright 2024, Gemini & User Collaboration |
//|                                       Verzió: 1.0 (Concept 3)    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

//--- Plot settings
#property indicator_label1  "FRAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  3

#property indicator_label3  "Sell Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  3

//--- Input parameters
input int      InpFRAMAPeriod = 16;    // FRAMA Period (Even number preferred)
input int      InpWPRPeriod   = 14;    // WPR Period
input int      InpATRPeriod   = 14;    // ATR Period
input double   InpATRThresh   = 0.0005;// Min Volatility Threshold (Points)

//--- Indicator Buffers
double         FRAMABuffer[];
double         BuyArrowBuffer[];
double         SellArrowBuffer[];
double         WPRBuffer[]; // Calculation buffer

//--- Handles
int            hWPR;
int            hATR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Ensure even period for FRAMA splitting
   if(InpFRAMAPeriod % 2 != 0) InpFRAMAPeriod++;

   SetIndexBuffer(0, FRAMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BuyArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SellArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, WPRBuffer, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(1, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 234); // Down Arrow

   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   hWPR = iWPR(_Symbol, _Period, InpWPRPeriod);
   hATR = iATR(_Symbol, _Period, InpATRPeriod);

   if(hWPR == INVALID_HANDLE || hATR == INVALID_HANDLE) return(INIT_FAILED);

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
   if(prev_calculated == 0)
     {
      start = InpFRAMAPeriod;
      // Initialize FRAMA with first Close to avoid 0 jump
      for(int i=0; i<start; i++) FRAMABuffer[i] = close[i];
     }
   else start = prev_calculated - 1;

   // Get WPR & ATR Data
   double wpr[], atr[];
   int to_copy = rates_total - start;
   if(to_copy <= 0) return prev_calculated;

   if(CopyBuffer(hWPR, 0, 0, rates_total, wpr) < rates_total) return 0; // Need full history for easy indexing
   if(CopyBuffer(hATR, 0, 0, rates_total, atr) < rates_total) return 0;

   // FRAMA Calculation Loop
   int N = InpFRAMAPeriod;
   int halfN = N / 2;

   for(int i = start; i < rates_total; i++)
     {
      // 1. Calculate High/Low ranges for 3 windows:
      //    Window 1: [i-N ... i-halfN] (Older half)
      //    Window 2: [i-halfN ... i]   (Newer half)
      //    Window 3: [i-N ... i]       (Full)

      // Need Highest/Lowest.
      // Optimized: manual loop is fast enough for small N (e.g. 16)
      double h1 = -DBL_MAX, l1 = DBL_MAX;
      double h2 = -DBL_MAX, l2 = DBL_MAX;
      double h3 = -DBL_MAX, l3 = DBL_MAX;

      // Scan Full Window (covers all)
      for(int k=0; k<N; k++) {
         int idx = i - k;
         double h = high[idx];
         double l = low[idx];

         // Update Full Window
         if(h > h3) h3 = h;
         if(l < l3) l3 = l;

         // Update Halves
         if(k < halfN) { // Newer half (indices i-0 to i-(halfN-1))
            if(h > h2) h2 = h;
            if(l < l2) l2 = l;
         } else { // Older half (indices i-halfN to i-(N-1))
            if(h > h1) h1 = h;
            if(l < l1) l1 = l;
         }
      }

      // 2. Calculate Dimensions
      double R1 = (h1 - l1) / (double)halfN;
      double R2 = (h2 - l2) / (double)halfN;
      double R3 = (h3 - l3) / (double)N;

      double D = 0;
      if (R1+R2 > 0 && R3 > 0)
         D = (MathLog(R1 + R2) - MathLog(R3)) / MathLog(2.0);
      else
         D = 0; // Fallback

      // 3. Calculate Alpha
      double alpha = MathExp(-4.6 * (D - 1.0));
      if(alpha < 0.01) alpha = 0.01; // Clamp
      if(alpha > 1.0) alpha = 1.0;

      // 4. FRAMA
      // FRAMA[i] = alpha * Price + (1-alpha) * FRAMA[i-1]
      double prevF = FRAMABuffer[i-1];
      FRAMABuffer[i] = alpha * close[i] + (1.0 - alpha) * prevF;

      // --- SIGNAL LOGIC ---
      BuyArrowBuffer[i] = 0.0;
      SellArrowBuffer[i] = 0.0;

      // Check ATR threshold
      if (atr[i] < InpATRThresh) continue;

      // WPR Logic: Oversold (-80) / Overbought (-20)
      bool os = wpr[i] < -80.0;
      bool ob = wpr[i] > -20.0;

      // Crossover Logic: Price crossing FRAMA
      bool crossUp   = (close[i] > FRAMABuffer[i] && close[i-1] <= FRAMABuffer[i-1]);
      bool crossDown = (close[i] < FRAMABuffer[i] && close[i-1] >= FRAMABuffer[i-1]);

      if (crossUp && os)
         BuyArrowBuffer[i] = low[i] - 10 * _Point;

      if (crossDown && ob)
         SellArrowBuffer[i] = high[i] + 10 * _Point;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hWPR);
   IndicatorRelease(hATR);
  }
//+------------------------------------------------------------------+
