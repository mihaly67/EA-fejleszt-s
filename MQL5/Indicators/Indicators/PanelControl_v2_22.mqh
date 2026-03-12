//+------------------------------------------------------------------+
//|                                             PanelControl_v2_21.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.21  |
//|                  (Dynamic Version Label Support)                 |
//+------------------------------------------------------------------+
#ifndef PANELCONTROL_V2_21_MQH
#define PANELCONTROL_V2_21_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_16.mqh" // For Enums v2.16 (Compatible)

// --- Panel Events ---
enum ENUM_PANEL_EVENT
{
   EVENT_NONE = 0,
   EVENT_FIRE,          // TRAP (Both)
   EVENT_FIRE_BUY,      // BUY ONLY
   EVENT_FIRE_SELL,     // SELL ONLY
   EVENT_CEASE_FIRE,
   EVENT_CLOSE_PROFIT,  // CLOSE ALL PROFIT
   EVENT_CHANGE_MODE,
   EVENT_CHANGE_ENTRY,
   EVENT_PARAM_UPDATE,
   EVENT_TP_SL_UPDATE,  // Virtual TP/SL Changed
   EVENT_TOGGLE_VISUAL  // Toggle Chart Graphics
};

//+------------------------------------------------------------------+
//| Class CPanelControl                                              |
//| Handles the GUI (Buttons, Inputs) for the Merkava EA.            |
//| Encapsulates object creation, events, and state.                 |
//| v2.21: Dynamic Version Label via Init()                          |
//+------------------------------------------------------------------+
class CPanelControl
{
private:
   string      m_prefix;
   string      m_version_label; // NEW: Stores dynamic version
   int         m_x, m_y;
   int         m_width, m_height;
   color       m_bg_color;
   color       m_txt_color;

   // Objects
   string ObjBG;
   string ObjStat;

   // Left Column (Legacy)
   string ObjBtnFire;
   string ObjBtnClear;
   string ObjBtnMode;
   string ObjBtnEntry;
   string ObjLabelLot;
   string ObjEditLot;
   string ObjLabelMultStart;
   string ObjEditMultStart;
   string ObjLabelMultStep;
   string ObjEditMultStep;
   string ObjLabelLayers;
   string ObjEditLayers;
   string ObjLabelMinDist;
   string ObjEditMinDist;
   string ObjLabelPL;

   // Right Column (New Directional + Stats)
   string ObjBtnFireBuy;
   string ObjBtnFireSell;
   string ObjBtnCloseProfit;
   string ObjLabelVirtualTP;
   string ObjEditVirtualTP;
   string ObjLabelVirtualSL;
   string ObjEditVirtualSL;

   string ObjLabelBalance;
   string ObjLabelEquity;
   string ObjLabelMargin;
   string ObjLabelFreeMargin;
   string ObjLabelMarginLevel;
   string ObjLabelTotalPL;
   string ObjLabelSessionPL;

   // Current State (Values)
   double      m_lot_size;
   double      m_mult_start;
   double      m_mult_step;
   int         m_layers;
   double      m_min_dist;
   double      m_virtual_tp;
   double      m_virtual_sl;
   bool        m_visual_active; // State for visual toggle
   ENUM_FIRE_MODE m_fire_mode;
   ENUM_ENTRY_MODE m_entry_mode;

public:
   CPanelControl() {
       m_prefix = "Merkava_";
       m_version_label = "Merkava v2.XX"; // Default fallback
       m_fire_mode = FIRE_MODE_STOP;
       m_entry_mode = ENTRY_PENDING;
       m_visual_active = true;
   }
   ~CPanelControl() {}

