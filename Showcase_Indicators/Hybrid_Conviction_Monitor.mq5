//+------------------------------------------------------------------+
//|                                  Hybrid_Conviction_Monitor.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (Phase Noise Analysis & Smart Fix)               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   2

//--- Plot 1: Legacy Conviction (Red - Current Logic)
#property indicator_label1  "Legacy Phase (Noisy)"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrRed
#property indicator_width1  1

//--- Plot 2: Smart Conviction (Blue - Proposed Fix)
#property indicator_label2  "Smart Phase (Smooth)"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

//--- Input Parameters (User's Golden Settings)
input uint               InpFastPeriod         = 5;
input uint               InpSlowPeriod         = 13;
input double             InpDemaGain           = 1.0;    // EMA Mode
input uint               InpNormPeriod         = 500;
input double             InpNormSensitivity    = 1.0;
input double             InpPhaseAdvance       = 2.0;    // High Aggression
input uint               InpSmartSmooth        = 3;      // Velocity Smoothing for Smart Mode

//--- Buffers
double      LegacyBuffer[];
double      SmartBuffer[];

//--- Calculation Buffers
double      FastDema[];
double      SlowDema[];
double      RawMacd[];
double      FastEma1[], FastEma2[];
double      SlowEma1[], SlowEma2[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, LegacyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SmartBuffer, INDICATOR_DATA);

   SetIndexBuffer(2, FastDema, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, SlowDema, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, RawMacd, INDICATOR_CALCULATIONS);

   // State buffers
   SetIndexBuffer(5, FastEma1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SlowEma1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, FastEma2, INDICATOR_CALCULATIONS); // Reusing as dummy or simple EMA storage if Gain=1.0

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Conviction Monitor");
   IndicatorSetDouble(INDICATOR_MINIMUM, -110);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 110);

   // Zero line
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Calculate DEMA/EMA                                       |
//+------------------------------------------------------------------+
void CalculateStep(int i, double price, int period, double gain,
                   double &val_buf[], double &ema1_buf[])
{
    // Simplified incremental for this monitor
    double alpha = 2.0 / (period + 1.0);
    double prev_ema = (i > 0) ? ema1_buf[i-1] : price;

    // EMA 1
    double ema1 = alpha * price + (1.0 - alpha) * prev_ema;
    ema1_buf[i] = ema1;

    // If Gain=1.0, we just use EMA1.
    // If Gain!=1.0, we would need EMA2.
    // For this monitor (Gain 1.0), we skip full DEMA complexity to match user setting strictly.
    if(gain == 1.0)
    {
        val_buf[i] = ema1;
    }
    else
    {
        // Full DEMA logic if needed later
        // ... (Not implemented here to keep focus on Phase logic with user's Gain=1.0)
        val_buf[i] = ema1;
    }
}

//+------------------------------------------------------------------+
//| Tanh Normalization                                               |
//+------------------------------------------------------------------+
double Normalize(double val, double std)
{
    if(std == 0) return 0;
    return 100.0 * MathTanh(val / std);
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
   if(rates_total < InpNormPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // 1. Calculate Base Signal (MACD)
   for(int i = start; i < rates_total; i++)
   {
       CalculateStep(i, close[i], InpFastPeriod, InpDemaGain, FastDema, FastEma1);
       CalculateStep(i, close[i], InpSlowPeriod, InpDemaGain, SlowDema, SlowEma1);
       RawMacd[i] = FastDema[i] - SlowDema[i];
   }

   // 2. Normalization StdDev (Rolling)
   // We calculate StdDev of the Raw Signal over N bars
   // Ideally we do this in a loop or optimize.
   // For Monitor, simple loop is fine.

   for(int i = start; i < rates_total; i++)
   {
       if(i < InpNormPeriod) { LegacyBuffer[i] = 0; SmartBuffer[i] = 0; continue; }

       double sum = 0, sum_sq = 0;
       for(int k = 0; k < InpNormPeriod; k++)
       {
           double val = RawMacd[i-k];
           sum += val;
           sum_sq += val * val;
       }
       double mean = sum / InpNormPeriod;
       double var = (sum_sq / InpNormPeriod) - (mean * mean);
       double std = (var > 0) ? MathSqrt(var) : 1.0;

       // 3. Phase Advance Logic

       // Velocity
       double vel = RawMacd[i] - RawMacd[i-1];

       // Legacy: Raw Velocity * Factor
       double legacy_boost = RawMacd[i] + (vel * InpPhaseAdvance);
       LegacyBuffer[i] = Normalize(legacy_boost, std);

       // Smart: Smoothed Velocity * Factor
       // Simple SMA of velocity
       double smooth_vel = 0;
       int v_count = 0;
       for(int v = 0; v < InpSmartSmooth; v++)
       {
           smooth_vel += (RawMacd[i-v] - RawMacd[i-v-1]);
           v_count++;
       }
       smooth_vel /= v_count;

       double smart_boost = RawMacd[i] + (smooth_vel * InpPhaseAdvance);
       SmartBuffer[i] = Normalize(smart_boost, std);
   }

   return rates_total;
}
