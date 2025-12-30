//+------------------------------------------------------------------+
//|                                    Hybrid_Liquidity_Sweep_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (Price Action SMC Logic)                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: Bearish Sweep (Arrow)
#property indicator_label1  "Bearish Sweep"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2

//--- Plot 2: Bullish Sweep (Arrow)
#property indicator_label2  "Bullish Sweep"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2

//--- Input Parameters
input group              "=== Sweep Detection ==="
input int                InpSwingLeft          = 10;     // Left Strength (Bars)
input int                InpSwingRight         = 3;      // Right Strength (Bars) - Reduce for Faster Swings
input double             InpWickRatio          = 0.4;    // Min Wick Ratio (40%) to Body
input bool               InpShowZones          = true;   // Draw Demand/Supply Zones

input group              "=== Zone Settings ==="
input color              InpSupplyColor        = clrRed;
input color              InpDemandColor        = clrGreen;
input int                InpZoneWidth          = 1;
input ENUM_LINE_STYLE    InpZoneStyle          = STYLE_SOLID;

//--- Buffers
double      BearishSweepBuffer[];
double      BullishSweepBuffer[];
double      SwingHighBuffer[]; // Internal calculation
double      SwingLowBuffer[];  // Internal calculation

//--- Global Variables for Zone Management
string g_last_supply_zone = "";
string g_last_demand_zone = "";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BearishSweepBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BullishSweepBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SwingHighBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, SwingLowBuffer, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_ARROW, 242); // Down Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 241); // Up Arrow

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Liquidity Sweep v1.0");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Draw Zone Object (Manages Single Active Zone)            |
//+------------------------------------------------------------------+
void DrawZone(datetime time1, double price1, double price2, bool is_supply, datetime bar_time)
{
    if(!InpShowZones) return;

    // Unique name for this specific potential zone
    string name = "Zone_" + (is_supply ? "Supply_" : "Demand_") + IntegerToString((long)bar_time);

    // --- LOGIC: Delete Old Zone ---
    // If a PREVIOUS zone exists and it is NOT this one (new signal), delete the old one.
    if (is_supply) {
        if (g_last_supply_zone != "" && g_last_supply_zone != name) {
            ObjectDelete(0, g_last_supply_zone);
        }
        g_last_supply_zone = name;
    } else {
        if (g_last_demand_zone != "" && g_last_demand_zone != name) {
            ObjectDelete(0, g_last_demand_zone);
        }
        g_last_demand_zone = name;
    }
    // -----------------------------

    // Create or Update
    if(ObjectFind(0, name) < 0) {
        if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, TimeCurrent(), price2)) return;

        // Set static properties only once
        ObjectSetInteger(0, name, OBJPROP_COLOR, is_supply ? InpSupplyColor : InpDemandColor);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, InpZoneWidth);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend to future
    } else {
        // Update coordinates (important for forming bars, though usually Sweep is fixed)
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
        ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
    }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpSwingLeft + InpSwingRight + 1) return 0;

   // Initialization / Reset
   if (prev_calculated == 0) {
       ObjectsDeleteAll(0, "Zone_");
       g_last_supply_zone = "";
       g_last_demand_zone = "";
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpSwingLeft;

   // 1. Identify Swing Points (Fractals)
   for(int i = start; i < rates_total - InpSwingRight; i++)
   {
       // Check if i is a High
       bool is_high = true;
       for(int k = 1; k <= InpSwingLeft; k++) if(high[i] <= high[i-k]) is_high = false;
       for(int k = 1; k <= InpSwingRight; k++) if(high[i] <= high[i+k]) is_high = false;

       if(is_high) SwingHighBuffer[i] = high[i];
       else SwingHighBuffer[i] = 0;

       // Check if i is a Low
       bool is_low = true;
       for(int k = 1; k <= InpSwingLeft; k++) if(low[i] >= low[i-k]) is_low = false;
       for(int k = 1; k <= InpSwingRight; k++) if(low[i] >= low[i+k]) is_low = false;

       if(is_low) SwingLowBuffer[i] = low[i];
       else SwingLowBuffer[i] = 0;
   }

   // 2. Sweep Detection
   int search_window = 50;

   // Loop through bars
   for(int i = start; i < rates_total; i++)
   {
       BearishSweepBuffer[i] = 0.0;
       BullishSweepBuffer[i] = 0.0;

       // Find nearest Swing High in the past
       double nearest_swing_high = 0;
       for(int k = 1; k < search_window; k++) {
           if(i-k >= 0 && SwingHighBuffer[i-k] > 0) {
               nearest_swing_high = SwingHighBuffer[i-k];
               break;
           }
       }

       // Find nearest Swing Low
       double nearest_swing_low = 0;
       for(int k = 1; k < search_window; k++) {
           if(i-k >= 0 && SwingLowBuffer[i-k] > 0) {
               nearest_swing_low = SwingLowBuffer[i-k];
               break;
           }
       }

       // Logic: Bearish Sweep (Liquidity Grab above High)
       if(nearest_swing_high > 0) {
           if(high[i] > nearest_swing_high && close[i] < nearest_swing_high) {
               double total_h = high[i] - low[i];
               if(total_h > 0) {
                   double wick_ratio = (high[i] - MathMax(open[i], close[i])) / total_h;
                   if(wick_ratio > InpWickRatio) {
                       BearishSweepBuffer[i] = high[i];
                       // Draw Supply Zone
                       DrawZone(time[i], MathMax(open[i], close[i]), high[i], true, time[i]);
                   }
               }
           }
       }

       // Logic: Bullish Sweep (Liquidity Grab below Low)
       if(nearest_swing_low > 0) {
           if(low[i] < nearest_swing_low && close[i] > nearest_swing_low) {
               double total_h = high[i] - low[i];
               if(total_h > 0) {
                   double wick_ratio = (MathMin(open[i], close[i]) - low[i]) / total_h;
                   if(wick_ratio > InpWickRatio) {
                       BullishSweepBuffer[i] = low[i];
                       // Draw Demand Zone
                       DrawZone(time[i], low[i], MathMin(open[i], close[i]), false, time[i]);
                   }
               }
           }
       }
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "Zone_");
}
