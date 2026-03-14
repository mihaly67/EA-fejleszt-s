//+------------------------------------------------------------------+
//|                                      Merkava_Online_Miner_v1_00.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 1.00   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "1.00"
#property strict
#property script_show_inputs

//--- Includes
#include "../Indicators/DataMiner_NavSystem_v1_00.mqh"
#include "../Indicators/DataMiner_BlackBox_v1_00.mqh"
#include "../Indicators/PhysicsEngine.mqh"

//--- Inputs
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
input bool c_show_p = true;
input bool c_show_t = true;
input int c_max_h = 2000;
input bool c_show_f = false;
input int c_fibo_h = 500;
input bool c_m_use = true; input int c_m_depth = 3; input int c_m_dev = 5; input int c_m_back = 3; input ENUM_LINE_STYLE c_m_style = STYLE_DOT; input int c_m_width = 1; input color c_m_c1 = clrRed; input color c_m_c2 = clrGreen;
input bool c_s_use = true; input int c_s_depth = 4; input int c_s_dev = 5; input int c_s_back = 3; input ENUM_LINE_STYLE c_s_style = STYLE_DASHDOT; input int c_s_width = 1; input color c_s_c1 = clrRed; input color c_s_c2 = clrGreen;
input bool c_t_use = true; input int c_t_depth = 7; input int c_t_dev = 5; input int c_t_back = 3; input ENUM_LINE_STYLE c_t_style = STYLE_SOLID; input int c_t_width = 1; input color c_t_c1 = clrRed; input color c_t_c2 = clrGreen;
input int c_tr_f = 25; input int c_tr_m = 50; input int c_tr_s = 150; input int c_tr_sup = 300; input ENUM_MA_METHOD c_tr_meth = MODE_EMA;

// Momentum Params
input int m_wpr_per = 5;
input int m_stoch_k = 3;
input int m_stoch_slow = 2;
input int m_stoch_d = 2;

