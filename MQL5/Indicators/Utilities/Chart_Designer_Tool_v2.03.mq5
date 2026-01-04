//+------------------------------------------------------------------+
//|                                   Chart_Designer_Tool_v2.03.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.03"
#property description "GUI Panel to design and save chart themes dynamically."
#property indicator_chart_window
#property indicator_plots 0
#property strict

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

//--- Configuration File Name
#define CONFIG_FILENAME "ChartDesigner_Config.bin"
#define TOOL_SHORTNAME "ChartDesignerTool"

//--- Color Palette Array (25 Colors)
color PALETTE_COLORS[25] = {
   clrBlack, clrDimGray, clrGray, clrSilver, clrWhite,
   clrMaroon, clrFireBrick, clrRed, clrTomato, clrSalmon,
   clrDarkGreen, clrForestGreen, clrGreen, clrLimeGreen, clrLime,
   clrMidnightBlue, clrNavy, clrBlue, clrRoyalBlue, clrDodgerBlue,
   clrIndigo, clrBlueViolet, clrMagenta, clrDeepPink, clrGold
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

   // Palette Buttons (5x5 Grid)
   CButton           m_palette[25];

   // Action Buttons
   CButton           m_btn_save_tpl;
   CButton           m_btn_close;

   // State
   string            m_active_target;
   ChartTheme        m_theme;

public:
                     CChartDesignerPanel(void);
                    ~CChartDesignerPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);

   void              LoadConfiguration();
   void              SaveConfiguration();
   void              ApplyToChart();
   void              SelfDestruct();

private:
   bool              CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h);
   bool              CreatePaletteButton(int index, int x, int y, int size);
   void              ShowPalette(bool show);
   void              OnPaletteClick(color c);
   void              UpdateStatus(string text);
  };

CChartDesignerPanel::CChartDesignerPanel(void) : m_active_target("") {}
CChartDesignerPanel::~CChartDesignerPanel(void) {}

//+------------------------------------------------------------------+
//| Create the Panel                                                 |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2)) return(false);

   int x = x1 + 10;
   int y = y1 + 40;
   int w = 90;
   int h = 25;
   int gap = 5;

   //--- Status Label
   if(!m_lbl_status.Create(chart,name+"Status",subwin,x,y,x+200,y+20)) return(false);
   m_lbl_status.Text("Select an element to color...");
   Add(m_lbl_status);
   y += 25;

   //--- Row 1: BG & Grid
   CreateCategoryButton(m_btn_bg, "BtnBG", "Background", x, y, w, h);
   CreateCategoryButton(m_btn_grid, "BtnGrid", "Grid Color", x+w+gap, y, w, h);
   y += h + gap;

   //--- Row 2: Bodies
   CreateCategoryButton(m_btn_bull_body, "BtnBullBody", "Bull Body", x, y, w, h);
   CreateCategoryButton(m_btn_bear_body, "BtnBearBody", "Bear Body", x+w+gap, y, w, h);
   y += h + gap;

   //--- Row 3: Wicks
   CreateCategoryButton(m_btn_bull_wick, "BtnBullWick", "Bull Wick", x, y, w, h);
   CreateCategoryButton(m_btn_bear_wick, "BtnBearWick", "Bear Wick", x+w+gap, y, w, h);
   y += h + gap;

   //--- Row 4: Text
   CreateCategoryButton(m_btn_text, "BtnText", "Text/Fg", x, y, w, h);
   y += h + gap + 5;

   //--- Palette Area
   int p_size = 30;
   int p_gap = 2;
   int start_y = y;
   for(int i=0; i<25; i++) {
      int row = i / 5;
      int col = i % 5;
      int px = x + (col * (p_size + p_gap));
      int py = start_y + (row * (p_size + p_gap));
      CreatePaletteButton(i, px, py, p_size);
   }
   y += (5 * (p_size + p_gap)) + 10;

   //--- Toggles
   CreateCategoryButton(m_tog_grid, "TogGrid", "Grid: ON", x, y, 60, h);
   CreateCategoryButton(m_tog_ohlc, "TogOHLC", "OHLC: ON", x+65, y, 60, h);
   CreateCategoryButton(m_tog_sep, "TogSep", "Sep: ON", x+130, y, 60, h);
   y += h + gap;

   //--- Save & Close Buttons
   if(!m_btn_save_tpl.Create(chart,name+"BtnSave",subwin,x,y,x+190,y+30)) return(false);
   m_btn_save_tpl.Text("SAVE DEFAULT.TPL");
   m_btn_save_tpl.ColorBackground(clrDarkBlue);
   m_btn_save_tpl.Color(clrWhite);
   Add(m_btn_save_tpl);

   y += 35;
   if(!m_btn_close.Create(chart,name+"BtnClose",subwin,x,y,x+190,y+30)) return(false);
   m_btn_close.Text("EXIT (Close Tool)");
   m_btn_close.ColorBackground(clrRed);
   m_btn_close.Color(clrWhite);
   Add(m_btn_close);

   ShowPalette(false);
   LoadConfiguration();
   ApplyToChart();

   return(true);
  }

//--- Helper Methods
bool CChartDesignerPanel::CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h) {
   if(!btn.Create(ChartID(), m_name+name, 0, x, y, x+w, y+h)) return(false);
   btn.Text(text);
   Add(btn);
   return(true);
}
bool CChartDesignerPanel::CreatePaletteButton(int index, int x, int y, int size) {
   if(!m_palette[index].Create(ChartID(), m_name+"Pal"+IntegerToString(index), 0, x, y, x+size, y+size)) return(false);
   m_palette[index].Text(" "); // Space ensures button is rendered correctly
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   Add(m_palette[index]);
   return(true);
}

