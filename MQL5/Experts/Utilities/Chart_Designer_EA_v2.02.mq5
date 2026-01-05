//+------------------------------------------------------------------+
//|                                     Chart_Designer_EA_v2.03.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.03"
#property description "GUI Panel to design and save chart themes dynamically. Pro Palette Edition."
#property strict

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

//--- Configuration File Name
#define CONFIG_FILENAME "ChartDesigner_Config.bin"

//--- Expanded Color Palette (100 Colors) - Soft Professional & Gradients
// Organized in rows of 10 for the grid
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

//--- Theme Structure for Persistence
struct ChartTheme {
   color bg_color;
   color grid_color;
   color bull_body;
   color bear_body;
   color bull_wick;
   color bear_wick;
   color text_color;
   int   show_grid;
   int   show_ohlc;
   int   show_period_sep;
   int   show_bid;
   int   show_ask;
};

//+------------------------------------------------------------------+
//| Class CChartDesignerPanel                                        |
//+------------------------------------------------------------------+
class CChartDesignerPanel : public CAppDialog
  {
private:
   CLabel            m_lbl_status;

   // Category Selection Buttons
   CButton           m_btn_bg;
   CButton           m_btn_grid;
   CButton           m_btn_bull_body;
   CButton           m_btn_bear_body;
   CButton           m_btn_bull_wick;
   CButton           m_btn_bear_wick;
   CButton           m_btn_text;

   // Toggle Buttons
   CButton           m_tog_grid;
   CButton           m_tog_ohlc;
   CButton           m_tog_sep;

   // Palette Buttons (100 Colors)
   CButton           m_palette[100];
   CButton           m_btn_close_palette;

   // Action Buttons
   CButton           m_btn_save_tpl;
   CButton           m_btn_close_panel;

   // State
   string            m_active_target;
   ChartTheme        m_theme;

   // Layout
   int               m_base_x;
   int               m_base_y;

public:
                     CChartDesignerPanel(void);
                    ~CChartDesignerPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);

   void              LoadConfiguration();
   void              SaveConfiguration();
   void              ApplyToChart();

private:
   bool              CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h);
   bool              CreatePaletteButton(int index, int x, int y, int size);
   void              ShowPalette(bool show);
   void              OnPaletteClick(color c);
   void              UpdateStatus(string text);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChartDesignerPanel::CChartDesignerPanel(void) : m_active_target("")
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChartDesignerPanel::~CChartDesignerPanel(void)
  {
  }

//+------------------------------------------------------------------+
//| Create the Panel                                                 |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2)) return(false);

   m_base_x = x1;
   m_base_y = y1;

   int x = 10;
   int y = 30; // Title bar offset
   int w = 90;
   int h = 25;
   int gap = 5;

   //--- Status Label
   if(!m_lbl_status.Create(chart,name+"Status",subwin, m_base_x + x, m_base_y + y, m_base_x + x + 250, m_base_y + y + 20)) return(false);
   m_lbl_status.Text("Select an element to color...");
   Add(m_lbl_status);
   y += 25;

   //--- Row 1: BG & Grid
   CreateCategoryButton(m_btn_bg, "BtnBG", "Background", m_base_x + x, m_base_y + y, w, h);
   CreateCategoryButton(m_btn_grid, "BtnGrid", "Grid Color", m_base_x + x+w+gap, m_base_y + y, w, h);
   y += h + gap;

   //--- Row 2: Bodies
   CreateCategoryButton(m_btn_bull_body, "BtnBullBody", "Bull Body", m_base_x + x, m_base_y + y, w, h);
   CreateCategoryButton(m_btn_bear_body, "BtnBearBody", "Bear Body", m_base_x + x+w+gap, m_base_y + y, w, h);
   y += h + gap;

   //--- Row 3: Wicks
   CreateCategoryButton(m_btn_bull_wick, "BtnBullWick", "Bull Wick", m_base_x + x, m_base_y + y, w, h);
   CreateCategoryButton(m_btn_bear_wick, "BtnBearWick", "Bear Wick", m_base_x + x+w+gap, m_base_y + y, w, h);
   y += h + gap;

   //--- Row 4: Text
   CreateCategoryButton(m_btn_text, "BtnText", "Text/Fg", m_base_x + x, m_base_y + y, w, h);
   y += h + gap + 10;

   //--- Palette Area (100 Colors - 10x10 Grid)
   int p_size = 22; // Smaller size to fit
   int p_gap = 2;
   int start_y = y;

   for(int i=0; i<100; i++) {
      int row = i / 10; // 10 columns
      int col = i % 10;

      int abs_px = m_base_x + x + (col * (p_size + p_gap));
      int abs_py = m_base_y + start_y + (row * (p_size + p_gap));

      CreatePaletteButton(i, abs_px, abs_py, p_size);
   }

   // Palette Close Button
   int close_x = m_base_x + x + (10*(p_size+p_gap)) + 5;
   int close_y = m_base_y + start_y;
   if(!m_btn_close_palette.Create(chart, m_name+"PalClose", subwin, close_x, close_y, close_x + 20, close_y + 20)) return(false);
   m_btn_close_palette.Text("X");
   m_btn_close_palette.ColorBackground(clrRed);
   m_btn_close_palette.Color(clrWhite);
   Add(m_btn_close_palette);

   y += (10 * (p_size + p_gap)) + 15;

   //--- Toggles
   CreateCategoryButton(m_tog_grid, "TogGrid", "Grid: ON", m_base_x + x, m_base_y + y, 60, h);
   CreateCategoryButton(m_tog_ohlc, "TogOHLC", "OHLC: ON", m_base_x + x+65, m_base_y + y, 60, h);
   CreateCategoryButton(m_tog_sep, "TogSep", "Sep: ON", m_base_x + x+130, m_base_y + y, 60, h);
   y += h + gap;

   //--- Save Button
   if(!m_btn_save_tpl.Create(chart,name+"BtnSave",subwin, m_base_x + x, m_base_y + y, m_base_x + x+190, m_base_y + y+30)) return(false);
   m_btn_save_tpl.Text("SAVE DEFAULT.TPL");
   m_btn_save_tpl.ColorBackground(clrDarkBlue);
   m_btn_save_tpl.Color(clrWhite);
   Add(m_btn_save_tpl);

   // Initialize State
   ShowPalette(false);
   LoadConfiguration();
   ApplyToChart();

   return(true);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h)
  {
   if(!btn.Create(ChartID(), m_name+name, 0, x, y, x+w, y+h)) return(false);
   btn.Text(text);
   Add(btn);
   return(true);
  }