//--- Global Objects
CDataMiner_NavSystem m_nav;
CDataMiner_BlackBox  m_blackbox;
PhysicsEngine        m_physics;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("Merkava Online Miner v1.00 Starting...");

    // 1. Initialize NavSystem
    ContextParams ctx;
    ctx.path = "Jules\\HybridContextIndicator_v3.28.ex5";
    ctx.show_pivots = c_show_p; ctx.show_trends = c_show_t; ctx.max_hist = c_max_h; ctx.show_fibo = c_show_f; ctx.fibo_hist = c_fibo_h;
    ctx.m_use = c_m_use; ctx.m_depth = c_m_depth; ctx.m_dev = c_m_dev; ctx.m_back = c_m_back; ctx.m_style = c_m_style; ctx.m_width = c_m_width; ctx.m_c1 = c_m_c1; ctx.m_c2 = c_m_c2;
    ctx.s_use = c_s_use; ctx.s_depth = c_s_depth; ctx.s_dev = c_s_dev; ctx.s_back = c_s_back; ctx.s_style = c_s_style; ctx.s_width = c_s_width; ctx.s_c1 = c_s_c1; ctx.s_c2 = c_s_c2;
    ctx.t_use = c_t_use; ctx.t_depth = c_t_depth; ctx.t_dev = c_t_dev; ctx.t_back = c_t_back; ctx.t_style = c_t_style; ctx.t_width = c_t_width; ctx.t_c1 = c_t_c1; ctx.t_c2 = c_t_c2;
    ctx.tr_fast = c_tr_f; ctx.tr_medium = c_tr_m; ctx.tr_slow = c_tr_s; ctx.tr_super = c_tr_sup; ctx.tr_method = c_tr_meth;

    HybridMomentumParams mom;
    mom.path = "Jules\\Hybrid_Momentum_WPR_Stoch_v1_04.ex5";
    mom.wpr_period = m_wpr_per; mom.stoch_k = m_stoch_k; mom.stoch_slow = m_stoch_slow; mom.stoch_d = m_stoch_d;

    bool nav_init = m_nav.Initialize(
        _Symbol, PERIOD_CURRENT,
        "Jules\\Jules_Hybrid_Momentum_Pulse_v1.05.ex5",
        h_fast_inp, h_slow_inp, h_bb_per_inp, h_bb_dev_inp, h_bb_meth_inp,
        h_kelt_per_inp, h_kelt_dev_inp, h_kelt_atr_inp, h_kelt_meth_inp,
        h_macd_scale_inp, h_shift_inp, h_scale_inp, h_auto_inp, h_lookback_inp, h_divisor_inp,
        "Jules\\HybridFlowIndicator_v1.126.ex5",
        _f_fixed_inp, _f_min_inp, _f_max_inp, _f_mfi_inp, _f_vroc_inp, _f_vroc_p_inp,
        _f_approx_inp, _f_smooth_inp, _f_norm_inp, _f_scale_f_inp, _f_vis_inp,
        ctx, mom
    );

    if(!nav_init) {
        Print("Failed to initialize NavSystem.");
        return;
    }

    // 2. Initialize BlackBox
    if(!m_blackbox.Initialize(_Symbol, "v1_00_LiveMiner")) {
        Print("Failed to initialize BlackBox.");
        return;
    }

    Print("Successfully connected. Waiting for live ticks (Crypto). Press STOP to end script.");

    // Physics Engine variables
    double last_price = 0;
    double velocity = 0, acceleration = 0;
    long last_tick_msc = 0;

    // 4. Infinite Live Processing Loop
    while(!IsStopped()) {
        MqlTick current_tick;
        if(SymbolInfoTick(_Symbol, current_tick)) {

            // Check if it's a completely new tick based on milliseconds timestamp
            if(current_tick.time_msc > last_tick_msc && current_tick.bid > 0) {

                // Live tick: shift = 0 in Refresh, extracting exact live indicator value matching this tick
                m_nav.Refresh(_Symbol, current_tick, 0);

                // Fetch values
                double rsi = m_nav.GetRSI();
                double h_macd = m_nav.GetHybridMACD();
                double h_dfcurve = m_nav.GetPulse();
                double f_mfi = m_nav.GetFlowMFI();
                double f_roc = m_nav.GetFlowROC();
                double f_delta = m_nav.GetFlowDelta();

                double ctx_ema_25 = m_nav.GetTrendFast();
                double ctx_ema_50 = m_nav.GetTrendMedium();
                double ctx_ema_150 = m_nav.GetTrendSlow();
                double ctx_ema_300 = m_nav.GetTrendSuper();

                double wpr = m_nav.GetWPR();
                double stoch_k = m_nav.GetStochK();

                // Basic Physics calculation
                if (last_price > 0) {
                    double time_diff_sec = (current_tick.time_msc - last_tick_msc) / 1000.0;
                    if (time_diff_sec > 0) {
                        double new_velocity = (current_tick.bid - last_price) / time_diff_sec;
                        acceleration = new_velocity - velocity;
                        velocity = new_velocity;
                    }
                } else {
                    velocity = 0;
                    acceleration = 0;
                }

                // Fetch Bar data
                double b_open = 0, b_high = 0, b_low = 0, b_close = current_tick.bid;
                MqlRates rates[1];
                if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) > 0) {
                    b_open = rates[0].open;
                    b_high = rates[0].high;
                    b_low = rates[0].low;
                }

                double spread = (current_tick.ask - current_tick.bid) / _Point;

                long ping_ms = 0;
                if (last_tick_msc > 0) ping_ms = current_tick.time_msc - last_tick_msc;

                m_blackbox.RecordTick(
                    current_tick.time_msc,
                    current_tick.bid, current_tick.ask, spread,
                    b_open, b_high, b_low, b_close,
                    rsi, velocity, acceleration,
                    h_macd, h_dfcurve,
                    f_mfi, f_roc, f_delta,
                    ctx_ema_25, ctx_ema_50, ctx_ema_150, ctx_ema_300,
                    wpr, stoch_k,
                    ping_ms
                );

                last_price = current_tick.bid;
                last_tick_msc = current_tick.time_msc;
            }
        }

        // Yield CPU
        Sleep(1);
    }

    Print("Data Miner execution finished/stopped by user.");
}
