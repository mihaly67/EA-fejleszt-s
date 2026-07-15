//+------------------------------------------------------------------+
//|                                HybridInstitutionalIndicator_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (VWAP + KAMA) - FIXED                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2

//--- Plot 1: VWAP
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrMagenta
#property indicator_width1  2

//--- Plot 2: KAMA
#property indicator_label2  "KAMA"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrYellow
#property indicator_width2  2

//--- Input Parameters
input group              "=== VWAP Settings ==="
input bool               InpShowVWAP           = true;
input ENUM_TIMEFRAMES    InpVWAPAnchor         = PERIOD_D1; // Anchor Period (Reset)

input group              "=== KAMA Settings ==="
input bool               InpShowKAMA           = true;
input int                InpKamaPeriod         = 10;    // Efficiency Ratio Period
input int                InpKamaFast           = 2;     // Fast EMA Period
input int                InpKamaSlow           = 30;    // Slow EMA Period
input ENUM_APPLIED_PRICE InpKamaPrice          = PRICE_CLOSE;

//--- Buffers
double      VWAPBuffer[];
double      KAMABuffer[];

//--- Hidden Buffers for VWAP State
double      CumPVBuffer[];
double      CumVolBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, KAMABuffer, INDICATOR_DATA);

   SetIndexBuffer(2, CumPVBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, CumVolBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Institutional v1.0");

   return INIT_SUCCEEDED;
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
   if(rates_total < InpKamaPeriod + 1) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- KAMA Calculation ---
   if(InpShowKAMA)
   {
       if(start == 0)
       {
           KAMABuffer[0] = close[0];
           start = 1;
       }

       for(int i = start; i < rates_total; i++)
       {
           double price = close[i];
           // Ensure we don't look back before array start
           if(i < InpKamaPeriod) { KAMABuffer[i] = price; continue; }

           double prev_kama = KAMABuffer[i-1];

           // Efficiency Ratio (ER)
           double change = MathAbs(price - close[i - InpKamaPeriod]);
           double volatility = 0.0;
           for(int j = 0; j < InpKamaPeriod; j++)
               volatility += MathAbs(close[i-j] - close[i-j-1]);

           double er = (volatility != 0) ? change / volatility : 0;

           // Smoothing Constant (SC)
           double fast_sc = 2.0 / (InpKamaFast + 1.0);
           double slow_sc = 2.0 / (InpKamaSlow + 1.0);
           double sc = MathPow(er * (fast_sc - slow_sc) + slow_sc, 2.0);

           // KAMA
           KAMABuffer[i] = prev_kama + sc * (price - prev_kama);
       }
   }

   // --- VWAP Calculation (Incremental) ---
   if(InpShowVWAP)
   {
       // Reset start for VWAP independently? No, single loop logic.
       // We iterate from 'start'.

       for(int i = start; i < rates_total; i++)
       {
           datetime current_time = time[i];
           datetime prev_time = (i > 0) ? time[i-1] : 0;

           // Determine start of anchor period (e.g., Day start)
           datetime anchor_start = iTime(_Symbol, InpVWAPAnchor, iBarShift(_Symbol, InpVWAPAnchor, current_time));

           bool reset = false;
           if(i == 0) reset = true;
           else if(current_time >= anchor_start && prev_time < anchor_start) reset = true;
           // The above logic detects crossing the boundary.
           // Simplified: If current bar's anchor time != prev bar's anchor time.
           datetime prev_anchor_start = iTime(_Symbol, InpVWAPAnchor, iBarShift(_Symbol, InpVWAPAnchor, prev_time));
           if(i > 0 && anchor_start != prev_anchor_start) reset = true;

           double p = (high[i] + low[i] + close[i]) / 3.0;
           double v = (double)tick_volume[i];

           if(reset)
           {
               CumPVBuffer[i] = p * v;
               CumVolBuffer[i] = v;
           }
           else
           {
               CumPVBuffer[i] = CumPVBuffer[i-1] + (p * v);
               CumVolBuffer[i] = CumVolBuffer[i-1] + v;
           }

           VWAPBuffer[i] = (CumVolBuffer[i] > 0) ? CumPVBuffer[i] / CumVolBuffer[i] : p;
       }
   }

   return rates_total;
}
