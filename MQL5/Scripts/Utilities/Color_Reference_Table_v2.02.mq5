//+------------------------------------------------------------------+
//|                                     Color_Reference_Table_v2.02.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.02"
#property description "Displays ALL Standard MQL5 Web Colors with Names and Hex Codes"
#property script_show_inputs

//--- Input Parameters
input int InpColumns = 8; // Number of columns
input int InpCellWidth = 150;
input int InpCellHeight = 40;
input int InpFontSize = 8;
input color InpTextColor = clrWhite;

//--- Arrays for Color Data
color ColorValues[] = {
   clrAliceBlue, clrAntiqueWhite, clrAqua, clrAquamarine, clrAzure,
   clrBeige, clrBisque, clrBlack, clrBlanchedAlmond, clrBlue,
   clrBlueViolet, clrBrown, clrBurlyWood, clrCadetBlue, clrChartreuse,
   clrChocolate, clrCoral, clrCornflowerBlue, clrCornsilk, clrCrimson,
   clrCyan, clrDarkBlue, clrDarkCyan, clrDarkGoldenrod, clrDarkGray,
   clrDarkGreen, clrDarkKhaki, clrDarkMagenta, clrDarkOliveGreen, clrDarkOrange,
   clrDarkOrchid, clrDarkRed, clrDarkSalmon, clrDarkSeaGreen, clrDarkSlateBlue,
   clrDarkSlateGray, clrDarkTurquoise, clrDarkViolet, clrDeepPink, clrDeepSkyBlue,
   clrDimGray, clrDodgerBlue, clrFireBrick, clrFloralWhite, clrForestGreen,
   clrFuchsia, clrGainsboro, clrGhostWhite, clrGold, clrGoldenrod,
   clrGray, clrGreen, clrGreenYellow, clrHoneydew, clrHotPink,
   clrIndianRed, clrIndigo, clrIvory, clrKhaki, clrLavender,
   clrLavenderBlush, clrLawnGreen, clrLemonChiffon, clrLightBlue, clrLightCoral,
   clrLightCyan, clrLightGoldenrod, clrLightGray, clrLightGreen, clrLightPink,
   clrLightSalmon, clrLightSeaGreen, clrLightSkyBlue, clrLightSlateGray, clrLightSteelBlue,
   clrLightYellow, clrLime, clrLimeGreen, clrLinen, clrMagenta,
   clrMaroon, clrMediumAquamarine, clrMediumBlue, clrMediumOrchid, clrMediumPurple,
   clrMediumSeaGreen, clrMediumSlateBlue, clrMediumSpringGreen, clrMediumTurquoise, clrMediumVioletRed,
   clrMidnightBlue, clrMintCream, clrMistyRose, clrMoccasin, clrNavajoWhite,
   clrNavy, clrOldLace, clrOlive, clrOliveDrab, clrOrange,
   clrOrangeRed, clrOrchid, clrPaleGoldenrod, clrPaleGreen, clrPaleTurquoise,
   clrPaleVioletRed, clrPapayaWhip, clrPeachPuff, clrPeru, clrPink,
   clrPlum, clrPowderBlue, clrPurple, clrRed, clrRosyBrown,
   clrRoyalBlue, clrSaddleBrown, clrSalmon, clrSandyBrown, clrSeaGreen,
   clrSeashell, clrSienna, clrSilver, clrSkyBlue, clrSlateBlue,
   clrSlateGray, clrSnow, clrSpringGreen, clrSteelBlue, clrTan,
   clrTeal, clrThistle, clrTomato, clrTurquoise, clrViolet,
   clrWheat, clrWhite, clrWhiteSmoke, clrYellow, clrYellowGreen,
   // Custom Dark Shades
   C'10,10,10', C'20,20,20', C'30,30,30'
};

