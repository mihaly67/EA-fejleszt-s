//+------------------------------------------------------------------+
//|                                            Chart_Designer_EA.mq5 |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Jules AI Agent"
#property link      "https://github.com/your-repo"
#property version   "1.00"
#property description "GUI Panel to design and save chart themes dynamically."

// DIRECT INCLUDE FOR STABILITY (Merged Chart_Designer_UI.mqh content)
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

//--- Palette Colors
const color C_Greys[] = {clrBlack, C'20,20,20', C'30,30,30', C'40,40,40', clrDimGray, clrGray, clrSilver, clrWhite, clrMidnightBlue, C'10,15,25'};
const color C_Greens[] = {clrForestGreen, clrLimeGreen, clrLime, clrGreen, clrSeaGreen, clrSpringGreen, clrMediumSeaGreen, clrDarkGreen, clrChartreuse, clrTeal};
const color C_Reds[] = {clrFireBrick, clrRed, clrCrimson, clrTomato, clrOrangeRed, clrIndianRed, clrMaroon, clrDarkRed, clrSalmon, clrBrown};
const color C_Blues[] = {clrDodgerBlue, clrDeepSkyBlue, clrRoyalBlue, clrBlue, clrNavy, clrSkyBlue, clrCornflowerBlue, clrSteelBlue, clrLightBlue, clrCadetBlue};

//+------------------------------------------------------------------+
//| Class CChartDesignerPanel                                        |
//+------------------------------------------------------------------+
class CChartDesignerPanel : public CAppDialog
  {
private:
   CLabel            m_lbl_title;
   CButton           m_btn_bg;
   CButton           m_btn_bull;
   CButton           m_btn_bear;
   CButton           m_btn_grid;
   CButton           m_btn_toggle_grid;
   CButton           m_btn_toggle_ohlc;
   CButton           m_btn_save;
   CButton           m_palette[10];
   string            m_active_category;

public:
                     CChartDesignerPanel(void);
                    ~CChartDesignerPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);

private:
   void              LoadPalette(const color &colors[]);
   void              ApplyColor(color c);
   void              ToggleGrid(void);
   void              ToggleOHLC(void);
   void              SaveTemplate(void);
  };

CChartDesignerPanel::CChartDesignerPanel(void) : m_active_category("BG") {}
CChartDesignerPanel::~CChartDesignerPanel(void) {}

bool CChartDesignerPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2)) return(false);

   int x_off = 10;
   int y_off = 10;
   int btn_h = 25;
   int btn_w = 80;

   if(!m_lbl_title.Create(chart,name+"Label",subwin,x_off,y_off,x_off+150,y_off+20)) return(false);
   m_lbl_title.Text("Chart Designer");
   Add(m_lbl_title);
   y_off += 25;

   if(!m_btn_bg.Create(chart,name+"BtnBG",subwin,x_off,y_off,x_off+btn_w,y_off+btn_h)) return(false);
   m_btn_bg.Text("Backgrnd");
   Add(m_btn_bg);

   if(!m_btn_grid.Create(chart,name+"BtnGridColor",subwin,x_off+90,y_off,x_off+90+btn_w,y_off+btn_h)) return(false);
   m_btn_grid.Text("Grid Color");
   Add(m_btn_grid);
   y_off += 30;

   if(!m_btn_bull.Create(chart,name+"BtnBull",subwin,x_off,y_off,x_off+btn_w,y_off+btn_h)) return(false);
   m_btn_bull.Text("Bullish");
   Add(m_btn_bull);

   if(!m_btn_bear.Create(chart,name+"BtnBear",subwin,x_off+90,y_off,x_off+90+btn_w,y_off+btn_h)) return(false);
   m_btn_bear.Text("Bearish");
   Add(m_btn_bear);
   y_off += 40;

   for(int i=0; i<10; i++) {
      int col = i % 5;
      int row = i / 5;
      int px = x_off + (col * 35);
      int py = y_off + (row * 35);
      if(!m_palette[i].Create(chart,name+"Pal"+IntegerToString(i),subwin,px,py,px+30,py+30)) return(false);
      m_palette[i].Text("");
      Add(m_palette[i]);
   }
   y_off += 80;

   if(!m_btn_toggle_grid.Create(chart,name+"TogGrid",subwin,x_off,y_off,x_off+btn_w,y_off+btn_h)) return(false);
   m_btn_toggle_grid.Text("Grid On/Off");
   Add(m_btn_toggle_grid);

   if(!m_btn_toggle_ohlc.Create(chart,name+"TogOHLC",subwin,x_off+90,y_off,x_off+90+btn_w,y_off+btn_h)) return(false);
   m_btn_toggle_ohlc.Text("OHLC On/Off");
   Add(m_btn_toggle_ohlc);
   y_off += 30;

   if(!m_btn_save.Create(chart,name+"BtnSave",subwin,x_off,y_off,x_off+180,y_off+40)) return(false);
   m_btn_save.Text("SAVE DEFAULT.TPL");
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);
   Add(m_btn_save);

   LoadPalette(C_Greys);
   return(true);
  }

void CChartDesignerPanel::LoadPalette(const color &colors[]) {
   for(int i=0; i<10; i++) {
      m_palette[i].ColorBackground(colors[i]);
      m_palette[i].Color(colors[i]);
   }
}

bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam) {
   if(id==CHARTEVENT_OBJECT_CLICK) {
      if(sparam==m_btn_bg.Name())   { m_active_category="BG"; LoadPalette(C_Greys); return(true); }
      if(sparam==m_btn_bull.Name()) { m_active_category="BULL"; LoadPalette(C_Greens); return(true); }
      if(sparam==m_btn_bear.Name()) { m_active_category="BEAR"; LoadPalette(C_Reds); return(true); }
      if(sparam==m_btn_grid.Name()) { m_active_category="GRID"; LoadPalette(C_Greys); return(true); }

      for(int i=0; i<10; i++) {
         if(sparam==m_palette[i].Name()) {
            ApplyColor(m_palette[i].ColorBackground());
            return(true);
         }
      }
      if(sparam==m_btn_toggle_grid.Name()) { ToggleGrid(); return(true); }
      if(sparam==m_btn_toggle_ohlc.Name()) { ToggleOHLC(); return(true); }
      if(sparam==m_btn_save.Name()) { SaveTemplate(); return(true); }
   }
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

void CChartDesignerPanel::ApplyColor(color c) {
   long cid = ChartID();
   if(m_active_category == "BG") {
      ChartSetInteger(cid, CHART_COLOR_BACKGROUND, c);
   } else if(m_active_category == "BULL") {
      ChartSetInteger(cid, CHART_COLOR_CANDLE_BULL, c);
      ChartSetInteger(cid, CHART_COLOR_CHART_UP, c);
   } else if(m_active_category == "BEAR") {
      ChartSetInteger(cid, CHART_COLOR_CANDLE_BEAR, c);
      ChartSetInteger(cid, CHART_COLOR_CHART_DOWN, c);
   } else if(m_active_category == "GRID") {
      ChartSetInteger(cid, CHART_COLOR_GRID, c);
   }
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
   if(!ExtDialog.Create(0,"ChartDesigner",0,20,20,240,350))
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