bool CChartDesignerPanel::CreatePaletteButton(int index, int x, int y, int size)
  {
   if(!m_palette[index].Create(ChartID(), m_name+"Pal"+IntegerToString(index), 0, x, y, x+size, y+size)) return(false);
   m_palette[index].Text(""); // Space to ensure clickability? User said text empty is ok but visibility...
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   Add(m_palette[index]);
   return(true);
  }

void CChartDesignerPanel::ShowPalette(bool show)
  {
   for(int i=0; i<100; i++) {
      if(show) {
         m_palette[i].Show();
         m_palette[i].BringToTop();
      }
      else m_palette[i].Hide();
   }
   if(show) {
      m_btn_close_palette.Show();
      m_btn_close_palette.BringToTop();
   } else {
      m_btn_close_palette.Hide();
   }
   ChartRedraw(ChartID());
  }

//+------------------------------------------------------------------+
//| Event Handler                                                    |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK) {

      // Category Logic
      if(sparam == m_btn_bg.Name())        { m_active_target="BG"; ShowPalette(true); UpdateStatus("Set Background Color..."); return(true); }
      if(sparam == m_btn_grid.Name())      { m_active_target="GRID"; ShowPalette(true); UpdateStatus("Set Grid Color..."); return(true); }
      if(sparam == m_btn_bull_body.Name()) { m_active_target="BULL_BODY"; ShowPalette(true); UpdateStatus("Set Bull Body Color..."); return(true); }
      if(sparam == m_btn_bear_body.Name()) { m_active_target="BEAR_BODY"; ShowPalette(true); UpdateStatus("Set Bear Body Color..."); return(true); }
      if(sparam == m_btn_bull_wick.Name()) { m_active_target="BULL_WICK"; ShowPalette(true); UpdateStatus("Set Bull Wick Color..."); return(true); }
      if(sparam == m_btn_bear_wick.Name()) { m_active_target="BEAR_WICK"; ShowPalette(true); UpdateStatus("Set Bear Wick Color..."); return(true); }
      if(sparam == m_btn_text.Name())      { m_active_target="TEXT"; ShowPalette(true); UpdateStatus("Set Text Color..."); return(true); }

      if(sparam == m_btn_close_palette.Name()) { ShowPalette(false); UpdateStatus("Palette Closed."); return(true); }

      // Palette Logic
      for(int i=0; i<100; i++) {
         if(sparam == m_palette[i].Name()) {
            OnPaletteClick(PALETTE_COLORS[i]);
            return(true);
         }
      }

      // Toggles
      if(sparam == m_tog_grid.Name()) { m_theme.show_grid = !m_theme.show_grid; ApplyToChart(); SaveConfiguration(); return(true); }
      if(sparam == m_tog_ohlc.Name()) { m_theme.show_ohlc = !m_theme.show_ohlc; ApplyToChart(); SaveConfiguration(); return(true); }
      if(sparam == m_tog_sep.Name())  { m_theme.show_period_sep = !m_theme.show_period_sep; ApplyToChart(); SaveConfiguration(); return(true); }

      // Save
      if(sparam == m_btn_save_tpl.Name()) {
         if(ChartSaveTemplate(0, "default.tpl")) MessageBox("Template 'default.tpl' Saved!", "Success", MB_OK);
         else MessageBox("Failed to save template.", "Error", MB_ICONERROR);
         return(true);
      }
   }
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

