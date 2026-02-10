//+------------------------------------------------------------------+
//|                                             PanelControl_v2_14.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.14  |
//+------------------------------------------------------------------+
#ifndef PANELCONTROL_V2_14_MQH
#define PANELCONTROL_V2_14_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_14.mqh" // For Enums

// --- Panel Events ---
enum ENUM_PANEL_EVENT
{
   EVENT_NONE = 0,
   EVENT_FIRE,
   EVENT_CEASE_FIRE,
   EVENT_CHANGE_MODE,
   EVENT_CHANGE_ENTRY,
   EVENT_CHANGE_ACTION,
   EVENT_PARAM_UPDATE
};

//+------------------------------------------------------------------+
//| Class CPanelControl                                              |
//| Handles the GUI (Buttons, Inputs) for the Merkava EA.            |
//| v2.14: Compact Layout & Directional Attack Buttons & Action Type |
//+------------------------------------------------------------------+
class CPanelControl
{
private:
   string      m_prefix;
   int         m_x, m_y;
   int         m_width, m_height;
   color       m_bg_color;
   color       m_txt_color;

   // Objects
   string ObjBG;
   string ObjStat;
   string ObjBtnAttackBuy;
   string ObjBtnAttackSell;
   string ObjBtnClear;
   string ObjBtnMode;
   string ObjBtnEntry;
   string ObjBtnAction;
   string ObjLineSep; // Separator Line

   // Compact Labels/Edits
   string ObjLabelLot;
   string ObjEditLot;
   string ObjLabelLayers;
   string ObjEditLayers;
   string ObjLabelMultStart;
   string ObjEditMultStart;
   string ObjLabelMultStep;
   string ObjEditMultStep;
   string ObjLabelMinDist;
   string ObjEditMinDist;
   string ObjLabelPL;

   // Current State (Values)
   double      m_lot_size;
   double      m_mult_start;
   double      m_mult_step;
   int         m_layers;
   double      m_min_dist;
   ENUM_FIRE_MODE m_fire_mode;
   ENUM_ENTRY_MODE m_entry_mode;
   ENUM_ATTACK_DIR m_attack_dir;
   ENUM_ACTION_TYPE m_action_type;

public:
   CPanelControl() {
       m_prefix = "Merkava_";
       m_fire_mode = FIRE_MODE_STOP;
       m_entry_mode = ENTRY_PENDING;
       m_attack_dir = ATTACK_BOTH;
       m_action_type = ACTION_COMBO;
   }
   ~CPanelControl() {}

   void Init(string prefix, int x, int y, color bg, color txt,
             double def_lot, double def_start, double def_step, int def_layers, double def_min_dist)
   {
      m_prefix = prefix;
      m_x = x; m_y = y;
      m_bg_color = bg; m_txt_color = txt;
      m_width = 140; // Reduced width
      m_height = 360; // Adjusted height

      // Initialize State
      m_lot_size = def_lot;
      m_mult_start = def_start;
      m_mult_step = def_step;
      m_layers = def_layers;
      m_min_dist = def_min_dist;
      m_fire_mode = FIRE_MODE_STOP; // Default: Breakout
      m_entry_mode = ENTRY_PENDING; // Default: Pending
      m_attack_dir = ATTACK_BOTH;
      m_action_type = ACTION_COMBO; // Default: Grid + Burst

      // Define Object Names
      ObjBG = m_prefix + "BG";
      ObjStat = m_prefix + "Status";
      ObjBtnAttackBuy = m_prefix + "BtnBuy";
      ObjBtnAttackSell = m_prefix + "BtnSell";
      ObjBtnClear = m_prefix + "BtnClear";
      ObjBtnMode = m_prefix + "BtnMode";
      ObjBtnEntry = m_prefix + "BtnEntry";
      ObjBtnAction = m_prefix + "BtnAction";
      ObjLineSep = m_prefix + "LineSep";

      ObjLabelLot = m_prefix + "LblLot";
      ObjEditLot = m_prefix + "EdtLot";
      ObjLabelLayers = m_prefix + "LblLay";
      ObjEditLayers = m_prefix + "EdtLay";

      ObjLabelMultStart = m_prefix + "LblMStart";
      ObjEditMultStart = m_prefix + "EdtMStart";
      ObjLabelMultStep = m_prefix + "LblMStep";
      ObjEditMultStep = m_prefix + "EdtMStep";

      ObjLabelMinDist = m_prefix + "LblDist";
      ObjEditMinDist = m_prefix + "EdtDist";

      ObjLabelPL = m_prefix + "LblPL";
   }

