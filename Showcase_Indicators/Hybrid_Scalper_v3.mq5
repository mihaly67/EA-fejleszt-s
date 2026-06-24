//+------------------------------------------------------------------+
//|                                           Hybrid_Scalper_v3.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 3.1 (Tick Average & Z-MACD) |
//|                                                                  |
//| LEÍRÁS:                                                          |
//| 1. Bemenet: 10mp Tick Átlag (Live) / Typical Price (History).    |
//| 2. Szűrő: Zero-Lag MACD (Fast DEMA - Slow DEMA).                 |
//| 3. Normalizálás: Z-Score (Adaptív Szórás).                       |
//| 4. Aktiváció: IFT.                                               |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "3.10"
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   2

//--- Plot 1: Hybrid Signal Line (Gradient)
#property indicator_label1  "Hybrid_Signal"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Histogram (Gradient)
#property indicator_label2  "Conviction_Hist"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//==================================================================
// INPUT PARAMETERS
//==================================================================

input group "Signal Source"
input int      InpTickAvgTime    = 10;       // Tick Átlagolás (mp) [Zajszűrés]
input int      InpFastPeriod     = 12;       // Fast DEMA Period
input int      InpSlowPeriod     = 26;       // Slow DEMA Period

input group "Normalization (Z-Score)"
input int      InpNormPeriod     = 20;       // Normalizálási Ablak (Szórás)
input double   InpStDevScale     = 2.0;      // Szórás Skálázó (Sigma)

input group "Activation"
input double   InpIFTGain        = 1.5;      // IFT Erősítés (Gain)
input double   InpThreshold      = 0.8;      // Jelszint (Vizuális)

input group "Colors"
input color    InpColorBuy       = clrLime;  // Vétel Szín
input color    InpColorSell      = clrRed;   // Eladás Szín
input color    InpColorNeutral   = clrGray;  // Semleges Szín

//==================================================================
// BUFFERS
//==================================================================
// Display Buffers
double         Buf_Signal[];
double         Buf_SignalColors[];
double         Buf_Hist[];
double         Buf_HistColors[];

// Calculation Buffers (Internal)
double         Buf_Input[];      // Mixed Source: TickAvg (Live) + Typical (Hist)
double         Buf_FastEMA1[];   // DEMA State
double         Buf_FastEMA2[];
double         Buf_SlowEMA1[];
double         Buf_SlowEMA2[];
double         Buf_MACD[];       // FastDEMA - SlowDEMA

// Tick Buffer (Struct Array)
struct TickNode {
   long     msc;
   double   price;
};
TickNode       TickBuffer[]; // Dinamikus tömb a tickeknek

