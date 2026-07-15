//+------------------------------------------------------------------+
//|                            Hybrid_Microstructure_Monitor_v1.6.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.6 (Pure Pressure + Tick Density Boost)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.6"
#property description "Microstructure Pressure Monitor."
#property description "Visualizes the battle between Upper and Lower Wicks."
#property description "Boosted by Tick Density (Volume) analysis."

/*
   ===================================================================
   HYBRID MICROSTRUCTURE MONITOR v1.6 - ÉRTELMEZÉS
   ===================================================================
   Ez az indikátor a gyertya belső harcát (Microstructure) mutatja meg.
   A v1.6 visszatér a "Tiszta Nyomás" (Pure Pressure) logikához, ahol
   nem szűrünk gyertyatest méretre, hanem a kanócok erejét hasonlítjuk össze.

   1. LOGIKA (Pressure):
      - Az indikátor kiszámolja: (Alsó Kanóc - Felső Kanóc).
      - Ha az Alsó Kanóc nagyobb -> Vevők nyomják fel az árat (Bullish).
      - Ha a Felső Kanóc nagyobb -> Eladók nyomják le az árat (Bearish).

   2. VIZUALIZÁCIÓ (Hisztogram):
      - 0.0 Vonal (DimGray): Egyensúly.
      - ZÖLD (Felfelé): Bika Nyomás (Vevők uralják a kanócokat).
      - PIROS (Lefelé): Medve Nyomás (Eladók uralják a kanócokat).

   3. TICK DENSITY (Sűrűség):
      - Ha be van kapcsolva, az indikátor megnézi, mennyi tick volt a kanócban.
      - Ha nagy a sűrűség (nagy csata), az oszlop MAGASABB lesz.
      - Ha kicsi a sűrűség (üres mozgás), az oszlop LAPOSABB lesz.
      - Extra erős sűrűségnél a szín élénkebb (Lime/Red).
*/

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Pressure Histogram
#property indicator_label1  "Wick Pressure"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrForestGreen, clrFireBrick, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Levels
#property indicator_level1 0.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
input group              "=== Pressure Logic ==="
input int                InpLookbackVol        = 10;       // Lookback for Volume Avg
input double             InpPressureGain       = 100.0;    // Visual Gain (Amplitude)

input group              "=== Tick Density (Volume) ==="
input bool               InpUseTickAnalysis    = true;     // Enable Tick Density Boost
input double             InpTickHistoryDays    = 1.0;      // Tick History Limit (Days)
input double             InpHighVolThreshold   = 1.5;      // High Volume Threshold (Color Boost)

//--- Buffers
double      PressureBuffer[];
double      ColorBuffer[]; // 0=Green, 1=Red, 2=Lime, 3=RedStrong
double      CalcVolAvg[];
double      TickRatioBuffer[]; // Debug/Calc

//--- Globals
long        limit_msc = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PressureBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, CalcVolAvg, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, TickRatioBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Microstructure v1.6");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   // Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);

   if (InpUseTickAnalysis) {
       limit_msc = (long)InpTickHistoryDays * 24 * 60 * 60 * 1000;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Get Density Factor                                       |
//+------------------------------------------------------------------+
double GetWickDensity(int i, const datetime &time[], double high, double low, double open, double close, bool check_upper)
{
    if (!InpUseTickAnalysis) return 1.0;

    long current_time_msc = (long)time[i] * 1000;
    long now_msc = TimeCurrent() * 1000;
    if (now_msc - current_time_msc > limit_msc) return 1.0;

    long t_start = current_time_msc;
    long t_end = (i < ArraySize(time)-1) ? (long)time[i+1] * 1000 : 0;

    MqlTick ticks[];
    int received = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, t_start, t_end);
    if (received < 10) return 1.0;

    // Determine Zone
    double zone_high, zone_low;
    double body_top = MathMax(open, close);
    double body_bottom = MathMin(open, close);

    if (check_upper) {
        zone_high = high;
        zone_low = body_top;
    } else {
        zone_high = body_bottom;
        zone_low = low;
    }

    double wick_size = zone_high - zone_low;
    if (wick_size == 0) return 0.0; // No wick

    // Count Ticks in Wick
    int ticks_in_wick = 0;
    for(int k=0; k<received; k++) {
        if (ticks[k].bid <= zone_high && ticks[k].bid >= zone_low) {
            ticks_in_wick++;
        }
    }

    double tick_ratio = (double)ticks_in_wick / (double)received;
    double range = high - low;
    double price_ratio = wick_size / range;

    if (price_ratio <= 0) return 1.0;

    // Density = How much action was in the wick relative to its size
    double density = tick_ratio / price_ratio;

    // Cap
    if (density < 0.2) density = 0.2; // Weak wick (hollow)
    if (density > 3.0) density = 3.0; // Strong wick (battle)

    return density;
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
   if(rates_total < InpLookbackVol + 1) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpLookbackVol;

   for(int i = start; i < rates_total; i++)
   {
       double range = high[i] - low[i];

       // Calc Volume Avg
       double sum_vol = 0;
       for(int k=1; k<=InpLookbackVol; k++) sum_vol += (double)tick_volume[i-k];
       CalcVolAvg[i] = sum_vol / InpLookbackVol;
       if(CalcVolAvg[i] == 0) CalcVolAvg[i] = 1.0;
       double vol_factor = (double)tick_volume[i] / CalcVolAvg[i];

       PressureBuffer[i] = 0.0;
       ColorBuffer[i] = 0.0; // Default

       if (range > 0) {
           double body_top    = MathMax(open[i], close[i]);
           double body_bottom = MathMin(open[i], close[i]);

           double upper_wick = high[i] - body_top;
           double lower_wick = body_bottom - low[i];

           // --- RAW PRESSURE ---
           // Positive if Lower Wick > Upper Wick (Buyers supporting)
           // Negative if Upper Wick > Lower Wick (Sellers resisting)
           double raw_pressure = (lower_wick - upper_wick) / range;

           // --- DENSITY BOOST ---
           double density_factor = 1.0;
           if (raw_pressure > 0) {
               // Check Lower Wick Density
               density_factor = GetWickDensity(i, time, high[i], low[i], open[i], close[i], false);
           } else if (raw_pressure < 0) {
               // Check Upper Wick Density
               density_factor = GetWickDensity(i, time, high[i], low[i], open[i], close[i], true);
           }

           // Final Value
           double final_val = raw_pressure * InpPressureGain * density_factor;

           // Apply Volume Boost as well
           if (vol_factor > 1.0) final_val *= MathSqrt(vol_factor);

           PressureBuffer[i] = final_val;

           // --- COLOR LOGIC ---
           bool is_strong = (vol_factor > InpHighVolThreshold && density_factor > 1.0);

           if (final_val >= 0) {
               ColorBuffer[i] = is_strong ? 2.0 : 0.0; // Lime or ForestGreen
           } else {
               ColorBuffer[i] = is_strong ? 3.0 : 1.0; // Red or FireBrick
           }
       }
   }

   return rates_total;
}
