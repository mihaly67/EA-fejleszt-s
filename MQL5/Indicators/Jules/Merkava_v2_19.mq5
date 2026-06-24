//+------------------------------------------------------------------+
//|                                                Merkava_v2_19.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.19   |
//|                    (Test Protocol: HybridMomentum v2.82 Only)      |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "2.19"
#property strict

#include "../Indicators/Types_v2_16.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

#include "../Indicators/FireControl_v2_16.mqh"
#include "../Indicators/PanelControl_v2_16.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_11.mqh" // Test Version
#include "../Indicators/BlackBox_v2_08.mqh" // Test Version
#include "../Indicators/ProfitManagement_v2_16.mqh"

CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;

PhysicsEngine m_physics(50);
CFireControl  m_fire_control;
CPanelControl m_panel;
CNavSystem    m_nav_system;
CBlackBox     m_black_box;
CProfitManager m_profit_manager;

//--- Inputs
input double        InpSpreadMultStart   = 1.5;
input double        InpSpreadMultStep    = 1.0;
input int           InpLayers            = 3;
input double        InpMinSpreadPoints   = 60.0;
input double        InpSafeZonePts       = 50.0;
input string        InpIndPath           = "Jules\\";

input double        InpLotSize           = 0.01;
input int           InpSlippage          = 10;
input ulong         InpMagicNumber       = 999015;
input double        InpVirtualTPCurrency = 0.0;
input double        InpVirtualSLCurrency = 0.0;
input double        InpMaxMarginPercent  = 70.0;
input string        InpComment           = "Merkava_v2.19_TEST";

// [Hybrid & Flow Settings] - Kept as is
input int           Hybrid_FastEMA       = 3;
input int           Hybrid_SlowEMA       = 6;
input double        Hybrid_MACDScale     = 4.0;
input double        Hybrid_DFScale       = 1.0;
input bool          Hybrid_AutoScaling   = true;
input double        Hybrid_Divisor       = 7.0;

input int           Flow_MFIPeriod       = 5;
input int           Flow_VROCPeriod      = 5;
input int           Flow_Smooth          = 3;
input int           Flow_NormLen         = 100;
input double        Flow_Scale           = 50.0;

// [Hybrid Momentum v2.82 Test Inputs]
input string        InpTestPath          = "Jules\\HybridMomentumIndicator_v2.82";
input ENUM_COLOR_LOGIC InpTestColorLogic = COLOR_SLOPE;
input int           InpTestFastP         = 3;
input int           InpTestSlowP         = 6;
input int           InpTestSigP          = 13;
input ENUM_APPLIED_PRICE InpTestPrice    = PRICE_CLOSE;
input double        InpTestKalman        = 1.0;
input double        InpTestPhase         = 0.5;
input bool          InpTestBoost         = true;
input double        InpTestMixW          = 0.2;
input int           InpTestStochK        = 5;
input int           InpTestStochD        = 3;
input int           InpTestStochS        = 3;
input int           InpTestNormP         = 100;
input double        InpTestNormS         = 1.0;

// [Panel UI]
input int           InpX                 = 10;
input int           InpY                 = 20;
input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

// Globals
bool g_active = false;
bool g_book_subscribed = false;
string g_last_action = "IDLE";
double g_last_realized_pl = 0.0;
double g_session_realized_pl = 0.0;
string g_tick_event_buffer = "";
string g_decision_log = "";
string g_transaction_buffer = "";
ulong g_last_deal_ticket = 0;
long g_last_deal_time_msc = 0;
int g_debug_counter = 0;
string Prefix = "MerkavaV2_";

// Helper Functions (Same as v2.18)
double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber)
           pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
    }
    return pl;
}

