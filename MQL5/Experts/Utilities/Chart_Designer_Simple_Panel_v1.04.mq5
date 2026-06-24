//+------------------------------------------------------------------+
//|                             Chart_Designer_Simple_Panel_v1.04.mq5 |
//|                             Copyright 2026, Jules AI Agent       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property version   "1.04"
#property strict
#property description "Simple Chart Designer Panel - v1.04 Fixed Event Handling"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

input int InpPanelX = 60;  // Panel X Position
input int InpPanelY = 100; // Panel Y Position (Moved up to avoid bottom overlap)

//--- Expanded Color Palette (100 Colors) - Soft Professional & Gradients
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
//| Class CSimplePanel                                               |
//+------------------------------------------------------------------+
class CSimplePanel : public CAppDialog
{
private:
   CLabel            m_lbl_status;

   // Categories
   CButton           m_btn_bg;
   CButton           m_btn_grid;
   CButton           m_btn_bull_body;
   CButton           m_btn_bear_body;
   CButton           m_btn_bull_wick;
   CButton           m_btn_bear_wick;
   CButton           m_btn_text;

   // Palette Grid
   CButton           m_palette[100];

   // Action
   CButton           m_btn_save;

   // State
   string            m_active_target;

public:
                     CSimplePanel(void) : m_active_target("BG") {}; // Default to Background
                    ~CSimplePanel(void) {};
   virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);
   virtual bool      OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

protected:
   // Helpers based on TradingPanel.mqh pattern
   bool              CreateButton(CButton &object, const string text, const int x, const int y, const int w, const int h);
   bool              CreateLabel(CLabel &object, const string text, const int x, const int y);
   bool              CreatePaletteButton(int index, int x, int y, int size);

   void              UpdateStatus(string text);
   void              ApplyColor(color c);
};

//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CSimplePanel::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   Print("Initializing SimplePanel v1.04...");
   // Using CAppDialog::Create (Parent call)
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) {
      Print("Error: Failed to create CAppDialog!");
      return(false);
   }

   // Dynamic Layout Calculation based on ClientArea
   int x = ClientAreaLeft() + 5;
   int y = ClientAreaTop() + 5;
   int w = 75;
   int h = 20;
   int gap = 2;

   // Status Label
   if(!CreateLabel(m_lbl_status, "Default: Background", x, y)) return(false);
   m_lbl_status.Color(clrBlack); // Ensure visibility
   y += 20;

   // Categories Row 1
   if(!CreateButton(m_btn_bg, "BackGnd", x, y, w, h)) return(false);
   if(!CreateButton(m_btn_grid, "Grid", x+w+gap, y, w, h)) return(false);
   if(!CreateButton(m_btn_text, "Text", x+(w+gap)*2, y, w, h)) return(false);
   y += h + gap;

   // Categories Row 2 (Bull)
   if(!CreateButton(m_btn_bull_body, "Bull Body", x, y, w, h)) return(false);
   if(!CreateButton(m_btn_bull_wick, "Bull Wick", x+w+gap, y, w, h)) return(false);
   y += h + gap;

   // Categories Row 3 (Bear)
   if(!CreateButton(m_btn_bear_body, "Bear Body", x, y, w, h)) return(false);
   if(!CreateButton(m_btn_bear_wick, "Bear Wick", x+w+gap, y, w, h)) return(false);
   y += h + gap + 5;

   // Palette Grid (10x10) - Compact
   int p_size = 18;
   int p_gap = 1;
   int start_x = x;

   for(int i=0; i<100; i++) {
      int row = i / 10;
      int col = i % 10;

      int px = start_x + (col * (p_size + p_gap));
      int py = y + (row * (p_size + p_gap));

      if(!CreatePaletteButton(i, px, py, p_size)) return(false);
   }

   y += (10 * (p_size + p_gap)) + 10;

   // Save Button
   if(!CreateButton(m_btn_save, "SAVE TEMPLATE", x, y, 150, 25)) return(false);
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);

   Print("SimplePanel Created Successfully.");
   return(true);
}

//+------------------------------------------------------------------+
//| Helper: CreateButton (Modeled after TradingPanel.mqh)            |
//+------------------------------------------------------------------+
bool CSimplePanel::CreateButton(CButton &object, const string text, const int x, const int y, const int w, const int h)
{
   // NOTE: We use m_chart_id and m_subwin from the parent class
   string name = m_name + "Btn_" + text; // Simple unique name generation

   if(!object.Create(m_chart_id, name, m_subwin, x, y, x+w, y+h)) return false;
   if(!object.Text(text)) return false;
   object.Locking(false); // CRITICAL: As seen in TradingPanel.mqh
   if(!Add(object)) return false; // CRITICAL: Register with container
   return true;
}

