//+------------------------------------------------------------------+
//|                                           Quick_Setup_Script.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.04"
#property description "Instantly applies chart colors and saves as default.tpl"
#property script_show_inputs

// Include Standard Library to ensure all constants are defined
#include <Controls\Dialog.mqh>

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
input bool  InpShowOHLC       = true;        // Show OHLC Dashboard (Restored)
input bool  InpShowBidAsk     = true;        // Show Bid/Ask Lines
input bool  InpCandleFilled   = true;        // Solid Candle Bodies

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart = ChartID();

   // 1. Apply Colors
   ChartSetInteger(chart, CHART_COLOR_BACKGROUND, InpBgColor);
   ChartSetInteger(chart, CHART_COLOR_GRID, InpGridColor);
   ChartSetInteger(chart, CHART_COLOR_FOREGROUND, InpTextColor);

   // Candle Colors (Body)
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, InpBullColor);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, InpBearColor);

   // Bar/Wick Colors (Outline)
   ChartSetInteger(chart, CHART_COLOR_CHART_UP, InpBullColor);
   ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, InpBearColor);
   ChartSetInteger(chart, CHART_COLOR_CHART_LINE, InpLineColor);

   // 2. Apply Visual Toggles
   ChartSetInteger(chart, CHART_SHOW_GRID, (long)InpShowGrid);

   // FIXED: Correct constant name is CHART_SHOW_PERIOD_SEP
   ChartSetInteger(chart, CHART_SHOW_PERIOD_SEP, (long)InpShowPeriodSep);

   // Restored OHLC property with explicit cast
   ChartSetInteger(chart, CHART_SHOW_OHLC, (long)InpShowOHLC);

   ChartSetInteger(chart, CHART_SHOW_BID_LINE, (long)InpShowBidAsk);
   ChartSetInteger(chart, CHART_SHOW_ASK_LINE, (long)InpShowBidAsk);

   // Mode: Candles
   ChartSetInteger(chart, CHART_MODE, CHART_CANDLES);

   // 3. Force Redraw
   ChartRedraw(chart);

   Print("Visual settings applied to Chart ID: ", chart);

   // 4. Auto-Save as Default Template
   if(ChartSaveTemplate(0, "default.tpl"))
     {
      Print("Successfully saved 'default.tpl'.");
      MessageBox("Settings applied and saved as default.tpl!", "Quick Setup", MB_OK);
     }
   else
     {
      Print("Error saving template: ", GetLastError());
      MessageBox("Error saving default.tpl!", "Error", MB_ICONERROR);
     }
  }
//+------------------------------------------------------------------+
