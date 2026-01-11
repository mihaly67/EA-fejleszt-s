//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.41.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 1.41 (Smart Sentiment: Panic vs Flow - Customizable)|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.41"
#property description "Hybrid WVF: Separates Fear (Panic) from Joy (Flow)."
#property description "Fully customizable Trend and Panic detection for Scalping."

/*
   ===================================================================
   HYBRID WVF v1.41 - ÉRTELMEZÉS (SMART SENTIMENT)
   ===================================================================
   Ez az indikátor szétválasztja a piaci mozgásokat két típusra:
   1. ÖRÖM (Joy/Flow) - Pozitív Oszlopok:
      - Egészséges, trendszerű mozgás. A piac örül a várt iránynak.
   2. FÉLELEM (Fear/Panic) - Negatív Oszlopok:
      - Túlfeszített, pánikszerű mozgás. A piac fél (vagy FOMO).

   PARAMÉTEREZÉS (Scalper Optimalizáció):
   - Trend Logic (Panic Switch):
     - DYNAMIC_STD (Bollinger-szerű): Ha a WVF kilép a sávból -> Pánik.
     - MA_CROSS (EMA): Ha a WVF átlépi az átlagát -> Pánik.
     - FIXED_LEVEL: Ha a WVF > Szint -> Pánik.

   - Color Logic:
     - CANDLE_COLOR: Gyertya színe.
     - MA_TREND: Árfolyam vs Mozgóátlag.
*/

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Histogram
#property indicator_label1  "Smart Sentiment"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrFireBrick, clrForestGreen, clrRed, clrLime
// 0=Red(Bear), 1=Green(Bull), 2=StrongRed, 3=StrongGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Levels
#property indicator_level1 0.0
#property indicator_level2 20.0
#property indicator_level3 -20.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Enums
enum ENUM_PANIC_METHOD {
    PANIC_DYNAMIC_STD, // Dynamic (Bollinger)
    PANIC_MA_CROSS,    // MA Cross (EMA Switch)
    PANIC_FIXED_LEVEL  // Fixed Level
};

enum ENUM_COLOR_METHOD {
    COLOR_CANDLE,      // Candle Color
    COLOR_MA_TREND     // Price vs MA
};

//--- Inputs
input group              "=== WVF Settings ==="
input int                InpPeriod       = 22;     // WVF Period
input int                InpNormPeriod   = 480;    // Scaling History (Bars)

input group              "=== Panic Logic (Positive vs Negative) ==="
input ENUM_PANIC_METHOD  InpPanicMethod  = PANIC_DYNAMIC_STD;
input double             InpPanicFactor  = 2.0;    // Threshold (Multiplier or Level)
input int                InpPanicMA      = 50;     // MA Period (for MA Cross mode)

input group              "=== Color Logic (Red vs Green) ==="
input ENUM_COLOR_METHOD  InpColorMethod  = COLOR_CANDLE;
input int                InpColorMA      = 9;      // MA Period (for Trend Color)

//--- Buffers
double      ValBuffer[];
double      ColorBuffer[];
double      WVFBuffer[];
double      ThresholdBuffer[];
double      MABuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ValBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, WVFBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, ThresholdBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, MABuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.41 (Smart)");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   IndicatorSetDouble(INDICATOR_MINIMUM, -100.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100.0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Get Highest                                              |
//+------------------------------------------------------------------+
double GetHighest(const double &array[], int start, int count)
{
   double max_val = -DBL_MAX;
   for(int i=0; i<count; i++) {
      if(start-i >= 0 && array[start-i] > max_val) max_val = array[start-i];
   }
   return max_val;
}

//+------------------------------------------------------------------+
//| Helper: Calculate StdDev of Buffer                               |
//+------------------------------------------------------------------+
double GetStdDev(const double &buffer[], int start, int period, double mean)
{
    double sum = 0.0;
    for(int i=0; i<period; i++) {
        if(start-i >= 0) sum += MathPow(buffer[start-i] - mean, 2);
    }
    return MathSqrt(sum / period);
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
   if(rates_total < InpPeriod * 2 || rates_total < InpPanicMA || rates_total < InpColorMA || rates_total < InpNormPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : MathMax(InpNormPeriod, MathMax(InpPeriod, MathMax(InpPanicMA, InpColorMA)));

   for(int i = start; i < rates_total; i++)
   {
       // 1. Calculate Standard WVF (Volatility Strength)
       double highest_c = GetHighest(close, i, InpPeriod);
       double wvf_val = 0.0;
       if (highest_c > 0) wvf_val = ((highest_c - low[i]) / highest_c) * 100.0;

       WVFBuffer[i] = wvf_val;

       // 2. Determine Panic Threshold (Dynamic Switch)
       double threshold = 999.0;

       if (InpPanicMethod == PANIC_DYNAMIC_STD) {
           double sum = 0;
           for(int k=0; k<InpPeriod; k++) if(i-k >=0) sum += WVFBuffer[i-k];
           double ma = sum / InpPeriod;
           double std = GetStdDev(WVFBuffer, i, InpPeriod, ma);
           threshold = ma + (std * InpPanicFactor);
       }
       else if (InpPanicMethod == PANIC_MA_CROSS) {
           double sum = 0;
           for(int k=0; k<InpPanicMA; k++) if(i-k >=0) sum += WVFBuffer[i-k];
           threshold = sum / InpPanicMA;
       }
       else if (InpPanicMethod == PANIC_FIXED_LEVEL) {
           threshold = InpPanicFactor;
       }

       ThresholdBuffer[i] = threshold;

       // 3. Logic: Flow (Joy) vs Panic (Fear)
       bool is_panic = (wvf_val > threshold);

       // 4. Direction: Bull or Bear? (Color)
       bool is_bear = false;
       if (InpColorMethod == COLOR_CANDLE) {
           is_bear = (close[i] < open[i]);
       }
       else if (InpColorMethod == COLOR_MA_TREND) {
           double sum_p = 0;
           for(int k=0; k<InpColorMA; k++) if(i-k >=0) sum_p += close[i-k];
           double ma_p = sum_p / InpColorMA;
           is_bear = (close[i] < ma_p);
       }

       // 5. SCALING FIX (Dynamic Normalization)
       double max_wvf = GetHighest(WVFBuffer, i, InpNormPeriod);
       if (max_wvf == 0) max_wvf = 1.0;

       double output_val = (wvf_val / max_wvf) * 100.0;
       if(output_val > 100.0) output_val = 100.0;

       if (is_panic) {
           // PANIC -> NEGATIVE (Fear)
           ValBuffer[i] = -output_val;
       } else {
           // FLOW -> POSITIVE (Joy)
           ValBuffer[i] = output_val;
       }

       // Color Logic
       if (is_bear) {
           ColorBuffer[i] = is_panic ? 2.0 : 0.0;
       } else {
           ColorBuffer[i] = is_panic ? 3.0 : 1.0;
       }
   }

   return rates_total;
}