   // --- Getters ---
   double GetLotSize() const { return m_lot_size; }
   double GetMultStart() const { return m_mult_start; }
   double GetMultStep() const { return m_mult_step; }
   int    GetLayers() const { return m_layers; }
   double GetMinDist() const { return m_min_dist; }
   ENUM_FIRE_MODE GetFireMode() const { return m_fire_mode; }
   ENUM_ENTRY_MODE GetEntryMode() const { return m_entry_mode; }
   ENUM_ATTACK_DIR GetAttackDir() const { return m_attack_dir; }
   ENUM_ACTION_TYPE GetActionType() const { return m_action_type; }

   // --- Core Methods ---
   void Create()
   {
       int x = m_x; int y = m_y;
       int w = m_width; int h = m_height;
       int font_size = 7; // Compact font
       int row_h = 22; // Reduced row height

       ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
       ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w); ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
       ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, m_bg_color);
       ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

       int cy = y+5;
       ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjStat, OBJPROP_TEXT, "MERKAVA v2.14");
       ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);
       ObjectSetInteger(0, ObjStat, OBJPROP_FONTSIZE, 8);

       // --- Row 1: Lot & Layers (Side by Side) ---
       cy+=20;
       // Lot
       ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "L:");
       ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, m_txt_color);
       ObjectSetInteger(0, ObjLabelLot, OBJPROP_FONTSIZE, font_size);

       ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+20); ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 40); ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 16);
       ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(m_lot_size, 2));
       ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjEditLot, OBJPROP_FONTSIZE, font_size);

       // Layers
       ObjectCreate(0, ObjLabelLayers, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelLayers, OBJPROP_XDISTANCE, x+70); ObjectSetInteger(0, ObjLabelLayers, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelLayers, OBJPROP_TEXT, "N:");
       ObjectSetInteger(0, ObjLabelLayers, OBJPROP_COLOR, m_txt_color);
       ObjectSetInteger(0, ObjLabelLayers, OBJPROP_FONTSIZE, font_size);

       ObjectCreate(0, ObjEditLayers, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_XDISTANCE, x+85); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_XSIZE, 30); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YSIZE, 16);
       ObjectSetString(0, ObjEditLayers, OBJPROP_TEXT, IntegerToString(m_layers));
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLayers, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjEditLayers, OBJPROP_FONTSIZE, font_size);

       // --- Row 2: Mult Start ---
       cy+=row_h;
       ObjectCreate(0, ObjLabelMultStart, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMultStart, OBJPROP_TEXT, "M.Start:");
       ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_COLOR, m_txt_color);
       ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_FONTSIZE, font_size);

       ObjectCreate(0, ObjEditMultStart, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XDISTANCE, x+60); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XSIZE, 55); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YSIZE, 16);
       ObjectSetString(0, ObjEditMultStart, OBJPROP_TEXT, DoubleToString(m_mult_start, 1));
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjEditMultStart, OBJPROP_FONTSIZE, font_size);

       // --- Row 3: Mult Step ---
       cy+=row_h;
       ObjectCreate(0, ObjLabelMultStep, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMultStep, OBJPROP_TEXT, "M.Step:");
       ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_COLOR, m_txt_color);
       ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_FONTSIZE, font_size);

       ObjectCreate(0, ObjEditMultStep, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XDISTANCE, x+60); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XSIZE, 55); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YSIZE, 16);
       ObjectSetString(0, ObjEditMultStep, OBJPROP_TEXT, DoubleToString(m_mult_step, 1));
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjEditMultStep, OBJPROP_FONTSIZE, font_size);

       // --- Row 4: Min Dist ---
       cy+=row_h;
       ObjectCreate(0, ObjLabelMinDist, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjLabelMinDist, OBJPROP_TEXT, "MinDist:");
       ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_COLOR, m_txt_color);
       ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_FONTSIZE, font_size);

       ObjectCreate(0, ObjEditMinDist, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XDISTANCE, x+60); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XSIZE, 55); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YSIZE, 16);
       ObjectSetString(0, ObjEditMinDist, OBJPROP_TEXT, DoubleToString(m_min_dist, 0));
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjEditMinDist, OBJPROP_FONTSIZE, font_size);

       // --- Separator Line ---
       cy+=20;
       ObjectCreate(0, ObjLineSep, OBJ_RECTANGLE_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLineSep, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLineSep, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjLineSep, OBJPROP_XSIZE, w-10); ObjectSetInteger(0, ObjLineSep, OBJPROP_YSIZE, 2);
       ObjectSetInteger(0, ObjLineSep, OBJPROP_BGCOLOR, clrGray);
       ObjectSetInteger(0, ObjLineSep, OBJPROP_BORDER_TYPE, BORDER_FLAT);

       cy+=5; // Margin after line

       // --- Mode Toggle Button ---
       ObjectCreate(0, ObjBtnMode, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XSIZE, w-10); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YSIZE, 22);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_FONTSIZE, font_size);

       // --- Entry Toggle Button ---
       cy+=25;
       ObjectCreate(0, ObjBtnEntry, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XSIZE, w-10); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YSIZE, 22);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_FONTSIZE, font_size);

       // --- Action Type Toggle Button (Solo/Combo) ---
       cy+=25;
       ObjectCreate(0, ObjBtnAction, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnAction, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjBtnAction, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnAction, OBJPROP_XSIZE, w-10); ObjectSetInteger(0, ObjBtnAction, OBJPROP_YSIZE, 22);
       ObjectSetInteger(0, ObjBtnAction, OBJPROP_FONTSIZE, font_size);

       // --- ATTACK BUTTONS (Side by Side) ---
       cy+=30;
       int btn_w = (w-15)/2;

       // BUY Button
       ObjectCreate(0, ObjBtnAttackBuy, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_XSIZE, btn_w); ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_YSIZE, 35);
       ObjectSetString(0, ObjBtnAttackBuy, OBJPROP_TEXT, "BUY");
       ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_BGCOLOR, clrForestGreen); ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, ObjBtnAttackBuy, OBJPROP_FONTSIZE, 8);

       // SELL Button
       ObjectCreate(0, ObjBtnAttackSell, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_XDISTANCE, x+5+btn_w+5); ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_XSIZE, btn_w); ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_YSIZE, 35);
       ObjectSetString(0, ObjBtnAttackSell, OBJPROP_TEXT, "SELL");
       ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_BGCOLOR, clrFireBrick); ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, ObjBtnAttackSell, OBJPROP_FONTSIZE, 8);

       // --- Cease Fire ---
       cy+=40;
       ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, w-10); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, 25);
       ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange); ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_FONTSIZE, font_size);

       // --- PL Label ---
       cy+=30;
       ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+5); ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_FONTSIZE, font_size);

       UpdateButtons(); // Set Initial Text/Color
   }

   void Destroy()
   {
       ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat);
       ObjectDelete(0, ObjBtnAttackBuy); ObjectDelete(0, ObjBtnAttackSell);
       ObjectDelete(0, ObjBtnClear); ObjectDelete(0, ObjLabelPL);
       ObjectDelete(0, ObjBtnMode); ObjectDelete(0, ObjBtnEntry);
       ObjectDelete(0, ObjBtnAction);
       ObjectDelete(0, ObjLineSep); // Delete Line

       ObjectDelete(0, ObjLabelLot); ObjectDelete(0, ObjEditLot);
       ObjectDelete(0, ObjLabelLayers); ObjectDelete(0, ObjEditLayers);
       ObjectDelete(0, ObjLabelMultStart); ObjectDelete(0, ObjEditMultStart);
       ObjectDelete(0, ObjLabelMultStep); ObjectDelete(0, ObjEditMultStep);
       ObjectDelete(0, ObjLabelMinDist); ObjectDelete(0, ObjEditMinDist);
   }

   void UpdateUI(double pl)
   {
       ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "PL: " + DoubleToString(pl, 2));
       ChartRedraw();
   }

   void UpdateButtons() {
        // Strategy Mode
        if(m_fire_mode == FIRE_MODE_STOP) {
            ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: BREAKOUT");
            ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrOrangeRed);
        } else {
            ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: REVERT");
            ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrCornflowerBlue);
        }

        // Entry Mode
        if(m_entry_mode == ENTRY_MARKET) {
            ObjectSetString(0, ObjBtnEntry, OBJPROP_TEXT, "ENTRY: INSTANT");
            ObjectSetInteger(0, ObjBtnEntry, OBJPROP_BGCOLOR, clrRed);
        } else {
            ObjectSetString(0, ObjBtnEntry, OBJPROP_TEXT, "ENTRY: PENDING");
            ObjectSetInteger(0, ObjBtnEntry, OBJPROP_BGCOLOR, clrDimGray);
        }

        // Action Type (Solo vs Combo)
        if(m_action_type == ACTION_SOLO) {
            ObjectSetString(0, ObjBtnAction, OBJPROP_TEXT, "SCOPE: SOLO (Burst)");
            ObjectSetInteger(0, ObjBtnAction, OBJPROP_BGCOLOR, clrPurple);
        } else {
            ObjectSetString(0, ObjBtnAction, OBJPROP_TEXT, "SCOPE: COMBO (Trap)");
            ObjectSetInteger(0, ObjBtnAction, OBJPROP_BGCOLOR, clrTeal);
        }

        ChartRedraw();
   }

   // --- Event Handling ---
   ENUM_PANEL_EVENT OnEvent(int id, long lparam, double dparam, string sparam)
   {
       if(id == CHARTEVENT_OBJECT_CLICK)
       {
          if(sparam == ObjBtnAttackBuy)
          {
             m_attack_dir = ATTACK_BUY;
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_FIRE;
          }
          else if(sparam == ObjBtnAttackSell)
          {
             m_attack_dir = ATTACK_SELL;
             ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
             ChartRedraw();
             Sleep(100);
             ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
             ChartRedraw();
             return EVENT_FIRE;
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
          else if (sparam == ObjBtnAction)
          {
             // Toggle Action Type
             m_action_type = (m_action_type == ACTION_COMBO) ? ACTION_SOLO : ACTION_COMBO;
             UpdateButtons();
             return EVENT_CHANGE_ACTION;
          }
       }
       else if(id == CHARTEVENT_OBJECT_ENDEDIT)
       {
          // Handle Updates & Validation
          if(sparam == ObjEditLot) {
               double val = StringToDouble(ObjectGetString(0, ObjEditLot, OBJPROP_TEXT));
               if(val > 0) m_lot_size = val;
          }
          else if(sparam == ObjEditMultStart) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMultStart, OBJPROP_TEXT));
               if(val > 0) m_mult_start = val;
          }
          else if(sparam == ObjEditMultStep) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMultStep, OBJPROP_TEXT));
               if(val > 0) m_mult_step = val;
          }
          else if(sparam == ObjEditLayers) {
               long val = StringToInteger(ObjectGetString(0, ObjEditLayers, OBJPROP_TEXT));
               if(val > 0 && val < 20) m_layers = (int)val;
          }
          else if(sparam == ObjEditMinDist) {
               double val = StringToDouble(ObjectGetString(0, ObjEditMinDist, OBJPROP_TEXT));
               if(val >= 0) m_min_dist = val;
          }
          return EVENT_PARAM_UPDATE;
       }

       return EVENT_NONE;
   }
};
#endif
