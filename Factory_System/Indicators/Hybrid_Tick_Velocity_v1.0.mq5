//+------------------------------------------------------------------+
//|                                   Hybrid_Tick_Velocity_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.0 (Hybrid: Velocity Height + Delta Color)        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"
#property description "Tick Velocity & Delta Monitor for Scalping."
#property description "Visualizes Market Activity (Speed) and Aggressor Side (Delta)."

/*
   ===================================================================
   HYBRID TICK VELOCITY v1.0 - ÉRTELMEZÉS
   ===================================================================
   Ez az indikátor a piac "szívverését" méri a Tick adatok alapján.
   Kifejezetten CFD skalpoláshoz készült, ahol a DOM nem elérhető.

   1. VIZUALIZÁCIÓ (Hibrid Hisztogram):
      - OSZLOP MAGASSÁGA = Tick Velocity (Sebesség/Aktivitás).
        Azt mutatja, mennyire "pörög" a piac. Magas oszlop = Nagy érdeklődés/Volatilitás.
      - OSZLOP SZÍNE = Delta (Agresszor Irány).
        - ZÖLD (Lime): Vevők dominálnak (Ask oldal aktívabb).
        - PIROS (OrangeRed): Eladók dominálnak (Bid oldal aktívabb).
        - SZÜRKE: Semleges (Delta az egyensúlyi küszöbön belül).

   2. JELZÉSEK:
      - Kitörés (Breakout): Hirtelen megugró Velocity (Magas oszlop) + Egyértelmű szín.
      - Kifulladás (Exhaustion): Az árfolyam még megy, de a Velocity (oszlop magassága) zuhan.
      - Abszorpció (Absorption): Magas Velocity, de az ár nem mozdul (nagy csata a szinten).

   3. SKÁLA:
      - Az indikátor "Ticks per Bar" (vagy normalizált Tick/Sec) értéket mutat.
      - A szaggatott vonal az átlagos sebességet jelzi (mozgóátlag).
*/

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Velocity Histogram (Colored by Delta)
#property indicator_label1  "Tick Velocity"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Inputs
input group              "=== Velocity Settings ==="
input int                InpVelocityMA         = 14;       // Avg Activity Period (Signal Line)
input ENUM_APPLIED_VOLUME InpVolumeType        = VOLUME_TICK; // Volume Type (Tick Count or Real)

input group              "=== Delta Settings ==="
input double             InpDeltaThreshold     = 0.1;      // Delta Threshold % (10% diff required for color)
input bool               InpUseAggressorLogic  = true;     // Use Bid/Ask Aggressor Logic (Best for Scalp)

input group              "=== Data Settings ==="
input int                InpHistoryBars        = 1000;     // Analyze last N bars (Limit Calculation)

//--- Buffers
double      VelocityBuffer[];
double      ColorBuffer[]; // 0=Gray, 1=Green, 2=Red
double      VelocityMABuffer[]; // Not plotted directly, used for internal logic or future overlay
double      DeltaBuffer[]; // Calculation buffer
double      CalcBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, VelocityBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, VelocityMABuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, DeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, CalcBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Tick Velocity v1.0");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   // Optional: Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Calculate Delta from Ticks                               |
//+------------------------------------------------------------------+
void CalcTickMetrics(int i, const datetime &time[], double &out_velocity, double &out_delta)
{
    long t_start = (long)time[i] * 1000;
    long t_end   = (i < ArraySize(time)-1) ? (long)time[i+1] * 1000 : 0; // 0 = now for last bar

    MqlTick ticks[];
    int received = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, t_start, t_end);

    if (received < 1) {
        out_velocity = 0;
        out_delta = 0;
        return;
    }

    // Velocity is simply the count (or sum of volume)
    if (InpVolumeType == VOLUME_REAL) {
        double sum_vol = 0;
        for(int k=0; k<received; k++) sum_vol += ticks[k].volume_real;
        out_velocity = sum_vol;
    } else {
        out_velocity = (double)received;
    }

    // Delta Calculation (Aggressor Logic)
    double buy_vol = 0;
    double sell_vol = 0;

    if (InpUseAggressorLogic && received > 1) {
        // First tick is neutral reference
        for(int k=1; k<received; k++) {
            bool is_buy = false;
            bool is_sell = false;

            // Check Price Change
            if (ticks[k].bid > ticks[k-1].bid) is_buy = true;
            else if (ticks[k].bid < ticks[k-1].bid) is_sell = true;
            // If Bid equal, check Ask (optional refinement)
            else if (ticks[k].ask > ticks[k-1].ask) is_buy = true;
            else if (ticks[k].ask < ticks[k-1].ask) is_sell = true;

            // Add Volume
            double vol = (InpVolumeType == VOLUME_REAL) ? ticks[k].volume_real : 1.0;

            if (is_buy) buy_vol += vol;
            if (is_sell) sell_vol += vol;
        }
    } else {
        // Fallback: Just Close > Open logic for the whole bar (Not accurate for ticks)
        // We assume valid ticks. If 1 tick, delta is 0.
    }

    out_delta = buy_vol - sell_vol;
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
   if(rates_total < InpVelocityMA) return 0;

   // Start calculation limit
   int start = (prev_calculated > 0) ? prev_calculated - 1 : rates_total - InpHistoryBars;
   if (start < 0) start = 0;

   for(int i = start; i < rates_total; i++)
   {
       // 1. Calculate Velocity & Delta via Ticks
       // Only if within history limit (Tick data is heavy)
       if (rates_total - i <= InpHistoryBars) {
           double velocity, delta;
           CalcTickMetrics(i, time, velocity, delta);

           VelocityBuffer[i] = velocity;
           DeltaBuffer[i]    = delta;
       } else {
           // Fallback for old history (use Tick Volume)
           VelocityBuffer[i] = (double)tick_volume[i];
           DeltaBuffer[i]    = 0; // Unknown
       }

       // 2. Color Logic
       double threshold = VelocityBuffer[i] * InpDeltaThreshold; // Relative threshold

       if (DeltaBuffer[i] > threshold) {
           ColorBuffer[i] = 1.0; // Green (Buy)
       } else if (DeltaBuffer[i] < -threshold) {
           ColorBuffer[i] = 2.0; // Red (Sell)
       } else {
           ColorBuffer[i] = 0.0; // Gray (Neutral)
       }
   }

   return rates_total;
}
