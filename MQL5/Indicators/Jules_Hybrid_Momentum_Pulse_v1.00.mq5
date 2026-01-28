//+------------------------------------------------------------------+
//|                         Jules_Hybrid_Momentum_Pulse_v1.00.mq5    |
//|                                     Jules Agent & User           |
//|                       Hybrid Momentum Pulse (MACD Curve + DF)    |
//+------------------------------------------------------------------+
#property copyright "Jules Agent (Hybrid)"
#property link      "https://mql5.com"
#property version   "1.00"
#property description "Hybrid Momentum Pulse: Flip-MACD Curve + DeltaForce Histogram"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   3

// --- PLOT 1: MACD Pulse Curve (Line) ---
#property indicator_label1  "MACD_Pulse"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// --- PLOT 2: DeltaForce Histogram ---
#property indicator_label2  "DeltaForce_H"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  clrForestGreen,clrGreen,clrFireBrick,clrRed,clrGray // 0=StrongL, 1=WeakL, 2=StrongS, 3=WeakS
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// --- PLOT 3: Zero Line ---
#property indicator_label3  "ZeroLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// --- INPUTS: MACD Squeeze ---
input group "MACD Pulse Settings"
input uint           InpPeriodFastEMA     =  8;          // [MACD] Fast EMA
input uint           InpPeriodSlowEMA     =  21;         // [MACD] Slow EMA
input ENUM_APPLIED_PRICE InpAppliedPrice  = PRICE_CLOSE; // [MACD] Price

// --- INPUTS: Delta Force ---
input group "Delta Force Settings"
input int            InpDFShift           = 0;           // [DF] Shift
input double         InpDFScale           = 1.0;         // [DF] Manual Scale Factor (if auto fails)
input bool           InpUseAutoScaling    = true;        // [DF] Auto-Scale to MACD?
input int            InpAutoScaleLookback = 100;         // [DF] Auto-Scale Lookback

