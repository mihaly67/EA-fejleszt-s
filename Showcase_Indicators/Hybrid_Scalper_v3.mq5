//+------------------------------------------------------------------+
//|                                           Hybrid_Scalper_v3.mq5 |
//|                                            Jules Assistant |
//|                             Verzió: 3.0 (The Scalper Core) |
//|                                                                  |
//| LEÍRÁS:                                                          |
//| Zajmentesített, gyors reagálású scalper indikátor.               |
//| 1. Időalapú mintavételezés (10s) a mikro-zaj ellen.              |
//| 2. DEMA szűrő a késésmentes trendkövetéshez.                     |
//| 3. Z-Score (Szórás) alapú dinamikus normalizálás.                |
//| 4. IFT aktiváció a tiszta -1..+1 jelhez.                         |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "3.00"
#property indicator_separate_window
#property indicator_buffers 5
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

input group "Sampling & Filtering"
input int      InpSampleTime     = 10;       // Mintavételezés (mp) [0 = Minden Tick]
input int      InpDemaPeriod     = 14;       // DEMA Periódus (Trend Filter)
input int      InpNormPeriod     = 20;       // Normalizálási Ablak (Z-Score)
input double   InpStDevScale     = 2.0;      // Szórás Skálázó (Sigma)

input group "Activation"
input double   InpIFTGain        = 1.5;      // IFT Erősítés (Gain)
input double   InpThreshold      = 0.8;      // Jelszint (Vizuális segéd)

input group "Colors"
input color    InpColorBuy       = clrLime;  // Vétel Szín
input color    InpColorSell      = clrRed;   // Eladás Szín
input color    InpColorNeutral   = clrGray;  // Semleges Szín

//==================================================================
// BUFFERS & GLOBALS
//==================================================================
double         Buf_Signal[];
double         Buf_SignalColors[];
double         Buf_Hist[];
double         Buf_HistColors[];

double         Buf_RawOsc[]; // Nyers Oszcillátor (Price - DEMA) tárolása a szóráshoz

int            hDEMA = INVALID_HANDLE;
datetime       LastSampleTime = 0; // Utolsó frissítés ideje (Live)

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- 1. Set Buffers
   SetIndexBuffer(0, Buf_Signal, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_SignalColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, Buf_Hist, INDICATOR_DATA);
   SetIndexBuffer(3, Buf_HistColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, Buf_RawOsc, INDICATOR_CALCULATIONS);

   //--- 2. Configure Plots
   // Signal Line
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid Signal");
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorNeutral);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorBuy);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorSell);

   // Histogram
   PlotIndexSetString(1, PLOT_LABEL, "Conviction");
   PlotIndexSetInteger(1, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, InpColorNeutral);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, InpColorBuy);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 2, InpColorSell);

   //--- 3. Levels
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.05);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.05);
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpThreshold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -InpThreshold);

   //--- 4. DEMA Handle
   hDEMA = iDEMA(NULL, PERIOD_CURRENT, InpDemaPeriod, 0, PRICE_CLOSE);
   if(hDEMA == INVALID_HANDLE) {
      Print("Hiba: DEMA Handle létrehozása sikertelen!");
      return(INIT_FAILED);
   }

   string name = StringFormat("HybridScalper_v3(T:%ds, D:%d, Z:%d)", InpSampleTime, InpDemaPeriod, InpNormPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hDEMA != INVALID_HANDLE) IndicatorRelease(hDEMA);
  }

//+------------------------------------------------------------------+
//| Helper: Inverse Fisher Transform                                 |
//+------------------------------------------------------------------+
double IFT(double x)
  {
   double e2x = MathExp(2.0 * x * InpIFTGain);
   if(DoubleToString(e2x) == "inf") return (x > 0) ? 1.0 : -1.0;
   return (e2x - 1.0) / (e2x + 1.0);
  }

//+------------------------------------------------------------------+
//| Helper: Calculate StdDev of a buffer                             |
//+------------------------------------------------------------------+
double CalcStdDev(const double &buffer[], int start_idx, int count)
  {
   if(start_idx < count) return 1.0; // Not enough data

   double sum = 0.0;
   double sum_sq = 0.0;

   for(int i = 0; i < count; i++) {
      double val = buffer[start_idx - i];
      sum += val;
      sum_sq += val * val;
   }

   double mean = sum / count;
   double variance = (sum_sq / count) - (mean * mean);

   if(variance <= 0) return 0.00001; // Avoid zero div
   return MathSqrt(variance);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
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
   if(rates_total < InpNormPeriod + InpDemaPeriod) return 0;

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   //--- Loop
   for(int i = start; i < rates_total; i++)
     {
      // --- SAMPLING LOGIC (Csak az aktuális bárnál) ---
      bool is_forming = (i == rates_total - 1);

      if(is_forming && InpSampleTime > 0) {
         datetime now = TimeCurrent();
         if(now - LastSampleTime < InpSampleTime) {
            // Még nem telt el a mintavételezési idő.
            // Nem frissítünk, KIVÉVE ha ez az első tick a bárban (pl. új gyertya)
            // Hogyan tudjuk? time[i] > LastBarTime?
            // Egyszerűbb: Hagyjuk a buffert a legutóbbi értéken.
            // De az MT5 újrahívja az OnCalculate-t.
            // Visszatérhetünk, de akkor a charton nem látszik semmi változás.
            // Ez a kívánt viselkedés ("Zajmentes").
            return prev_calculated;
         }
         // Frissítés engedélyezve
         LastSampleTime = now;
      }

      // 1. Get DEMA (Trend)
      double dema_val = 0.0;
      double dema_buf[1];

      // Mindig a legfrissebb DEMA értéket kérjük az adott indexre
      // Mivel iDEMA bar-alapú, az 'i' indexhez tartozó értéket adja.
      // Live bárnál ez a formálódó érték (tick-based).
      if(CopyBuffer(hDEMA, 0, rates_total - 1 - i, 1, dema_buf) > 0) {
         dema_val = dema_buf[0];
      }

      // 2. Raw Oscillator (Detrended Price)
      double price = close[i]; // Close ár (vagy Typical?)
      double raw = price - dema_val;

      Buf_RawOsc[i] = raw;

      // 3. Z-Score Normalization
      // Szórás számítása az elmúlt 'InpNormPeriod' alapján a 'Buf_RawOsc'-ból
      double sigma = CalcStdDev(Buf_RawOsc, i, InpNormPeriod);

      // Z-Score = Raw / (Sigma * Scale)
      // Ha Sigma nagyon kicsi (csend), növeljük a nevezőt, hogy ne legyen zaj?
      // Nem, a Bollinger elv: Ha Sigma kicsi, a sáv szűk. Kis mozgás is "kitörés".
      // Scalpernál ez jó!
      // Védelem: Ha Sigma 0 közeli, akkor zaj.
      if(sigma < _Point) sigma = _Point; // Minimum zajszint

      double z_score = raw / (sigma * InpStDevScale);

      // 4. IFT Activation
      double signal = IFT(z_score);

      Buf_Signal[i] = signal;
      Buf_Hist[i]   = signal; // Hisztogram ugyanaz, csak vizuális

      // 5. Colors (Logic)
      // 0=Neutral, 1=Buy, 2=Sell
      int color_idx = 0;
      if(signal > InpThreshold)       color_idx = 1; // Strong Buy
      else if(signal < -InpThreshold) color_idx = 2; // Strong Sell
      else                            color_idx = 0; // Neutral / Noise

      Buf_SignalColors[i] = color_idx;
      Buf_HistColors[i]   = color_idx;
     }

   return(rates_total);
  }
