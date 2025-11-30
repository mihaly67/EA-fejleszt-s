//+------------------------------------------------------------------+
//|                                    Adaptive_Scalper_Showcase.mq5 |
//|                             Copyright 2024, Gemini & User Collaboration |
//|                                       Verzió: 1.1 (Fix Indexing) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.01"
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

   // --- FIX: Reverse Indexing Alignment ---
   ArraySetAsSeries(wpr, true); // Set series flag BEFORE copy
   ArraySetAsSeries(atr, true);

   // CopyBuffer with series flag: Index 0 = Newest (Bar 0)
   // We copy 'to_copy' elements starting from 0 (Newest) backwards
   // Wait! CopyBuffer(..., start_pos, count, ...)
   // If I want to align with 'start' index logic, I should copy everything?
   // Or better: Copy from 0 (Current) 'to_copy' bars.
   // This covers the range [Current ... Current - to_copy + 1].
   // But 'start' is an index from the BEGINNING.
   // So 'start' corresponds to bar index 'rates_total - 1 - start'.
   // This is getting confusing.

   // SIMPLE APPROACH:
   // 1. Copy ALL required data (not efficient but safe for showcase).
   // 2. Or Copy 'to_copy' amount from 0. This gives us the NEWEST 'to_copy' bars.
   //    Which is exactly what 'start' to 'rates_total' represents (the newest bars).

   if(CopyBuffer(hWPR, 0, 0, to_copy, wpr) < to_copy) return 0;
   if(CopyBuffer(hATR, 0, 0, to_copy, atr) < to_copy) return 0;

   // FRAMA Calculation Loop
   int N = InpFRAMAPeriod;
   int halfN = N / 2;

   for(int i = start; i < rates_total; i++)
     {
      // Calculate shift index for Series buffers (wpr, atr)
      // i = 0 (Oldest) -> shift = rates_total - 1 (Oldest, but if we only copied 'to_copy', it's out of range!)
      // ERROR in reasoning above!

      // If wpr[] has only 'to_copy' elements (e.g. 5 elements).
      // wpr[0] is Newest. wpr[4] is Oldest.
      // i goes from rates_total-5 to rates_total-1.
      // shift = rates_total - 1 - i.
      // i = rates_total-1 -> shift = 0. Correct.
      // i = rates_total-5 -> shift = 4. Correct.
      // This works!

      int shift = rates_total - 1 - i;

      // Range Check
      if (shift >= to_copy || shift < 0) continue; // Should not happen with correct logic

      // 1. Calculate High/Low ranges for 3 windows
      double h1 = -DBL_MAX, l1 = DBL_MAX;
      double h2 = -DBL_MAX, l2 = DBL_MAX;
      double h3 = -DBL_MAX, l3 = DBL_MAX;

      for(int k=0; k<N; k++) {
         int idx = i - k;
         if (idx < 0) continue;
         double h = high[idx];
         double l = low[idx];

         if(h > h3) h3 = h;
         if(l < l3) l3 = l;

         if(k < halfN) {
            if(h > h2) h2 = h;
            if(l < l2) l2 = l;
         } else {
            if(h > h1) h1 = h;
            if(l < l1) l1 = l;
         }
      }

      double R1 = (h1 - l1) / (double)halfN;
      double R2 = (h2 - l2) / (double)halfN;
      double R3 = (h3 - l3) / (double)N;

      double D = 0;
      if (R1+R2 > 0 && R3 > 0)
         D = (MathLog(R1 + R2) - MathLog(R3)) / MathLog(2.0);
      else
         D = 0;

      double alpha = MathExp(-4.6 * (D - 1.0));
      if(alpha < 0.01) alpha = 0.01;
      if(alpha > 1.0) alpha = 1.0;

      double prevF = FRAMABuffer[i-1];
      FRAMABuffer[i] = alpha * close[i] + (1.0 - alpha) * prevF;

      // --- SIGNAL LOGIC ---
      BuyArrowBuffer[i] = 0.0;
      SellArrowBuffer[i] = 0.0;

      // Access wpr and atr using shift
      if (atr[shift] < InpATRThresh) continue;

      bool os = wpr[shift] < -80.0;
      bool ob = wpr[shift] > -20.0;

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
