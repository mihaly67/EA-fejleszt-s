//+------------------------------------------------------------------+
//|                                           Quick_Setup_Script.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.00"
#property description "Instantly applies chart colors and saves as default.tpl"
#property script_show_inputs

//--- Input Parameters
input group "Color Settings"
input color InpBgColor        = C'20,20,20'; // Background Color
input color InpGridColor      = clrDimGray;  // Grid Color (if visible)
input color InpBullColor      = clrForestGreen; // Bull Candle/Bar Color
input color InpBearColor      = clrFireBrick;   // Bear Candle/Bar Color
input color InpLineColor      = clrSilver;   // Line Chart Color
input color InpTextColor      = clrWhite;    // Axis Text Color

input group "Visual Settings"
input bool  InpShowGrid       = false;       // Show Grid
input bool  InpShowPeriodSep  = true;        // Show Period Separators
input bool  InpShowOHLC       = false;       // Show OHLC Dashboard
input bool  InpShowBidAsk     = true;        // Show Bid/Ask Lines
input bool  InpCandleFilled   = true;        // Solid Candle Bodies

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart_id = ChartID();

   // 1. Apply Colors
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, InpBgColor);
   ChartSetInteger(chart_id, CHART_COLOR_GRID, InpGridColor);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, InpTextColor); // Text & Frame

   // Candle Colors (Body)
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, InpBullColor);
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, InpBearColor);

   // Bar/Wick Colors (Outline)
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, InpBullColor);   // Up Bar/Wick
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, InpBearColor); // Down Bar/Wick
   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, InpLineColor); // Line Chart

   // 2. Apply Visual Toggles
   ChartSetInteger(chart_id, CHART_SHOW_GRID, InpShowGrid);
   ChartSetInteger(chart_id, CHART_SHOW_PERIOD_SEPARATORS, InpShowPeriodSep);
   ChartSetInteger(chart_id, CHART_SHOW_OHLC, InpShowOHLC);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, InpShowBidAsk);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, InpShowBidAsk);

   // Mode: Candles
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);

   // 3. Force Redraw
   ChartRedraw(chart_id);

   Print("Visual settings applied to Chart ID: ", chart_id);

   // 4. Auto-Save as Default Template
   if(ChartSaveTemplate(0, "default.tpl"))
     {
      Print("Successfully saved 'default.tpl'. New charts will use this theme.");
      MessageBox("Settings applied and saved as default.tpl!", "Quick Setup", MB_OK);
     }
   else
     {
      Print("Error saving template: ", GetLastError());
      MessageBox("Error saving default.tpl!", "Error", MB_ICONERROR);
     }
  }
//+------------------------------------------------------------------+
