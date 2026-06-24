//+------------------------------------------------------------------+
//|                                     Merkava_Data_Miner_v1_01.mq5 |
//|                                                      Jules Agent |
//|                                       Part of Operation Néma Sz. |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "1.01"
#property strict

#include <Trade\SymbolInfo.mqh>
#include "../../Indicators/Indicators/DataMiner_NavSystem_v1_00.mqh"
#include "../../Indicators/Indicators/DataMiner_BlackBox_v1_00.mqh"

//--- Inputs
input string   InpIndPath     = "Jules\\"; // Indicators Path
input string   InpContextPath = "Jules\\HybridContextIndicator_v3.28";

// Pulse Params
input int h_fast_inp = 3;
input int h_slow_inp = 6;
input int h_bb_per_inp = 20;
input double h_bb_dev_inp = 2.0;
input ENUM_MA_METHOD h_bb_meth_inp = MODE_EMA;
input int h_kelt_per_inp = 20;
input double h_kelt_dev_inp = 1.5;
input int h_kelt_atr_inp = 10;
input ENUM_MA_METHOD h_kelt_meth_inp = MODE_EMA;
input double h_macd_scale_inp = 4.0;
input int h_shift_inp = 0;
input double h_scale_inp = 1.0;
input bool h_auto_inp = true;
input int h_lookback_inp = 100;
input double h_divisor_inp = 7.0;

// Flow Params
input bool _f_fixed_inp = false;
input double _f_min_inp = -100.0;
input double _f_max_inp = 200.0;
input int _f_mfi_inp = 5;
input bool _f_vroc_inp = true;
input int _f_vroc_p_inp = 5;
input bool _f_approx_inp = true;
input int _f_smooth_inp = 3;
input int _f_norm_inp = 100;
input double _f_scale_f_inp = 50.0;
input double _f_vis_inp = 3.0;

// Context Params
input bool c_m_use = true; input int c_m_depth = 3; input int c_m_dev = 5; input int c_m_back = 3; input ENUM_LINE_STYLE c_m_style = STYLE_DOT; input int c_m_width = 1; input color c_m_c1 = clrRed; input color c_m_c2 = clrGreen;
input bool c_s_use = true; input int c_s_depth = 4; input int c_s_dev = 5; input int c_s_back = 3; input ENUM_LINE_STYLE c_s_style = STYLE_DASHDOT; input int c_s_width = 1; input color c_s_c1 = clrRed; input color c_s_c2 = clrGreen;
input bool c_t_use = true; input int c_t_depth = 7; input int c_t_dev = 5; input int c_t_back = 3; input ENUM_LINE_STYLE c_t_style = STYLE_SOLID; input int c_t_width = 1; input color c_t_c1 = clrRed; input color c_t_c2 = clrGreen;
input int c_tr_f = 25; input int c_tr_m = 50; input int c_tr_s = 150; input int c_tr_sup = 300; input ENUM_MA_METHOD c_tr_meth = MODE_EMA;

// Momentum Params
input int m_wpr_per = 5;
input int m_stoch_k = 3;
input int m_stoch_slow = 2;
input int m_stoch_d = 2;

//--- Subsystems
CSymbolInfo          m_symbol;
CDataMiner_NavSystem m_nav_system;
CDataMiner_BlackBox  m_black_box;

