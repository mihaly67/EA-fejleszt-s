//+------------------------------------------------------------------+
//|                                                Merkava_v2_51.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.51   |
//|                         (Mirror Phase: MDAS Visualization)       |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "2.51"
#property strict

// --- CORE MDAS INTEGRATION (MIRROR PHASE) ---
#include <Merkava_Defense.mqh> 

// Use legacy includes from v2.40 for compatibility
#include "../Indicators/Types_v2_16.mqh" 
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

#include "../Indicators/FireControl_v2_25.mqh"
#include "../Indicators/StealthEngine.mqh"
#include "../Indicators/StealthRegistry_v1_08.mqh"
#include "../Indicators/PanelControl_v2_21.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_20.mqh"
#include "../Indicators/BlackBox_v2_09.mqh"
#include "../Indicators/ProfitManagement_v2_18.mqh"

CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;

// --- MDAS CONTROLLER ---
CMerkavaDefense *g_defense;

PhysicsEngine m_physics(50);
CFireControl  m_fire_control;
CStealthEngine m_stealth; 
CStealthRegistry m_registry;
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
input ulong         InpMagicNumber       = 999050; // Updated Magic v2.51
input double        InpVirtualTPCurrency = 0.0;
input double        InpVirtualSLCurrency = 0.0;
input double        InpMaxMarginPercent  = 70.0;
input string        InpComment           = "Merkava v2.51";

// [Deep Stealth Engine (Humanizer)]
input bool          Stealth_Enabled      = true;
input int           Stealth_BaseDelay    = 400; // ms
input int           Stealth_Jitter       = 150; // ms +/-
input bool          DeepStealth_Enabled  = true; 

// [Mirror Phase Settings]
input bool          MDAS_VisualDebug     = true; // Enable Ghost Mouse & Panel

// [Hybrid & Flow Settings]
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

// [Hybrid Context Settings v3.27]
input string        InpContextPath       = "Jules\\HybridContextIndicator_v3.27_StyleFix";
input bool          Ctx_ShowPivots       = true;
input bool          Ctx_ShowTrends       = true;
input int           Ctx_MaxHistory       = 50000;
input bool          Ctx_ShowFibo         = false; 
input int           Ctx_FiboHist         = 0;

input bool          Ctx_Mic_Use          = true;
input int           Ctx_Mic_Depth        = 3;
input int           Ctx_Mic_Dev          = 5;
input int           Ctx_Mic_Back         = 3;
input ENUM_LINE_STYLE Ctx_Mic_Style      = STYLE_DOT;
input int           Ctx_Mic_Width        = 1;
input color         Ctx_Mic_ColorR       = clrRed;
input color         Ctx_Mic_ColorS       = clrGreen;

input bool          Ctx_Sec_Use          = true;
input int           Ctx_Sec_Depth        = 10;
input int           Ctx_Sec_Dev          = 10;
input int           Ctx_Sec_Back         = 5;
input ENUM_LINE_STYLE Ctx_Sec_Style      = STYLE_DASHDOT;
input int           Ctx_Sec_Width        = 1;
input color         Ctx_Sec_ColorR       = clrRed;
input color         Ctx_Sec_ColorS       = clrGreen;

input bool          Ctx_Ter_Use          = true;
input int           Ctx_Ter_Depth        = 20;
input int           Ctx_Ter_Dev          = 10;
input int           Ctx_Ter_Back         = 5;
input ENUM_LINE_STYLE Ctx_Ter_Style      = STYLE_SOLID;
input int           Ctx_Ter_Width        = 1;
input color         Ctx_Ter_ColorR       = clrRed;
input color         Ctx_Ter_ColorS       = clrGreen;

input int           Ctx_Tr_FastP         = 50;
input int           Ctx_Tr_SlowP         = 150;
input ENUM_MA_METHOD Ctx_Tr_Method       = MODE_EMA;

// [Hybrid Momentum v2.82 Inputs]
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