string ColorNames[] = {
   "AliceBlue", "AntiqueWhite", "Aqua", "Aquamarine", "Azure",
   "Beige", "Bisque", "Black", "BlanchedAlmond", "Blue",
   "BlueViolet", "Brown", "BurlyWood", "CadetBlue", "Chartreuse",
   "Chocolate", "Coral", "CornflowerBlue", "Cornsilk", "Crimson",
   "Cyan", "DarkBlue", "DarkCyan", "DarkGoldenrod", "DarkGray",
   "DarkGreen", "DarkKhaki", "DarkMagenta", "DarkOliveGreen", "DarkOrange",
   "DarkOrchid", "DarkRed", "DarkSalmon", "DarkSeaGreen", "DarkSlateBlue",
   "DarkSlateGray", "DarkTurquoise", "DarkViolet", "DeepPink", "DeepSkyBlue",
   "DimGray", "DodgerBlue", "FireBrick", "FloralWhite", "ForestGreen",
   "Fuchsia", "Gainsboro", "GhostWhite", "Gold", "Goldenrod",
   "Gray", "Green", "GreenYellow", "Honeydew", "HotPink",
   "IndianRed", "Indigo", "Ivory", "Khaki", "Lavender",
   "LavenderBlush", "LawnGreen", "LemonChiffon", "LightBlue", "LightCoral",
   "LightCyan", "LightGoldenrod", "LightGray", "LightGreen", "LightPink",
   "LightSalmon", "LightSeaGreen", "LightSkyBlue", "LightSlateGray", "LightSteelBlue",
   "LightYellow", "Lime", "LimeGreen", "Linen", "Magenta",
   "Maroon", "MediumAquamarine", "MediumBlue", "MediumOrchid", "MediumPurple",
   "MediumSeaGreen", "MediumSlateBlue", "MediumSpringGreen", "MediumTurquoise", "MediumVioletRed",
   "MidnightBlue", "MintCream", "MistyRose", "Moccasin", "NavajoWhite",
   "Navy", "OldLace", "Olive", "OliveDrab", "Orange",
   "OrangeRed", "Orchid", "PaleGoldenrod", "PaleGreen", "PaleTurquoise",
   "PaleVioletRed", "PapayaWhip", "PeachPuff", "Peru", "Pink",
   "Plum", "PowderBlue", "Purple", "Red", "RosyBrown",
   "RoyalBlue", "SaddleBrown", "Salmon", "SandyBrown", "SeaGreen",
   "Seashell", "Sienna", "Silver", "SkyBlue", "SlateBlue",
   "SlateGray", "Snow", "SpringGreen", "SteelBlue", "Tan",
   "Teal", "Thistle", "Tomato", "Turquoise", "Violet",
   "Wheat", "White", "WhiteSmoke", "Yellow", "YellowGreen",
   "Custom Dark 10", "Custom Dark 20", "Custom Dark 30"
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart = ChartID();
   int subwin = 0;

   // Clean up old objects
   ObjectsDeleteAll(chart, subwin, 0, OBJ_RECTANGLE_LABEL);
   ObjectsDeleteAll(chart, subwin, 0, OBJ_LABEL);

   int total_colors = ArraySize(ColorValues);

   int x_base = 20;
   int y_base = 30;
   int gap = 2;

   Print("Drawing ", total_colors, " colors...");

   for(int i=0; i<total_colors; i++) {
      int row = i / InpColumns;
      int col = i % InpColumns;

      int x = x_base + (col * (InpCellWidth + gap));
      int y = y_base + (row * (InpCellHeight + gap));

      string name_rect = "CR_Rect_" + IntegerToString(i);
      string name_lbl  = "CR_Lbl_" + IntegerToString(i);

      // 1. Color Rectangle (Left Side of Cell)
      if(!ObjectCreate(chart, name_rect, OBJ_RECTANGLE_LABEL, subwin, 0, 0)) continue;
      ObjectSetInteger(chart, name_rect, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart, name_rect, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart, name_rect, OBJPROP_XSIZE, 40); // Color swatch width
      ObjectSetInteger(chart, name_rect, OBJPROP_YSIZE, InpCellHeight);
      ObjectSetInteger(chart, name_rect, OBJPROP_BGCOLOR, ColorValues[i]);
      ObjectSetInteger(chart, name_rect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart, name_rect, OBJPROP_COLOR, clrNONE);
      ObjectSetInteger(chart, name_rect, OBJPROP_CORNER, CORNER_LEFT_UPPER);

      // 2. Text Label (Right Side of Cell)
      if(!ObjectCreate(chart, name_lbl, OBJ_LABEL, subwin, 0, 0)) continue;
      ObjectSetInteger(chart, name_lbl, OBJPROP_XDISTANCE, x + 45); // Offset text
      ObjectSetInteger(chart, name_lbl, OBJPROP_YDISTANCE, y + 10);
      ObjectSetInteger(chart, name_lbl, OBJPROP_COLOR, InpTextColor);
      ObjectSetInteger(chart, name_lbl, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetInteger(chart, name_lbl, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(chart, name_lbl, OBJPROP_TEXT, ColorNames[i]);
      // Optional: Add Hex code to tooltip or description
      ObjectSetString(chart, name_lbl, OBJPROP_TOOLTIP, ColorToHex(ColorValues[i]));
   }

   ChartRedraw(chart);
   Print("Done. Table created.");
  }

//+------------------------------------------------------------------+
//| Helper: Convert Color to Hex String (e.g. 0xFF0000)              |
//+------------------------------------------------------------------+
string ColorToHex(color c)
{
   // MQL5 color is integer 0xBBGGRR
   int r = c & 0xFF;
   int g = (c >> 8) & 0xFF;
   int b = (c >> 16) & 0xFF;

   return StringFormat("R:%d G:%d B:%d", r, g, b);
}
//+------------------------------------------------------------------+
