//+------------------------------------------------------------------+
//|                                            Chart_Designer_UI.mqh |
//|                                  Copyright 2026, Jules AI Agent  |
//|                                       For Hybrid Scalper System  |
//+------------------------------------------------------------------+
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

   // Category Buttons
   CButton           m_btn_bg;
   CButton           m_btn_bull;
   CButton           m_btn_bear;
   CButton           m_btn_grid;

   // Toggle Buttons
   CButton           m_btn_toggle_grid;
   CButton           m_btn_toggle_ohlc;

   // Save Button
   CButton           m_btn_save;

   // Palette Buttons (Dynamic)
   CButton           m_palette[10];

   // State
   string            m_active_category; // "BG", "BULL", "BEAR", "GRID"

public:
                     CChartDesignerPanel(void);
                    ~CChartDesignerPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);

private:
   bool              CreatePalette(void);
   void              LoadPalette(const color &colors[]);
   void              ApplyColor(color c);
   void              ToggleGrid(void);
   void              ToggleOHLC(void);
   void              SaveTemplate(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChartDesignerPanel::CChartDesignerPanel(void) : m_active_category("BG")
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChartDesignerPanel::~CChartDesignerPanel(void)
  {
  }
//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);

   int x_off = 10;
   int y_off = 10;
   int btn_h = 25;
   int btn_w = 80;

   //--- Title
   if(!m_lbl_title.Create(chart,name+"Label",subwin,x_off,y_off,x_off+150,y_off+20)) return(false);
   m_lbl_title.Text("Chart Designer");
   Add(m_lbl_title);
   y_off += 25;

   //--- Category Buttons
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
   y_off += 40; // Space for palette

   //--- Create Palette Buttons (Grid 5x2)
   for(int i=0; i<10; i++)
     {
      int col = i % 5;
      int row = i / 5;
      int px = x_off + (col * 35);
      int py = y_off + (row * 35);

      if(!m_palette[i].Create(chart,name+"Pal"+IntegerToString(i),subwin,px,py,px+30,py+30)) return(false);
      m_palette[i].Text("");
      // Force flat style handled by OnEvent usually, but standard button supports ColorBackground
      Add(m_palette[i]);
     }
   y_off += 80;

   //--- Toggles
   if(!m_btn_toggle_grid.Create(chart,name+"TogGrid",subwin,x_off,y_off,x_off+btn_w,y_off+btn_h)) return(false);
   m_btn_toggle_grid.Text("Grid On/Off");
   Add(m_btn_toggle_grid);

   if(!m_btn_toggle_ohlc.Create(chart,name+"TogOHLC",subwin,x_off+90,y_off,x_off+90+btn_w,y_off+btn_h)) return(false);
   m_btn_toggle_ohlc.Text("OHLC On/Off");
   Add(m_btn_toggle_ohlc);
   y_off += 30;

   //--- Save
   if(!m_btn_save.Create(chart,name+"BtnSave",subwin,x_off,y_off,x_off+180,y_off+40)) return(false);
   m_btn_save.Text("SAVE DEFAULT.TPL");
   m_btn_save.ColorBackground(clrDarkBlue);
   m_btn_save.Color(clrWhite);
   Add(m_btn_save);

   // Load Initial Palette (Backgrounds)
   LoadPalette(C_Greys);

   return(true);
  }

//+------------------------------------------------------------------+
//| LoadPalette                                                      |
//+------------------------------------------------------------------+
void CChartDesignerPanel::LoadPalette(const color &colors[])
  {
   for(int i=0; i<10; i++)
     {
      m_palette[i].ColorBackground(colors[i]);
      // Hack to make button show color clearly
      m_palette[i].Color(colors[i]);
     }
  }

//+------------------------------------------------------------------+
//| Events                                                           |
//+------------------------------------------------------------------+
bool CChartDesignerPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      // Categories
      if(sparam==m_btn_bg.Name())   { m_active_category="BG"; LoadPalette(C_Greys); return(true); }
      if(sparam==m_btn_bull.Name()) { m_active_category="BULL"; LoadPalette(C_Greens); return(true); }
      if(sparam==m_btn_bear.Name()) { m_active_category="BEAR"; LoadPalette(C_Reds); return(true); }
      if(sparam==m_btn_grid.Name()) { m_active_category="GRID"; LoadPalette(C_Greys); return(true); } // Grid usually grey

      // Palette Clicks
      for(int i=0; i<10; i++)
        {
         if(sparam==m_palette[i].Name())
           {
            ApplyColor(m_palette[i].ColorBackground());
            return(true);
           }
        }

      // Toggles
      if(sparam==m_btn_toggle_grid.Name()) { ToggleGrid(); return(true); }
      if(sparam==m_btn_toggle_ohlc.Name()) { ToggleOHLC(); return(true); }

      // Save
      if(sparam==m_btn_save.Name()) { SaveTemplate(); return(true); }
     }
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
  }

//+------------------------------------------------------------------+
//| Actions                                                          |
//+------------------------------------------------------------------+
void CChartDesignerPanel::ApplyColor(color c)
  {
   long cid = ChartID();
   if(m_active_category == "BG")
     {
      ChartSetInteger(cid, CHART_COLOR_BACKGROUND, c);
     }
   else if(m_active_category == "BULL")
     {
      ChartSetInteger(cid, CHART_COLOR_CANDLE_BULL, c);
      ChartSetInteger(cid, CHART_COLOR_CHART_UP, c); // Wick same as body
     }
   else if(m_active_category == "BEAR")
     {
      ChartSetInteger(cid, CHART_COLOR_CANDLE_BEAR, c);
      ChartSetInteger(cid, CHART_COLOR_CHART_DOWN, c); // Wick same as body
     }
   else if(m_active_category == "GRID")
     {
      ChartSetInteger(cid, CHART_COLOR_GRID, c);
     }
   ChartRedraw(cid);
  }

void CChartDesignerPanel::ToggleGrid(void)
  {
   long cid = ChartID();
   bool current = (bool)ChartGetInteger(cid, CHART_SHOW_GRID);
   ChartSetInteger(cid, CHART_SHOW_GRID, !current);
   ChartRedraw(cid);
  }

void CChartDesignerPanel::ToggleOHLC(void)
  {
   long cid = ChartID();
   bool current = (bool)ChartGetInteger(cid, CHART_SHOW_OHLC);
   ChartSetInteger(cid, CHART_SHOW_OHLC, !current);
   ChartRedraw(cid);
  }

void CChartDesignerPanel::SaveTemplate(void)
  {
   if(ChartSaveTemplate(0, "default.tpl"))
      MessageBox("Template saved as default.tpl", "Success", MB_OK);
   else
      MessageBox("Failed to save template", "Error", MB_ICONERROR);
  }
//+------------------------------------------------------------------+