// Helper Functions
double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           bool is_mine = false;
           if(DeepStealth_Enabled) is_mine = m_registry.IsMyTicket(m_position.Ticket());
           else is_mine = (m_position.Magic() == InpMagicNumber);

           if(is_mine)
               pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
       }
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
   // --- MDAS INIT (NUCLEAR OPTION) ---
   Print("=== Merkava v2.51 (Mirror Phase) Startup ===");
   g_defense = new CMerkavaDefense(MDAS_VisualDebug);
   
   // Use '.' operator for pointer access in MQL5 (standard practice for dynamic objects)
   if(!g_defense.SecureBoot()) {
       Print("MDAS: Environment Unstable (Running in Diagnostic Mode)");
   } else {
       Print("MDAS: Environment Secure.");
   }

   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
       Print("⚠️ WARNING: Account is NOT in Hedging Mode! Instant Entry (Hedge) may fail.");
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();
   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   // --- INITIALIZE STEALTH ENGINE ---
   m_stealth.Init(Stealth_Enabled, Stealth_BaseDelay, Stealth_Jitter);
   PrintFormat("🥷 Stealth Engine Initialized: %s", Stealth_Enabled ? "ON" : "OFF");

   // --- INITIALIZE DEEP STEALTH REGISTRY ---
   CStealthRegistry *reg_ptr = NULL;
   if(DeepStealth_Enabled) {
       m_registry.Init(); 
       reg_ptr = &m_registry;
       m_registry.LogAudit("", 0, 0, ""); // SILENT LOG
   }

   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber, &m_stealth, reg_ptr);
   m_profit_manager.Init(&m_trade, &m_position, InpMagicNumber, _Symbol, reg_ptr);

   m_profit_manager.SetVirtualTP(InpVirtualTPCurrency);
   m_profit_manager.SetVirtualSL(InpVirtualSLCurrency);

   // Prepare Context Params (v3.27)
   ContextParams ctx;
   ctx.path = InpContextPath;
   ctx.show_pivots = Ctx_ShowPivots; ctx.show_trends = Ctx_ShowTrends; ctx.max_hist = Ctx_MaxHistory;
   ctx.show_fibo = Ctx_ShowFibo; ctx.fibo_hist = Ctx_FiboHist;
   ctx.m_use = Ctx_Mic_Use; ctx.m_depth = Ctx_Mic_Depth; ctx.m_dev = Ctx_Mic_Dev; ctx.m_back = Ctx_Mic_Back;
   ctx.m_style = Ctx_Mic_Style; ctx.m_width = Ctx_Mic_Width; ctx.m_c1 = Ctx_Mic_ColorR; ctx.m_c2 = Ctx_Mic_ColorS;
   ctx.s_use = Ctx_Sec_Use; ctx.s_depth = Ctx_Sec_Depth; ctx.s_dev = Ctx_Sec_Dev; ctx.s_back = Ctx_Sec_Back;
   ctx.s_style = Ctx_Sec_Style; ctx.s_width = Ctx_Sec_Width; ctx.s_c1 = Ctx_Sec_ColorR; ctx.s_c2 = Ctx_Sec_ColorS;
   ctx.t_use = Ctx_Ter_Use; ctx.t_depth = Ctx_Ter_Depth; ctx.t_dev = Ctx_Ter_Dev; ctx.t_back = Ctx_Ter_Back;
   ctx.t_style = Ctx_Ter_Style; ctx.t_width = Ctx_Ter_Width; ctx.t_c1 = Ctx_Ter_ColorR; ctx.t_c2 = Ctx_Ter_ColorS;
   ctx.tr_fast = Ctx_Tr_FastP; ctx.tr_slow = Ctx_Tr_SlowP; ctx.tr_method = Ctx_Tr_Method;

   // Prepare Momentum Params (v2.82)
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
       ctx, mom
   );

   if(init_ok) {
       m_nav_system.AttachToChart(0);
   }

   m_black_box.Initialize(_Symbol, "v2.51");

   string version_str = "MERKAVA v2.51 (Mirror Phase)";

   m_panel.Init(Prefix, InpX, InpY, InpBgColor, InpTxtColor,
                InpLotSize, InpSpreadMultStart, InpSpreadMultStep, InpLayers, InpMinSpreadPoints,
                InpVirtualTPCurrency, InpVirtualSLCurrency, version_str); 
   m_panel.Create();
   m_panel.UpdateUI(GetFloatingPL());
   
   // Refresh Diagnostics Panel on top of everything
   if(CheckPointer(g_defense) != POINTER_INVALID) g_defense.SetVisualMode(MDAS_VisualDebug);

   Print("Merkava v2.51 Initialized.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(CheckPointer(g_defense) == POINTER_DYNAMIC) delete g_defense;

   m_panel.Destroy();
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   m_black_box.CloseLog();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
}

