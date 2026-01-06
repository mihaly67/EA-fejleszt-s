//+------------------------------------------------------------------+
//|                             Chart_Designer_Simple_Panel_v1.03.mq5 |
//|                             Copyright 2026, Jules AI Agent       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property version   "1.03"
#property strict
#property description "Simple Chart Designer Panel - v1.03 Logging Edition"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

input int InpPanelX = 60;  // Panel X Position
input int InpPanelY = 300; // Panel Y Position

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
   bool              CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h);
   bool              CreatePaletteButton(int index, int x, int y, int size);
   void              UpdateStatus(string text);
   void              ApplyColor(color c);
};

//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CSimplePanel::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   Print("Initializing SimplePanel...");
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) {
      Print("Error: Failed to create CAppDialog!");
      return(false);
   }

   int x = ClientAreaLeft() + 5;
   int y = ClientAreaTop() + 5;
   int w = 75;  // Slightly reduced width
   int h = 20;  // Reduced height (Compact Mode)
   int gap = 2; // Reduced gap

   // Status Label
   if(!m_lbl_status.Create(m_chart_id, m_name + "Status", m_subwin, x, y, x + 250, y + 20)) return(false);
   m_lbl_status.Text("Default: Background"); // Inform user about default state
   Add(GetPointer(m_lbl_status));
   y += 20;

   // Categories Row 1
   CreateCategoryButton(m_btn_bg, "BtnBG", "BackGnd", x, y, w, h);
   CreateCategoryButton(m_btn_grid, "BtnGrid", "Grid", x+w+gap, y, w, h);
   CreateCategoryButton(m_btn_text, "BtnText", "Text", x+(w+gap)*2, y, w, h);
   y += h + gap;

   // Categories Row 2 (Bull)
   CreateCategoryButton(m_btn_bull_body, "BtnBullB", "Bull Body", x, y, w, h);
   CreateCategoryButton(m_btn_bull_wick, "BtnBullW", "Bull Wick", x+w+gap, y, w, h);
   y += h + gap;

   // Categories Row 3 (Bear)
   CreateCategoryButton(m_btn_bear_body, "BtnBearB", "Bear Body", x, y, w, h);
   CreateCategoryButton(m_btn_bear_wick, "BtnBearW", "Bear Wick", x+w+gap, y, w, h);
   y += h + gap + 5;

   // Palette Grid (10x10) - Compact
   int p_size = 18; // Reduced size
   int p_gap = 1;   // Minimal gap
   int start_x = x;

   for(int i=0; i<100; i++) {
      int row = i / 10;
      int col = i % 10;

      int px = start_x + (col * (p_size + p_gap));
      int py = y + (row * (p_size + p_gap));

      CreatePaletteButton(i, px, py, p_size);
   }

   y += (10 * (p_size + p_gap)) + 10;

   // Save Button
   if(!m_btn_save.Create(m_chart_id, m_name+"Save", m_subwin, x, y, x+150, y+25)) return(false);
   m_btn_save.Text("SAVE TEMPLATE");
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);
   Add(GetPointer(m_btn_save));

   Print("SimplePanel Created Successfully.");
   return(true);
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool CSimplePanel::CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h)
{
   if(!btn.Create(m_chart_id, m_name+name, m_subwin, x, y, x+w, y+h)) return(false);
   btn.Text(text);
   Add(GetPointer(btn));
   return(true);
}

bool CSimplePanel::CreatePaletteButton(int index, int x, int y, int size)
{
   if(!m_palette[index].Create(m_chart_id, m_name+"Pal"+IntegerToString(index), m_subwin, x, y, x+size, y+size)) return(false);

   m_palette[index].Text(" ");
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   Add(GetPointer(m_palette[index]));

   // Force Visibility
   m_palette[index].Show();
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);

   return(true);
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
//| OnEvent                                                          |
//+------------------------------------------------------------------+
bool CSimplePanel::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Debug Print
      Print("Click Event: ", sparam);

      // Category Selection
      if(sparam == m_btn_bg.Name())        { m_active_target="BG"; UpdateStatus("Editing: Background"); return(true); }
      if(sparam == m_btn_grid.Name())      { m_active_target="GRID"; UpdateStatus("Editing: Grid"); return(true); }
      if(sparam == m_btn_text.Name())      { m_active_target="TEXT"; UpdateStatus("Editing: Text"); return(true); }
      if(sparam == m_btn_bull_body.Name()) { m_active_target="BULL_BODY"; UpdateStatus("Editing: Bull Body"); return(true); }
      if(sparam == m_btn_bear_body.Name()) { m_active_target="BEAR_BODY"; UpdateStatus("Editing: Bear Body"); return(true); }
      if(sparam == m_btn_bull_wick.Name()) { m_active_target="BULL_WICK"; UpdateStatus("Editing: Bull Wick"); return(true); }
      if(sparam == m_btn_bear_wick.Name()) { m_active_target="BEAR_WICK"; UpdateStatus("Editing: Bear Wick"); return(true); }

      // Palette Selection
      for(int i=0; i<100; i++) {
         if(sparam == m_palette[i].Name()) {
            if(m_active_target == "") {
               Print("Click ignored: No category selected.");
               UpdateStatus("Select Category First!");
               return(true);
            }
            ApplyColor(PALETTE_COLORS[i]);
            return(true);
         }
      }

      // Save
      if(sparam == m_btn_save.Name()) {
         bool saved = ChartSaveTemplate(0, "default.tpl");
         Print("Save Template 'default.tpl': ", saved);
         if(saved) MessageBox("Default Template Saved!", "Success", MB_OK);
         else MessageBox("Failed to Save!", "Error", MB_ICONERROR);
         return(true);
      }
   }
   return(CAppDialog::OnEvent(id, lparam, dparam, sparam));
}

// Global Instance
CSimplePanel ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Compact Panel size
   int width = 260; // Slightly narrower
   int height = 380; // Significantly shorter (was 500)

   Print("OnInit: Starting Chart_Designer_Simple_Panel v1.03...");

   // Create the panel
   if(!ExtDialog.Create(0, "SimplePanel", 0, InpPanelX, InpPanelY, InpPanelX + width, InpPanelY + height)) {
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
