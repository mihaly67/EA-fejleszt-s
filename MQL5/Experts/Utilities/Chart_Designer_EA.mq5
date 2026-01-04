//+------------------------------------------------------------------+
//|                                            Chart_Designer_EA.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.30"
#property description "GUI Panel to design and save chart themes dynamically."

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\ColorPicker.mqh> // Standard Color Picker

//--- Input Parameters
input group "Initial Settings"
input int   InpPanelX         = 60;             // Panel X Position
input int   InpPanelY         = 300;            // Panel Y Position
input color InpBgColor        = C'20,20,20';    // Default Background
input color InpBullColor      = clrForestGreen; // Default Bull Color
input color InpBearColor      = clrFireBrick;   // Default Bear Color
input bool  InpShowGrid       = false;          // Show Grid Initially
input bool  InpShowOHLC       = true;           // Show OHLC Initially

//+------------------------------------------------------------------+
//| Class CChartDesignerPanel                                        |
//+------------------------------------------------------------------+
class CChartDesignerPanel : public CAppDialog
  {
private:
   CLabel            m_lbl_title;

   // Visual Components
   CLabel            m_lbl_bg;
   CColorPicker      m_cp_bg;

   CLabel            m_lbl_bull;
   CColorPicker      m_cp_bull;

   CLabel            m_lbl_bear;
   CColorPicker      m_cp_bear;

   CLabel            m_lbl_grid;
   CColorPicker      m_cp_grid;

   // Toggles & Actions
   CButton           m_btn_toggle_grid;
   CButton           m_btn_toggle_ohlc;
   CButton           m_btn_save;

public:
                     CChartDesignerPanel(void);
                    ~CChartDesignerPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   void              ApplyInitialSettings();

private:
   void              ApplyColorChange(void);
   void              ToggleGrid(void);
   void              ToggleOHLC(void);
   void              SaveTemplate(void);
  };

CChartDesignerPanel::CChartDesignerPanel(void) {}
CChartDesignerPanel::~CChartDesignerPanel(void) {}

bool CChartDesignerPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2)) return(false);

   int x_off = 10;
   int y_off = 10;
   int lh = 20; // Label height
   int cp_h = 25; // Picker height
   int gap = 5;
   int row_h = 35;

   if(!m_lbl_title.Create(chart,name+"Label",subwin,x_off,y_off,x_off+150,y_off+20)) return(false);
   m_lbl_title.Text("Chart Designer v1.3");
   Add(m_lbl_title);
   y_off += 30;

   //--- Background
   if(!m_lbl_bg.Create(chart,name+"LblBG",subwin,x_off,y_off,x_off+60,y_off+lh)) return(false);
   m_lbl_bg.Text("Backgrnd:");
   Add(m_lbl_bg);

   if(!m_cp_bg.Create(chart,name+"CPBG",subwin,x_off+70,y_off,x_off+70+50,y_off+cp_h)) return(false);
   m_cp_bg.Color(InpBgColor);
   Add(m_cp_bg);
   y_off += row_h;

   //--- Bullish
   if(!m_lbl_bull.Create(chart,name+"LblBull",subwin,x_off,y_off,x_off+60,y_off+lh)) return(false);
   m_lbl_bull.Text("Bullish:");
   Add(m_lbl_bull);

   if(!m_cp_bull.Create(chart,name+"CPBull",subwin,x_off+70,y_off,x_off+70+50,y_off+cp_h)) return(false);
   m_cp_bull.Color(InpBullColor);
   Add(m_cp_bull);
   y_off += row_h;

   //--- Bearish
   if(!m_lbl_bear.Create(chart,name+"LblBear",subwin,x_off,y_off,x_off+60,y_off+lh)) return(false);
   m_lbl_bear.Text("Bearish:");
   Add(m_lbl_bear);

   if(!m_cp_bear.Create(chart,name+"CPBear",subwin,x_off+70,y_off,x_off+70+50,y_off+cp_h)) return(false);
   m_cp_bear.Color(InpBearColor);
   Add(m_cp_bear);
   y_off += row_h;

   //--- Grid Color
   if(!m_lbl_grid.Create(chart,name+"LblGrid",subwin,x_off,y_off,x_off+60,y_off+lh)) return(false);
   m_lbl_grid.Text("Grid Clr:");
   Add(m_lbl_grid);

   if(!m_cp_grid.Create(chart,name+"CPGrid",subwin,x_off+70,y_off,x_off+70+50,y_off+cp_h)) return(false);
   m_cp_grid.Color(clrDimGray);
   Add(m_cp_grid);
   y_off += 40;

   //--- Toggles
   if(!m_btn_toggle_grid.Create(chart,name+"TogGrid",subwin,x_off,y_off,x_off+90,y_off+25)) return(false);
   m_btn_toggle_grid.Text("Grid On/Off");
   Add(m_btn_toggle_grid);

   if(!m_btn_toggle_ohlc.Create(chart,name+"TogOHLC",subwin,x_off+100,y_off,x_off+190,y_off+25)) return(false);
   m_btn_toggle_ohlc.Text("OHLC");
   Add(m_btn_toggle_ohlc);
   y_off += 35;

   //--- Save
   if(!m_btn_save.Create(chart,name+"BtnSave",subwin,x_off,y_off,x_off+190,y_off+35)) return(false);
   m_btn_save.Text("SAVE DEFAULT.TPL");
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);
   Add(m_btn_save);

   return(true);
  }

