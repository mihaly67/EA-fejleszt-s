//+------------------------------------------------------------------+
//|                                                Hybrid_Panel.mqh |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Hybrid System Trading Panel (Face)                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property strict

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include <Controls\ComboBox.mqh>
#include <Hybrid\Hybrid_TradingAgent.mqh>
#include <Hybrid\Hybrid_Signal_Aggregator.mqh>

//--- Resources for Checkboxes/Spinners (Standard MQL5 Paths)
#resource "\\Include\\Controls\\res\\CheckBoxOn.bmp"
#resource "\\Include\\Controls\\res\\CheckBoxOff.bmp"
#resource "\\Include\\Controls\\res\\SpinInc.bmp"
#resource "\\Include\\Controls\\res\\SpinDec.bmp"

enum ENUM_LABEL_ALIGN{
   LEFT = -1,
   CENTER = 0,
   RIGHT = 1
};

enum ENUM_PANEL_PAGE {
   PAGE_DASHBOARD,
   PAGE_TRADE,
   PAGE_PROFIT
};

//+------------------------------------------------------------------+
//| Class: Hybrid_Panel                                              |
//+------------------------------------------------------------------+
class Hybrid_Panel : public CAppDialog
{
private:
   //--- Logic Modules
   Hybrid_TradingAgent     m_agent;
   HybridSignal_Aggregator *m_brain; // Pointer to external brain (or internal)

   //--- State
   ENUM_PANEL_PAGE         m_active_page;

   //--- Tab Buttons
   CButton                 m_tab_dashboard;
   CButton                 m_tab_trade;
   CButton                 m_tab_profit;

   //--- DASHBOARD Controls
   CLabel                  m_lbl_mom_name, m_lbl_mom_val;
   CLabel                  m_lbl_flow_name, m_lbl_flow_val;
   CLabel                  m_lbl_ctx_name, m_lbl_ctx_val;
   CLabel                  m_lbl_wvf_name, m_lbl_wvf_val;
   CLabel                  m_lbl_inst_name, m_lbl_inst_val;
   CLabel                  m_lbl_conviction;

   //--- TRADE Controls (Adapted from TradingPanel)
   CLabel                  mAsk_value, mSpread_value, mBid_value;
   CLabel                  mAmount_label, mLots1_label, mSL_label, mTP_label;
   CLabel                  mSellPositions_value, mBuyPositions_value;
   CLabel                  mSellProfit_value, mBuyProfit_value;
   CLabel                  mEquity_value;

   CEdit                   mLots_input, mSL_input, mTP_input, mAmount_input;
   CBmpButton              mIncreaseLots_button, mDecreaseLots_button;
   CBmpButton              mIncreaseSL_button, mDecreaseSL_button;
   CBmpButton              mIncreaseTP_button, mDecreaseTP_button;
   CBmpButton              mSL_button, mTP_button; // Checkboxes

   CButton                 mOrderSell_button, mOrderBuy_button, mOrderClose_button;
   CButton                 mCloseAll_button;

   //--- Variables
   double                  mLots;
   double                  mSL, mTP;
   bool                    mEnable_SL, mEnable_TP;

   //--- Layout Constants
   #define  H_STEP   (int)(ClientAreaHeight()/18/4)
   #define  H_HEIGHT (int)(ClientAreaHeight()/18)
   #define  H_BORDER (int)(ClientAreaHeight()/24)

public:
   Hybrid_Panel();
   ~Hybrid_Panel();

   bool Init(HybridSignal_Aggregator *brain, int magic);

   virtual bool Create(const string name, const int x1=5,const int y1=20,const int x2=320,const int y2=420);
   virtual void Update(void); // Refresh UI

   //--- Event Handlers
   void OnClickTabDashboard();
   void OnClickTabTrade();
   void OnClickTabProfit();

   void OnClickBuy();
   void OnClickSell();
   void OnClickCloseAll();

   void OnChangeLots();
   // ... add others as needed

private:
   bool CreateLabel(CLabel &object, const string text, const int x, const int y, ENUM_LABEL_ALIGN align);
   bool CreateButton(CButton &object, const string text, const int x, const int y, const int x_size, const int y_size);
   bool CreateEdit(CEdit &object, const string text, const int x, const int y, const int x_size, const int y_size);
   bool CreateBmpButton(CBmpButton &object, const int x, const int y, string BmpON, string BmpOFF);

   void SetPage(ENUM_PANEL_PAGE page);
   void UpdateDashboard();
   void UpdateTrade();
};

//--- Event Map
EVENT_MAP_BEGIN(Hybrid_Panel)
   ON_EVENT(ON_CLICK, m_tab_dashboard, OnClickTabDashboard)
   ON_EVENT(ON_CLICK, m_tab_trade,     OnClickTabTrade)
   ON_EVENT(ON_CLICK, m_tab_profit,    OnClickTabProfit)
   ON_EVENT(ON_CLICK, mOrderBuy_button, OnClickBuy)
   ON_EVENT(ON_CLICK, mOrderSell_button, OnClickSell)
   ON_EVENT(ON_CLICK, mCloseAll_button, OnClickCloseAll)
   // Add spin buttons...