   void Init(string prefix, int x, int y, color bg, color txt,
             double def_lot, double def_start, double def_step, int def_layers, double def_min_dist,
             double def_vtp, double def_vsl, string version_text) // Added version_text param
   {
      m_prefix = prefix;
      m_x = x; m_y = y;
      m_bg_color = bg; m_txt_color = txt;
      m_version_label = version_text; // Store version

      m_width = 320; m_height = 500;

      // Initialize State
      m_lot_size = def_lot;
      m_mult_start = def_start;
      m_mult_step = def_step;
      m_layers = def_layers;
      m_min_dist = def_min_dist;
      m_virtual_tp = def_vtp;
      m_virtual_sl = def_vsl;
      m_fire_mode = FIRE_MODE_STOP;
      m_entry_mode = ENTRY_PENDING;

      // Define Object Names
      ObjBG = m_prefix + "BG";
      ObjStat = m_prefix + "Status";

      // Left Column
      ObjBtnFire = m_prefix + "BtnFire";
      ObjBtnClear = m_prefix + "BtnClear";
      ObjBtnMode = m_prefix + "BtnMode";
      ObjBtnEntry = m_prefix + "BtnEntry";
      ObjLabelLot = m_prefix + "LabelLot";
      ObjEditLot = m_prefix + "EditLot";
      ObjLabelMultStart = m_prefix + "LabelMultStart";
      ObjEditMultStart = m_prefix + "EditMultStart";
      ObjLabelMultStep = m_prefix + "LabelMultStep";
      ObjEditMultStep = m_prefix + "EditMultStep";
      ObjLabelLayers = m_prefix + "LabelLayers";
      ObjEditLayers = m_prefix + "EditLayers";
      ObjLabelMinDist = m_prefix + "LabelMinDist";
      ObjEditMinDist = m_prefix + "EditMinDist";
      ObjLabelPL = m_prefix + "LabelPL";

      // Right Column
      ObjBtnFireBuy = m_prefix + "BtnFireBuy";
      ObjBtnFireSell = m_prefix + "BtnFireSell";
      ObjBtnCloseProfit = m_prefix + "BtnCloseProfit";

      ObjLabelVirtualTP = m_prefix + "LabelVirtualTP";
      ObjEditVirtualTP = m_prefix + "EditVirtualTP";
      ObjLabelVirtualSL = m_prefix + "LabelVirtualSL";
      ObjEditVirtualSL = m_prefix + "EditVirtualSL";

      ObjLabelBalance = m_prefix + "LabelBalance";
      ObjLabelEquity = m_prefix + "LabelEquity";
      ObjLabelMargin = m_prefix + "LabelMargin";
      ObjLabelFreeMargin = m_prefix + "LabelFreeMargin";
      ObjLabelMarginLevel = m_prefix + "LabelMarginLevel";
      ObjLabelTotalPL = m_prefix + "LabelTotalPL";
      ObjLabelSessionPL = m_prefix + "LabelSessionPL";
   }

   // --- Getters ---
   double GetLotSize() const { return m_lot_size; }
   double GetMultStart() const { return m_mult_start; }
   double GetMultStep() const { return m_mult_step; }
   int    GetLayers() const { return m_layers; }
   double GetMinDist() const { return m_min_dist; }
   double GetVirtualTP() const { return m_virtual_tp; }
   double GetVirtualSL() const { return m_virtual_sl; }
   bool   GetVisualActive() const { return m_visual_active; }
   ENUM_FIRE_MODE GetFireMode() const { return m_fire_mode; }
   ENUM_ENTRY_MODE GetEntryMode() const { return m_entry_mode; }