//--- Global State
double g_last_price = 0;
double g_velocity = 0, g_acceleration = 0;
long g_last_tick_msc = 0;
long g_ticks_processed = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 Merkava Data Miner v1.01 Initializing (Strategy Tester EA Mode)...");

    if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
    m_symbol.RefreshRates();

    // Context Params: show_trends MUST be true for EMAs to be calculated
    ContextParams ctx;
    ctx.path = InpContextPath;
    ctx.show_pivots = true; ctx.show_trends = true; ctx.max_hist = 50000;
    ctx.show_fibo = false; ctx.fibo_hist = 0;

    ctx.m_use = c_m_use; ctx.m_depth = c_m_depth; ctx.m_dev = c_m_dev; ctx.m_back = c_m_back; ctx.m_style = c_m_style; ctx.m_width = c_m_width; ctx.m_c1 = c_m_c1; ctx.m_c2 = c_m_c2;
    ctx.s_use = c_s_use; ctx.s_depth = c_s_depth; ctx.s_dev = c_s_dev; ctx.s_back = c_s_back; ctx.s_style = c_s_style; ctx.s_width = c_s_width; ctx.s_c1 = c_s_c1; ctx.s_c2 = c_s_c2;
    ctx.t_use = c_t_use; ctx.t_depth = c_t_depth; ctx.t_dev = c_t_dev; ctx.t_back = c_t_back; ctx.t_style = c_t_style; ctx.t_width = c_t_width; ctx.t_c1 = c_t_c1; ctx.t_c2 = c_t_c2;
    ctx.tr_fast = c_tr_f; ctx.tr_medium = c_tr_m; ctx.tr_slow = c_tr_s; ctx.tr_super = c_tr_sup; ctx.tr_method = c_tr_meth;

    HybridMomentumParams mom;
    ZeroMemory(mom);
    mom.path = InpIndPath + "Hybrid_Momentum_WPR_Stoch_v1_04";
    mom.wpr_period = m_wpr_per;
    mom.stoch_k = m_stoch_k;
    mom.stoch_slow = m_stoch_slow;
    mom.stoch_d = m_stoch_d;

    bool init_ok = m_nav_system.Initialize(
        _Symbol, _Period,
        InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05",
        h_fast_inp, h_slow_inp, h_bb_per_inp, h_bb_dev_inp, h_bb_meth_inp,
        h_kelt_per_inp, h_kelt_dev_inp, h_kelt_atr_inp, h_kelt_meth_inp,
        h_macd_scale_inp, h_shift_inp, h_scale_inp, h_auto_inp, h_lookback_inp, h_divisor_inp,
        InpIndPath + "HybridFlowIndicator_v1.126",
        _f_fixed_inp, _f_min_inp, _f_max_inp, _f_mfi_inp, _f_vroc_inp, _f_vroc_p_inp,
        _f_approx_inp, _f_smooth_inp, _f_norm_inp, _f_scale_f_inp, _f_vis_inp,
        ctx, mom
    );

    if(!init_ok) {
        Print("❌ Miner Initialization Failed at NavSystem");
        return INIT_FAILED;
    }

    m_black_box.Initialize(_Symbol, "MINER_TESTER_v1.01");

    Print("✅ Miner Ready. Standing by for Strategy Tester ticks...");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    m_nav_system.Release();
    m_black_box.CloseLog();
    PrintFormat("🛑 Miner Deinitialized. Total ticks processed: %I64d", g_ticks_processed);
}

//+------------------------------------------------------------------+
//| Expert tick function (Strategy Tester Real-Time Evaluation)      |
//+------------------------------------------------------------------+
void OnTick()
{
    MqlTick current_tick;
    if(!SymbolInfoTick(_Symbol, current_tick)) return;

    // Ensure new tick by timestamp (prevent duplicating same tick in fast markets)
    if(current_tick.time_msc <= g_last_tick_msc) return;

    // Use shift 0 (current) to get the true tick-level indicator values as they form in real-time in the Tester
    m_nav_system.Refresh(_Symbol, current_tick, 0);

    double bid = current_tick.bid;
    double ask = current_tick.ask;
    double spread = (ask - bid) / _Point;

    double pulse = m_nav_system.GetPulse();
    double macd = m_nav_system.GetHybridMACD();

    double mfi = m_nav_system.GetFlowMFI();
    double delta = m_nav_system.GetFlowDelta();
    double roc = m_nav_system.GetFlowROC();

    double ema25 = m_nav_system.GetTrendFast();
    double ema50 = m_nav_system.GetTrendMedium();
    double ema150 = m_nav_system.GetTrendSlow();
    double ema300 = m_nav_system.GetTrendSuper();

    double wpr = m_nav_system.GetWPR();
    double stoch = m_nav_system.GetStochK();
    double rsi = m_nav_system.GetRSI();

    // Basic Physics calculation using real-time milliseconds difference
    if (g_last_price > 0) {
        double time_diff_sec = (current_tick.time_msc - g_last_tick_msc) / 1000.0;
        if (time_diff_sec > 0) {
            double new_velocity = (bid - g_last_price) / time_diff_sec;
            g_acceleration = new_velocity - g_velocity;
            g_velocity = new_velocity;
        }
    } else {
        g_velocity = 0;
        g_acceleration = 0;
    }
    g_last_price = bid;

    // Fetch OHLC
    double b_open = 0, b_high = 0, b_low = 0, b_close = current_tick.bid;
    MqlRates rates[1];
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) > 0) {
        b_open = rates[0].open;
        b_high = rates[0].high;
        b_low = rates[0].low;
    }

    long ping_ms = 0;
    if (g_last_tick_msc > 0) ping_ms = current_tick.time_msc - g_last_tick_msc;

    // Write to CSV
    m_black_box.RecordTick(
        current_tick.time_msc,
        bid, ask, spread,
        b_open, b_high, b_low, b_close,
        rsi, g_velocity, g_acceleration,
        macd, pulse,
        mfi, roc, delta,
        ema25, ema50, ema150, ema300,
        wpr, stoch,
        ping_ms
    );

    g_last_tick_msc = current_tick.time_msc;
    g_ticks_processed++;

    // Optional progress tracking in tester journal
    if(g_ticks_processed % 100000 == 0) {
        PrintFormat("⏳ Extracted %I64d ticks...", g_ticks_processed);
    }
}
//+------------------------------------------------------------------+