void CChartDesignerPanel::ShowPalette(bool show) {
   for(int i=0; i<25; i++) {
      if(show) {
         m_palette[i].ColorBackground(PALETTE_COLORS[i]); // Force re-apply color on show
         m_palette[i].Show();
      }
      else m_palette[i].Hide();
   }
   ChartRedraw(ChartID());
}

void CChartDesignerPanel::UpdateStatus(string text) {
   m_lbl_status.Text(text);
}

//--- Event Handling
bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == m_btn_close.Name())     { SelfDestruct(); return(true); }
      if(sparam == m_btn_bg.Name())        { m_active_target="BG"; ShowPalette(true); UpdateStatus("Set Background Color..."); return(true); }
      if(sparam == m_btn_grid.Name())      { m_active_target="GRID"; ShowPalette(true); UpdateStatus("Set Grid Color..."); return(true); }
      if(sparam == m_btn_bull_body.Name()) { m_active_target="BULL_BODY"; ShowPalette(true); UpdateStatus("Set Bull Body Color..."); return(true); }
      if(sparam == m_btn_bear_body.Name()) { m_active_target="BEAR_BODY"; ShowPalette(true); UpdateStatus("Set Bear Body Color..."); return(true); }
      if(sparam == m_btn_bull_wick.Name()) { m_active_target="BULL_WICK"; ShowPalette(true); UpdateStatus("Set Bull Wick Color..."); return(true); }
      if(sparam == m_btn_bear_wick.Name()) { m_active_target="BEAR_WICK"; ShowPalette(true); UpdateStatus("Set Bear Wick Color..."); return(true); }
      if(sparam == m_btn_text.Name())      { m_active_target="TEXT"; ShowPalette(true); UpdateStatus("Set Text Color..."); return(true); }

      for(int i=0; i<25; i++) {
         if(sparam == m_palette[i].Name()) {
            OnPaletteClick(PALETTE_COLORS[i]);
            return(true);
         }
      }

      if(sparam == m_tog_grid.Name()) { m_theme.show_grid = !m_theme.show_grid; ApplyToChart(); SaveConfiguration(); return(true); }
      if(sparam == m_tog_ohlc.Name()) { m_theme.show_ohlc = !m_theme.show_ohlc; ApplyToChart(); SaveConfiguration(); return(true); }
      if(sparam == m_tog_sep.Name())  { m_theme.show_period_sep = !m_theme.show_period_sep; ApplyToChart(); SaveConfiguration(); return(true); }

      if(sparam == m_btn_save_tpl.Name()) {
         if(ChartSaveTemplate(0, "default.tpl")) MessageBox("Template Saved!", "Success");
         else MessageBox("Error saving template", "Error");
         return(true);
      }
   }
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

void CChartDesignerPanel::OnPaletteClick(color c) {
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

void CChartDesignerPanel::SelfDestruct() {
   SaveConfiguration();
   // Remove this indicator from the chart
   ChartIndicatorDelete(0, 0, TOOL_SHORTNAME);
}

//--- Application Logic
void CChartDesignerPanel::ApplyToChart() {
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

   m_tog_grid.Text(m_theme.show_grid ? "Grid: ON" : "Grid: OFF");
   m_tog_ohlc.Text(m_theme.show_ohlc ? "OHLC: ON" : "OHLC: OFF");
   m_tog_sep.Text(m_theme.show_period_sep ? "Sep: ON" : "Sep: OFF");
   ChartRedraw(chart);
}

void CChartDesignerPanel::LoadConfiguration() {
   // 1. Define Defaults
   ChartTheme defaults;
   defaults.bg_color = C'20,20,20'; defaults.grid_color = clrDimGray;
   defaults.bull_body = clrForestGreen; defaults.bear_body = clrFireBrick;
   defaults.bull_wick = clrForestGreen; defaults.bear_wick = clrFireBrick;
   defaults.text_color = clrWhite;
   defaults.show_grid = 0; defaults.show_ohlc = 1; defaults.show_period_sep = 1;
   defaults.show_bid = 1; defaults.show_ask = 1;

   // 2. Set memory to defaults first
   m_theme = defaults;

   // 3. Try Load
   int handle = FileOpen(CONFIG_FILENAME, FILE_READ|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      if(FileReadStruct(handle, m_theme) > 0) {
         // Validate loaded data. If partially zero/corrupt, revert to defaults.
         // A valid theme typically won't have black (0) for everything.
         if(m_theme.bull_body == 0 && m_theme.bear_body == 0 && m_theme.bg_color == 0) {
             Print("Config file seems corrupt or empty (all zeros). Reverting to defaults.");
             m_theme = defaults;
         }
      }
      FileClose(handle);
   }
}

void CChartDesignerPanel::SaveConfiguration() {
   int handle = FileOpen(CONFIG_FILENAME, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      FileWriteStruct(handle, m_theme);
      FileClose(handle);
   }
}

//--- Global
CChartDesignerPanel ExtDialog;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, TOOL_SHORTNAME);
   if(!ExtDialog.Create(0,"ChartDesigner",0,60,60,60+240,60+490))
      return(INIT_FAILED);
   ExtDialog.Run();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtDialog.Destroy(reason);
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
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }
//+------------------------------------------------------------------+
