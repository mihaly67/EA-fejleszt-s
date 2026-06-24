//+------------------------------------------------------------------+
//|                                             PanelControl_v2_13.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.13  |
//+------------------------------------------------------------------+
#ifndef PANELCONTROL_V2_13_MQH
#define PANELCONTROL_V2_13_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_13.mqh" // For Enums

// --- Panel Events ---
enum ENUM_PANEL_EVENT
{
   EVENT_NONE = 0,
   EVENT_FIRE,
   EVENT_CEASE_FIRE,
   EVENT_CHANGE_MODE,
   EVENT_CHANGE_ENTRY,
   EVENT_PARAM_UPDATE
};

//+------------------------------------------------------------------+
//| Class CPanelControl                                              |
//| Handles the GUI (Buttons, Inputs) for the Merkava EA.            |
//| Encapsulates object creation, events, and state.                 |
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

   // Current State (Values)
   double      m_lot_size;
   double      m_mult_start;
   double      m_mult_step;
   int         m_layers;
   double      m_min_dist;
   ENUM_FIRE_MODE m_fire_mode;
   ENUM_ENTRY_MODE m_entry_mode;

public:
   CPanelControl() {
       m_prefix = "Merkava_";
       m_fire_mode = FIRE_MODE_STOP;
       m_entry_mode = ENTRY_PENDING;
   }
   ~CPanelControl() {}

   void Init(string prefix, int x, int y, color bg, color txt,
             double def_lot, double def_start, double def_step, int def_layers, double def_min_dist)
   {
      m_prefix = prefix;
      m_x = x; m_y = y;
      m_bg_color = bg; m_txt_color = txt;
      m_width = 160; m_height = 380; // Standard v2.13 Height

      // Initialize State
      m_lot_size = def_lot;
      m_mult_start = def_start;
      m_mult_step = def_step;
      m_layers = def_layers;
      m_min_dist = def_min_dist;
      m_fire_mode = FIRE_MODE_STOP; // Default: Breakout
      m_entry_mode = ENTRY_PENDING; // Default: Pending

      // Define Object Names
      ObjBG = m_prefix + "BG";
      ObjStat = m_prefix + "Status";
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
   }

   // --- Getters ---
   double GetLotSize() const { return m_lot_size; }
   double GetMultStart() const { return m_mult_start; }
   double GetMultStep() const { return m_mult_step; }
   int    GetLayers() const { return m_layers; }
   double GetMinDist() const { return m_min_dist; }
   ENUM_FIRE_MODE GetFireMode() const { return m_fire_mode; }
   ENUM_ENTRY_MODE GetEntryMode() const { return m_entry_mode; }

   // --- Core Methods ---
   void Create()
   {
       int x = m_x; int y = m_y;
       int w = m_width; int h = m_height;

       ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
       ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w); ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
       ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, m_bg_color);

       int cy = y+10;
       ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
       ObjectSetString(0, ObjStat, OBJPROP_TEXT, "MERKAVA v2.13");
       ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);

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

       // --- Mode Toggle Button (Breakout/Limit) ---
       cy+=30;
       ObjectCreate(0, ObjBtnMode, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YSIZE, 30);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_FONTSIZE, 8);

       // --- Entry Toggle Button (Pending/Market) ---
       cy+=35;
       ObjectCreate(0, ObjBtnEntry, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YSIZE, 30);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_FONTSIZE, 8);

       // --- Fire Button ---
       cy+=40;
       ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, 40);
       ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE GRID");
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed); ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);

       // --- Cease Fire ---
       cy+=50;
       ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, 30);
       ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange); ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);

       // --- PL Label ---
       cy+=40;
       ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);

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
   }

   void UpdateUI(double pl)
   {
       ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "PL: " + DoubleToString(pl, 2));
       ChartRedraw();
   }

   void UpdateButtons() {
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
