//+------------------------------------------------------------------+
//|                                     Hybrid_Scalper_Zerolag.mq5 |
//|                                                   Jules Assistant|
//|                                       Based on RAG Research Findings |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property link      "https://github.com/mihaly67/EA-fejleszt-s"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot settings
#property indicator_label1  "Hybrid_MACD_IFT"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Hybrid_WPR_Norm"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Inputs
input int      InpMacdFast    = 12;    // MACD Fast Period (DEMA)
input int      InpMacdSlow    = 26;    // MACD Slow Period (DEMA)
input int      InpMacdSignal  = 9;     // MACD Signal Period
input int      InpWPRPeriod   = 14;    // WPR Period
input int      InpNormPeriod  = 50;    // Normalization Lookback (Bars)
input double   InpIFTGain     = 1.5;   // IFT Gain (Sharpness)

//--- Buffers
double         Buf_MacdIFT[];
double         Buf_WprNorm[];
double         Buf_MacdRaw[];   // Hidden calculation buffer
double         Buf_SignalRaw[]; // Hidden calculation buffer

//--- Handles
int            hWPR;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Indicator Buffers
   SetIndexBuffer(0, Buf_MacdIFT, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_WprNorm, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_MacdRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, Buf_SignalRaw, INDICATOR_CALCULATIONS);

   //--- Plot Names
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid MACD (IFT)");
   PlotIndexSetString(1, PLOT_LABEL, "Hybrid WPR (Norm)");

   //--- Fixed Scale [-1, 1]
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.8);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -0.8);

   //--- Get WPR Handle
   hWPR = iWPR(NULL, 0, InpWPRPeriod);
   if(hWPR == INVALID_HANDLE)
     {
      Print("Failed to create WPR handle");
      return(INIT_FAILED);
     }

   //--- Short Name
   string name = StringFormat("HybridScalper(MACD%d-%d, WPR%d)", InpMacdFast, InpMacdSlow, InpWPRPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hWPR != INVALID_HANDLE)
      IndicatorRelease(hWPR);
  }

//+------------------------------------------------------------------+
//| Helper: DEMA (Double Exponential Moving Average)                 |
//| Calculation: 2 * EMA(P) - EMA(EMA(P))                            |
//| Note: This is an approximation for valid series calculation      |
//+------------------------------------------------------------------+
double CalculateDEMA(int index, int period, const double &price[])
  {
   // In a real optimized indicator, we would use iDEMA handle or maintain EMA buffers.
   // For this showcase, we use iMA calls for simplicity and reliability?
   // No, calling iMA inside loop is slow.
   // We will implement simple EMA on the fly? No, that requires state.
   // Correct approach: Use iDEMA built-in indicator.
   return 0; // Placeholder, see OnCalculate
  }

//+------------------------------------------------------------------+
//| Helper: Inverse Fisher Transform                                 |
//| Formula: (exp(2*x) - 1) / (exp(2*x) + 1)                         |
//+------------------------------------------------------------------+
double IFT(double x)
  {
   double e2x = MathExp(2 * x * InpIFTGain);
   return (e2x - 1) / (e2x + 1);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Iteration                                       |
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
   //--- Need enough bars
   if(rates_total < InpNormPeriod + InpMacdSlow)
      return(0);

   //--- 1. Get WPR Data
   double wpr_buffer[];
   ArraySetAsSeries(wpr_buffer, true); // Process as series for easier indexing if needed
   // CopyBuffer returns elements in chronological order (oldest first) by default
   // But let's stick to standard loop: i=0 is OLDEST in OnCalculate arrays.

   double wpr_raw[];
   int copied = CopyBuffer(hWPR, 0, 0, rates_total, wpr_raw);
   if(copied < rates_total) return(0);

   //--- 2. Calculate DEMA-based MACD
   // Since we don't have built-in iDEMA easily accessible in all environments without handle,
   // We will use standard EMA for the prototype but simulate ZeroLag logic or use built-in iDEMA handles.
   // Better: Use iDEMA handles.

   static int hFast = INVALID_HANDLE;
   static int hSlow = INVALID_HANDLE;

   if(hFast == INVALID_HANDLE)
      hFast = iDEMA(NULL, 0, InpMacdFast, 0, PRICE_CLOSE);
   if(hSlow == INVALID_HANDLE)
      hSlow = iDEMA(NULL, 0, InpMacdSlow, 0, PRICE_CLOSE);

   double dema_fast[], dema_slow[];
   if(CopyBuffer(hFast, 0, 0, rates_total, dema_fast) < rates_total) return 0;
   if(CopyBuffer(hSlow, 0, 0, rates_total, dema_slow) < rates_total) return 0;

   //--- Loop
   int limit = prev_calculated - 1;
   if(limit < 0) limit = 0;

   // Start loop from 0 (or prev limit) to populate RAW buffers everywhere
   for(int i = limit; i < rates_total; i++)
     {
      // --- MACD ZeroLag Calculation ---
      // DEMA handles (dema_fast/slow) already align with Close price
      double macd_val = dema_fast[i] - dema_slow[i];
      Buf_MacdRaw[i] = macd_val;

      // --- Normalization Logic ---
      // Only run Normalization if we have enough history (InpNormPeriod)
      // Otherwise set output to 0 or neutral

      if (i < InpNormPeriod) {
          Buf_MacdIFT[i] = 0.0;
          Buf_WprNorm[i] = 0.0; // Wait for enough data
          continue;
      }

      // --- Normalization (Stochastic of MACD) ---
      // Find Min/Max of MACD over InpNormPeriod
      double min_val = macd_val;
      double max_val = macd_val;

      for(int k=1; k<InpNormPeriod; k++)
        {
         // i-k is safe here because i >= InpNormPeriod
         double v = Buf_MacdRaw[i-k];
         if(v < min_val) min_val = v;
         if(v > max_val) max_val = v;
        }

      double range = max_val - min_val;
      double stoch_macd = 0;
      if(range > 0)
         stoch_macd = (macd_val - min_val) / range; // 0..1
      else
         stoch_macd = 0.5;

      // Center around 0 -> -0.5 .. 0.5
      double centered = stoch_macd - 0.5;

      // Scale for IFT (needs roughly -2..2 or -5..5)
      // Multiply by 4 -> -2 .. 2
      double scaled = centered * 4.0;

      Buf_MacdIFT[i] = IFT(scaled);

      // --- WPR Normalization ---
      // WPR is 0 to -100. Center is -50.
      // Formula to map 0..-100 to 1..-1:
      // (-WPR - 50) / 50 * -1 ?
      // Let's test:
      // WPR 0 (Overbought) -> Should be 1.  (0 / -50) + 1 = 1.
      // WPR -100 (Oversold) -> Should be -1. (-100 / -50) + 1 = 2+1=3 NO.
      // Formula: 1 + (WPR / 50)
      // -100 / 50 = -2. 1 + (-2) = -1. Correct.
      // 0 / 50 = 0. 1 + 0 = 1. Correct.
      // -50 / 50 = -1. 1 + (-1) = 0. Correct.

      Buf_WprNorm[i] = 1.0 + (wpr_raw[i] / 50.0);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