//+------------------------------------------------------------------+
//| Chart Event - FULL RESTORATION                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ENUM_PANEL_EVENT event = m_panel.OnEvent(id, lparam, dparam, sparam);

   if (event != EVENT_NONE)
   {
       double center = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
       double lot = m_panel.GetLotSize();
       int layers = m_panel.GetLayers();
       double mstart = m_panel.GetMultStart();
       double mstep = m_panel.GetMultStep();
       double mindist = m_panel.GetMinDist();
       ENUM_FIRE_MODE mode = m_panel.GetFireMode();
       ENUM_ENTRY_MODE entry = m_panel.GetEntryMode();

       double equity = AccountInfoDouble(ACCOUNT_EQUITY);
       double margin = AccountInfoDouble(ACCOUNT_MARGIN);
       double margin_percent = (equity > 0) ? (margin / equity) * 100.0 : 0.0;

       if (margin_percent > InpMaxMarginPercent && (event == EVENT_FIRE || event == EVENT_FIRE_BUY || event == EVENT_FIRE_SELL)) {
           PrintFormat("⛔ SAFETY MARGIN LIMIT HIT! Used: %.1f%% > Limit: %.1f%%. Fire BLOCKED.", margin_percent, InpMaxMarginPercent);
           Alert("⛔ SAFETY MARGIN LIMIT HIT! Used: %.1f%% > Limit: %.1f%%. Fire BLOCKED.");
           return; 
       }

       if (event == EVENT_FIRE)
       {
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_BOTH);
           g_last_action = (mode == FIRE_MODE_STOP) ? "TRAP_SET" : "LIMIT_GRID";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired BOTH L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_FIRE_BUY)
       {
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_BUY);
           g_last_action = "FIRE_BUY";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired BUY L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_FIRE_SELL)
       {
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_SELL);
           g_last_action = "FIRE_SELL";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired SELL L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_CEASE_FIRE)
       {
           m_fire_control.CeaseFire();
           g_last_action = "CEASE_FIRE";
           g_decision_log += "Cease Fire;";
       }
       else if (event == EVENT_CLOSE_PROFIT) 
       {
           int closed = m_profit_manager.CloseAllProfit();
           g_last_action = "CLOSE_PROFIT";
           g_decision_log += "Manually Closed " + IntegerToString(closed) + " Profitable Positions;";
       }
       else if (event == EVENT_TP_SL_UPDATE) 
       {
           double vtp = m_panel.GetVirtualTP();
           double vsl = m_panel.GetVirtualSL();
           m_profit_manager.SetVirtualTP(vtp);
           m_profit_manager.SetVirtualSL(vsl);
           PrintFormat("🔄 Sync: Virtual TP=%.2f, Virtual SL=%.2f", vtp, vsl);
       }
   }

   m_panel.UpdateUI(GetFloatingPL());
}

string GetNetLotDirection(double &total_lots) {
    double net = 0.0; total_lots = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           bool is_mine = false;
           if(DeepStealth_Enabled) is_mine = m_registry.IsMyTicket(m_position.Ticket());
           else is_mine = (m_position.Magic() == InpMagicNumber);

           if(is_mine) {
               total_lots += m_position.Volume();
               if(m_position.PositionType()==POSITION_TYPE_BUY) net+=m_position.Volume(); else net-=m_position.Volume();
           }
       }
    }
    if(net > 0.001) return "BUY";
    if(net < -0.001) return "SELL";
    if(PositionsTotal() > 0) return "NEUTRAL";
    return "NONE";
}

string DetermineVerdict(double v, double pl) {
    if(pl < -50.0 && v > 20.0) return "CRASH_RISK";
    if(pl > 10.0) return "WINNING";
    if(pl < -10.0) return "PRESSURE";
    return "STABLE";
}

string GetSLTPSnapshot() {
    string s = ""; int c = 0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           bool is_mine = false;
           if(DeepStealth_Enabled) is_mine = m_registry.IsMyTicket(m_position.Ticket());
           else is_mine = (m_position.Magic() == InpMagicNumber);

           if(is_mine) {
               if(c > 0) s += "|";
               string t = (m_position.PositionType()==POSITION_TYPE_BUY) ? "B" : "S";
               s += t + ":" + DoubleToString(m_position.StopLoss(),_Digits) + "/" + DoubleToString(m_position.TakeProfit(),_Digits);
               c++; if(c>=3) { s+="|..."; break; }
           }
       }
    }
    return (s=="") ? "NONE" : s;
}

