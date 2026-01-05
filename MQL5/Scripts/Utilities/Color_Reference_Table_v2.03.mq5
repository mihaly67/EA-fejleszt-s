//+------------------------------------------------------------------+
//|                                     Color_Reference_Table_v2.03.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.03"
#property description "Displays Standard MQL5 Web Colors Organized by Group"
#property script_show_inputs

//--- Input Parameters
input int InpColumns = 6; // Adjusted for better grouping width
input int InpCellWidth = 160;
input int InpCellHeight = 35;
input int InpFontSize = 8;
input color InpTextColor = clrWhite;

//--- Helper Structure
struct ColorItem {
   color col;
   string name;
   string group;
};

//--- Color Database (Grouped)
// We will populate this in OnStart to allow easier grouping logic
ColorItem Colors[];

//+------------------------------------------------------------------+
//| Helper to Add Color                                              |
//+------------------------------------------------------------------+
void AddColor(color c, string n, string g) {
   int s = ArraySize(Colors);
   ArrayResize(Colors, s + 1);
   Colors[s].col = c;
   Colors[s].name = n;
   Colors[s].group = g;
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // --- 1. Populate Database (Grouped Logic) ---

   // Grays / Black / White
   AddColor(clrBlack, "Black", "Grays");
   AddColor(C'10,10,10', "Dark 10", "Grays"); // Custom
   AddColor(C'20,20,20', "Dark 20", "Grays"); // Custom
   AddColor(clrDimGray, "DimGray", "Grays");
   AddColor(clrGray, "Gray", "Grays");
   AddColor(clrDarkGray, "DarkGray", "Grays");
   AddColor(clrSilver, "Silver", "Grays");
   AddColor(clrLightGray, "LightGray", "Grays");
   AddColor(clrGainsboro, "Gainsboro", "Grays");
   AddColor(clrWhiteSmoke, "WhiteSmoke", "Grays");
   AddColor(clrWhite, "White", "Grays");
   AddColor(clrSnow, "Snow", "Grays");
   AddColor(clrGhostWhite, "GhostWhite", "Grays");
   AddColor(clrFloralWhite, "FloralWhite", "Grays");
   AddColor(clrLinen, "Linen", "Grays");
   AddColor(clrAntiqueWhite, "AntiqueWhite", "Grays");
   AddColor(clrPapayaWhip, "PapayaWhip", "Grays");
   AddColor(clrBlanchedAlmond, "BlanchedAlmond", "Grays");
   AddColor(clrBisque, "Bisque", "Grays");
   AddColor(clrMoccasin, "Moccasin", "Grays");
   AddColor(clrNavajoWhite, "NavajoWhite", "Grays");

   // Reds / Pinks / Browns
   AddColor(clrMaroon, "Maroon", "Reds");
   AddColor(clrDarkRed, "DarkRed", "Reds");
   AddColor(clrBrown, "Brown", "Reds");
   AddColor(clrFireBrick, "FireBrick", "Reds");
   AddColor(clrCrimson, "Crimson", "Reds");
   AddColor(clrRed, "Red", "Reds");
   AddColor(clrTomato, "Tomato", "Reds");
   AddColor(clrCoral, "Coral", "Reds");
   AddColor(clrIndianRed, "IndianRed", "Reds");
   AddColor(clrLightCoral, "LightCoral", "Reds");
   AddColor(clrDarkSalmon, "DarkSalmon", "Reds");
   AddColor(clrSalmon, "Salmon", "Reds");
   AddColor(clrLightSalmon, "LightSalmon", "Reds");
   AddColor(clrOrangeRed, "OrangeRed", "Reds");
   AddColor(clrDarkOrange, "DarkOrange", "Reds");
   AddColor(clrOrange, "Orange", "Reds");
   AddColor(clrGold, "Gold", "Reds");
   AddColor(clrDarkGoldenrod, "DarkGoldenrod", "Reds");
   AddColor(clrGoldenrod, "Goldenrod", "Reds");
   AddColor(clrPaleGoldenrod, "PaleGoldenrod", "Reds");
   AddColor(clrKhaki, "Khaki", "Reds");
   AddColor(clrDarkKhaki, "DarkKhaki", "Reds");
   AddColor(clrChocolate, "Chocolate", "Reds");
   AddColor(clrSaddleBrown, "SaddleBrown", "Reds");
   AddColor(clrSienna, "Sienna", "Reds");
   AddColor(clrPeru, "Peru", "Reds");
   AddColor(clrRosyBrown, "RosyBrown", "Reds");
   AddColor(clrSandyBrown, "SandyBrown", "Reds");
   AddColor(clrTan, "Tan", "Reds");
   AddColor(clrBurlyWood, "BurlyWood", "Reds");
   AddColor(clrWheat, "Wheat", "Reds");
   AddColor(clrPeachPuff, "PeachPuff", "Reds");

   AddColor(clrDeepPink, "DeepPink", "Pinks");
   AddColor(clrFuchsia, "Fuchsia", "Pinks");
   AddColor(clrMagenta, "Magenta", "Pinks");
   AddColor(clrHotPink, "HotPink", "Pinks");
   AddColor(clrPaleVioletRed, "PaleVioletRed", "Pinks");
   AddColor(clrPink, "Pink", "Pinks");
   AddColor(clrLightPink, "LightPink", "Pinks");
   AddColor(clrThistle, "Thistle", "Pinks");
   AddColor(clrPlum, "Plum", "Pinks");
   AddColor(clrViolet, "Violet", "Pinks");
   AddColor(clrOrchid, "Orchid", "Pinks");
   AddColor(clrMediumOrchid, "MediumOrchid", "Pinks");
   AddColor(clrDarkOrchid, "DarkOrchid", "Pinks");
   AddColor(clrDarkViolet, "DarkViolet", "Pinks");
   AddColor(clrBlueViolet, "BlueViolet", "Pinks");
   AddColor(clrPurple, "Purple", "Pinks");
   AddColor(clrMediumPurple, "MediumPurple", "Pinks");
   AddColor(clrMediumSlateBlue, "MediumSlateBlue", "Pinks");
   AddColor(clrSlateBlue, "SlateBlue", "Pinks");
   AddColor(clrDarkSlateBlue, "DarkSlateBlue", "Pinks");
   AddColor(clrIndigo, "Indigo", "Pinks");

   // Greens
   AddColor(clrDarkGreen, "DarkGreen", "Greens");
   AddColor(clrGreen, "Green", "Greens");
   AddColor(clrForestGreen, "ForestGreen", "Greens");
   AddColor(clrSeaGreen, "SeaGreen", "Greens");
   AddColor(clrMediumSeaGreen, "MediumSeaGreen", "Greens");
   AddColor(clrDarkSeaGreen, "DarkSeaGreen", "Greens");
   AddColor(clrLightSeaGreen, "LightSeaGreen", "Greens");
   AddColor(clrPaleGreen, "PaleGreen", "Greens");
   AddColor(clrSpringGreen, "SpringGreen", "Greens");
   AddColor(clrMediumSpringGreen, "MediumSpringGreen", "Greens");
   AddColor(clrLawnGreen, "LawnGreen", "Greens");
   AddColor(clrChartreuse, "Chartreuse", "Greens");
   AddColor(clrLime, "Lime", "Greens");
   AddColor(clrLimeGreen, "LimeGreen", "Greens");
   AddColor(clrYellowGreen, "YellowGreen", "Greens");
   AddColor(clrDarkOliveGreen, "DarkOliveGreen", "Greens");
   AddColor(clrOlive, "Olive", "Greens");
   AddColor(clrOliveDrab, "OliveDrab", "Greens");
   AddColor(clrTeal, "Teal", "Greens");
   AddColor(clrDarkCyan, "DarkCyan", "Greens");
   AddColor(clrLightCyan, "LightCyan", "Greens");
   AddColor(clrCyan, "Cyan", "Greens");
   AddColor(clrAqua, "Aqua", "Greens");
   AddColor(clrAquamarine, "Aquamarine", "Greens");
   AddColor(clrMediumAquamarine, "MediumAquamarine", "Greens");
   AddColor(clrPaleTurquoise, "PaleTurquoise", "Greens");
   AddColor(clrTurquoise, "Turquoise", "Greens");
   AddColor(clrMediumTurquoise, "MediumTurquoise", "Greens");
   AddColor(clrDarkTurquoise, "DarkTurquoise", "Greens");
   AddColor(clrCadetBlue, "CadetBlue", "Greens");

   // Blues
   AddColor(clrMidnightBlue, "MidnightBlue", "Blues");
   AddColor(clrNavy, "Navy", "Blues");
   AddColor(clrDarkBlue, "DarkBlue", "Blues");
   AddColor(clrMediumBlue, "MediumBlue", "Blues");
   AddColor(clrBlue, "Blue", "Blues");
   AddColor(clrRoyalBlue, "RoyalBlue", "Blues");
   AddColor(clrSteelBlue, "SteelBlue", "Blues");
   AddColor(clrCornflowerBlue, "CornflowerBlue", "Blues");
   AddColor(clrDodgerBlue, "DodgerBlue", "Blues");
   AddColor(clrDeepSkyBlue, "DeepSkyBlue", "Blues");
   AddColor(clrLightSkyBlue, "LightSkyBlue", "Blues");
   AddColor(clrSkyBlue, "SkyBlue", "Blues");
   AddColor(clrLightBlue, "LightBlue", "Blues");
   AddColor(clrPowderBlue, "PowderBlue", "Blues");
   AddColor(clrPaleTurquoise, "PaleTurquoise", "Blues"); // Dup ok
   AddColor(clrAliceBlue, "AliceBlue", "Blues");
   AddColor(clrAzure, "Azure", "Blues");
   AddColor(clrMintCream, "MintCream", "Blues");
   AddColor(clrDarkSlateGray, "DarkSlateGray", "Blues");
   AddColor(clrSlateGray, "SlateGray", "Blues");
   AddColor(clrLightSlateGray, "LightSlateGray", "Blues");

   // --- 2. Draw Table ---
   long chart = ChartID();
   int subwin = 0;

   // Clean up old objects
   ObjectsDeleteAll(chart, subwin, 0, OBJ_RECTANGLE_LABEL);
   ObjectsDeleteAll(chart, subwin, 0, OBJ_LABEL);

   int total_colors = ArraySize(Colors);

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
      ObjectSetInteger(chart, name_rect, OBJPROP_XSIZE, 40);
      ObjectSetInteger(chart, name_rect, OBJPROP_YSIZE, InpCellHeight);
      ObjectSetInteger(chart, name_rect, OBJPROP_BGCOLOR, Colors[i].col);
      ObjectSetInteger(chart, name_rect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart, name_rect, OBJPROP_COLOR, clrNONE);
      ObjectSetInteger(chart, name_rect, OBJPROP_CORNER, CORNER_LEFT_UPPER);

      // 2. Text Label (Right Side of Cell)
      if(!ObjectCreate(chart, name_lbl, OBJ_LABEL, subwin, 0, 0)) continue;
      ObjectSetInteger(chart, name_lbl, OBJPROP_XDISTANCE, x + 45);
      ObjectSetInteger(chart, name_lbl, OBJPROP_YDISTANCE, y + 10);
      ObjectSetInteger(chart, name_lbl, OBJPROP_COLOR, InpTextColor);
      ObjectSetInteger(chart, name_lbl, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetInteger(chart, name_lbl, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(chart, name_lbl, OBJPROP_TEXT, Colors[i].name);

      // FIX: Implicit conversion warning
      // The previous code had IntegerToString(i) appended to name inside loop string building
      // Here we explicitly build the tooltip string
      string tooltip = Colors[i].group + "\n" + ColorToHex(Colors[i].col);
      ObjectSetString(chart, name_lbl, OBJPROP_TOOLTIP, tooltip);
   }

   ChartRedraw(chart);
   Print("Done. Table created.");
  }

//+------------------------------------------------------------------+
//| Helper: Convert Color to Hex String (e.g. R:255 G:0 B:0)         |
//+------------------------------------------------------------------+
string ColorToHex(color c)
{
   int r = c & 0xFF;
   int g = (c >> 8) & 0xFF;
   int b = (c >> 16) & 0xFF;

   // FIX: Use IntegerToString to avoid implicit conversion warnings in concatenation
   return "R:" + IntegerToString(r) + " G:" + IntegerToString(g) + " B:" + IntegerToString(b);
}
//+------------------------------------------------------------------+
