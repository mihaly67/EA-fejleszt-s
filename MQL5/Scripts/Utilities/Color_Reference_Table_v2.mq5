//+------------------------------------------------------------------+
//|                                   Color_Reference_Table_v2.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.00"
#property script_show_inputs

//--- Lists of Web Colors (Grouped for easier reading)
// Grays / Whites
color Col_Grays[] = {clrWhite, clrSnow, clrMintCream, clrLavenderBlush, clrAliceBlue, clrGhostWhite, clrWhiteSmoke, clrSeashell, clrBeige, clrOldLace, clrFloralWhite, clrIvory, clrAntiqueWhite, clrLinen, clrLavender, clrMistyRose, clrGainsboro, clrLightGray, clrSilver, clrDarkGray, clrGray, clrDimGray, clrLightSlateGray, clrSlateGray, clrDarkSlateGray, clrBlack};
string Name_Grays[] = {"White", "Snow", "MintCream", "LavenderBlush", "AliceBlue", "GhostWhite", "WhiteSmoke", "Seashell", "Beige", "OldLace", "FloralWhite", "Ivory", "AntiqueWhite", "Linen", "Lavender", "MistyRose", "Gainsboro", "LightGray", "Silver", "DarkGray", "Gray", "DimGray", "LightSlateGray", "SlateGray", "DarkSlateGray", "Black"};

// Blues
color Col_Blues[] = {clrLightCyan, clrPaleturquoise, clrAqua, clrAquamarine, clrTurquoise, clrMediumTurquoise, clrDarkTurquoise, clrCadetBlue, clrSteelBlue, clrLightSteelBlue, clrPowderBlue, clrLightBlue, clrSkyBlue, clrLightSkyBlue, clrDeepSkyBlue, clrDodgerBlue, clrCornflowerBlue, clrRoyalBlue, clrBlue, clrMediumBlue, clrDarkBlue, clrNavy, clrMidnightBlue};
string Name_Blues[] = {"LightCyan", "Paleturquoise", "Aqua", "Aquamarine", "Turquoise", "MediumTurquoise", "DarkTurquoise", "CadetBlue", "SteelBlue", "LightSteelBlue", "PowderBlue", "LightBlue", "SkyBlue", "LightSkyBlue", "DeepSkyBlue", "DodgerBlue", "CornflowerBlue", "RoyalBlue", "Blue", "MediumBlue", "DarkBlue", "Navy", "MidnightBlue"};

// Greens
color Col_Greens[] = {clrGreenYellow, clrChartreuse, clrLawnGreen, clrLime, clrLimeGreen, clrPaleGreen, clrLightGreen, clrMediumSpringGreen, clrSpringGreen, clrMediumSeaGreen, clrSeaGreen, clrForestGreen, clrGreen, clrDarkGreen, clrYellowGreen, clrOliveDrab, clrOlive, clrDarkOliveGreen, clrMediumAquamarine, clrDarkSeaGreen, clrLightSeaGreen, clrTeal};
string Name_Greens[] = {"GreenYellow", "Chartreuse", "LawnGreen", "Lime", "LimeGreen", "PaleGreen", "LightGreen", "MediumSpringGreen", "SpringGreen", "MediumSeaGreen", "SeaGreen", "ForestGreen", "Green", "DarkGreen", "YellowGreen", "OliveDrab", "Olive", "DarkOliveGreen", "MediumAquamarine", "DarkSeaGreen", "LightSeaGreen", "Teal"};

// Reds / Pinks / Oranges
color Col_Reds[] = {clrLightSalmon, clrSalmon, clrDarkSalmon, clrLightCoral, clrIndianRed, clrCrimson, clrFireBrick, clrRed, clrDarkRed, clrMaroon, clrTomato, clrOrangeRed, clrPaleVioletRed, clrDeepPink, clrHotPink, clrLightPink, clrPink, clrMoccasin, clrPeachPuff, clrGold, clrYellow, clrKhaki, clrDarkKhaki, clrOrange, clrDarkOrange, clrCoral, clrSaddleBrown, clrSienna, clrChocolate, clrPeru, clrSandyBrown, clrBurlyWood, clrTan, clrRosyBrown};
string Name_Reds[] = {"LightSalmon", "Salmon", "DarkSalmon", "LightCoral", "IndianRed", "Crimson", "FireBrick", "Red", "DarkRed", "Maroon", "Tomato", "OrangeRed", "PaleVioletRed", "DeepPink", "HotPink", "LightPink", "Pink", "Moccasin", "PeachPuff", "Gold", "Yellow", "Khaki", "DarkKhaki", "Orange", "DarkOrange", "Coral", "SaddleBrown", "Sienna", "Chocolate", "Peru", "SandyBrown", "BurlyWood", "Tan", "RosyBrown"};

void OnStart()
{
   long chart = ChartID();
   ObjectsDeleteAll(chart, "CRef_");

   int col_width = 180;
   int row_height = 18;
   int start_x = 20;
   int start_y = 20;

   DrawColumn(chart, Col_Grays, Name_Grays, start_x, start_y, row_height, "GRAYS");
   DrawColumn(chart, Col_Blues, Name_Blues, start_x + col_width, start_y, row_height, "BLUES");
   DrawColumn(chart, Col_Greens, Name_Greens, start_x + (col_width*2), start_y, row_height, "GREENS");
   DrawColumn(chart, Col_Reds, Name_Reds, start_x + (col_width*3), start_y, row_height, "REDS/ORANGES");

   ChartRedraw(chart);
}

void DrawColumn(long chart, color &cols[], string &names[], int x, int y, int h, string header)
{
   // Header
   ObjectCreate(chart, "CRef_Head_"+header, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chart, "CRef_Head_"+header, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart, "CRef_Head_"+header, OBJPROP_YDISTANCE, y);
   ObjectSetString(chart, "CRef_Head_"+header, OBJPROP_TEXT, header);
   ObjectSetInteger(chart, "CRef_Head_"+header, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(chart, "CRef_Head_"+header, OBJPROP_FONTSIZE, 10);

   y += h + 5;

   for(int i=0; i<ArraySize(cols); i++)
   {
      string box = "CRef_B_"+header+(string)i;
      string lbl = "CRef_L_"+header+(string)i;

      // Box
      ObjectCreate(chart, box, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(chart, box, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart, box, OBJPROP_YDISTANCE, y + (i*h));
      ObjectSetInteger(chart, box, OBJPROP_XSIZE, 40);
      ObjectSetInteger(chart, box, OBJPROP_YSIZE, h-2);
      ObjectSetInteger(chart, box, OBJPROP_BGCOLOR, cols[i]);
      ObjectSetInteger(chart, box, OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Name
      ObjectCreate(chart, lbl, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chart, lbl, OBJPROP_XDISTANCE, x + 45);
      ObjectSetInteger(chart, lbl, OBJPROP_YDISTANCE, y + (i*h));
      ObjectSetString(chart, lbl, OBJPROP_TEXT, names[i]);
      ObjectSetInteger(chart, lbl, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(chart, lbl, OBJPROP_FONTSIZE, 8);
   }
}