void CheckForNewDeals()
{
    if(!HistorySelect(TimeCurrent() - 600, TimeCurrent() + 10)) return;
    int total = HistoryDealsTotal();

    for(int i=0; i<total; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        long deal_time = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);

        if (deal_time > g_last_deal_time_msc || (deal_time == g_last_deal_time_msc && ticket > g_last_deal_ticket)) {
            g_last_deal_time_msc = deal_time;
            g_last_deal_ticket = ticket;

            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            string type_str = (type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string info = "T#" + IntegerToString(ticket);

            if (entry == DEAL_ENTRY_IN) {
                if(g_transaction_buffer!="") g_transaction_buffer+="|";
                g_transaction_buffer += info + ":OPEN:" + type_str + ":" + DoubleToString(vol,2);
            } else if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
                if(g_transaction_buffer!="") g_transaction_buffer+="|";
                g_transaction_buffer += info + ":CLOSE:" + type_str + ":PL=" + DoubleToString(profit,2);
                g_last_realized_pl += profit;
                g_session_realized_pl += profit;
            }
        }
    }
}

void OnTick()
{
   // --- MDAS ACTIVE DEFENSE ---
   if(CheckPointer(g_defense) != POINTER_INVALID) {
      g_defense.Defend();
   }
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   m_physics.Update(tick);
   PhysicsState p = m_physics.GetState();
   m_nav_system.Refresh(_Symbol, tick);

   g_debug_counter++;

   CheckForNewDeals();

   int closed = m_profit_manager.Check();
   if(closed > 0) {
       g_last_action = "VIRTUAL_TP_SL_HIT";
       g_decision_log += "Closed " + IntegerToString(closed) + " positions via Virtual Manager;";
   }

   double float_pl = GetFloatingPL();
   m_panel.UpdateUI(float_pl);
   m_panel.UpdateAccountStats(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_FREE), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), CalculateTotalHistoryProfit(), g_session_realized_pl);

   MqlBookInfo book[];
   if (g_book_subscribed && MarketBookGet(_Symbol, book)) {}

   MqlRates rates[];
   double b_o=0, b_h=0, b_l=0, b_c=0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) > 0) {
       b_o = rates[0].open; b_h = rates[0].high; b_l = rates[0].low; b_c = rates[0].close;
   }

   double total_lots = 0; 
   string lot_dir = GetNetLotDirection(total_lots);
   string verdict = DetermineVerdict(p.velocity, float_pl);

   if (g_transaction_buffer == "") g_transaction_buffer = "NONE";
   if (g_decision_log != "") g_transaction_buffer += "|" + g_decision_log;

   m_black_box.RecordTick(
       tick.time_msc, g_last_action, 0, verdict,
       tick.bid, tick.ask, p.spread_avg, 0, 0,
       b_o, b_h, b_l, b_c,
       m_nav_system.GetRSI(), p.velocity, p.acceleration,
       m_nav_system.GetHybridMACD(), m_nav_system.GetPulse(),
       m_nav_system.GetFlowMFI(), m_nav_system.GetFlowROC(), m_nav_system.GetFlowDelta(),
       // Context
       m_nav_system.GetMicP(), m_nav_system.GetMicR(), m_nav_system.GetMicS(),
       m_nav_system.GetSecP(), m_nav_system.GetSecR(), m_nav_system.GetSecS(),
       m_nav_system.GetTerP(), m_nav_system.GetTerR(), m_nav_system.GetTerS(),
       m_nav_system.GetTrendFast(), m_nav_system.GetTrendSlow(),
       // Momentum
       m_nav_system.GetTestHist(), m_nav_system.GetTestMACD(), m_nav_system.GetTestSignal(),
       // Stats
       AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
       float_pl, g_last_realized_pl, g_session_realized_pl,
       PositionsTotal(), lot_dir, total_lots,
       GetSLTPSnapshot(), g_transaction_buffer, g_tick_event_buffer
   );

   g_last_realized_pl = 0.0;
   g_tick_event_buffer = "";
   g_decision_log = "";
   g_transaction_buffer = "";
   if (g_last_action != "IDLE") g_last_action = "IDLE";
}
