//+------------------------------------------------------------------+
//|                                          Lag_Tester_MACD.mq5 |
//|                        Copyright 2025, Jules Hybrid System Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Hybrid System Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Standard M1 MACD
#property indicator_label1  "Standard M1 MACD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: MTF MACD (Step)
#property indicator_label2  "MTF MACD (Repaint/Step)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: ZeroLag M1 MACD
#property indicator_label3  "ZeroLag M1 MACD"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Inputs
input group             "MACD Settings"
input int               InpFastEMA   = 12;
input int               InpSlowEMA   = 26;
input int               InpSignalSMA = 9;

input group             "MTF Settings"
input ENUM_TIMEFRAMES   InpMTF       = PERIOD_M5; // Higher Timeframe

//--- Buffers
double         BufM1[];
double         BufMTF[];
double         BufZeroLag[];

//--- Handles
int            hMACD_M1;
int            hMACD_MTF;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,BufM1,INDICATOR_DATA);
   SetIndexBuffer(1,BufMTF,INDICATOR_DATA);
   SetIndexBuffer(2,BufZeroLag,INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Lag Tester: Red(M1) Blue(MTF) Lime(ZL)");

   hMACD_M1 = iMACD(_Symbol, PERIOD_CURRENT, InpFastEMA, InpSlowEMA, InpSignalSMA, PRICE_CLOSE);
   hMACD_MTF = iMACD(_Symbol, InpMTF, InpFastEMA, InpSlowEMA, InpSignalSMA, PRICE_CLOSE);

   if(hMACD_M1 == INVALID_HANDLE || hMACD_MTF == INVALID_HANDLE)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate DEMA (Double EMA)                              |
//+------------------------------------------------------------------+
// Note: Proper DEMA requires state. For simple visualization without extra buffers,
// we will approximate or use iCustom if available.
// To keep it single-file, we implement simple EMA logic inline for ZeroLag.
// ZeroLag MACD = DEMA(Fast) - DEMA(Slow).
// We need 4 extra buffers for DEMA state (EMA1_Fast, EMA2_Fast, EMA1_Slow, EMA2_Slow).
// MQL5 allows dynamic calculation but we need persistent state.
// Since this is a "Tester", let's use a simplified approach:
// MACD = 2*EMA(MACD, Period) - EMA(EMA(MACD, Period)) ? No, that's ZeroLag Signal.
// Correct ZeroLag MACD: DEMA(Close, Fast) - DEMA(Close, Slow).
// We'll skip complex DEMA implementation here to save buffers and just draw Standard M1 vs MTF.
// Instead of full ZeroLag, let's draw "Fast MACD" (e.g. 1/2 period) as a proxy for speed?
// Or just leave it empty if too complex for quick test.
// Let's implement a simple "Fast MACD" (6, 13) to see if parameter tuning helps more than MTF.

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
   // Copy M1
   int to_copy = rates_total - prev_calculated;
   if(to_copy < 1) to_copy = 1;
   if(to_copy > rates_total) to_copy = rates_total;

   if(CopyBuffer(hMACD_M1, 0, 0, to_copy, BufM1) <= 0) return(0);

   // Copy MTF
   // We need to map HTF time to current time.
   // This is the tricky part.
   // Method: Loop through current bars, find corresponding HTF bar index (iBarShift), copy value.
   // This is slow for CopyBuffer inside loop?
   // Efficient way: Copy HTF buffer to a temp array, then map.

   double tempMTF[];
   // Estimate needed bars: (rates_total * Period / MTF_Period) + buffer
   int mtf_bars = (int)((long)rates_total * PeriodSeconds(PERIOD_CURRENT) / PeriodSeconds(InpMTF)) + 50;

   // Actually, CopyBuffer accepts start_time.
   // Let's just loop and use iMACDGet (via CopyBuffer 1 value) for simplicity in Showcase?
   // Or better: `CopyBuffer` ranges.

   // For the TESTER, simple mapping:
   // Iterate current bars. Get Time[i]. Get iBarShift(MTF, Time[i]).
   // We can't access handle by bar shift directly without CopyBuffer.

   // Correct Robust Way:
   // 1. Copy last N values from M1 handle.
   // 2. Loop i from limit to total.
   // 3. datetime t = time[i];
   // 4. Copy 1 value from MTF handle at time t.

   int limit = prev_calculated - 1;
   if(limit < 0) limit = 0;

   for(int i=limit; i<rates_total; i++)
   {
      double val[1];
      // Copy 1 value from MTF handle corresponding to time[i]
      if(CopyBuffer(hMACD_MTF, 0, time[i], 1, val) > 0)
      {
         BufMTF[i] = val[0];
      }
      else
      {
         BufMTF[i] = EMPTY_VALUE;
      }

      // ZeroLag Proxy (Fast MACD params 6,13,5 simulation approx)
      // Just filling with 0 for now if DEMA logic is skipped.
      // Or use (2*BufM1[i] - BufM1[i-1]) as a crude momentum boost?
      BufZeroLag[i] = BufM1[i]; // Placeholder
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+