   // --- Core Methods ---
   void Create()
   {
       int x = m_x; int y = m_y;
       int w = m_width; int h = m_height;

       int col_w = 150;
       int col2_x = x + 160;

       // Main Background
       ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
       ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w); ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
       ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, m_bg_color);

       int cy = y+10;

       // Header - DYNAMIC VERSION
       ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjStat, OBJPROP_TEXT, m_version_label); // Use dynamic label
       ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);

       // === LEFT COLUMN (Legacy Controls) ===

       // --- Lot Size ---
       cy+=30;
       ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "Lot:");
       ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(m_lot_size, 2));
       ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);

       // --- Mult Start ---
       cy+=25;
       ObjectCreate(0, ObjLabelMultStart, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMultStart, OBJPROP_TEXT, "Mult Start:");
       ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditMultStart, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditMultStart, OBJPROP_TEXT, DoubleToString(m_mult_start, 1));
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_COLOR, clrBlack);

       // --- Mult Step ---
       cy+=25;
       ObjectCreate(0, ObjLabelMultStep, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMultStep, OBJPROP_TEXT, "Mult Step:");
       ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditMultStep, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditMultStep, OBJPROP_TEXT, DoubleToString(m_mult_step, 1));
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_COLOR, clrBlack);

       // --- Layers ---
       cy+=25;
       ObjectCreate(0, ObjLabelLayers, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelLayers, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelLayers, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelLayers, OBJPROP_TEXT, "Layers:");
       ObjectSetInteger(0, ObjLabelLayers, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditLayers, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditLayers, OBJPROP_TEXT, IntegerToString(m_layers));
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLayers, OBJPROP_COLOR, clrBlack);

       // --- Min Dist ---
       cy+=25;
       ObjectCreate(0, ObjLabelMinDist, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMinDist, OBJPROP_TEXT, "Min Dist:");
       ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditMinDist, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditMinDist, OBJPROP_TEXT, DoubleToString(m_min_dist, 0));
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_COLOR, clrBlack);

       int btn_h = 24; // 20% smaller than previous 30px
       int cy_step = btn_h + 5;

       // --- Visual Toggle Button ---
       cy += 30;
       ObjectCreate(0, ObjBtnVisual, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnVisual, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnVisual, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_FONTSIZE, 8);

       // --- Mode Toggle Button (Breakout/Limit) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnMode, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_FONTSIZE, 8);

       // --- Entry Toggle Button (Pending/Market) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnEntry, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_FONTSIZE, 8);

       // --- Fire TRAP Button (Legacy) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, btn_h + 4);
       ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE TRAP");
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed); ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);

       // --- Cease Fire ---
       cy += cy_step + 4;
       ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange); ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);


       // === RIGHT COLUMN (New Directional Controls) ===
       cy = y + 40;

       // --- Fire BUY ---
       ObjectCreate(0, ObjBtnFireBuy, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnFireBuy, OBJPROP_TEXT, "FIRE BUY");
       ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_FONTSIZE, 8);
       ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_BGCOLOR, clrForestGreen); ObjectSetInteger(0, ObjBtnFireBuy, OBJPROP_COLOR, clrWhite);

       // --- Fire SELL ---
       ObjectCreate(0, ObjBtnFireSell, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_XDISTANCE, col2_x + 80); ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnFireSell, OBJPROP_TEXT, "FIRE SELL");
       ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_FONTSIZE, 8);
       ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_BGCOLOR, clrFireBrick); ObjectSetInteger(0, ObjBtnFireSell, OBJPROP_COLOR, clrWhite);

       // --- Close Profit (New v2.15) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnCloseProfit, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_XSIZE, 130); ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnCloseProfit, OBJPROP_TEXT, "CLOSE PROFIT");
       ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_FONTSIZE, 8);
       ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_BGCOLOR, clrDarkGreen); ObjectSetInteger(0, ObjBtnCloseProfit, OBJPROP_COLOR, clrWhite);

       // --- Virtual TP (New v2.15) ---
       cy+=35;
       ObjectCreate(0, ObjLabelVirtualTP, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelVirtualTP, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelVirtualTP, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelVirtualTP, OBJPROP_TEXT, "Virtual TP ($):");
       ObjectSetInteger(0, ObjLabelVirtualTP, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditVirtualTP, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_XDISTANCE, col2_x + 90); ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_XSIZE, 50); ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditVirtualTP, OBJPROP_TEXT, DoubleToString(m_virtual_tp, 1));
       ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditVirtualTP, OBJPROP_COLOR, clrBlack);

       // --- Virtual SL (New v2.15) ---
       cy+=25;
       ObjectCreate(0, ObjLabelVirtualSL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelVirtualSL, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelVirtualSL, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelVirtualSL, OBJPROP_TEXT, "Virtual SL ($):");
       ObjectSetInteger(0, ObjLabelVirtualSL, OBJPROP_COLOR, m_txt_color);

       ObjectCreate(0, ObjEditVirtualSL, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_XDISTANCE, col2_x + 90); ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_XSIZE, 50); ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_YSIZE, 18);
       ObjectSetString(0, ObjEditVirtualSL, OBJPROP_TEXT, DoubleToString(m_virtual_sl, 1));
       ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditVirtualSL, OBJPROP_COLOR, clrBlack);

       // === ACCOUNT STATS (Below Inputs) ===
       cy += 30;

       // Floating P/L
       ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "P/L: 0.00");
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);

       // Session P/L (New)
       cy += 20;
       ObjectCreate(0, ObjLabelSessionPL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelSessionPL, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelSessionPL, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelSessionPL, OBJPROP_TEXT, "Ses P/L: 0.00");
       ObjectSetInteger(0, ObjLabelSessionPL, OBJPROP_COLOR, clrWhite);

       // Total P/L (Hist) (New)
       cy += 20;
       ObjectCreate(0, ObjLabelTotalPL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelTotalPL, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelTotalPL, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelTotalPL, OBJPROP_TEXT, "Tot P/L: 0.00");
       ObjectSetInteger(0, ObjLabelTotalPL, OBJPROP_COLOR, clrWhite);

       // Balance
       cy += 20;
       ObjectCreate(0, ObjLabelBalance, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelBalance, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelBalance, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelBalance, OBJPROP_TEXT, "Bal: 0.00");
       ObjectSetInteger(0, ObjLabelBalance, OBJPROP_COLOR, clrSilver);

       // Equity
       cy += 20;
       ObjectCreate(0, ObjLabelEquity, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelEquity, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelEquity, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelEquity, OBJPROP_TEXT, "Eq: 0.00");
       ObjectSetInteger(0, ObjLabelEquity, OBJPROP_COLOR, clrSilver);

       // Margin
       cy += 20;
       ObjectCreate(0, ObjLabelMargin, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMargin, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelMargin, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMargin, OBJPROP_TEXT, "Mrg: 0.00");
       ObjectSetInteger(0, ObjLabelMargin, OBJPROP_COLOR, clrSilver);

       // Free Margin (New)
       cy += 20;
       ObjectCreate(0, ObjLabelFreeMargin, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelFreeMargin, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelFreeMargin, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelFreeMargin, OBJPROP_TEXT, "Free: 0.00");
       ObjectSetInteger(0, ObjLabelFreeMargin, OBJPROP_COLOR, clrSilver);

       // Margin Level
       cy += 20;
       ObjectCreate(0, ObjLabelMarginLevel, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_XDISTANCE, col2_x + 10); ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMarginLevel, OBJPROP_TEXT, "Lvl: 0%");
       ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_COLOR, clrSilver);


       UpdateButtons(); // Set Initial Text/Color
   }

   void Destroy()
   {
       ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat); ObjectDelete(0, ObjBtnFire);
       ObjectDelete(0, ObjBtnClear); ObjectDelete(0, ObjLabelPL);
       ObjectDelete(0, ObjBtnMode); ObjectDelete(0, ObjBtnEntry);

       ObjectDelete(0, ObjLabelLot); ObjectDelete(0, ObjEditLot);
       ObjectDelete(0, ObjLabelMultStart); ObjectDelete(0, ObjEditMultStart);
       ObjectDelete(0, ObjLabelMultStep); ObjectDelete(0, ObjEditMultStep);
       ObjectDelete(0, ObjLabelLayers); ObjectDelete(0, ObjEditLayers);
       ObjectDelete(0, ObjLabelMinDist); ObjectDelete(0, ObjEditMinDist);

       ObjectDelete(0, ObjBtnFireBuy); ObjectDelete(0, ObjBtnFireSell);
       ObjectDelete(0, ObjBtnCloseProfit); ObjectDelete(0, ObjBtnVisual);

       ObjectDelete(0, ObjLabelVirtualTP); ObjectDelete(0, ObjEditVirtualTP); // New
       ObjectDelete(0, ObjLabelVirtualSL); ObjectDelete(0, ObjEditVirtualSL); // New

       ObjectDelete(0, ObjLabelBalance); ObjectDelete(0, ObjLabelEquity);
       ObjectDelete(0, ObjLabelMargin); ObjectDelete(0, ObjLabelMarginLevel);
       ObjectDelete(0, ObjLabelFreeMargin); // New
       ObjectDelete(0, ObjLabelTotalPL); ObjectDelete(0, ObjLabelSessionPL); // New
   }

   void UpdateUI(double pl)
   {
       ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "P/L: " + DoubleToString(pl, 2));
       if (pl > 0) ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrLime);
       else if (pl < 0) ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrRed);
       else ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);

       ChartRedraw();
   }

   // Enhanced Stats Update
   void UpdateAccountStats(double balance, double equity, double margin, double free_margin, double margin_level, double total_pl, double session_pl)
   {
       ObjectSetString(0, ObjLabelBalance, OBJPROP_TEXT, "Bal: " + DoubleToString(balance, 2));
       ObjectSetString(0, ObjLabelEquity, OBJPROP_TEXT, "Eq: " + DoubleToString(equity, 2));
       ObjectSetString(0, ObjLabelMargin, OBJPROP_TEXT, "Mrg: " + DoubleToString(margin, 2));
       ObjectSetString(0, ObjLabelFreeMargin, OBJPROP_TEXT, "Free: " + DoubleToString(free_margin, 2));
       ObjectSetString(0, ObjLabelMarginLevel, OBJPROP_TEXT, "Lvl: " + DoubleToString(margin_level, 1) + "%");

       ObjectSetString(0, ObjLabelTotalPL, OBJPROP_TEXT, "Tot P/L: " + DoubleToString(total_pl, 2));
       ObjectSetString(0, ObjLabelSessionPL, OBJPROP_TEXT, "Ses P/L: " + DoubleToString(session_pl, 2));

       // Color Logic for Level
       if (margin_level < 100) ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_COLOR, clrRed);
       else if (margin_level < 300) ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_COLOR, clrOrange);
       else ObjectSetInteger(0, ObjLabelMarginLevel, OBJPROP_COLOR, clrLime);

       ChartRedraw();
   }

   void UpdateButtons() {
        // Visual Toggle Mode
        if(m_visual_active) {
            ObjectSetString(0, ObjBtnVisual, OBJPROP_TEXT, "VISUAL: ON");
            ObjectSetInteger(0, ObjBtnVisual, OBJPROP_BGCOLOR, clrDarkCyan);
        } else {
            ObjectSetString(0, ObjBtnVisual, OBJPROP_TEXT, "VISUAL: OFF");
            ObjectSetInteger(0, ObjBtnVisual, OBJPROP_BGCOLOR, clrDimGray);
        }

        // Strategy Mode
        if(m_fire_mode == FIRE_MODE_STOP) {
            ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: STOP (Breakout)");
            ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrOrangeRed);
        } else {
            ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: LIMIT (Revert)");
            ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrCornflowerBlue);
        }

        // Entry Mode
        if(m_entry_mode == ENTRY_MARKET) {
            ObjectSetString(0, ObjBtnEntry, OBJPROP_TEXT, "ENTRY: MARKET (Instant)");
            ObjectSetInteger(0, ObjBtnEntry, OBJPROP_BGCOLOR, clrRed);
        } else {
            ObjectSetString(0, ObjBtnEntry, OBJPROP_TEXT, "ENTRY: PENDING");
            ObjectSetInteger(0, ObjBtnEntry, OBJPROP_BGCOLOR, clrDimGray);
        }
        ChartRedraw();
   }

   // --- Event Handling ---
   ENUM_PANEL_EVENT OnEvent(int id, long lparam, double dparam, string sparam)
   {
       if(id == CHARTEVENT_OBJECT_CLICK)
       {
          if(sparam == ObjBtnFire)
          {
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_FIRE;
          }
          else if(sparam == ObjBtnFireBuy)
          {
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_FIRE_BUY;
          }
          else if(sparam == ObjBtnFireSell)
          {
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_FIRE_SELL;
          }
          else if(sparam == ObjBtnCloseProfit) // Close Profit Event
          {
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_CLOSE_PROFIT;
          }
          else if (sparam == ObjBtnClear)
          {
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_CEASE_FIRE;
          }
          else if (sparam == ObjBtnMode)
          {
             // Toggle Strategy Mode
             m_fire_mode = (m_fire_mode == FIRE_MODE_STOP) ? FIRE_MODE_LIMIT : FIRE_MODE_STOP;
             UpdateButtons();
             return EVENT_CHANGE_MODE;
          }
          else if (sparam == ObjBtnEntry)
          {
             // Toggle Entry Mode
             m_entry_mode = (m_entry_mode == ENTRY_PENDING) ? ENTRY_MARKET : ENTRY_PENDING;
             UpdateButtons();
             return EVENT_CHANGE_ENTRY;
          }
          else if (sparam == ObjBtnVisual)
          {
             // Toggle Visual Mode
             m_visual_active = !m_visual_active;
             UpdateButtons();
             return EVENT_TOGGLE_VISUAL;
          }
       }
       else if(id == CHARTEVENT_OBJECT_ENDEDIT)
       {
          // Handle Updates & Validation
          if(sparam == ObjEditLot) {
               double val = StringToDouble(ObjectGetString(0, ObjEditLot, OBJPROP_TEXT));
               if(val > 0) m_lot_size = val;
               return EVENT_PARAM_UPDATE;
          }
          else if(sparam == ObjEditMultStart) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMultStart, OBJPROP_TEXT));
               if(val > 0) m_mult_start = val;
               return EVENT_PARAM_UPDATE;
          }
          else if(sparam == ObjEditMultStep) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMultStep, OBJPROP_TEXT));
               if(val > 0) m_mult_step = val;
               return EVENT_PARAM_UPDATE;
          }
          else if(sparam == ObjEditLayers) {
               long val = StringToInteger(ObjectGetString(0, ObjEditLayers, OBJPROP_TEXT));
               if(val > 0 && val < 20) m_layers = (int)val;
               return EVENT_PARAM_UPDATE;
          }
          else if(sparam == ObjEditMinDist) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMinDist, OBJPROP_TEXT));
               if(val >= 0) m_min_dist = val;
               return EVENT_PARAM_UPDATE;
          }
          else if(sparam == ObjEditVirtualTP) { // Virtual TP Update
               double val = StringToDouble(ObjectGetString(0, ObjEditVirtualTP, OBJPROP_TEXT));
               m_virtual_tp = val;
               return EVENT_TP_SL_UPDATE;
          }
          else if(sparam == ObjEditVirtualSL) { // Virtual SL Update
               double val = StringToDouble(ObjectGetString(0, ObjEditVirtualSL, OBJPROP_TEXT));
               m_virtual_sl = val;
               return EVENT_TP_SL_UPDATE;
          }
       }

       return EVENT_NONE;
   }
};
#endif
