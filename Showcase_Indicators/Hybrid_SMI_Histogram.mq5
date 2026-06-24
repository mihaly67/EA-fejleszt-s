//+------------------------------------------------------------------+
//|                                     Hybrid_SMI_Histogram.mq5     |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.0 (Stochastic Momentum Index Histogram)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"
#property description "Stochastic Momentum Index (SMI) Histogram"

//--- Indicator Settings
#property indicator_separate_window
#property indicator_buffers 10  // Increased for EMAs
#property indicator_plots   1

//--- Plot 1: Histogram
#property indicator_label1  "SMI Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
#property indicator_color1  clrForestGreen, clrFireBrick, clrGray

//--- Input Parameters
input group              "=== SMI Settings ==="
input int                InpPeriodQ            = 13;     // Q Period (Length)
input int                InpPeriodR            = 25;     // R Period (Smoothing 1)
input int                InpPeriodS            = 2;      // S Period (Smoothing 2)
input int                InpSignalPeriod       = 5;      // Signal Line Period

input group              "=== Visual Settings ==="
input color              InpColorUp            = clrForestGreen;
input color              InpColorDown          = clrFireBrick;
input color              InpColorFlat          = clrGray;

//--- Buffers
double      HistBuffer[];
double      ColorBuffer[];
double      SMIBuffer[];
double      SignalBuffer[]; // Used for Signal Line

//--- Calculation Buffers (Double Smoothing)
double      range_buf[];
double      range_ema1[];
double      range_ema2[];
double      diff_buf[];
double      diff_ema1[];
double      diff_ema2[];

//+------------------------------------------------------------------+
//| Helper: Simple EMA Update                                        |
//+------------------------------------------------------------------+
void UpdateEMA(int i, double price, double prev_ema, int period, double &buffer[])
{
   if(period <= 1) {
      buffer[i] = price;
      return;
   }

   if(i==0) {
       buffer[i] = price;
       return;
   }

   double alpha = 2.0 / (period + 1.0);
   buffer[i] = prev_ema + alpha * (price - prev_ema);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, SMIBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, SignalBuffer, INDICATOR_CALCULATIONS);

   SetIndexBuffer(4, range_buf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, range_ema1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, range_ema2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, diff_buf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, diff_ema1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, diff_ema2, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid SMI Hist");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorUp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorDown);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorFlat);

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
   if(rates_total < InpPeriodQ) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 0) start = 0;

   for(int i = start; i < rates_total; i++)
   {
       // 1. Calculate Range and Diff
       // Range = High - Low
       // Diff = Close - Midpoint = Close - (High+Low)/2

       // Need Highest High and Lowest Low over Period Q
       int p_start = i - InpPeriodQ + 1;
       if(p_start < 0) p_start = 0;

       double hh = high[ArrayMaximum(high, p_start, InpPeriodQ)];
       double ll = low[ArrayMinimum(low, p_start, InpPeriodQ)];
       double midpoint = (hh + ll) / 2.0;

       diff_buf[i] = close[i] - midpoint;
       range_buf[i] = hh - ll;

       // 2. Double Smoothing (Diff)
       double prev_d1 = (i>0) ? diff_ema1[i-1] : diff_buf[i];
       UpdateEMA(i, diff_buf[i], prev_d1, InpPeriodR, diff_ema1);

       double prev_d2 = (i>0) ? diff_ema2[i-1] : diff_ema1[i];
       UpdateEMA(i, diff_ema1[i], prev_d2, InpPeriodS, diff_ema2);

       // 3. Double Smoothing (Range)
       double prev_r1 = (i>0) ? range_ema1[i-1] : range_buf[i];
       UpdateEMA(i, range_buf[i], prev_r1, InpPeriodR, range_ema1);

       double prev_r2 = (i>0) ? range_ema2[i-1] : range_ema1[i];
       UpdateEMA(i, range_ema1[i], prev_r2, InpPeriodS, range_ema2);

       // 4. Calculate SMI
       double denom = range_ema2[i];
       if(denom == 0) denom = _Point;

       SMIBuffer[i] = 100.0 * (diff_ema2[i] / (0.5 * denom));

       // 5. Signal Line (EMA of SMI)
       // We can use the SignalBuffer for this
       double prev_sig = (i>0) ? SignalBuffer[i-1] : SMIBuffer[i];
       UpdateEMA(i, SMIBuffer[i], prev_sig, InpSignalPeriod, SignalBuffer);

       // 6. Histogram
       double hist = SMIBuffer[i] - SignalBuffer[i];
       HistBuffer[i] = hist;

       // 7. Colors
       if(hist >= 0) {
           ColorBuffer[i] = 0; // Up
       } else {
           ColorBuffer[i] = 1; // Down
       }
   }

   return rates_total;
}
