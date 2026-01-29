//+------------------------------------------------------------------+
//|                         Jules_Hybrid_Momentum_Pulse_v1.02.mq5    |
//|                                     Jules Agent & User           |
//|                       Hybrid Momentum Pulse (DF Curve + MACD Hist)|
//+------------------------------------------------------------------+
#property copyright "Jules Agent (Hybrid)"
#property link      "https://mql5.com"
#property version   "1.02"
#property description "Hybrid Momentum Pulse: DeltaForce Curve + MACD Squeeze Histogram"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   3

// --- PLOT 1: DeltaForce Curve (Line) ---
#property indicator_label1  "DeltaForce_Curve"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// --- PLOT 2: MACD Squeeze Histogram ---
#property indicator_label2  "MACD_Hist"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  clrForestGreen,clrFireBrick // 0=Rising, 1=Falling
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

// --- PLOT 3: Zero Line ---
#property indicator_label3  "ZeroLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// --- INPUTS: MACD Squeeze ---
input group "MACD Pulse Settings"
input uint           InpPeriodFastEMA     =  3;          // [MACD] Fast EMA
input uint           InpPeriodSlowEMA     =  6;          // [MACD] Slow EMA
input ENUM_APPLIED_PRICE InpAppliedPrice  = PRICE_CLOSE; // [MACD] Price
input double         InpMACDScale         =  1.0;        // [MACD] Amplitude Scale (Multiplier)

// --- INPUTS: Delta Force ---
input group "Delta Force Settings"
input int            InpDFShift           = 0;           // [DF] Shift
input double         InpDFScale           = 1.0;         // [DF] Manual Scale Factor (if auto fails)
input bool           InpUseAutoScaling    = true;        // [DF] Auto-Scale to MACD?
input int            InpAutoScaleLookback = 100;         // [DF] Auto-Scale Lookback

// --- BUFFERS ---
double   BufferDFCurve[];    // Plot 1 (DF)
double   BufferMACDHist[];   // Plot 2 Value (MACD)
double   BufferMACDColor[];  // Plot 2 Color (MACD)
double   BufferZero[];       // Plot 3

// --- CALC BUFFERS ---
double   BufferFastMA[];
double   BufferSlowMA[];
double   BufferDFRawH[];     // Internal DF High logic
double   BufferDFRawL[];     // Internal DF Low logic

// --- HANDLES ---
int      h_fma, h_sma;

