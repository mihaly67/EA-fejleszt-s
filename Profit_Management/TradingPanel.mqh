//+------------------------------------------------------------------+
//|                                                 TradingPanel.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>

//+------------------------------------------------------------------+
//| Definitions                                                      |
//+------------------------------------------------------------------+
#define PANEL_WIDTH  350
#define PANEL_HEIGHT 200
#define MARGIN_LEFT  10
#define MARGIN_TOP   10
#define ROW_HEIGHT   25

//+------------------------------------------------------------------+
//| Class: Trading Dashboard Panel                                   |
//+------------------------------------------------------------------+
class CTradingPanel : public CAppDialog
  {
private:
   // UI Components
   CLabel            m_lbl_title;
   CLabel            m_lbl_regime;
   CLabel            m_lbl_advice;
   CLabel            m_lbl_score;
   CLabel            m_lbl_volatility;

   // Cockpit Controls
   CButton           m_btn_mode;       // Auto / Manual
   CButton           m_btn_sl_auto;    // SL Auto/Man
   CButton           m_btn_tp_auto;    // TP Auto/Man
   CButton           m_btn_risk_up;    // Risk +
   CButton           m_btn_risk_down;  // Risk -
   CLabel            m_lbl_risk;       // Risk Display

   CButton           m_btn_close_all;

public:
                     CTradingPanel(void);
                    ~CTradingPanel(void);

   // Create method override
   virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);

   // Update method to refresh data
   void              UpdateValues(string regime_text, string advice_text, double score, double volatility);

protected:
   // Event Handlers
   virtual bool      OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   void              OnClickCloseAll(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradingPanel::CTradingPanel(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradingPanel::~CTradingPanel(void)
  {
  }
//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CTradingPanel::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
  {
   // 1. Create Main Dialog
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false;

   // 2. Create Title
   if(!m_lbl_title.Create(chart, name+"Title", subwin, MARGIN_LEFT, MARGIN_TOP, x2-x1-MARGIN_LEFT, MARGIN_TOP+ROW_HEIGHT)) return false;
   m_lbl_title.Text("WPR Analyst Assistant");
   m_lbl_title.Color(clrWhite);
   m_lbl_title.Font("Arial Bold");
   Add(m_lbl_title);

   // 3. Regime Label
   int row = 1;
   if(!m_lbl_regime.Create(chart, name+"Regime", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), x2-x1-MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_lbl_regime.Text("Regime: Waiting...");
   Add(m_lbl_regime);

   // 4. Advice Label (Large)
   row = 2;
   if(!m_lbl_advice.Create(chart, name+"Advice", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), x2-x1-MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_lbl_advice.Text("ADVICE: ---");
   m_lbl_advice.Color(clrGold);
   Add(m_lbl_advice);

   // 5. Score Label
   row = 3;
   if(!m_lbl_score.Create(chart, name+"Score", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), x2-x1-MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_lbl_score.Text("Conviction: 0%");
   Add(m_lbl_score);

   // 6. Volatility Label
   row = 4;
   if(!m_lbl_volatility.Create(chart, name+"Vol", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), x2-x1-MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_lbl_volatility.Text("Tick Vol: 0.00000");
   Add(m_lbl_volatility);

   // --- Cockpit Controls ---
   row = 5;
   int col_width = (x2-x1-MARGIN_LEFT*2) / 3;

   // Mode Toggle
   if(!m_btn_mode.Create(chart, name+"Mode", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), MARGIN_LEFT+col_width, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_btn_mode.Text("MODE: AUTO");
   m_btn_mode.ColorBackground(clrGreen);
   Add(m_btn_mode);

   // SL Toggle
   if(!m_btn_sl_auto.Create(chart, name+"SLMode", subwin, MARGIN_LEFT+col_width+5, MARGIN_TOP + (row*ROW_HEIGHT), MARGIN_LEFT+col_width*2, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_btn_sl_auto.Text("SL: AUTO");
   Add(m_btn_sl_auto);

   // Risk Control
   row = 6;
   if(!m_lbl_risk.Create(chart, name+"RiskLbl", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT), MARGIN_LEFT+col_width, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_lbl_risk.Text("Risk: 1.0%");
   Add(m_lbl_risk);

   if(!m_btn_risk_up.Create(chart, name+"RiskUp", subwin, MARGIN_LEFT+col_width+5, MARGIN_TOP + (row*ROW_HEIGHT), MARGIN_LEFT+col_width+40, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_btn_risk_up.Text("+");
   Add(m_btn_risk_up);

   if(!m_btn_risk_down.Create(chart, name+"RiskDn", subwin, MARGIN_LEFT+col_width+45, MARGIN_TOP + (row*ROW_HEIGHT), MARGIN_LEFT+col_width+80, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT)) return false;
   m_btn_risk_down.Text("-");
   Add(m_btn_risk_down);

   // 7. Close All Button
   row = 7;
   if(!m_btn_close_all.Create(chart, name+"BtnClose", subwin, MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT) + 10, x2-x1-MARGIN_LEFT, MARGIN_TOP + (row*ROW_HEIGHT)+ROW_HEIGHT + 10)) return false;
   m_btn_close_all.Text("CLOSE ALL POSITIONS");
   m_btn_close_all.ColorBackground(clrRed);
   m_btn_close_all.Color(clrWhite);
   Add(m_btn_close_all);

   return true;
  }
//+------------------------------------------------------------------+
//| Update UI Values                                                 |
//+------------------------------------------------------------------+
void CTradingPanel::UpdateValues(string regime_text, string advice_text, double score, double volatility)
  {
   m_lbl_regime.Text("Regime: " + regime_text);
   m_lbl_advice.Text("ADVICE: " + advice_text);
   m_lbl_score.Text(StringFormat("Conviction: %.1f %%", score));
   m_lbl_volatility.Text(StringFormat("Tick SD: %.5f", volatility));

   // Color coding for advice
   if(StringFind(advice_text, "BUY") >= 0) m_lbl_advice.Color(clrLime);
   else if(StringFind(advice_text, "SELL") >= 0) m_lbl_advice.Color(clrRed);
   else m_lbl_advice.Color(clrGray);
  }
//+------------------------------------------------------------------+
//| Event Handler                                                    |
//+------------------------------------------------------------------+
bool CTradingPanel::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // Process button clicks
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == m_btn_close_all.Name()) { OnClickCloseAll(); return true; }
      if(sparam == m_btn_mode.Name())      { ToggleMode(); return true; }
      if(sparam == m_btn_risk_up.Name())   { AdjustRisk(0.5); return true; }
      if(sparam == m_btn_risk_down.Name()) { AdjustRisk(-0.5); return true; }
     }

   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
//| Button Handler                                                   |
//+------------------------------------------------------------------+
void CTradingPanel::OnClickCloseAll(void)
  {
   Print("User requested CLOSE ALL POSITIONS via Dashboard.");
  }

void CTradingPanel::ToggleMode(void)
  {
   static bool is_auto = true;
   is_auto = !is_auto;
   m_btn_mode.Text(is_auto ? "MODE: AUTO" : "MODE: MANUAL");
   m_btn_mode.ColorBackground(is_auto ? clrGreen : clrOrange);
  }

void CTradingPanel::AdjustRisk(double delta)
  {
   static double risk = 1.0;
   risk += delta;
   if(risk < 0.5) risk = 0.5;
   if(risk > 10.0) risk = 10.0;
   m_lbl_risk.Text(StringFormat("Risk: %.1f%%", risk));
  }
//+------------------------------------------------------------------+
