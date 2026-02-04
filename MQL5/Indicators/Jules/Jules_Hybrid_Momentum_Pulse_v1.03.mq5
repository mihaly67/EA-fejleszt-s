//+------------------------------------------------------------------+
//|                         Jules_Hybrid_Momentum_Pulse_v1.03.mq5    |
//|                                     Jules Agent & User           |
//|                 Hybrid Momentum Pulse (Full Squeeze Params)      |
//+------------------------------------------------------------------+
#property copyright "Jules Agent (Hybrid)"
#property link      "https://mql5.com"
#property version   "1.03"
#property description "Hybrid Momentum Pulse: MACD Squeeze Hist + DeltaForce Curve (Foreground)"
#property indicator_separate_window
#property indicator_buffers 16
#property indicator_plots   3

// --- PLOT 1: MACD Squeeze Histogram (Background) ---
#property indicator_label1  "MACD_Hist"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrForestGreen,clrFireBrick // 0=Rising, 1=Falling
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4

// --- PLOT 2: DeltaForce Curve (Foreground) ---
#property indicator_label2  "DeltaForce_Curve"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// --- PLOT 3: Zero Line ---
#property indicator_label3  "ZeroLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// --- INPUTS: MACD Squeeze (Flat - No Group) ---
input uint           InpPeriodFastEMA     =  3;          // MACD Fast EMA period
input uint           InpPeriodSlowEMA     =  6;          // MACD Slow EMA period
input uint           InpPeriodBB          =  20;         // Bollinger Bands period
input double         InpDeviationBB       =  2.0;        // Bollinger Bands deviation
input ENUM_MA_METHOD InpMethodBB          =  MODE_EMA;   // Bollinger Bands MA method
input uint           InpPeriodKeltner     =  20;         // Keltner period
input double         InpDeviationKeltner  =  1.5;        // Keltner deviation
input uint           InpPeriodATRKeltner  =  10;         // Keltner ATR period
input ENUM_MA_METHOD InpMethodKeltner     =  MODE_EMA;   // Keltner MA method

// --- INPUTS: Hybrid Extras (Flat - No Group) ---
input double         InpMACDScale         =  4.0;        // [Hybrid] MACD Scale
input int            InpDFShift           = 0;           // [Hybrid] DF Shift
input double         InpDFScale           = 1.0;         // [Hybrid] DF Manual Scale
input bool           InpUseAutoScaling    = true;        // [Hybrid] DF Auto-Scale
input int            InpAutoScaleLookback = 100;         // [Hybrid] DF Lookback

// --- BUFFERS ---
// Plots
double   BufferMACDHist[];   // Plot 1 Data
double   BufferMACDColor[];  // Plot 1 Color
double   BufferDFCurve[];    // Plot 2 Data
double   BufferZero[];       // Plot 3 Data

// Calculation Buffers (MACD Squeeze)
double   BufferFMA[];
double   BufferSMA[];
double   BufferBBMA[];
double   BufferBBDEV[];
double   BufferKMA[];
double   BufferKATR[];

// Calculation Buffers (Delta Force)
double   BufferDFRawH[];     // Internal DF High logic
double   BufferDFRawL[];     // Internal DF Low logic

// --- HANDLES ---
int      h_fma, h_sma;
int      h_bbma, h_bbdev;
int      h_kma, h_katr;

