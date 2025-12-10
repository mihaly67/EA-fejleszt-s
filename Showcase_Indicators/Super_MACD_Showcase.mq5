//+------------------------------------------------------------------+
//|                                        Super_MACD_Showcase.mq5 |
//|                        Copyright 2025, Jules Hybrid System Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Hybrid System Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   3

//--- Plot 1: Histogram (Color)
#property indicator_label1  "SuperMACD Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrGreen, clrRed, clrMaroon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: MACD Line
#property indicator_label2  "SuperMACD Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrWhite
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Inputs
input group             "Super MACD Settings"
input int               InpFastPeriod = 12;          // Fast FRAMA Period
input int               InpSlowPeriod = 26;          // Slow FRAMA Period
input int               InpSignalPeriod = 9;         // Signal SMA Period

input group             "Visualization"
input bool              InpUseColor   = true;        // Use Dynamic Coloring?

//--- Buffers
double         HistBuffer[];
double         HistColorBuffer[];
double         MACDBuffer[];
double         SignalBuffer[];
double         FastFRAMA[]; // Intermediate
double         SlowFRAMA[]; // Intermediate

//+------------------------------------------------------------------+
//| Class: CFRAMA (Fractal Adaptive Moving Average)                  |
//| Based on John Ehlers logic                                       |
//+------------------------------------------------------------------+
class CFRAMA
  {
private:
   int       m_period;
   double    m_prev_frama;

public:
   CFRAMA(void) : m_period(14), m_prev_frama(0.0) {}
   ~CFRAMA(void) {}

   void Init(int period) { m_period = period; }

   // Calculate FRAMA for a single bar (requires full history access for High/Low)
   // NOTE: To be efficient in a class without passing full arrays every time,
   // we often just implement the static logic in OnCalculate.
   // But for cleanliness, let's keep logic here.

   // Ehlers Formula:
   // N = Period.
   // N must be even. If odd, N=N+1? Ehlers usually uses fixed blocks.
   // D = (Log(N1+N2) - Log(N3)) / Log(2)
   // Alpha = Exp(-4.6 * (D - 1))
   // FRAMA = Alpha*Price + (1-Alpha)*PrevFRAMA
  };

