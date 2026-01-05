//+------------------------------------------------------------------+
//|                                     Color_Reference_Table_v2.01.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.01"
#property description "Displays a table of MQL5 Web Colors for reference"
#property script_show_inputs

//--- Expanded Color Palette (100 Colors) - Matches Chart Designer EA v2.04
color PALETTE_COLORS[100] = {
   // Row 1: Grayscale (Dark to Light)
   C'0,0,0', C'10,10,10', C'20,20,20', C'30,30,30', C'40,40,40', C'60,60,60', clrDimGray, clrGray, clrSilver, clrWhite,
   // Row 2: Reds/Pinks (Bearish)
   C'40,0,0', clrMaroon, clrDarkRed, clrFireBrick, clrRed, clrCrimson, clrTomato, clrSalmon, clrHotPink, clrDeepPink,
   // Row 3: Greens (Bullish)
   C'0,40,0', clrDarkGreen, clrForestGreen, clrGreen, clrLimeGreen, clrLime, clrChartreuse, clrSpringGreen, clrSeaGreen, clrMediumSeaGreen,
   // Row 4: Blues (Dark to Light)
   C'0,0,40', clrMidnightBlue, clrNavy, clrDarkBlue, clrMediumBlue, clrBlue, clrRoyalBlue, clrDodgerBlue, clrDeepSkyBlue, clrCyan,
   // Row 5: Purples/Violets
   clrIndigo, clrPurple, clrDarkViolet, clrBlueViolet, clrDarkOrchid, clrMediumOrchid, clrMagenta, clrFuchsia, clrViolet, clrPlum,
   // Row 6: Yellows/Oranges
   clrSaddleBrown, clrSienna, clrChocolate, clrDarkOrange, clrOrangeRed, clrOrange, clrGold, clrYellow, clrKhaki, clrLemonChiffon,
   // Row 7: Teals/Cyans
   clrTeal, clrDarkCyan, clrLightSeaGreen, clrCadetBlue, clrDarkTurquoise, clrMediumTurquoise, clrTurquoise, clrAqua, clrAquamarine, clrPaleTurquoise,
   // Row 8: Browns/Beiges (Earth Tones)
   clrBrown, clrRosyBrown, clrIndianRed, clrSandyBrown, clrTan, clrBurlyWood, clrWheat, clrNavajoWhite, clrMoccasin, clrBisque,
   // Row 9: Dark "Pro" Background Candidates
   C'5,5,10', C'10,15,20', C'15,10,15', C'5,20,20', C'18,18,18', C'25,25,25', C'35,35,40', C'45,45,50', C'20,30,40', C'40,30,20',
   // Row 10: Special Markers
   clrAliceBlue, clrMintCream, clrHoneydew, clrIvory, clrBeige, clrLavender, clrLavenderBlush, clrMistyRose, clrSnow, clrGhostWhite
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart = ChartID();
   int subwin = 0;

   // Position: Center-Left to avoid overlap with EA panel on right
   int x_start = 20;
   int y_start = 40;
   int size_w = 40;
   int size_h = 20;
   int gap = 2;

   // Clear previous objects
   ObjectsDeleteAll(chart, subwin, 0, OBJ_RECTANGLE_LABEL);
   ObjectsDeleteAll(chart, subwin, 0, OBJ_LABEL);

   for(int i=0; i<100; i++) {
      int row = i / 10;
      int col = i % 10;

      int x = x_start + (col * (size_w + gap));
      int y = y_start + (row * (size_h + gap));

      string name_rect = "ColorRef_Rect_" + IntegerToString(i);

      // Create Rectangle
      ObjectCreate(chart, name_rect, OBJ_RECTANGLE_LABEL, subwin, 0, 0);
      ObjectSetInteger(chart, name_rect, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart, name_rect, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart, name_rect, OBJPROP_XSIZE, size_w);
      ObjectSetInteger(chart, name_rect, OBJPROP_YSIZE, size_h);
      ObjectSetInteger(chart, name_rect, OBJPROP_BGCOLOR, PALETTE_COLORS[i]);
      ObjectSetInteger(chart, name_rect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart, name_rect, OBJPROP_COLOR, clrWhite);
   }

   ChartRedraw(chart);
   Print("Color Reference Table (100 Colors) Drawn.");
  }
//+------------------------------------------------------------------+