EVENT_MAP_END(CAppDialog)

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Hybrid_Panel::Hybrid_Panel()
{
   m_active_page = PAGE_DASHBOARD;
   mLots = 0.01;
   mSL = 15;
   mTP = 30;
   mEnable_SL = true;
   mEnable_TP = true;
}

Hybrid_Panel::~Hybrid_Panel()
{
}

bool Hybrid_Panel::Init(HybridSignal_Aggregator *brain, int magic)
{
   m_brain = brain;
   return m_agent.Init(magic);
}

//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool Hybrid_Panel::Create(const string name, const int x1=5,const int y1=20,const int x2=320,const int y2=420)
{
   if(!CAppDialog::Create(0, name, 0, x1, y1, x2, y2)) return false;

   int width = ClientAreaWidth();
   int btn_w = width / 3;
   int y = H_BORDER;

   //--- 1. Tabs
   if(!CreateButton(m_tab_dashboard, "DASHBOARD", 0, 0, btn_w, H_HEIGHT)) return false;
   if(!CreateButton(m_tab_trade, "TRADE", btn_w, 0, btn_w, H_HEIGHT)) return false;
   if(!CreateButton(m_tab_profit, "PROFIT", btn_w*2, 0, btn_w, H_HEIGHT)) return false;

   y += H_HEIGHT + H_STEP;

   //--- 2. Dashboard Page Controls
   // Labels
   int lbl_x = H_BORDER;
   int val_x = width - H_BORDER - 50;
   int row_h = H_HEIGHT + 5;

   CreateLabel(m_lbl_mom_name, "Momentum:", lbl_x, y, LEFT);
   CreateLabel(m_lbl_mom_val, "---", val_x, y, RIGHT);
   y += row_h;

   CreateLabel(m_lbl_flow_name, "Flow:", lbl_x, y, LEFT);
   CreateLabel(m_lbl_flow_val, "---", val_x, y, RIGHT);
   y += row_h;

   CreateLabel(m_lbl_ctx_name, "Context:", lbl_x, y, LEFT);
   CreateLabel(m_lbl_ctx_val, "---", val_x, y, RIGHT);
   y += row_h;

   CreateLabel(m_lbl_wvf_name, "WVF (Fear):", lbl_x, y, LEFT);
   CreateLabel(m_lbl_wvf_val, "---", val_x, y, RIGHT);
   y += row_h;

   CreateLabel(m_lbl_inst_name, "Institutional:", lbl_x, y, LEFT);
   CreateLabel(m_lbl_inst_val, "---", val_x, y, RIGHT);
   y += row_h * 2;

   CreateLabel(m_lbl_conviction, "WAITING...", width/2, y, CENTER);
   m_lbl_conviction.FontSize(12);

   //--- 3. Trade Page Controls (Created but Hidden)
   // Reuse 'y' from top for consistent layout, or reset? Reset.
   y = H_HEIGHT + H_STEP * 2;
   int x_mid = width / 2;

   // Price Display
   CreateLabel(mBid_value, "0.00000", H_BORDER, y, LEFT);
   CreateLabel(mAsk_value, "0.00000", width-H_BORDER, y, RIGHT);
   y += H_HEIGHT * 1.5;

   // Buttons
   CreateButton(mOrderSell_button, "SELL", H_BORDER, y, 80, H_HEIGHT*2);
   CreateButton(mOrderBuy_button, "BUY", width-H_BORDER-80, y, 80, H_HEIGHT*2);
   y += H_HEIGHT * 2 + H_STEP;

   // Lots
   CreateLabel(mLots1_label, "Lots:", H_BORDER, y, LEFT);
   CreateEdit(mLots_input, "0.01", H_BORDER+50, y, 60, H_HEIGHT);
   y += H_HEIGHT + H_STEP;

   // SL/TP
   CreateLabel(mSL_label, "SL:", H_BORDER, y, LEFT);
   CreateEdit(mSL_input, "15.0", H_BORDER+30, y, 50, H_HEIGHT);
   CreateLabel(mTP_label, "TP:", x_mid+10, y, LEFT);
   CreateEdit(mTP_input, "30.0", x_mid+40, y, 50, H_HEIGHT);
   y += H_HEIGHT + H_STEP;

   // Close
   CreateButton(mCloseAll_button, "CLOSE ALL", H_BORDER, y, width-2*H_BORDER, H_HEIGHT);
   y += H_HEIGHT + H_STEP;

   // Info
   CreateLabel(mEquity_value, "Equity: ---", width/2, y, CENTER);

   // Initial State
   SetPage(PAGE_DASHBOARD);

   return true;
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool Hybrid_Panel::CreateLabel(CLabel &object, const string text, const int x, const int y, ENUM_LABEL_ALIGN align)
{
   if(!object.Create(0, m_name+"Lbl"+(string)MathRand(), 0, x, y, 0, 0)) return false;
   object.Text(text);
   ObjectSetInteger(0,object.Name(),OBJPROP_ANCHOR,(align==LEFT ? ANCHOR_LEFT_UPPER : (align==RIGHT ? ANCHOR_RIGHT_UPPER : ANCHOR_UPPER)));
   Add(object);
   return true;
}

bool Hybrid_Panel::CreateButton(CButton &object, const string text, const int x, const int y, const int x_size, const int y_size)
{
   if(!object.Create(0, m_name+"Btn"+(string)MathRand(), 0, x, y, x+x_size, y+y_size)) return false;
   object.Text(text);
   Add(object);
   return true;
}

bool Hybrid_Panel::CreateEdit(CEdit &object, const string text, const int x, const int y, const int x_size, const int y_size)
{
   if(!object.Create(0, m_name+"Edt"+(string)MathRand(), 0, x, y, x+x_size, y+y_size)) return false;
   object.Text(text);
   Add(object);
   return true;
}

//+------------------------------------------------------------------+
//| Set Page Visibility                                              |
//+------------------------------------------------------------------+
void Hybrid_Panel::SetPage(ENUM_PANEL_PAGE page)
{
   m_active_page = page;

   // Dashboard Visibility
   bool dash = (page == PAGE_DASHBOARD);
   m_lbl_mom_name.Visible(dash); m_lbl_mom_val.Visible(dash);
   m_lbl_flow_name.Visible(dash); m_lbl_flow_val.Visible(dash);
   m_lbl_ctx_name.Visible(dash); m_lbl_ctx_val.Visible(dash);
   m_lbl_wvf_name.Visible(dash); m_lbl_wvf_val.Visible(dash);
   m_lbl_inst_name.Visible(dash); m_lbl_inst_val.Visible(dash);
   m_lbl_conviction.Visible(dash);

   // Trade Visibility
   bool trade = (page == PAGE_TRADE);
   mBid_value.Visible(trade); mAsk_value.Visible(trade);
   mOrderSell_button.Visible(trade); mOrderBuy_button.Visible(trade);
   mLots1_label.Visible(trade); mLots_input.Visible(trade);
   mSL_label.Visible(trade); mSL_input.Visible(trade);
   mTP_label.Visible(trade); mTP_input.Visible(trade);
   mCloseAll_button.Visible(trade);
   mEquity_value.Visible(trade);

   // Profit Visibility
   bool profit = (page == PAGE_PROFIT);
   // ... Add profit controls later

   // Highlight Tabs
   m_tab_dashboard.Color(dash ? clrBlue : clrBlack);
   m_tab_trade.Color(trade ? clrBlue : clrBlack);
   m_tab_profit.Color(profit ? clrBlue : clrBlack);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Events                                                           |
//+------------------------------------------------------------------+
void Hybrid_Panel::OnClickTabDashboard() { SetPage(PAGE_DASHBOARD); }
void Hybrid_Panel::OnClickTabTrade()     { SetPage(PAGE_TRADE); }
void Hybrid_Panel::OnClickTabProfit()    { SetPage(PAGE_PROFIT); }

void Hybrid_Panel::OnClickBuy()
{
   double lots = StringToDouble(mLots_input.Text());
   double sl = StringToDouble(mSL_input.Text());
   double tp = StringToDouble(mTP_input.Text());
   m_agent.OrderBuy(lots, sl, tp);
}

void Hybrid_Panel::OnClickSell()
{
   double lots = StringToDouble(mLots_input.Text());
   double sl = StringToDouble(mSL_input.Text());
   double tp = StringToDouble(mTP_input.Text());
   m_agent.OrderSell(lots, sl, tp);
}

void Hybrid_Panel::OnClickCloseAll()
{
   m_agent.OrderCloseAll();
}

//+------------------------------------------------------------------+
//| Update Loop                                                      |
//+------------------------------------------------------------------+
void Hybrid_Panel::Update(void)
{
   if(m_active_page == PAGE_DASHBOARD) UpdateDashboard();
   if(m_active_page == PAGE_TRADE)     UpdateTrade();
}

void Hybrid_Panel::UpdateDashboard()
{
   if(!m_brain) return;
   HybridSignalStatus status = m_brain.GetStatus();

   m_lbl_mom_val.Text(DoubleToString(status.MomentumScore, 2));
   m_lbl_mom_val.Color(status.MomentumScore > 0 ? clrGreen : clrRed);

   m_lbl_flow_val.Text(DoubleToString(status.FlowScore, 2));
   m_lbl_flow_val.Color(status.FlowScore > 0 ? clrGreen : clrRed);

   m_lbl_ctx_val.Text(DoubleToString(status.ContextScore, 2));

   m_lbl_wvf_val.Text(DoubleToString(status.WVFScore, 2));

   m_lbl_inst_val.Text(DoubleToString(status.InstScore, 2));

   m_lbl_conviction.Text(status.Recommendation + " (" + DoubleToString(status.TotalConviction, 2) + ")");
   m_lbl_conviction.Color(status.SignalColor);
}

void Hybrid_Panel::UpdateTrade()
{
   mAsk_value.Text(DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits));
   mBid_value.Text(DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits));
   mEquity_value.Text("Equity: " + DoubleToString(m_agent.Equity(), 2));
}