// --- GLOBALS ---
// DF Logic State
double   g_deltah = 0;
double   g_deltal = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. MACD Squeeze Handles
   h_fma = iMA(NULL, PERIOD_CURRENT, InpPeriodFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_sma = iMA(NULL, PERIOD_CURRENT, InpPeriodSlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   h_bbma   = iMA(NULL, PERIOD_CURRENT, InpPeriodBB, 0, InpMethodBB, PRICE_CLOSE);
   h_bbdev  = iStdDev(NULL, PERIOD_CURRENT, InpPeriodBB, 0, MODE_SMA, PRICE_CLOSE); // Standard BB Dev is usually SMA

   h_kma    = iMA(NULL, PERIOD_CURRENT, InpPeriodKeltner, 0, InpMethodKeltner, PRICE_CLOSE);
   h_katr   = iATR(NULL, PERIOD_CURRENT, InpPeriodATRKeltner);

   if (h_fma == INVALID_HANDLE || h_sma == INVALID_HANDLE ||
       h_bbma == INVALID_HANDLE || h_bbdev == INVALID_HANDLE ||
       h_kma == INVALID_HANDLE || h_katr == INVALID_HANDLE)
   {
       Print("Hybrid Pulse v1.03: Failed to create handles!");
       return INIT_FAILED;
   }

   // 2. Buffers
   SetIndexBuffer(0, BufferMACDHist, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferDFCurve, INDICATOR_DATA);
   SetIndexBuffer(3, BufferZero, INDICATOR_DATA);

   SetIndexBuffer(4, BufferFMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferBBMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferBBDEV, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, BufferKMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, BufferKATR, INDICATOR_CALCULATIONS);

   SetIndexBuffer(10, BufferDFRawH, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, BufferDFRawL, INDICATOR_CALCULATIONS);

   // 3. Properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Jules_Hybrid_Momentum_Pulse_v1.03");
   IndicatorSetInteger(INDICATOR_DIGITS, Digits());

   // Shift DF (Plot 2 is Index 2 in Data buffers? No, Plot indices correspond to buffer registration order for INDICATOR_DATA)
   // Buffer 0 = Plot 1 (Hist)
   // Buffer 1 = Plot 1 Color
   // Buffer 2 = Plot 2 (Curve)
   // Buffer 3 = Plot 3 (Zero)

   PlotIndexSetInteger(1, PLOT_SHIFT, InpDFShift); // Shift Plot 2 (DF Curve)

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
   // Check Requirements (Max of all lookbacks)
   int min_req = (int)MathMax(InpPeriodSlowEMA, MathMax(InpPeriodBB, InpPeriodKeltner));
   if(rates_total < min_req) return 0;

   // Loop Limits
   int limit = rates_total - prev_calculated;
   if (prev_calculated == 0)
   {
      limit = rates_total - 1;
      ArrayInitialize(BufferZero, 0.0);
   }

   // --- 1. PREPARE DATA ---
   int count = (limit > 0) ? limit + 1 : 1;

   if(CopyBuffer(h_fma, 0, 0, count, BufferFMA) != count) return 0;
   if(CopyBuffer(h_sma, 0, 0, count, BufferSMA) != count) return 0;
   // We only need these if we calculate Squeeze Dots (which we don't draw yet, but we have inputs)
   // For now, we perform the copies to respect the inputs' existence and potential future use.
   if(CopyBuffer(h_bbma, 0, 0, count, BufferBBMA) != count) return 0;
   if(CopyBuffer(h_bbdev, 0, 0, count, BufferBBDEV) != count) return 0;
   if(CopyBuffer(h_kma, 0, 0, count, BufferKMA) != count) return 0;
   if(CopyBuffer(h_katr, 0, 0, count, BufferKATR) != count) return 0;

   // Set Series
   ArraySetAsSeries(BufferFMA, true);
   ArraySetAsSeries(BufferSMA, true);
   ArraySetAsSeries(BufferBBMA, true);
   ArraySetAsSeries(BufferBBDEV, true);
   ArraySetAsSeries(BufferKMA, true);
   ArraySetAsSeries(BufferKATR, true);

   ArraySetAsSeries(BufferMACDHist, true);
   ArraySetAsSeries(BufferMACDColor, true);
   ArraySetAsSeries(BufferDFCurve, true);
   ArraySetAsSeries(BufferZero, true);
   ArraySetAsSeries(close, true);

   // Calc Buffers Series
   ArraySetAsSeries(BufferDFRawH, true);
   ArraySetAsSeries(BufferDFRawL, true);

   // Scaling
   double scaling_factor = InpDFScale;
   if (InpUseAutoScaling) {
       scaling_factor = Point();
   }

   for(int i = limit; i >= 0 && !IsStopped(); i--)
   {
       BufferZero[i] = 0.0;

       // --- A. MACD HISTOGRAM LOGIC ---
       double macd_val = (BufferFMA[i] - BufferSMA[i]) * InpMACDScale;
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

       BufferDFRawH[i] = curr_h;
       BufferDFRawL[i] = curr_l;

       // Select active power
       double df_raw = (curr_h != 0) ? curr_h : curr_l;

       // Apply Scaling
       double final_scale = InpUseAutoScaling ? Point() : InpDFScale;

       BufferDFCurve[i] = df_raw * final_scale;
   }

   return rates_total;
  }
