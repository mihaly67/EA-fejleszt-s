//+------------------------------------------------------------------+
//|                                     Configure_Chart_Template.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters
input color InpBackColor = C'20,20,20';    // Background Color (Very Dark Gray)
input color InpGridColor = clrDimGray;     // Grid Color
input color InpBullColor = clrForestGreen; // Bull Candle Body (Forest Green)
input color InpBearColor = clrFireBrick;   // Bear Candle Body (Fire Brick)
input color InpUpColor   = clrForestGreen; // Bull Wick/Border
input color InpDownColor = clrFireBrick;   // Bear Wick/Border
input color InpTextColor = clrWhite;       // Text/Axis Color

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart_id = ChartID();

   //--- 1. Set Chart Mode to Candles
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);

   //--- 2. Set Colors
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

   //--- 3. Optional: Clean up visual noise
   ChartSetInteger(chart_id, CHART_SHOW_GRID, true);
   ChartSetInteger(chart_id, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(chart_id, CHART_SHOW_ASK_LINE, true);
   ChartSetInteger(chart_id, CHART_SHOW_BID_LINE, true);

   ChartRedraw(chart_id);

   //--- 4. Save as 'default.tpl'
   // This ensures that any NEW chart opened will inherit these settings.
   if(ChartSaveTemplate(chart_id, "default.tpl"))
     {
      Print("✅ Success: 'default.tpl' saved. New charts will use this theme.");
      Comment("Chart colors updated and saved as default.tpl");
     }
   else
     {
      Print("❌ Error: Failed to save 'default.tpl'. Error code: ", GetLastError());
      Comment("Error saving template!");
     }
  }
//+------------------------------------------------------------------+
