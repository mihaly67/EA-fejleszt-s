//+------------------------------------------------------------------+
//|                                     Configure_Chart_Template.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.10"
#property script_show_inputs

//--- 1. COLORS (Színek)
input color InpBackColor = C'20,20,20';    // Background Color (Very Dark Gray)
input color InpGridColor = clrDimGray;     // Grid Color
input color InpBullColor = clrForestGreen; // Bull Candle Body (Forest Green)
input color InpBearColor = clrFireBrick;   // Bear Candle Body (Fire Brick)
input color InpUpColor   = clrForestGreen; // Bull Wick/Border
input color InpDownColor = clrFireBrick;   // Bear Wick/Border
input color InpTextColor = clrWhite;       // Text/Axis Color

//--- 2. VISIBILITY (Láthatóság)
input bool InpShowGrid      = false; // Show Grid (Rács mutatása)
input bool InpShowPeriodSep = true;  // Show Period Separators (Napelválasztók)
input bool InpShowAskLine   = true;  // Show Ask Line (Ask vonal)
input bool InpShowBidLine   = true;  // Show Bid Line (Bid vonal)
input bool InpShowOHLC      = true;  // Show OHLC Info (Bal felső infó)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart_id = ChartID();

   //--- A. Set Chart Mode to Candles
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);

   //--- B. Set Colors
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, InpBackColor);
   ChartSetInteger(chart_id, CHART_COLOR_GRID, InpGridColor);
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, InpTextColor);

   // Bullish settings
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, InpBullColor); // Body
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, InpUpColor);      // Wick/Outline

   // Bearish settings
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, InpBearColor); // Body
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, InpDownColor);  // Wick/Outline

   // Line Graph Color (Fallback)
   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, clrSilver);

   //--- C. Visibility Settings (Finomhangolás)
   ChartSetInteger(chart_id, CHART_SHOW_GRID, InpShowGrid);
   ChartSetInteger(chart_id, CHART_SHOW_PERIOD_SEP, InpShowPeriodSep);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, InpShowAskLine);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, InpShowBidLine);
   ChartSetInteger(chart_id, CHART_SHOW_OHLC, InpShowOHLC);

   ChartRedraw(chart_id);

   //--- D. Save as 'default.tpl'
   // This ensures that any NEW chart opened will inherit these settings.
   if(ChartSaveTemplate(chart_id, "default.tpl"))
     {
      Print("✅ Success: 'default.tpl' saved. New charts will use this theme.");
      Comment("Chart colors & settings updated and saved as default.tpl");
     }
   else
     {
      Print("❌ Error: Failed to save 'default.tpl'. Error code: ", GetLastError());
      Comment("Error saving template!");
     }
  }
//+------------------------------------------------------------------+
