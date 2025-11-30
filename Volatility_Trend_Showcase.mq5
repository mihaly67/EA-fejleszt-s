//+------------------------------------------------------------------+
//|                                   Volatility_Trend_Showcase.mq5 |
//|                             Copyright 2024, Gemini & User Collaboration |
//|                                       Verzió: 1.0 (Concept 2)    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1

//--- Plot settings: Traffic Light Histogram
#property indicator_label1  "Trend Traffic Light"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input parameters
input int      InpMacdFast    = 12;
input int      InpMacdSlow    = 26;
input int      InpMacdSignal  = 9;
input int      InpBandsPeriod = 20;
input double   InpBandsDev    = 2.0;

//--- Indicator Buffers
double         HistBuffer[];
double         ColorBuffer[];
double         MacdBuffer[]; // Hidden calculation buffer
double         SignalBuffer[]; // Hidden calculation buffer

//--- Indicator Handles
int            hMACD;
int            hBands;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Indicator buffers mapping
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, MacdBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, SignalBuffer, INDICATOR_CALCULATIONS);

//--- Plot settings
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(0, PLOT_LABEL, "Volatility Trend");

//--- Create Indicator Handles
   hMACD = iMACD(_Symbol, _Period, InpMacdFast, InpMacdSlow, InpMacdSignal, PRICE_CLOSE);

   if(hMACD == INVALID_HANDLE)
     {
      Print("Error creating MACD handle!");
      return(INIT_FAILED);
     }

   // Create Bollinger Bands ON the MACD indicator handle
   // Note: iBands applied to a handle uses the 0-th buffer of that indicator (MACD Main Line)
   hBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, hMACD);

   if(hBands == INVALID_HANDLE)
     {
      Print("Error creating Bands on MACD handle!");
      return(INIT_FAILED);
     }

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
   int start;
   if(prev_calculated == 0) start = 0;
   else start = prev_calculated - 1;

   int to_copy = rates_total - start;
   if (to_copy <= 0) return prev_calculated;

   // Source Data Buffers
   double macd_main[], macd_sig[];
   double band_upper[], band_lower[], band_mid[]; // Mid unused but needed for copy

   // Copy MACD Data
   if(CopyBuffer(hMACD, 0, 0, to_copy, macd_main) < to_copy) return 0;
   // We only need Main for the bands logic, but Signal is good for extra logic if needed later

   // Copy Bands Data (Calculated on MACD)
   if(CopyBuffer(hBands, 1, 0, to_copy, band_upper) < to_copy) return 0; // Buffer 1 is UPPER
   if(CopyBuffer(hBands, 2, 0, to_copy, band_lower) < to_copy) return 0; // Buffer 2 is LOWER

   // Main Loop
   for(int i = 0; i < to_copy; i++)
     {
      int idx = start + i;

      double m_val = macd_main[i];
      double upper = band_upper[i];
      double lower = band_lower[i];

      // Histogram Value is simply the MACD value itself, but colored
      HistBuffer[idx] = m_val;

      // Logic:
      // Breakout ABOVE Upper Band -> Bullish (Lime)
      // Breakout BELOW Lower Band -> Bearish (Red)
      // Inside Bands -> Noise (Gray)

      if (m_val > upper)
         ColorBuffer[idx] = 1.0; // Lime
      else if (m_val < lower)
         ColorBuffer[idx] = 2.0; // Red
      else
         ColorBuffer[idx] = 0.0; // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hMACD);
   IndicatorRelease(hBands);
  }
//+------------------------------------------------------------------+