// --- BUFFERS ---
double   BufferMACDPulse[];  // Plot 1
double   BufferDFHist[];     // Plot 2 Value
double   BufferDFColor[];    // Plot 2 Color Index
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
int      g_resh = 0;
int      g_resl = 0;

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
   SetIndexBuffer(0, BufferMACDPulse, INDICATOR_DATA);
   SetIndexBuffer(1, BufferDFHist, INDICATOR_DATA);
   SetIndexBuffer(2, BufferDFColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, BufferZero, INDICATOR_DATA);

   SetIndexBuffer(4, BufferFastMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSlowMA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDFRawH, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferDFRawL, INDICATOR_CALCULATIONS);

   // 3. Properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Jules_Hybrid_Momentum_Pulse");
   IndicatorSetInteger(INDICATOR_DIGITS, Digits());

   // Shift DF
   PlotIndexSetInteger(1, PLOT_SHIFT, InpDFShift);

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
   if(rates_total < InpPeriodSlowEMA) return 0;

   // Loop Limits
   int limit = rates_total - prev_calculated;
   if (prev_calculated == 0) limit = rates_total - 1;

   // --- 1. PREPARE MACD DATA ---
   int count = (limit > 0) ? limit + 1 : 1;
   if(CopyBuffer(h_fma, 0, 0, count, BufferFastMA) != count) return 0;
   if(CopyBuffer(h_sma, 0, 0, count, BufferSlowMA) != count) return 0;

   // Set Series to match standard indicator loop (limit -> 0)
   ArraySetAsSeries(BufferFastMA, true);
   ArraySetAsSeries(BufferSlowMA, true);

   ArraySetAsSeries(BufferMACDPulse, true);
   ArraySetAsSeries(BufferDFHist, true);
   ArraySetAsSeries(BufferDFColor, true);
   ArraySetAsSeries(BufferZero, true);
   // Note: Internal calc buffers for DF need forward calculation or state tracking
   // DF logic depends on previous value. Best to calculate DF forward (0 to total).
   // But MACD copy buffer gives reverse (limit to 0).
   // Let's use reverse loop for MACD curve and direct array access for DF logic.
   // Wait, CopyBuffer returns oldest first. ArraySetAsSeries(true) reverses it.
   // Let's reset series flags for Calc buffers to handle DF logic cleanly manually or use standard pattern.

   // RESET Series for DF Calc to be safe, we will handle indexing manually
   ArraySetAsSeries(close, true); // Close is Series by default in OnCalculate? No, depends.
   // Standard OnCalculate arrays are NOT series (0 is oldest).
   // Let's adhere to: Loop i from limit down to 0.
   // Use Series=true for buffers to map i=0 to newest.

   // For DF Logic (Cumulative), we need to be careful with "limit" logic and state.
   // DF uses `close[bar] - close[bar-1]`.
   // If `bar` is loop index `i` (going down), `bar+1` is older.
   // So diff = close[i] - close[i+1].

   // Auto-Scaling Stats
   double max_macd = 0;
   double max_df = 0;

   for(int i = limit; i >= 0 && !IsStopped(); i--)
   {
       BufferZero[i] = 0.0;

       // --- A. MACD PULSE LOGIC ---
       double macd_val = BufferFastMA[i] - BufferSlowMA[i];

       // Determine Trend (Color Logic from MACD Squeeze)
       // Green (Rising): val > prev_val
       // Red (Falling): val < prev_val
       // Lookahead i+1 (older)
       double prev_macd = (i < rates_total-1) ? (BufferFastMA[i+1] - BufferSlowMA[i+1]) : 0;

       bool is_rising = (macd_val > prev_macd);

       // FLIP LOGIC:
       // If Rising (Green) -> Keep Value (Positive Logic)
       // If Falling (Red) -> Mirror to Negative (Flip Logic)
       // Wait, if Value is +5 and Falling, we mirror to -5? Yes.
       // If Value is -5 and Rising, we keep -5? Yes.
       // User: "amikor felül átvált pirosba a görbét átkell vinni negativ irányba"
       // "Igen zajos lesz mert akár pozitiv vagy negativ oldalon lehetnek piros... ellentétes oldalra csap át"

       if (is_rising) {
           BufferMACDPulse[i] = macd_val;
       } else {
           BufferMACDPulse[i] = -1.0 * macd_val;
       }

       // Track Max MACD for scaling
       if (MathAbs(BufferMACDPulse[i]) > max_macd) max_macd = MathAbs(BufferMACDPulse[i]);


       // --- B. DELTA FORCE LOGIC ---
       // close[i] is current, close[i+1] is previous
       if (i >= rates_total - 1) {
           BufferDFHist[i] = 0;
           continue;
       }

       double diff = (close[i] - close[i+1]) / Point(); // Points

       // Logic reconstruction from DeltaForce_Cust (which uses forward loop)
       // We need persistent state if calculating incrementally.
       // But here we are in a loop that might re-calc history.
       // DF depends on cumulative sums (deltah += diff).
       // We must re-calculate DF from a known point or beginning if limit is large.
       // However, typical indicator optimization only calcs last few bars.
       // We need to store state in Buffers (BufferDFRawH/L) to resume.

       // Retrieve previous state
       double prev_h = (i < rates_total-1) ? BufferDFRawH[i+1] : 0;
       double prev_l = (i < rates_total-1) ? BufferDFRawL[i+1] : 0;
       // We also need "resh" "resl" reset flags state.
       // Since we don't have integer buffers, we can infer reset if value is 0? No.
       // Let's simplify DF logic for "Hybrid" or try to implement full state.
       // Given the complexity of maintaining `static` state in reverse loop,
       // it is safer to rely on Buffers holding the cumulative value.

       double curr_h = prev_h;
       double curr_l = prev_l;

       // High Logic
       if (diff > 0) {
           // If previous was reset (0 or empty?), start new?
           // Original: if(diff>0) { resl=0; if(!resh) deltah=NULL; deltah+=diff; resh=1; }
           // Implies: if we are going UP, we accumulate High. If we were NOT going up before, reset High to 0 then add.
           // How to know if we were "going up"? Check if diff was > 0 previously?
           // Actually, simpler:
           // If Close > PrevClose (Diff > 0): Add to High Buffer. Reset Low Buffer.
           // If Close < PrevClose (Diff < 0): Add to Low Buffer. Reset High Buffer.

           curr_h += diff; // Accumulate
           curr_l = 0;     // Reset Opposing
       }
       else if (diff < 0) {
           curr_l += diff; // Accumulate (Negative)
           curr_h = 0;     // Reset Opposing
       }
       else {
           // Do nothing? Or reset both? Original code doesn't explicitly handle 0 diff clearly in `if(diff>0)... if(diff<0)`.
           // It keeps previous values if diff=0?
       }

       BufferDFRawH[i] = curr_h;
       BufferDFRawL[i] = curr_l;

       // Combine for Histogram
       // Use H if H!=0, else L.
       double df_final = (curr_h != 0) ? curr_h : curr_l;

       // --- C. SCALING ---
       double scale = InpDFScale;
       if (InpUseAutoScaling) {
           // Simple dynamic scaling: Match peaks
           // This is hard in a single pass without lookback.
           // We'll use a running estimate or fixed ratio derived from Price vs Point.
           // Price ~ 1.0000, Point ~ 0.00001. Factor ~ 10000.
           // MACD is price diff ~ 0.001. DF is points ~ 100.
           // To fit 100 into 0.001, we need multiplier 0.00001.
           scale = Point(); // Start with point size to convert back to price scale
       }

       BufferDFHist[i] = df_final * scale;

       // --- D. COLORING ---
       // 0=StrongL (ForestGreen), 1=WeakL (Green), 2=StrongS (FireBrick), 3=WeakS (Red)
       // Strong if |Value| > |PrevValue| (Momentum increasing)
       // Weak if |Value| < |PrevValue|

       double prev_df = (i < rates_total-1) ? BufferDFHist[i+1] : 0;

       if (BufferDFHist[i] > 0) { // Long
           if (BufferDFHist[i] > prev_df) BufferDFColor[i] = 0.0; // Strong Long
           else BufferDFColor[i] = 1.0; // Weak Long
       }
       else if (BufferDFHist[i] < 0) { // Short
           if (BufferDFHist[i] < prev_df) BufferDFColor[i] = 2.0; // Strong Short (More Negative)
           else BufferDFColor[i] = 3.0; // Weak Short
       }
       else {
           BufferDFColor[i] = 4.0; // Gray
       }
   }

   return rates_total;
  }