// Since we need array access (High/Low) for FRAMA, implementing it as a pure function
// inside OnCalculate loop is often more performant in MQL5 than a class wrapper
// that demands CopyBuffer or array passing for every tick.
// We will implement the FRAMA logic directly in the loop for speed.

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,HistBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,HistColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,MACDBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,SignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,FastFRAMA,INDICATOR_CALCULATIONS); // Using buffer for state

   // NOTE: We need another buffer for SlowFRAMA state?
   // Yes, explicitly resize dynamic array if not using SetIndexBuffer,
   // OR increase indicator_buffers count.
   // Let's use internal dynamic arrays for calculations if we run out of buffers?
   // MQL5 allows many buffers. Let's fix property.

   IndicatorSetString(INDICATOR_SHORTNAME, "Super MACD (FRAMA)");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+1);

   // Define Colors explicitly if needed (0-4)
   // 0: Gray (Flat)
   // 1: Lime (Strong Up)
   // 2: Green (Weak Up)
   // 3: Red (Strong Down)
   // 4: Maroon (Weak Down)
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 5);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrGray);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrLime);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrRed);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 4, clrMaroon);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate Fractal Dimension (D)                          |
//+------------------------------------------------------------------+
double CalculateDimension(int index, int period, const double &high[], const double &low[])
{
   // Ehlers method:
   // Split period into two halves.
   // N1 = (Highest - Lowest) / Period  <-- No, that's not it.
   // Correct Ehlers Formula:
   // Len = (High - Low) / Price? No.
   // It uses a specific "Length" calculation based on Pythagorean theorem over price/time?
   // Or the simplified "Range" version?
   // Standard FRAMA uses High/Low range.

   if (index < period) return 1.5; // Default neutral D

   int half = period / 2;

   // Range of first half
   double h1 = -DBL_MAX, l1 = DBL_MAX;
   for(int i=0; i<half; i++) {
      if(high[index-i] > h1) h1 = high[index-i];
      if(low[index-i] < l1) l1 = low[index-i];
   }
   double N1 = (h1 - l1) / half;

   // Range of second half
   double h2 = -DBL_MAX, l2 = DBL_MAX;
   for(int i=half; i<period; i++) {
      if(high[index-i] > h2) h2 = high[index-i];
      if(low[index-i] < l2) l2 = low[index-i];
   }
   double N2 = (h2 - l2) / half;

   // Range of full period
   double h3 = -DBL_MAX, l3 = DBL_MAX;
   for(int i=0; i<period; i++) {
      if(high[index-i] > h3) h3 = high[index-i];
      if(low[index-i] < l3) l3 = low[index-i];
   }
   double N3 = (h3 - l3) / period;

   if (N1+N2 <= 0 || N3 <= 0) return 1.5;

   double D = (MathLog(N1+N2) - MathLog(N3)) / MathLog(2.0);
   return D;
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
   // Need a dedicated buffer for SlowFRAMA since we have limited buffers defined above?
   // We defined 5 buffers but only 4 used in SetIndexBuffer?
   // Wait: 0=Hist, 1=HistColor, 2=MACD, 3=Signal, 4=FastFRAMA.
   // We need SlowFRAMA too.
   // Re-defining properties locally by adding one more buffer.

   // We need to manage static arrays for SlowFRAMA if we don't want to expose it.
   // Or just resize a dynamic array manually.
   // Better: Increase #property indicator_buffers to 6.

   if(rates_total < InpSlowPeriod) return(0);

   // Manual management of SlowFRAMA buffer
   static double SlowFRAMA[];
   if(ArraySize(SlowFRAMA) != rates_total) ArrayResize(SlowFRAMA, rates_total);

   // To handle series direction:
   ArraySetAsSeries(close, false); // We iterate forward (standard) or backward?
   // Standard MQL5 indicators often iterate 0..total.
   // But Ehlers logic often looks back [i-1].
   // Let's stick to Standard Loop: 0 is oldest, rates_total-1 is newest.

   int limit = prev_calculated - 1;
   if(limit < InpSlowPeriod) limit = InpSlowPeriod;

   for(int i = limit; i < rates_total; i++)
     {
      // --- FAST FRAMA ---
      double D_fast = CalculateDimension(i, InpFastPeriod, high, low);
      double alpha_fast = MathExp(-4.6 * (D_fast - 1.0));
      if(alpha_fast < 0.01) alpha_fast = 0.01;
      if(alpha_fast > 1.0) alpha_fast = 1.0;

      double prev_fast = (i>0) ? FastFRAMA[i-1] : close[i];
      FastFRAMA[i] = alpha_fast * close[i] + (1.0 - alpha_fast) * prev_fast;

      // --- SLOW FRAMA ---
      double D_slow = CalculateDimension(i, InpSlowPeriod, high, low);
      double alpha_slow = MathExp(-4.6 * (D_slow - 1.0));
      if(alpha_slow < 0.01) alpha_slow = 0.01;
      if(alpha_slow > 1.0) alpha_slow = 1.0;

      double prev_slow = (i>0) ? SlowFRAMA[i-1] : close[i];
      SlowFRAMA[i] = alpha_slow * close[i] + (1.0 - alpha_slow) * prev_slow;

      // --- MACD ---
      MACDBuffer[i] = FastFRAMA[i] - SlowFRAMA[i];

      // --- Signal (SMA of MACD) ---
      // Simple loop for SMA
      double sum = 0.0;
      for(int k=0; k<InpSignalPeriod; k++) sum += MACDBuffer[i-k];
      SignalBuffer[i] = sum / InpSignalPeriod;

      // --- Histogram ---
      HistBuffer[i] = MACDBuffer[i] - SignalBuffer[i];

      // --- Color Logic ---
      if(InpUseColor)
      {
         double curr = HistBuffer[i];
         double prev = HistBuffer[i-1];

         if(curr > 0)
         {
            if(curr > prev) HistColorBuffer[i] = 1.0; // Lime (Strong Up)
            else            HistColorBuffer[i] = 2.0; // Green (Weak Up)
         }
         else
         {
            if(curr < prev) HistColorBuffer[i] = 3.0; // Red (Strong Down)
            else            HistColorBuffer[i] = 4.0; // Maroon (Weak Down)
         }
      }
      else
      {
         HistColorBuffer[i] = 0.0; // Gray
      }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