//+------------------------------------------------------------------+
//| Helper: CreateLabel                                              |
//+------------------------------------------------------------------+
bool CSimplePanel::CreateLabel(CLabel &object, const string text, const int x, const int y)
{
   string name = m_name + "Lbl_" + text;
   if(!object.Create(m_chart_id, name, m_subwin, x, y, x+200, y+20)) return false; // Fixed width for label
   if(!object.Text(text)) return false;
   if(!Add(object)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Helper: CreatePaletteButton                                      |
//+------------------------------------------------------------------+
bool CSimplePanel::CreatePaletteButton(int index, int x, int y, int size)
{
   string name = m_name + "Pal_" + IntegerToString(index);
   if(!m_palette[index].Create(m_chart_id, name, m_subwin, x, y, x+size, y+size)) return false;

   m_palette[index].Text(" "); // Must be space, not empty
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   m_palette[index].Locking(false); // CRITICAL

   if(!Add(m_palette[index])) return false;

   // Force show to be safe
   m_palette[index].Show();
   // Re-apply color after show (Standard Library quirk prevention)
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);

   return true;
}

void CSimplePanel::UpdateStatus(string text)
{
   m_lbl_status.Text(text);
}

void CSimplePanel::ApplyColor(color c)
{
   long chart = ChartID();
   bool res = false;
   if(m_active_target == "BG")        res = ChartSetInteger(chart, CHART_COLOR_BACKGROUND, c);
   if(m_active_target == "GRID")      res = ChartSetInteger(chart, CHART_COLOR_GRID, c);
   if(m_active_target == "TEXT")      res = ChartSetInteger(chart, CHART_COLOR_FOREGROUND, c);
   if(m_active_target == "BULL_BODY") res = ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, c);
   if(m_active_target == "BEAR_BODY") res = ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, c);
   if(m_active_target == "BULL_WICK") res = ChartSetInteger(chart, CHART_COLOR_CHART_UP, c);
   if(m_active_target == "BEAR_WICK") res = ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, c);

   ChartRedraw(chart);
   Print("ApplyColor [", m_active_target, "] -> ", c, " Success: ", res);
   UpdateStatus("Set " + m_active_target + " to " + (string)c);
}

//+------------------------------------------------------------------+
//| OnEvent (Fixed Hybrid Logic)                                     |
//+------------------------------------------------------------------+
bool CSimplePanel::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // 1. Process Parent Events (Visual Updates)
   // We store the result but DO NOT return immediately, to allow custom logic execution.
   bool parent_handled = CAppDialog::OnEvent(id, lparam, dparam, sparam);

   bool custom_handled = false;

   // 2. Custom Click Logic
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Check Categories (Static comparison)
      if(sparam == m_btn_bg.Name())        { m_active_target="BG"; UpdateStatus("Target: Background"); custom_handled=true; }
      else if(sparam == m_btn_grid.Name())      { m_active_target="GRID"; UpdateStatus("Target: Grid"); custom_handled=true; }
      else if(sparam == m_btn_text.Name())      { m_active_target="TEXT"; UpdateStatus("Target: Text"); custom_handled=true; }
      else if(sparam == m_btn_bull_body.Name()) { m_active_target="BULL_BODY"; UpdateStatus("Target: Bull Body"); custom_handled=true; }
      else if(sparam == m_btn_bear_body.Name()) { m_active_target="BEAR_BODY"; UpdateStatus("Target: Bear Body"); custom_handled=true; }
      else if(sparam == m_btn_bull_wick.Name()) { m_active_target="BULL_WICK"; UpdateStatus("Target: Bull Wick"); custom_handled=true; }
      else if(sparam == m_btn_bear_wick.Name()) { m_active_target="BEAR_WICK"; UpdateStatus("Target: Bear Wick"); custom_handled=true; }

      // Check Save
      else if(sparam == m_btn_save.Name()) {
         bool saved = ChartSaveTemplate(0, "default.tpl");
         Print("Template Saved: ", saved);
         if(saved) MessageBox("Default Template Saved!", "Success", MB_OK);
         else MessageBox("Failed to Save!", "Error", MB_ICONERROR);
         custom_handled=true;
      }

      // Check Palette (Dynamic Array)
      // Optimization: Check prefix "Pal_" first
      else if(StringFind(sparam, "Pal_") >= 0) {
         // Loop to find exact match
         for(int i=0; i<100; i++) {
            if(sparam == m_palette[i].Name()) {
               ApplyColor(PALETTE_COLORS[i]);
               custom_handled=true;
               break;
            }
         }
      }
   }

   // Return true if either parent or custom logic did something
   return (parent_handled || custom_handled);
}

// Global Instance
CSimplePanel ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Compact Panel size
   int width = 260;
   int height = 380;

   Print("OnInit: Starting Chart_Designer_Simple_Panel v1.04...");

   // Create the panel
   if(!ExtDialog.Create(0, "SimplePanel_v104", 0, InpPanelX, InpPanelY, InpPanelX + width, InpPanelY + height)) {
      Print("OnInit: Failed to create dialog.");
      return(INIT_FAILED);
   }

   // Run the panel
   ExtDialog.Run();
   Print("OnInit: Panel Running.");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ExtDialog.Destroy(reason);
   Print("OnDeinit: Panel Destroyed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);
}
