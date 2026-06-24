//+------------------------------------------------------------------+
//|                                     Configure_Chart_Template.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.20"
#property script_show_inputs

//--- 1. COLORS (Input Parameters for Native Color Picker)
input group "--- Chart Colors ---"
input color InpBackColor      = C'20,20,20';    // Background Color
input color InpGridColor      = clrDimGray;     // Grid Color
input color InpBullBodyColor  = clrForestGreen; // Bull Candle Body
input color InpBearBodyColor  = clrFireBrick;   // Bear Candle Body
input color InpBullWickColor  = clrForestGreen; // Bull Candle Wick
input color InpBearWickColor  = clrFireBrick;   // Bear Candle Wick
input color InpTextColor      = clrWhite;       // Text / Axis Color
input color InpAskLineColor   = clrRed;         // Ask Line Color
input color InpBidLineColor   = clrBlue;        // Bid Line Color

//--- 2. VISIBILITY (Toggle Features)
input group "--- Visibility Settings ---"
input bool  InpShowGrid       = false;          // Show Grid
input bool  InpShowPeriodSep  = true;           // Show Period Separators
input bool  InpShowAskLine    = true;           // Show Ask Line
input bool  InpShowBidLine    = true;           // Show Bid Line
input bool  InpShowOHLC       = true;           // Show OHLC (Top Left)
input bool  InpShowVolume     = false;          // Show Real Volume

//--- 3. PERSISTENCE
input group "--- Save Options ---"
input bool  InpSaveAsDefault  = true;           // Save as 'default.tpl' (Apply to new charts)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // DEBUG: Show message to confirm inputs were received (if needed)
   // MessageBox("Applying settings...", "Debug", MB_OK);

   long chart_id = ChartID();

   //--- A. Set Chart Mode to Candles (Standard)
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);

   //--- B. Apply Colors
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, InpBackColor);
   ChartSetInteger(chart_id, CHART_COLOR_GRID, InpGridColor);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, InpTextColor);

   // Bullish
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, InpBullBodyColor);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, InpBullWickColor);

   // Bearish
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, InpBearBodyColor);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, InpBearWickColor);

   // Lines
   ChartSetInteger(chart_id, CHART_COLOR_ASK, InpAskLineColor);
   ChartSetInteger(chart_id, CHART_COLOR_BID, InpBidLineColor);
   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, clrSilver); // Fallback for line chart

   //--- C. Apply Visibility
   ChartSetInteger(chart_id, CHART_SHOW_GRID, (long)InpShowGrid);
   ChartSetInteger(chart_id, CHART_SHOW_PERIOD_SEP, (long)InpShowPeriodSep);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, (long)InpShowAskLine);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, (long)InpShowBidLine);
   ChartSetInteger(chart_id, CHART_SHOW_OHLC, (long)InpShowOHLC);
   ChartSetInteger(chart_id, CHART_SHOW_VOLUMES, (long)(InpShowVolume ? CHART_VOLUME_REAL : CHART_VOLUME_HIDE));

   //--- D. Force Redraw
   ChartRedraw(chart_id);

   //--- E. Save Template
   if(InpSaveAsDefault)
     {
      if(ChartSaveTemplate(chart_id, "default.tpl"))
        {
         Print("✅ Success: Settings applied and saved as 'default.tpl'.");
         MessageBox("Chart configured and saved as Default Template.", "Success", MB_OK);
        }
      else
        {
         Print("❌ Error: Failed to save 'default.tpl'. Error code: ", GetLastError());
         MessageBox("Settings applied, but could not save template.", "Warning", MB_ICONWARNING);
        }
     }
   else
     {
      Print("✅ Success: Settings applied to current chart (not saved as default).");
     }
  }
//+------------------------------------------------------------------+