// --- GLOBALS ---
// DF Logic State
double   g_deltah = 0;
double   g_deltal = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. MACD Handles
   h_fma = iMA(NULL, PERIOD_CURRENT, InpPeriodFastEMA, 0, MODE_EMA, InpAppliedPrice);
   h_sma = iMA(NULL, PERIOD_CURRENT, InpPeriodSlowEMA, 0, MODE_EMA, InpAppliedPrice);

   if (h_fma == INVALID_HANDLE || h_sma == INVALID_HANDLE)
   {
       Print("Hybrid Pulse: Failed to create MA handles!");
       return INIT_FAILED;
   }

   // 2. Buffers
   SetIndexBuffer(0, BufferDFCurve, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDHist, INDICATOR_DATA);
   SetIndexBuffer(2, BufferMACDColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, BufferZero, INDICATOR_DATA);

   SetIndexBuffer(4, BufferFastMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSlowMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDFRawH, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferDFRawL, INDICATOR_CALCULATIONS);

   // 3. Properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Jules_Hybrid_Momentum_Pulse_v1.02");
   IndicatorSetInteger(INDICATOR_DIGITS, Digits());

   // Shift DF (Only affects Plot 1 technically, but we apply index shift)
   PlotIndexSetInteger(0, PLOT_SHIFT, InpDFShift);

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
   if(rates_total < (int)InpPeriodSlowEMA) return 0;

   // Loop Limits
   int limit = rates_total - prev_calculated;
   if (prev_calculated == 0)
   {
      limit = rates_total - 1;
      ArrayInitialize(BufferZero, 0.0);
   }

   // --- 1. PREPARE MACD DATA ---
   int count = (limit > 0) ? limit + 1 : 1;
   if(CopyBuffer(h_fma, 0, 0, count, BufferFastMA) != count) return 0;
   if(CopyBuffer(h_sma, 0, 0, count, BufferSlowMA) != count) return 0;

   // Set Series
   ArraySetAsSeries(BufferFastMA, true);
   ArraySetAsSeries(BufferSlowMA, true);

   ArraySetAsSeries(BufferDFCurve, true);
   ArraySetAsSeries(BufferMACDHist, true);
   ArraySetAsSeries(BufferMACDColor, true);
   ArraySetAsSeries(BufferZero, true);
   ArraySetAsSeries(close, true);

   // Calculation Buffers
   ArraySetAsSeries(BufferDFRawH, true);
   ArraySetAsSeries(BufferDFRawL, true);

   // Stats for Auto-Scaling
   double max_macd_abs = 0;
   double max_df_abs = 0;

   // First Pass: Calculate MACD and raw DF to find peaks (if scaling needed)
   // Ideally we do this in one loop, but scaling requires knowledge of the range.
   // For efficiency, we'll use a running peak or simple ratio.

   // Ratio Estimation:
   // MACD is Price Difference (e.g. 0.0005)
   // DF is Accumulation of Points (e.g. 50 points = 0.00050)
   // Usually DF values (integers/points) are much larger than Price diffs.
   // Example: Gold Price 2500. MACD ~ 2.0. DF ~ 200.
   // Forex Price 1.05. MACD ~ 0.001. DF ~ 100.
   // Factor = MACD / DF.

   double scaling_factor = InpDFScale;

   if (InpUseAutoScaling) {
       // Heuristic: Scale DF (Points) to Price Scale
       // Point() converts integer points to price.
       // DF is calculated in Points? No, usually Raw DF is cumulative price diff.
       // Let's check DF Logic below.
       scaling_factor = Point(); // Default to Point size
   }

   for(int i = limit; i >= 0 && !IsStopped(); i--)
   {
       BufferZero[i] = 0.0;

       // --- A. MACD HISTOGRAM LOGIC ---
       double macd_val = (BufferFastMA[i] - BufferSlowMA[i]) * InpMACDScale;
       BufferMACDHist[i] = macd_val;

       // Color Logic: Rising vs Falling
       double prev_macd = (i < rates_total-1) ? BufferMACDHist[i+1] : 0;

       if (macd_val > prev_macd) {
           BufferMACDColor[i] = 0.0; // Rising -> ForestGreen
       } else {
           BufferMACDColor[i] = 1.0; // Falling -> FireBrick
       }


       // --- B. DELTA FORCE LOGIC (Curve) ---
       // close[i] is current, close[i+1] is previous
       if (i >= rates_total - 1) {
           BufferDFCurve[i] = 0;
           continue;
       }

       double diff = (close[i] - close[i+1]) / Point(); // Difference in Points

       // Retrieve previous state
       double prev_h = (i < rates_total-1) ? BufferDFRawH[i+1] : 0;
       double prev_l = (i < rates_total-1) ? BufferDFRawL[i+1] : 0;

       double curr_h = prev_h;
       double curr_l = prev_l;

       // Accumulation Logic
       if (diff > 0) {
           curr_h += diff; // Add to Bull Power
           curr_l = 0;     // Reset Bear Power
       }
       else if (diff < 0) {
           curr_l += diff; // Add to Bear Power (negative)
           curr_h = 0;     // Reset Bull Power
       }
       // If diff == 0, keep previous values

       BufferDFRawH[i] = curr_h;
       BufferDFRawL[i] = curr_l;

       // Select active power
       double df_raw = (curr_h != 0) ? curr_h : curr_l;

       // Apply Scaling
       // If AutoScaling is ON, we try to match MACD magnitude.
       // DF is in Points (e.g., 50). MACD is in Price (e.g., 0.0005).
       // To visualize DF on Price scale, we multiply by Point().
       // 50 * 0.00001 = 0.0005. This usually matches well!

       double final_scale = InpUseAutoScaling ? Point() : InpDFScale;

       BufferDFCurve[i] = df_raw * final_scale;
   }

   return rates_total;
  }
