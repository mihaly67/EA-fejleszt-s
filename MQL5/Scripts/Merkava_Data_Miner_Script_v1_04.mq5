//+------------------------------------------------------------------+
//|                             Merkava_Data_Miner_Script_v1_04.mq5 |
//|                                                      Jules Agent |
//|                                       Part of Operation Néma Sz. |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "1.04"
#property strict
#property script_show_inputs

#include <Trade\SymbolInfo.mqh>
#include "../Indicators/DataMiner_NavSystem_v1_00.mqh"
#include "../Indicators/DataMiner_BlackBox_v1_00.mqh"

//--- Inputs
input datetime InpStartDate   = D'2025.03.09 00:00:00'; // Start Date for Mining
input datetime InpEndDate     = D'2026.06.13 23:59:59'; // End Date for Mining
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

//+------------------------------------------------------------------+
//| Kényszerített Történeti Adatletöltő Függvény                     |
//+------------------------------------------------------------------+
int CheckLoadHistory(string symbol, ENUM_TIMEFRAMES period, datetime start_date)
{
    datetime first_date = 0;
    datetime times[100];

    SeriesInfoInteger(symbol, period, SERIES_FIRSTDATE, first_date);
    if(first_date > 0 && first_date <= start_date) return(1);

    if(SeriesInfoInteger(symbol, PERIOD_M1, SERIES_TERMINAL_FIRSTDATE, first_date)) {
        if(first_date > 0) {
            CopyTime(symbol, period, first_date + PeriodSeconds(period), 1, times);
            if(SeriesInfoInteger(symbol, period, SERIES_FIRSTDATE, first_date)) {
                if(first_date > 0 && first_date <= start_date) return(2);
            }
        }
    }

    int max_bars = (int)TerminalInfoInteger(TERMINAL_MAXBARS);
    datetime first_server_date = 0;
    while(!SeriesInfoInteger(symbol, PERIOD_M1, SERIES_SERVER_FIRSTDATE, first_server_date) && !IsStopped()) Sleep(5);

    if(first_server_date > start_date) start_date = first_server_date;

    int fail_cnt = 0;
    while(!IsStopped()) {
        while(!SeriesInfoInteger(symbol, period, SERIES_SYNCHRONIZED) && !IsStopped()) Sleep(5);

        int bars = Bars(symbol, period);
        if(bars > 0) {
            if(bars >= max_bars) return(-2);
            if(SeriesInfoInteger(symbol, period, SERIES_FIRSTDATE, first_date)) {
                if(first_date > 0 && first_date <= start_date) return(0);
            }
        }

        int copied = CopyTime(symbol, period, bars, 100, times);
        if(copied > 0) {
            if(times[0] <= start_date) return(0);
            if(bars + copied >= max_bars) return(-2);
            fail_cnt = 0;
        } else {
            fail_cnt++;
            if(fail_cnt >= 100) return(-5);
            Sleep(10);
        }
    }
    return(-3);
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🚀 Merkava Data Miner Script v1.04 Initializing...");

    if(!m_symbol.Name(_Symbol)) { Print("❌ Hiba a szimbólum beállításakor!"); return; }
    m_symbol.RefreshRates();

    // Context Params initialization
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
        return;
    }

    m_black_box.Initialize(_Symbol, "MINER_M1_SCRIPT_v1.04");

    PrintFormat("📥 Kényszerített adatletöltés indítása a Bróker szerverről: %s (M1), Kezdete: %s", _Symbol, TimeToString(InpStartDate));

    int load_res = CheckLoadHistory(_Symbol, PERIOD_M1, InpStartDate);
    PrintFormat("📊 CheckLoadHistory eredmény kód: %d", load_res);

    if(load_res == -2) Print("⚠️ Figyelem: A 'Max bars in chart' terminál limitet elértük, lehet, hogy nem lesz meg a teljes év!");
    else if(load_res < 0) {
        Print("❌ Hiba az adatok letöltése során! Kód: ", load_res);
        return;
    } else {
        Print("✅ A teljes történelmi adat elérhető a gép memóriájában. Bányászat indítása...");
    }

    MqlRates rates[];
    int count = CopyRates(_Symbol, PERIOD_M1, InpStartDate, InpEndDate, rates);

    if(count <= 0) {
        Print("❌ No rates found in range.");
        m_black_box.CloseLog();
        return;
    }

    PrintFormat("✅ Received %d M1 bars. Processing and Logging...", count);

    double last_price = 0;
    double velocity = 0;
    double acceleration = 0;

    for(int i=0; i<count; i++)
    {
        if(IsStopped()) break;

        datetime t = rates[i].time;
        long time_msc = (long)t * 1000;
        double r_open = rates[i].open;
        double r_high = rates[i].high;
        double r_low = rates[i].low;
        double r_close = rates[i].close;
        double spread = rates[i].spread;

        double bid = r_close;
        double ask = r_close + (spread * _Point);

        // CREATE DUMMY TICK FOR NAV SYSTEM (To trigger hybrid indicators calculation sequentially)
        MqlTick dummy_tick;
        dummy_tick.time = t;
        dummy_tick.time_msc = time_msc;
        dummy_tick.bid = bid;
        dummy_tick.ask = ask;
        dummy_tick.last = r_close;
        dummy_tick.volume = rates[i].tick_volume;

        // Update indicators
        m_nav_system.Refresh(_Symbol, dummy_tick, t);

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

        double macd = m_nav_system.GetHybridMACD();
        double pulse = m_nav_system.GetPulse();

        // Basic Physics calculation
        if (last_price > 0 && i > 0 && rates[i].time > rates[i-1].time) {
            double new_velocity = (bid - last_price) / (time_msc - (long)rates[i-1].time * 1000) * 1000.0;
            acceleration = new_velocity - velocity;
            velocity = new_velocity;
        } else {
            velocity = 0;
            acceleration = 0;
        }
        last_price = bid;

        long ping_ms = 60000; // M1 spacing

        // Write to CSV
        m_black_box.RecordTick(
            time_msc,
            bid, ask, spread,
            r_open, r_high, r_low, r_close,
            rsi, velocity, acceleration,
            macd, pulse,
            mfi, roc, delta,
            ema25, ema50, ema150, ema300,
            wpr, stoch,
            ping_ms
        );
    }

    PrintFormat("✅ Mining Complete. All %d M1 bars logged. CSV saved directly in the terminal's Files/ directory.", count);
    Alert("✅ Data Miner Script befejezte a gyűjtést!");
    m_black_box.CloseLog();
}
