//+------------------------------------------------------------------+
//|                                           Lag_Comparator.mq5 |
//|                                               Jules Assistant|
//|                                     Lag Analysis & Comparison|
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property link      "https://github.com/mihaly67/EA-fejleszt-s"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot settings
#property indicator_label1  "Kalman (Opt)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "ALMA (ZeroLag)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "DEMA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "Jurik (Sim)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Inputs
input int      InpPeriod      = 14;    // Common Period
input double   InpALMAOffset  = 0.95;  // ALMA Offset (0.85-1.0 for ZeroLag)
input double   InpALMASigma   = 6.0;   // ALMA Sigma
input double   InpKalmanQ     = 0.01;  // Kalman Process Noise (Sensitivity)

//--- Buffers
double         Buf_Kalman[];
double         Buf_ALMA[];
double         Buf_DEMA[];
double         Buf_Jurik[];

//--- Global Variables for Kalman
double k_x = 0; // State estimate
double k_p = 1; // Error covariance

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, Buf_Kalman, INDICATOR_DATA);
   SetIndexBuffer(1, Buf_ALMA, INDICATOR_DATA);
   SetIndexBuffer(2, Buf_DEMA, INDICATOR_DATA);
   SetIndexBuffer(3, Buf_Jurik, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Lag Comparator");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: ALMA Calculation                                         |
//+------------------------------------------------------------------+
double CalculateALMA(const double &price[], int index, int period, double sigma, double offset)
  {
   double m = offset * (period - 1);
   double s = period / sigma;
   double sum = 0;
   double w_sum = 0;

   for(int i = 0; i < period; i++)
     {
      if(index - i < 0) break;
      double w = MathExp(-((i - m) * (i - m)) / (2 * s * s));
      sum += price[index - i] * w;
      w_sum += w;
     }
   return (w_sum != 0) ? sum / w_sum : price[index];
  }

//+------------------------------------------------------------------+
//| Helper: Simple Kalman Step                                       |
//+------------------------------------------------------------------+
double CalculateKalman(double price)
  {
   // Prediction
   // x_pred = x (assume constant model)
   // p_pred = p + Q
   double p_pred = k_p + InpKalmanQ;

   // Update
   // K = p_pred / (p_pred + R)  (assume R=1 measurement noise)
   double K = p_pred / (p_pred + 1.0);

   k_x = k_x + K * (price - k_x);
   k_p = (1 - K) * p_pred;

   return k_x;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Iteration                                       |
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
   int start = prev_calculated - 1;
   if(start < InpPeriod) start = InpPeriod;

   // Initialize Kalman state if needed
   if(prev_calculated == 0) {
      k_x = close[0];
      k_p = 1.0;
      start = 0;
   }

   for(int i = start; i < rates_total; i++)
     {
      // 1. ALMA
      Buf_ALMA[i] = CalculateALMA(close, i, InpPeriod, InpALMASigma, InpALMAOffset);

      // 2. Kalman (Running)
      // Note: Kalman is recursive, must run from start linearly.
      // If i jumps (history update), we might need to reset.
      // For this indicator, we assume sequential access.
      Buf_Kalman[i] = CalculateKalman(close[i]);

      // 3. DEMA
      // EMA1 = EMA(Price)
      // EMA2 = EMA(EMA1)
      // DEMA = 2*EMA1 - EMA2
      // Simple approximation for loop:
      // (Proper implementation needs full buffers, simplified here for comparative visual)
      // We'll use iMA for accuracy in comparison if handles were used, but for raw logic:
      double alpha = 2.0 / (InpPeriod + 1);
      static double ema1=0, ema2=0;
      if(i==0) { ema1=close[i]; ema2=close[i]; }

      ema1 = alpha * close[i] + (1-alpha) * ema1;
      ema2 = alpha * ema1 + (1-alpha) * ema2;
      Buf_DEMA[i] = 2 * ema1 - ema2;

      // 4. Jurik Simulator (JMA-like behavior: Adaptive)
      // Simplified: changes alpha based on volatility
      double vol = MathAbs(close[i] - close[i-1]);
      double j_alpha = alpha * (1 + vol*100); // More vol = faster
      if(j_alpha > 1) j_alpha = 1;
      static double jma = 0;
      if(i==0) jma = close[i];
      jma = j_alpha * close[i] + (1-j_alpha) * jma;
      Buf_Jurik[i] = jma;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
