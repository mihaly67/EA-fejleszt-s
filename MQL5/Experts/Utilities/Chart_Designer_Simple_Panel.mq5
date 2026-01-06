//+------------------------------------------------------------------+
//|                             Chart_Designer_Simple_Panel.mq5      |
//|                             Copyright 2026, Jules AI Agent       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property version   "1.00"
#property strict
#property description "Simple Chart Designer Panel - Phase 2 (Grid + Logic)"

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
                     CSimplePanel(void) : m_active_target("") {};
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
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return(false);

   int x = ClientAreaLeft() + 10;
   int y = ClientAreaTop() + 10;
   int w = 80;
   int h = 25;
   int gap = 5;

   // Status Label
   if(!m_lbl_status.Create(m_chart_id, m_name + "Status", m_subwin, x, y, x + 200, y + 20)) return(false);
   m_lbl_status.Text("Select Category first...");
   Add(GetPointer(m_lbl_status));
   y += 25;

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
   y += h + gap + 10;

   // Palette Grid (10x10)
   int p_size = 20;
   int p_gap = 2;
   int start_x = x;

   for(int i=0; i<100; i++) {
      int row = i / 10;
      int col = i % 10;

      int px = start_x + (col * (p_size + p_gap));
      int py = y + (row * (p_size + p_gap));

      CreatePaletteButton(i, px, py, p_size);
   }

   y += (10 * (p_size + p_gap)) + 15;

   // Save Button
   if(!m_btn_save.Create(m_chart_id, m_name+"Save", m_subwin, x, y, x+150, y+30)) return(false);
   m_btn_save.Text("SAVE TEMPLATE");
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);
   Add(GetPointer(m_btn_save));

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
   m_palette[index].Text(" "); // Space needed for visibility
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   Add(GetPointer(m_palette[index]));
   // Re-apply background color after adding to dialog ensures visibility
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
   if(m_active_target == "BG")        ChartSetInteger(chart, CHART_COLOR_BACKGROUND, c);
   if(m_active_target == "GRID")      ChartSetInteger(chart, CHART_COLOR_GRID, c);
   if(m_active_target == "TEXT")      ChartSetInteger(chart, CHART_COLOR_FOREGROUND, c);
   if(m_active_target == "BULL_BODY") ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, c);
   if(m_active_target == "BEAR_BODY") ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, c);
   if(m_active_target == "BULL_WICK") ChartSetInteger(chart, CHART_COLOR_CHART_UP, c);
   if(m_active_target == "BEAR_WICK") ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, c);

   ChartRedraw(chart);
   UpdateStatus("Applied: " + m_active_target);
}

//+------------------------------------------------------------------+
//| OnEvent                                                          |
//+------------------------------------------------------------------+
bool CSimplePanel::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
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
               UpdateStatus("Select Category First!");
               return(true);
            }
            ApplyColor(PALETTE_COLORS[i]);
            return(true);
         }
      }

      // Save
      if(sparam == m_btn_save.Name()) {
         if(ChartSaveTemplate(0, "default.tpl")) MessageBox("Default Template Saved!", "Success", MB_OK);
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
   // Panel size
   int width = 280;
   int height = 500;

   // Create the panel
   if(!ExtDialog.Create(0, "SimplePanel", 0, InpPanelX, InpPanelY, InpPanelX + width, InpPanelY + height))
      return(INIT_FAILED);

   // Run the panel
   ExtDialog.Run();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ExtDialog.Destroy(reason);
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
