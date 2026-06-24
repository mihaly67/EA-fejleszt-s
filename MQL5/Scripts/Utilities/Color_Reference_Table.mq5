//+------------------------------------------------------------------+
//|                                     Color_Reference_Table.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.00"
#property script_show_inputs

//--- List of key Web Colors used in trading
string ColorNames[] = {
   "clrBlack", "clrDimGray", "clrGray", "clrSilver", "clrWhite",
   "clrRed", "clrFireBrick", "clrMaroon", "clrTomato", "clrSalmon",
   "clrGreen", "clrForestGreen", "clrLime", "clrLimeGreen", "clrSeaGreen",
   "clrBlue", "clrNavy", "clrMidnightBlue", "clrRoyalBlue", "clrDodgerBlue",
   "clrGold", "clrOrange", "clrOrangeRed", "clrYellow", "clrKhaki"
};
color ColorValues[] = {
   clrBlack, clrDimGray, clrGray, clrSilver, clrWhite,
   clrRed, clrFireBrick, clrMaroon, clrTomato, clrSalmon,
   clrGreen, clrForestGreen, clrLime, clrLimeGreen, clrSeaGreen,
   clrBlue, clrNavy, clrMidnightBlue, clrRoyalBlue, clrDodgerBlue,
   clrGold, clrOrange, clrOrangeRed, clrYellow, clrKhaki
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart = ChartID();
   int total = ArraySize(ColorNames);
   int x_base = 50;
   int y_base = 50;
   int row_height = 25;
   int col_width = 150;

   // Clean up old objects first
   ObjectsDeleteAll(chart, "ColorRef_");

   for(int i=0; i<total; i++)
     {
      string name_label = "ColorRef_Name_" + IntegerToString(i);
      string box_label = "ColorRef_Box_" + IntegerToString(i);

      int y = y_base + (i * row_height);

      // 1. Color Sample Box (Rectangle Label)
      ObjectCreate(chart, box_label, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(chart, box_label, OBJPROP_XDISTANCE, x_base);
      ObjectSetInteger(chart, box_label, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart, box_label, OBJPROP_XSIZE, 40);
      ObjectSetInteger(chart, box_label, OBJPROP_YSIZE, 20);
      ObjectSetInteger(chart, box_label, OBJPROP_BGCOLOR, ColorValues[i]);
      ObjectSetInteger(chart, box_label, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart, box_label, OBJPROP_COLOR, clrWhite); // Border

      // 2. Color Name Label
      ObjectCreate(chart, name_label, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chart, name_label, OBJPROP_XDISTANCE, x_base + 50);
      ObjectSetInteger(chart, name_label, OBJPROP_YDISTANCE, y);
      ObjectSetString(chart, name_label, OBJPROP_TEXT, ColorNames[i]);
      ObjectSetInteger(chart, name_label, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(chart, name_label, OBJPROP_FONTSIZE, 10);
     }

   ChartRedraw(chart);
   Print("Color Reference Table drawn on chart.");
  }
//+------------------------------------------------------------------+
