//+------------------------------------------------------------------+
//|                                            Chart_Designer_EA.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "2.00"
#property description "GUI Panel to design and save chart themes dynamically."

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

//--- Configuration File Name
#define CONFIG_FILENAME "ChartDesigner_Config.bin"

//--- Color Palette Array (25 Colors)
const color PALETTE_COLORS[] = {
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
   bool  show_grid;
   bool  show_ohlc;
   bool  show_period_sep;
   bool  show_bid;
   bool  show_ask;
};

//--- Global Configuration Instance
ChartTheme GlobalTheme;

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

   // State
   string            m_active_target; // "BG", "GRID", "BULL_BODY", etc.

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
   void              ResetCategoryButtons();
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

   // Calculate inner coordinates relative to the panel position (x1, y1)
   // and the client area offset. CAppDialog borders are usually handled,
   // but absolute coordinates for controls are required.
   int x = x1 + 10;
   int y = y1 + 40; // Offset for Title Bar
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

   //--- Palette Area (Initially Hidden)
   // 5x5 Grid
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

   //--- Save Button
   if(!m_btn_save_tpl.Create(chart,name+"BtnSave",subwin,x,y,x+190,y+30)) return(false);
   m_btn_save_tpl.Text("SAVE DEFAULT.TPL");
   m_btn_save_tpl.ColorBackground(clrDarkBlue);
   m_btn_save_tpl.Color(clrWhite);
   Add(m_btn_save_tpl);

   // Initialize State
   ShowPalette(false); // Hide palette initially
   LoadConfiguration(); // Load from file
   ApplyToChart();      // Apply loaded settings

   return(true);
  }

//+------------------------------------------------------------------+
//| Helper: Create Category Button                                   |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::CreateCategoryButton(CButton &btn, string name, string text, int x, int y, int w, int h)
  {
   if(!btn.Create(m_chart_id, m_name+name, m_subwin, x, y, x+w, y+h)) return(false);
   btn.Text(text);
   Add(btn);
   return(true);
  }

//+------------------------------------------------------------------+
//| Helper: Create Palette Button                                    |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::CreatePaletteButton(int index, int x, int y, int size)
  {
   if(!m_palette[index].Create(m_chart_id, m_name+"Pal"+IntegerToString(index), m_subwin, x, y, x+size, y+size)) return(false);
   m_palette[index].Text("");
   m_palette[index].ColorBackground(PALETTE_COLORS[index]);
   Add(m_palette[index]);
   return(true);
  }

//+------------------------------------------------------------------+
//| Show/Hide Palette                                                |
//+------------------------------------------------------------------+
void CChartDesignerPanel::ShowPalette(bool show)
  {
   for(int i=0; i<25; i++) {
      if(show) m_palette[i].Show();
      else m_palette[i].Hide();
   }
   ChartRedraw(m_chart_id);
  }

//+------------------------------------------------------------------+
//| Event Handler                                                    |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK) {

      //--- Category Buttons
      if(sparam == m_btn_bg.Name())        { m_active_target="BG"; ShowPalette(true); UpdateStatus("Set Background Color..."); return(true); }
      if(sparam == m_btn_grid.Name())      { m_active_target="GRID"; ShowPalette(true); UpdateStatus("Set Grid Color..."); return(true); }
      if(sparam == m_btn_bull_body.Name()) { m_active_target="BULL_BODY"; ShowPalette(true); UpdateStatus("Set Bull Body Color..."); return(true); }
      if(sparam == m_btn_bear_body.Name()) { m_active_target="BEAR_BODY"; ShowPalette(true); UpdateStatus("Set Bear Body Color..."); return(true); }
      if(sparam == m_btn_bull_wick.Name()) { m_active_target="BULL_WICK"; ShowPalette(true); UpdateStatus("Set Bull Wick Color..."); return(true); }
      if(sparam == m_btn_bear_wick.Name()) { m_active_target="BEAR_WICK"; ShowPalette(true); UpdateStatus("Set Bear Wick Color..."); return(true); }
      if(sparam == m_btn_text.Name())      { m_active_target="TEXT"; ShowPalette(true); UpdateStatus("Set Text Color..."); return(true); }

      //--- Palette Clicks
      for(int i=0; i<25; i++) {
         if(sparam == m_palette[i].Name()) {
            OnPaletteClick(PALETTE_COLORS[i]);
            return(true);
         }
      }

      //--- Toggles
      if(sparam == m_tog_grid.Name()) {
         GlobalTheme.show_grid = !GlobalTheme.show_grid;
         ApplyToChart(); SaveConfiguration();
         return(true);
      }
      if(sparam == m_tog_ohlc.Name()) {
         GlobalTheme.show_ohlc = !GlobalTheme.show_ohlc;
         ApplyToChart(); SaveConfiguration();
         return(true);
      }
      if(sparam == m_tog_sep.Name()) {
         GlobalTheme.show_period_sep = !GlobalTheme.show_period_sep;
         ApplyToChart(); SaveConfiguration();
         return(true);
      }

      //--- Save TPL
      if(sparam == m_btn_save_tpl.Name()) {
         if(ChartSaveTemplate(0, "default.tpl")) {
             MessageBox("Template 'default.tpl' Saved!", "Success", MB_OK);
         } else {
             MessageBox("Failed to save template.", "Error", MB_ICONERROR);
         }
         return(true);
      }
   }
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