//==================================================================
// INIT
//==================================================================
int OnInit()
  {
   // 1. Buffers
   SetIndexBuffer(0, Buf_Signal, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_SignalColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, Buf_Hist, INDICATOR_DATA);
   SetIndexBuffer(3, Buf_HistColors, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(4, Buf_Input, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, Buf_FastEMA1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, Buf_FastEMA2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, Buf_SlowEMA1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, Buf_SlowEMA2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, Buf_MACD, INDICATOR_CALCULATIONS);

   // 2. Plots
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorNeutral);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorBuy);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorSell);

   PlotIndexSetString(1, PLOT_LABEL, "Conviction");
   PlotIndexSetInteger(1, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, InpColorNeutral);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, InpColorBuy);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 2, InpColorSell);

   // 3. Levels
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpThreshold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -InpThreshold);

   string name = StringFormat("HybridScalper_v3.1(Tick:%ds, F:%d, S:%d)", InpTickAvgTime, InpFastPeriod, InpSlowPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ArrayFree(TickBuffer);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate EMA                                            |
//+------------------------------------------------------------------+
// Calculates EMA for index 'i' based on previous EMA 'i-1'
void CalcEMA(int i, int period, const double &src[], double &ema_buf[])
{
   if(i == 0) {
      ema_buf[0] = src[0];
      return;
   }

   double alpha = 2.0 / (period + 1.0);
   // ema = alpha * src + (1-alpha) * prev
   // Check for empty history
   double prev = ema_buf[i-1];
   if(prev == 0.0 && i > 0) prev = src[i]; // Init if empty

   ema_buf[i] = alpha * src[i] + (1.0 - alpha) * prev;
}

//+------------------------------------------------------------------+
//| Helper: Calculate DEMA                                           |
//+------------------------------------------------------------------+
// Needs 2 EMA buffers.
// DEMA = 2*EMA1 - EMA2
double CalcDEMA(int i, int period, const double &src[], double &ema1[], double &ema2[])
{
   // 1. Calc EMA1 of Source
   CalcEMA(i, period, src, ema1);

   // 2. Calc EMA2 of EMA1
   CalcEMA(i, period, ema1, ema2);

   // 3. DEMA
   return (2.0 * ema1[i]) - ema2[i];
}

//+------------------------------------------------------------------+
//| Helper: Calculate StdDev                                         |
//+------------------------------------------------------------------+
double CalcStdDev(const double &buffer[], int idx, int count)
  {
   if(idx < count) return 1.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int actual_count = 0;

   for(int i = 0; i < count; i++) {
      int pos = idx - i;
      if(pos < 0) break;

      double val = buffer[pos];
      sum += val;
      sum_sq += val * val;
      actual_count++;
   }

   if(actual_count < 2) return 1.0;

   double mean = sum / actual_count;
   double variance = (sum_sq / actual_count) - (mean * mean);

   if(variance <= 0.00000001) return 0.00000001;
   return MathSqrt(variance);
  }

//+------------------------------------------------------------------+
//| Helper: IFT                                                      |
//+------------------------------------------------------------------+
double IFT(double x)
  {
   double e2x = MathExp(2.0 * x * InpIFTGain);
   if(DoubleToString(e2x) == "inf") return (x > 0) ? 1.0 : -1.0;
   return (e2x - 1.0) / (e2x + 1.0);
  }

//+------------------------------------------------------------------+
//| Helper: Update Tick Buffer & Get Average                         |
//+------------------------------------------------------------------+
double UpdateTickAverage(double current_price)
{
   long now_msc = TimeCurrent() * 1000; // TimeCurrent is sec. SymbolInfoInteger(SYMBOL_TIME_MSC) better?
   // Let's use gettickcount or just TimeCurrent for 10s precision is fine.
   // Better: SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)
   long sym_time = SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC);

   // 1. Add new tick
   int size = ArraySize(TickBuffer);
   ArrayResize(TickBuffer, size + 1);
   TickBuffer[size].msc = sym_time;
   TickBuffer[size].price = current_price;

   // 2. Remove old ticks (> InpTickAvgTime seconds)
   long cutoff = sym_time - (InpTickAvgTime * 1000);

   // Find count to remove
   int remove_cnt = 0;
   for(int i=0; i<ArraySize(TickBuffer); i++) {
      if(TickBuffer[i].msc < cutoff) remove_cnt++;
      else break; // Sorted by time, so we can stop
   }

   if(remove_cnt > 0) {
      ArrayRemove(TickBuffer, 0, remove_cnt);
   }

   // 3. Calc Average
   size = ArraySize(TickBuffer);
   if(size == 0) return current_price;

   double sum = 0;
   for(int i=0; i<size; i++) sum += TickBuffer[i].price;

   return sum / size;
}

//+------------------------------------------------------------------+
//| MAIN CALCULATION                                                 |
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
   if(rates_total < InpSlowPeriod + InpNormPeriod) return 0;

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   //--- Loop
   for(int i = start; i < rates_total; i++)
     {
      // 1. Prepare Input Source
      bool is_forming = (i == rates_total - 1);
      double input_val = 0.0;

      if(is_forming) {
         // Live: Use Tick Average
         // Note: close[i] is the current bid price usually
         input_val = UpdateTickAverage(close[i]);
      } else {
         // History: Use Typical Price as approximation
         input_val = (high[i] + low[i] + close[i]) / 3.0;
      }
      Buf_Input[i] = input_val;

      // 2. Manual DEMA Calculation (Zero-Lag MACD)
      // Fast DEMA
      double fast_val = CalcDEMA(i, InpFastPeriod, Buf_Input, Buf_FastEMA1, Buf_FastEMA2);
      // Slow DEMA
      double slow_val = CalcDEMA(i, InpSlowPeriod, Buf_Input, Buf_SlowEMA1, Buf_SlowEMA2);

      // MACD (Raw Oscillator)
      double macd = fast_val - slow_val;
      Buf_MACD[i] = macd;

      // 3. Z-Score Normalization
      // Calculate StdDev of the MACD signal itself over last N bars
      double sigma = CalcStdDev(Buf_MACD, i, InpNormPeriod);

      // Normalize: Value / (Sigma * Scale)
      double z_score = macd / (sigma * InpStDevScale);

      // 4. IFT Activation
      double signal = IFT(z_score);

      Buf_Signal[i] = signal;
      Buf_Hist[i]   = signal;

      // 5. Colors
      int color_idx = 0;
      if(signal > InpThreshold)       color_idx = 1; // Buy
      else if(signal < -InpThreshold) color_idx = 2; // Sell
      else                            color_idx = 0; // Neutral

      Buf_SignalColors[i] = color_idx;
      Buf_HistColors[i]   = color_idx;
     }

   return(rates_total);
  }
