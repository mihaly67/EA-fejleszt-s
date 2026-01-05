//+------------------------------------------------------------------+
//|                                     Color_Reference_Table_v2.0.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.00"
#property description "Displays a table of MQL5 Web Colors for reference"
#property script_show_inputs

//--- Color Palette Array (25 Colors) - Matches Chart Designer EA
color PALETTE_COLORS[25] = {
   C'10,10,10', C'20,20,20', C'30,30,30', clrBlack, clrMidnightBlue,
   clrForestGreen, clrLimeGreen, clrGreen, clrSeaGreen, clrChartreuse,
   clrFireBrick, clrRed, clrMaroon, clrCrimson, clrTomato,
   clrDimGray, clrGray, clrSilver, clrLightGray, clrWhite,
   clrGold, clrOrange, clrDeepPink, clrBlueViolet, clrRoyalBlue
};

string PALETTE_NAMES[25] = {
   "C'10,10,10'", "C'20,20,20'", "C'30,30,30'", "Black", "MidnightBlue",
   "ForestGreen", "LimeGreen", "Green", "SeaGreen", "Chartreuse",
   "FireBrick", "Red", "Maroon", "Crimson", "Tomato",
   "DimGray", "Gray", "Silver", "LightGray", "White",
   "Gold", "Orange", "DeepPink", "BlueViolet", "RoyalBlue"
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart = ChartID();
   int subwin = 0;

   int x_start = 100;
   int y_start = 100;
   int size_w = 120;
   int size_h = 40;
   int gap = 5;

   // Clear previous objects
   ObjectsDeleteAll(chart, subwin, 0, OBJ_RECTANGLE_LABEL);
   ObjectsDeleteAll(chart, subwin, 0, OBJ_LABEL);

   for(int i=0; i<25; i++) {
      int row = i / 5;
      int col = i % 5;

      int x = x_start + (col * (size_w + gap));
      int y = y_start + (row * (size_h + gap));

      string name_rect = "ColorRef_Rect_" + IntegerToString(i);
      string name_lbl  = "ColorRef_Lbl_" + IntegerToString(i);

      // Create Rectangle
      ObjectCreate(chart, name_rect, OBJ_RECTANGLE_LABEL, subwin, 0, 0);
      ObjectSetInteger(chart, name_rect, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart, name_rect, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart, name_rect, OBJPROP_XSIZE, size_w);
      ObjectSetInteger(chart, name_rect, OBJPROP_YSIZE, size_h);
      ObjectSetInteger(chart, name_rect, OBJPROP_BGCOLOR, PALETTE_COLORS[i]);
      ObjectSetInteger(chart, name_rect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart, name_rect, OBJPROP_COLOR, clrWhite); // Border color

      // Create Label
      ObjectCreate(chart, name_lbl, OBJ_LABEL, subwin, 0, 0);
      ObjectSetInteger(chart, name_lbl, OBJPROP_XDISTANCE, x + 5);
      ObjectSetInteger(chart, name_lbl, OBJPROP_YDISTANCE, y + 12);
      ObjectSetInteger(chart, name_lbl, OBJPROP_COLOR, (PALETTE_COLORS[i]==clrWhite || PALETTE_COLORS[i]==clrLightGray || PALETTE_COLORS[i]==clrChartreuse) ? clrBlack : clrWhite);
      ObjectSetString(chart, name_lbl, OBJPROP_TEXT, PALETTE_NAMES[i]);
      ObjectSetInteger(chart, name_lbl, OBJPROP_FONTSIZE, 8);
   }

   ChartRedraw(chart);
   Print("Color Reference Table Drawn.");
  }
//+------------------------------------------------------------------+