//+------------------------------------------------------------------+
//| Handle Palette Click                                             |
//+------------------------------------------------------------------+
void CChartDesignerPanel::OnPaletteClick(color c)
  {
   if(m_active_target == "BG") GlobalTheme.bg_color = c;
   else if(m_active_target == "GRID") GlobalTheme.grid_color = c;
   else if(m_active_target == "BULL_BODY") GlobalTheme.bull_body = c;
   else if(m_active_target == "BEAR_BODY") GlobalTheme.bear_body = c;
   else if(m_active_target == "BULL_WICK") GlobalTheme.bull_wick = c;
   else if(m_active_target == "BEAR_WICK") GlobalTheme.bear_wick = c;
   else if(m_active_target == "TEXT") GlobalTheme.text_color = c;

   ApplyToChart();
   SaveConfiguration();

   ShowPalette(false); // Hide palette
   m_active_target = "";
   UpdateStatus("Color Applied.");
  }

//+------------------------------------------------------------------+
//| Update Status Label                                              |
//+------------------------------------------------------------------+
void CChartDesignerPanel::UpdateStatus(string text)
  {
   m_lbl_status.Text(text);
  }

//+------------------------------------------------------------------+
//| Apply Settings to Chart                                          |
//+------------------------------------------------------------------+
void CChartDesignerPanel::ApplyToChart()
  {
   long chart = ChartID();
   ChartSetInteger(chart, CHART_COLOR_BACKGROUND, GlobalTheme.bg_color);
   ChartSetInteger(chart, CHART_COLOR_GRID, GlobalTheme.grid_color);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, GlobalTheme.bull_body);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, GlobalTheme.bear_body);
   ChartSetInteger(chart, CHART_COLOR_CHART_UP, GlobalTheme.bull_wick);
   ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, GlobalTheme.bear_wick);
   ChartSetInteger(chart, CHART_COLOR_FOREGROUND, GlobalTheme.text_color);

   ChartSetInteger(chart, CHART_SHOW_GRID, GlobalTheme.show_grid);
   ChartSetInteger(chart, CHART_SHOW_OHLC, GlobalTheme.show_ohlc);
   ChartSetInteger(chart, CHART_SHOW_PERIOD_SEP, GlobalTheme.show_period_sep);

   // Update Buttons Text
   m_tog_grid.Text(GlobalTheme.show_grid ? "Grid: ON" : "Grid: OFF");
   m_tog_ohlc.Text(GlobalTheme.show_ohlc ? "OHLC: ON" : "OHLC: OFF");
   m_tog_sep.Text(GlobalTheme.show_period_sep ? "Sep: ON" : "Sep: OFF");

   ChartRedraw(chart);
  }

//+------------------------------------------------------------------+
//| Load Configuration from File                                     |
//+------------------------------------------------------------------+
void CChartDesignerPanel::LoadConfiguration()
  {
   // 1. Set Defaults
   GlobalTheme.bg_color = C'20,20,20';
   GlobalTheme.grid_color = clrDimGray;
   GlobalTheme.bull_body = clrForestGreen;
   GlobalTheme.bear_body = clrFireBrick;
   GlobalTheme.bull_wick = clrForestGreen;
   GlobalTheme.bear_wick = clrFireBrick;
   GlobalTheme.text_color = clrWhite;
   GlobalTheme.show_grid = false;
   GlobalTheme.show_ohlc = true;
   GlobalTheme.show_period_sep = true;

   // 2. Try Load
   int handle = FileOpen(CONFIG_FILENAME, FILE_READ|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      if(FileReadStruct(handle, GlobalTheme) > 0) {
         Print("Configuration loaded successfully.");
      }
      FileClose(handle);
   } else {
      Print("No config file found, using defaults.");
   }
  }

//+------------------------------------------------------------------+
//| Save Configuration to File                                       |
//+------------------------------------------------------------------+
void CChartDesignerPanel::SaveConfiguration()
  {
   int handle = FileOpen(CONFIG_FILENAME, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      FileWriteStruct(handle, GlobalTheme);
      FileClose(handle);
      Print("Configuration saved.");
   } else {
      Print("Error saving config: ", GetLastError());
   }
  }

//--- GLOBAL INSTANCE
CChartDesignerPanel ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ExtDialog.Create(0,"ChartDesigner",0,60,60,60+240,60+450))
      return(INIT_FAILED);

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
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }
