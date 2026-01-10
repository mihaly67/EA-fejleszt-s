//+------------------------------------------------------------------+
//|                            Hybrid_Microstructure_Monitor_v1.5.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.5 (Scalper Max: Wick + Tick Density Logic)       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.5"
#property description "Advanced Microstructure Monitor for Scalping."
#property description "Combines Wick/Body Ratio with Tick Volume Density analysis."
#property description "Provides Histogram signals for Bullish/Bearish Rejection Pressure."

/*
   ===================================================================
   HYBRID MICROSTRUCTURE MONITOR v1.5 - ÉRTELMEZÉS
   ===================================================================
   Ez az indikátor kifejezetten skalpoláshoz készült (M1, M5, M15).
   Két fő technológiát ötvöz:
   1. Gyertya Alakzat Elemzés (OHLC): Kanóc és Törzs arányok vizsgálata.
   2. Tick Sűrűség Elemzés (Tick Density): Megvizsgálja, hogy a kanócban
      ténylegesen mennyi kötés történt.

   JELZÉSEK (Hisztogram):
   - 0.0 Vonal: Semleges zóna (Szürke pontozott vonal).
   - ZÖLD Oszlop (Felfelé): Bika Nyomás (Bullish Rejection).
     Jelentése: Az ár lenézett, hosszú alsó kanóc keletkezett, és ebben
     a kanócban nagy volumenű vásárlás (vagy limit megbízás) történt.
   - PIROS Oszlop (Lefelé): Medve Nyomás (Bearish Rejection).
     Jelentése: Az ár felnézett, hosszú felső kanóc keletkezett, és az
     eladók agresszívan verték vissza az árat.

   SZÍNEK INTENZITÁSA:
   - Sötétebb/Élénkebb színek (Lime/Red vs ForestGreen/FireBrick):
     Ha a "Tick Density" (Volumen a kanócban) kiemelkedően magas,
     az indikátor erősebb (élénkebb) színnel jelzi a "Prémium" jelet.

   HASZNÁLAT:
   - Trendforduló keresése (Counter-Trend Scalp): Extrém hosszú oszlopoknál.
   - Visszateszt belépő (Trend Scalp): Ha a trend irányába mutató
     elutasítást látunk (pl. Emelkedő trendben hosszú alsó kanóc).
*/

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Rejection Pressure (Histogram)
#property indicator_label1  "Rejection Pressure"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrForestGreen, clrFireBrick, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Levels
#property indicator_level1 0.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
input group              "=== Candle Microstructure (OHLC) ==="
input double             InpMinWickRatio       = 0.4;      // Min Wick Ratio (e.g. 0.4 = 40% of range)
input double             InpMaxBodyRatio       = 0.5;      // Max Body Ratio (e.g. 0.5 = Body max 50% of range)
input int                InpLookbackVol        = 10;       // Lookback for Volume Avg

input group              "=== Tick Density (Volume) ==="
input bool               InpUseTickAnalysis    = true;     // Enable True Tick Analysis (Slower calc)
input double             InpTickHistoryDays    = 1.0;      // Tick History Limit (Days)
input double             InpHighVolThreshold   = 1.5;      // High Volume Multiplier (1.5x Avg)

input group              "=== Visuals ==="
input bool               InpUseZeroBased       = true;     // Always true (Hidden logic parameter)

//--- Buffers
double      PressureBuffer[];
double      ColorBuffer[]; // 0=Green, 1=Red, 2=Lime(Strong), 3=Red(Strong)
double      CalcVolAvg[];  // Calculation buffer for volume average

//--- Globals
long        limit_msc = 0; // Time limit for tick download

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PressureBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, CalcVolAvg, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Microstructure v1.5 (Scalper)");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   // Set Levels Explicitly
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);

   // Calculate time limit for ticks
   if (InpUseTickAnalysis) {
       limit_msc = (long)InpTickHistoryDays * 24 * 60 * 60 * 1000;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Analyze Wick Ticks                                       |
//+------------------------------------------------------------------+
// Returns a "Density Factor" (1.0 = Normal, >1.5 = Strong)
double AnalyzeWickDensity(int i, const datetime &time[], const double &open[], const double &close[], const double &high[], const double &low[], bool is_upper_wick)
{
    if (!InpUseTickAnalysis) return 1.0;

    // Time Check
    long current_time_msc = (long)time[i] * 1000;
    long now_msc = TimeCurrent() * 1000; // approx
    if (now_msc - current_time_msc > limit_msc) return 1.0; // Too old

    // Define Time Range for Bar
    long t_start = current_time_msc;
    long t_end = (i < ArraySize(time)-1) ? (long)time[i+1] * 1000 : 0; // 0 means 'to now' for last bar

    MqlTick ticks[];
    int received = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, t_start, t_end);

    if (received < 10) return 1.0; // Not enough data

    // Define Wick Price Zone
    double zone_high, zone_low;
    double body_top = MathMax(open[i], close[i]);
    double body_bottom = MathMin(open[i], close[i]);

    if (is_upper_wick) {
        zone_high = high[i];
        zone_low = body_top;
    } else { // Lower Wick
        zone_high = body_bottom;
        zone_low = low[i];
    }

    // Count Ticks in Zone
    int ticks_in_zone = 0;
    for(int k=0; k<received; k++) {
        // Check if Bid or Ask touched the zone
        // For simplicity, we check if the Bid is in the zone
        if (ticks[k].bid <= zone_high && ticks[k].bid >= zone_low) {
            ticks_in_zone++;
        }
    }

    // Calculate Ratio (Zone Ticks / Total Ticks)
    double tick_ratio = (double)ticks_in_zone / (double)received;

    // Normalize: A wick covering 40% of range should have ~40% of ticks.
    // If it has 60-70% of ticks, that's High Density (Battleground).

    double price_range = high[i] - low[i];
    double wick_range = zone_high - zone_low;
    if (price_range == 0) return 1.0;

    double price_ratio = wick_range / price_range;

    // Density Factor = Actual Tick Ratio / Expected Price Ratio
    if (price_ratio == 0) return 1.0;

    double density = tick_ratio / price_ratio;

    // Cap reasonably
    if (density < 0.5) density = 0.5;
    if (density > 3.0) density = 3.0;

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

   // Ensure Series Array for TicksVolume helper if we copied it (not used here directly yet)
   // but standard arrays are sufficient for loop i.

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpLookbackVol;

   for(int i = start; i < rates_total; i++)
   {
       // 1. Basic Range Calc
       double current_range = high[i] - low[i];

       // Calc Volume Avg
       double sum_vol = 0;
       for(int k=1; k<=InpLookbackVol; k++) sum_vol += (double)tick_volume[i-k];
       CalcVolAvg[i] = sum_vol / InpLookbackVol;
       if(CalcVolAvg[i] == 0) CalcVolAvg[i] = 1.0;

       PressureBuffer[i] = 0.0;
       ColorBuffer[i] = 0.0; // Default

       if (current_range > 0) {
           double body_top    = MathMax(open[i], close[i]);
           double body_bottom = MathMin(open[i], close[i]);
           double body_size   = body_top - body_bottom;

           double upper_wick = high[i] - body_top;
           double lower_wick = body_bottom - low[i];

           double upper_ratio = upper_wick / current_range;
           double lower_ratio = lower_wick / current_range;
           double body_ratio  = body_size / current_range;

           // --- LOGIC: REJECTION DETECTION ---
           // Rule: Small Body + Large Wick
           bool is_small_body = (body_ratio <= InpMaxBodyRatio);

           if (is_small_body) {
               // A) BULLISH REJECTION (Lower Wick)
               if (lower_ratio >= InpMinWickRatio && lower_ratio > upper_ratio) {

                   // Analyze Density
                   double density = AnalyzeWickDensity(i, time, open, close, high, low, false);
                   double vol_factor = (double)tick_volume[i] / CalcVolAvg[i];

                   // Base Strength = Wick Ratio * 100
                   double strength = lower_ratio * 100.0;

                   // Boost by Density & Volume
                   strength *= density;
                   if (vol_factor > 1.0) strength *= MathSqrt(vol_factor);

                   PressureBuffer[i] = strength;

                   // Color Logic
                   if (vol_factor > InpHighVolThreshold || density > 1.2) {
                       ColorBuffer[i] = 2.0; // Lime (Strong)
                   } else {
                       ColorBuffer[i] = 0.0; // ForestGreen (Normal)
                   }
               }
               // B) BEARISH REJECTION (Upper Wick)
               else if (upper_ratio >= InpMinWickRatio && upper_ratio > lower_ratio) {

                   // Analyze Density
                   double density = AnalyzeWickDensity(i, time, open, close, high, low, true);
                   double vol_factor = (double)tick_volume[i] / CalcVolAvg[i];

                   // Base Strength
                   double strength = upper_ratio * 100.0;

                   // Boost
                   strength *= density;
                   if (vol_factor > 1.0) strength *= MathSqrt(vol_factor);

                   PressureBuffer[i] = -strength; // Negative for Down

                   // Color Logic
                   if (vol_factor > InpHighVolThreshold || density > 1.2) {
                       ColorBuffer[i] = 3.0; // Red (Strong)
                   } else {
                       ColorBuffer[i] = 1.0; // FireBrick (Normal)
                   }
               }
           }
       }
   }

   return rates_total;
}