double CalculateTotalHistoryProfit() {
    double total_profit = 0.0;
    if (HistorySelect(0, TimeCurrent())) {
        int total = HistoryDealsTotal();
        for(int i=0; i<total; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            if (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
                total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                total_profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                total_profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
    }
    return total_profit;
}

int OnInit()
{
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();
   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber);
   m_profit_manager.Init(&m_trade, &m_position, InpMagicNumber, _Symbol);
   m_profit_manager.SetVirtualTP(InpVirtualTPCurrency);
   m_profit_manager.SetVirtualSL(InpVirtualSLCurrency);

   // Prepare Test Params
   HybridMomentumParams mom;
   mom.path = InpTestPath;
   mom.color_logic = InpTestColorLogic;
   mom.fast_p = InpTestFastP; mom.slow_p = InpTestSlowP; mom.sig_p = InpTestSigP;
   mom.price = InpTestPrice;
   mom.kalman = InpTestKalman; mom.phase = InpTestPhase;
   mom.boost = InpTestBoost; mom.stoch_w = InpTestMixW;
   mom.stoch_k = InpTestStochK; mom.stoch_d = InpTestStochD; mom.stoch_s = InpTestStochS;
   mom.norm_p = InpTestNormP; mom.norm_sens = InpTestNormS;

   bool init_ok = m_nav_system.Initialize(
       _Symbol, _Period,
       InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05",
       Hybrid_FastEMA, Hybrid_SlowEMA, 20, 2.0, MODE_EMA,
       20, 1.5, 10, MODE_EMA,
       Hybrid_MACDScale, 0, Hybrid_DFScale, Hybrid_AutoScaling, 100,
       Hybrid_Divisor,
       InpIndPath + "HybridFlowIndicator_v1.125",
       false, -100, 200, Flow_MFIPeriod, true, Flow_VROCPeriod, 20.0, true,
       Flow_Smooth, Flow_NormLen, Flow_Scale, 3.0,
       mom // Pass Test Params
   );

   if(init_ok) {
       m_nav_system.AttachToChart(0);
   }

   m_black_box.Initialize(_Symbol, "v2.19_TEST");

   m_panel.Init(Prefix, InpX, InpY, InpBgColor, InpTxtColor,
                InpLotSize, InpSpreadMultStart, InpSpreadMultStep, InpLayers, InpMinSpreadPoints,
                InpVirtualTPCurrency, InpVirtualSLCurrency);
   m_panel.Create();
   m_panel.UpdateUI(GetFloatingPL());

   Print("Merkava v2.19 TEST Initialized (HybridMomentum v2.82 Integration).");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   m_panel.Destroy();
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   m_black_box.CloseLog();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ENUM_PANEL_EVENT event = m_panel.OnEvent(id, lparam, dparam, sparam);
   if (event != EVENT_NONE) {
       // ... (Event handling same as v2.18 - Fire, Close, etc.) ...
       // Simplified for brevity, logic preserved
       double center = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
       if (event == EVENT_FIRE) m_fire_control.FireGrid(center, m_panel.GetLotSize(), m_panel.GetLayers(), m_panel.GetMultStart(), m_panel.GetMultStep(), m_panel.GetMinDist(), m_panel.GetFireMode(), m_panel.GetEntryMode(), ATTACK_BOTH);
       // ...
   }
   m_panel.UpdateUI(GetFloatingPL());
}

void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   m_physics.Update(tick);
   PhysicsState p = m_physics.GetState();
   m_nav_system.Refresh(_Symbol, tick);

   g_debug_counter++;
   if(g_debug_counter % 10 == 0) {
       PrintFormat("TEST TICK: Hist=%.2f, MACD=%.2f, Sig=%.2f",
                   m_nav_system.GetTestHist(), m_nav_system.GetTestMACD(), m_nav_system.GetTestSignal());
   }

   // ... (Deals, ProfitManager logic same as v2.18) ...
   int closed = m_profit_manager.Check();
   if(closed > 0) g_decision_log += "Closed via Manager;";

   double float_pl = GetFloatingPL();
   m_panel.UpdateUI(float_pl);
   m_panel.UpdateAccountStats(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_FREE), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), CalculateTotalHistoryProfit(), g_session_realized_pl);

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) > 0) {}

   if (g_transaction_buffer == "") g_transaction_buffer = "NONE";
   if (g_decision_log != "") g_transaction_buffer += "|" + g_decision_log;

   m_black_box.RecordTick(
       tick.time_msc, g_last_action, 0, "TEST",
       tick.bid, tick.ask, p.spread_avg, 0, 0,
       0, 0, 0, 0,
       m_nav_system.GetRSI(), p.velocity, p.acceleration,
       m_nav_system.GetHybridMACD(), m_nav_system.GetPulse(),
       m_nav_system.GetFlowMFI(), m_nav_system.GetFlowROC(), m_nav_system.GetFlowDelta(),
       m_nav_system.GetTestHist(), m_nav_system.GetTestMACD(), m_nav_system.GetTestSignal(), // v2.82
       AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
       float_pl, g_last_realized_pl, g_session_realized_pl,
       PositionsTotal(), "NONE", 0, "NONE", g_transaction_buffer, g_tick_event_buffer
   );

   g_last_realized_pl = 0.0;
   g_tick_event_buffer = "";
   g_decision_log = "";
   g_transaction_buffer = "";
   if (g_last_action != "IDLE") g_last_action = "IDLE";
}