void CChartDesignerPanel::ApplyInitialSettings()
{
   long chart = ChartID();
   ChartSetInteger(chart, CHART_COLOR_BACKGROUND, InpBgColor);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, InpBullColor);
   ChartSetInteger(chart, CHART_COLOR_CHART_UP, InpBullColor);
   ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, InpBearColor);
   ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, InpBearColor);
   ChartSetInteger(chart, CHART_SHOW_GRID, (long)InpShowGrid);
   ChartSetInteger(chart, CHART_SHOW_OHLC, (long)InpShowOHLC);
   ChartRedraw(chart);
}

bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam) {
   // Handle Color Picker Changes (ON_CHANGE)
   if(id == ON_CHANGE) {
      if(lparam == m_cp_bg.Id() || lparam == m_cp_bull.Id() || lparam == m_cp_bear.Id() || lparam == m_cp_grid.Id()) {
         ApplyColorChange();
         return(true);
      }
   }

   // Handle Button Clicks (CHARTEVENT_OBJECT_CLICK or ON_CLICK)
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == m_btn_toggle_grid.Name()) { ToggleGrid(); return(true); }
      if(sparam == m_btn_toggle_ohlc.Name()) { ToggleOHLC(); return(true); }
      if(sparam == m_btn_save.Name()) { SaveTemplate(); return(true); }
   }

   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

void CChartDesignerPanel::ApplyColorChange(void) {
   long cid = ChartID();
   ChartSetInteger(cid, CHART_COLOR_BACKGROUND, m_cp_bg.Color());

   ChartSetInteger(cid, CHART_COLOR_CANDLE_BULL, m_cp_bull.Color());
   ChartSetInteger(cid, CHART_COLOR_CHART_UP, m_cp_bull.Color());

   ChartSetInteger(cid, CHART_COLOR_CANDLE_BEAR, m_cp_bear.Color());
   ChartSetInteger(cid, CHART_COLOR_CHART_DOWN, m_cp_bear.Color());

   ChartSetInteger(cid, CHART_COLOR_GRID, m_cp_grid.Color());

   ChartRedraw(cid);
}

void CChartDesignerPanel::ToggleGrid(void) {
   long cid = ChartID();
   bool current = (bool)ChartGetInteger(cid, CHART_SHOW_GRID);
   ChartSetInteger(cid, CHART_SHOW_GRID, !current);
   ChartRedraw(cid);
}

void CChartDesignerPanel::ToggleOHLC(void) {
   long cid = ChartID();
   bool current = (bool)ChartGetInteger(cid, CHART_SHOW_OHLC);
   ChartSetInteger(cid, CHART_SHOW_OHLC, !current);
   ChartRedraw(cid);
}

void CChartDesignerPanel::SaveTemplate(void) {
   if(ChartSaveTemplate(0, "default.tpl"))
      MessageBox("Template saved as default.tpl", "Success", MB_OK);
   else
      MessageBox("Failed to save template", "Error", MB_ICONERROR);
}

//--- GLOBAL INSTANCE
CChartDesignerPanel ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ExtDialog.Create(0,"ChartDesigner",0,InpPanelX,InpPanelY,InpPanelX+220,InpPanelY+350))
      return(INIT_FAILED);

   ExtDialog.Run();
   ExtDialog.ApplyInitialSettings();

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
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }
//+------------------------------------------------------------------+