void CChartDesignerPanel::OnPaletteClick(color c)
  {
   if(m_active_target == "BG") m_theme.bg_color = c;
   else if(m_active_target == "GRID") m_theme.grid_color = c;
   else if(m_active_target == "BULL_BODY") m_theme.bull_body = c;
   else if(m_active_target == "BEAR_BODY") m_theme.bear_body = c;
   else if(m_active_target == "BULL_WICK") m_theme.bull_wick = c;
   else if(m_active_target == "BEAR_WICK") m_theme.bear_wick = c;
   else if(m_active_target == "TEXT") m_theme.text_color = c;

   ApplyToChart();
   SaveConfiguration();
   ShowPalette(false);
   m_active_target = "";
   UpdateStatus("Color Applied.");
  }

void CChartDesignerPanel::UpdateStatus(string text)
  {
   m_lbl_status.Text(text);
  }

void CChartDesignerPanel::ApplyToChart()
  {
   long chart = ChartID();
   ChartSetInteger(chart, CHART_COLOR_BACKGROUND, m_theme.bg_color);
   ChartSetInteger(chart, CHART_COLOR_GRID, m_theme.grid_color);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, m_theme.bull_body);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, m_theme.bear_body);
   ChartSetInteger(chart, CHART_COLOR_CHART_UP, m_theme.bull_wick);
   ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, m_theme.bear_wick);
   ChartSetInteger(chart, CHART_COLOR_FOREGROUND, m_theme.text_color);
   ChartSetInteger(chart, CHART_SHOW_GRID, (long)m_theme.show_grid);
   ChartSetInteger(chart, CHART_SHOW_OHLC, (long)m_theme.show_ohlc);
   ChartSetInteger(chart, CHART_SHOW_PERIOD_SEP, (long)m_theme.show_period_sep);
   ChartSetInteger(chart, CHART_MODE, CHART_CANDLES);
   m_tog_grid.Text(m_theme.show_grid ? "Grid: ON" : "Grid: OFF");
   m_tog_ohlc.Text(m_theme.show_ohlc ? "OHLC: ON" : "OHLC: OFF");
   m_tog_sep.Text(m_theme.show_period_sep ? "Sep: ON" : "Sep: OFF");
   ChartRedraw(chart);
  }

void CChartDesignerPanel::LoadConfiguration()
  {
   m_theme.bg_color = C'20,20,20';
   m_theme.grid_color = clrDimGray;
   m_theme.bull_body = clrForestGreen;
   m_theme.bear_body = clrFireBrick;
   m_theme.bull_wick = clrForestGreen;
   m_theme.bear_wick = clrFireBrick;
   m_theme.text_color = clrWhite;
   m_theme.show_grid = 0;
   m_theme.show_ohlc = 1;
   m_theme.show_period_sep = 1;

   int handle = FileOpen(CONFIG_FILENAME, FILE_READ|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      if(FileReadStruct(handle, m_theme) > 0) Print("Config loaded.");
      FileClose(handle);
   }
  }

void CChartDesignerPanel::SaveConfiguration()
  {
   int handle = FileOpen(CONFIG_FILENAME, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      FileWriteStruct(handle, m_theme);
      FileClose(handle);
   }
  }

CChartDesignerPanel ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Dynamic Positioning: Top-Right
   long chart_w = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   // Panel Width approx 300px
   int width = 280;
   int height = 550; // Taller for 100 colors

   // Position at Top Right: x = Width - PanelWidth - Margin
   int x1 = (int)chart_w - width - 10;
   int y1 = 40; // Top margin

   if(x1 < 0) x1 = 10; // Safety for small windows

   if(!ExtDialog.Create(0,"ChartDesigner",0,x1,y1,x1+width,y1+height))
      return(INIT_FAILED);

   ExtDialog.Run();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ExtDialog.Destroy(reason);
  }

void OnTick()
  {
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }
