//+------------------------------------------------------------------+
//|                                            NavSystem_v2_20.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.20   |
//|        (Integration: Context v3.27 Style Fix + Momentum)         |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

// --- Definitions from v2.11 (Momentum) ---
enum ENUM_COLOR_LOGIC {
    COLOR_SLOPE,
    COLOR_CROSSOVER,
    COLOR_ZERO_CROSS
};

struct HybridMomentumParams {
    string path;
    ENUM_COLOR_LOGIC color_logic;
    int fast_p; int slow_p; int sig_p;
    ENUM_APPLIED_PRICE price;
    double kalman; double phase;
    bool boost; double stoch_w; int stoch_k; int stoch_d; int stoch_s;
    int norm_p; double norm_sens;
};

// --- Definitions from v2.09 (Context) ---
struct ContextParams {
    string path;
    bool show_pivots;
    bool show_trends;
    int max_hist;
    bool show_fibo;
    int fibo_hist;

    // Micro
    bool m_use; int m_depth; int m_dev; int m_back; ENUM_LINE_STYLE m_style; int m_width; color m_c1; color m_c2;
    // Secondary
    bool s_use; int s_depth; int s_dev; int s_back; ENUM_LINE_STYLE s_style; int s_width; color s_c1; color s_c2;
    // Tertiary
    bool t_use; int t_depth; int t_dev; int t_back; ENUM_LINE_STYLE t_style; int t_width; color t_c1; color t_c2;
    // Trends
    int tr_fast; int tr_slow; ENUM_MA_METHOD tr_method;
};

class CNavSystem
{
private:
   int      m_handle_rsi;
   int      m_handle_hybrid_macd; // Pulse
   int      m_handle_flow;
   int      m_handle_context;     // Context v3.27
   int      m_handle_test_mom;    // Momentum v2.82

   MqlRates m_rates[];
   int      m_lookback;

   // Physics / Pulse / Flow Values
   double   m_val_rsi;
   double   m_val_macd;
   double   m_val_dfcurve;
   double   m_val_flow_mfi;
   double   m_val_flow_delta;
   double   m_val_flow_roc;

   // Context Values (11 Fields)
   double   m_val_mic_p, m_val_mic_r, m_val_mic_s;
   double   m_val_sec_p, m_val_sec_r, m_val_sec_s;
   double   m_val_ter_p, m_val_ter_r, m_val_ter_s;
   double   m_val_tr_fast, m_val_tr_slow;

   // Momentum Values (3 Fields)
   double   m_val_test_hist;
   double   m_val_test_macd;
   double   m_val_test_signal;

   // Legacy params for Pulse/Flow
   int      p_macd_fast;
   int      p_macd_slow;
   double   p_macd_scale;
   double   p_df_scale;
   bool     p_df_auto;
   double   p_divisor;

   int      f_mfi_period;
   int      f_vroc_period;
   int      f_smooth;
   int      f_norm_len;
   double   f_scale;
   double   f_vis_gain;
   bool     f_approx;

   string   m_symbol;

public:
   CNavSystem()
   {
      m_handle_rsi = INVALID_HANDLE;
      m_handle_hybrid_macd = INVALID_HANDLE;
      m_handle_flow = INVALID_HANDLE;
      m_handle_context = INVALID_HANDLE;
      m_handle_test_mom = INVALID_HANDLE;

      m_lookback = 300;
      ArrayResize(m_rates, m_lookback);

      // Defaults
      m_val_rsi = 50.0;
      m_val_macd = 0.0;
      m_val_dfcurve = 0.0;
      m_val_flow_mfi = 50.0;
      m_val_flow_delta = 0.0;
      m_val_flow_roc = 0.0;

      m_val_mic_p = 0; m_val_mic_r = 0; m_val_mic_s = 0;
      m_val_sec_p = 0; m_val_sec_r = 0; m_val_sec_s = 0;
      m_val_ter_p = 0; m_val_ter_r = 0; m_val_ter_s = 0;
      m_val_tr_fast = 0; m_val_tr_slow = 0;

      m_val_test_hist = 0.0;
      m_val_test_macd = 0.0;
      m_val_test_signal = 0.0;
   }

   ~CNavSystem() { Release(); }

   void Release()
   {
      // Clean up charts
      int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
      for(int w=windows-1; w>=0; w--) {
          int total = ChartIndicatorsTotal(0, w);
          for(int i=total-1; i>=0; i--) {
              string name = ChartIndicatorName(0, w, i);
              string nlow = name; StringToLower(nlow);
              if(StringFind(nlow, "hybrid") >= 0 || StringFind(nlow, "pulse") >= 0 || StringFind(nlow, "flow") >= 0 || StringFind(nlow, "context") >= 0 || StringFind(nlow, "momentum") >= 0)
                  ChartIndicatorDelete(0, w, name);
          }
      }

      if(m_handle_rsi != INVALID_HANDLE) { IndicatorRelease(m_handle_rsi); m_handle_rsi = INVALID_HANDLE; }
      if(m_handle_hybrid_macd != INVALID_HANDLE) { IndicatorRelease(m_handle_hybrid_macd); m_handle_hybrid_macd = INVALID_HANDLE; }
      if(m_handle_flow != INVALID_HANDLE) { IndicatorRelease(m_handle_flow); m_handle_flow = INVALID_HANDLE; }
      if(m_handle_context != INVALID_HANDLE) { IndicatorRelease(m_handle_context); m_handle_context = INVALID_HANDLE; }
      if(m_handle_test_mom != INVALID_HANDLE) { IndicatorRelease(m_handle_test_mom); m_handle_test_mom = INVALID_HANDLE; }
   }

   bool Initialize(
       string symbol, ENUM_TIMEFRAMES period,
       // Pulse Inputs
       string path_hybrid,
       int h_fast, int h_slow, int h_bb_per, double h_bb_dev, ENUM_MA_METHOD h_bb_meth,
       int h_kelt_per, double h_kelt_dev, int h_kelt_atr, ENUM_MA_METHOD h_kelt_meth,
       double h_macd_scale, int h_shift, double h_scale, bool h_auto, int h_lookback,
       double h_divisor,
       // Flow Inputs
       string path_flow,
       bool _f_fixed, double _f_min, double _f_max, int _f_mfi, bool _f_vroc, int _f_vroc_p,
       double _f_thresh, bool _f_approx, int _f_smooth, int _f_norm, double _f_scale_f, double _f_vis,
       // Context Inputs
       ContextParams &ctx,
       // Momentum Inputs
       HybridMomentumParams &mom
   )
   {
       Release();
       m_symbol = symbol;

       // Store internal params
       p_macd_fast = h_fast; p_macd_slow = h_slow; p_macd_scale = h_macd_scale;
       p_df_scale = h_scale; p_df_auto = h_auto; p_divisor = h_divisor;
       f_mfi_period = _f_mfi; f_vroc_period = _f_vroc_p; f_smooth = _f_smooth;
       f_norm_len = _f_norm; f_scale = _f_scale_f; f_vis_gain = _f_vis; f_approx = _f_approx;

       // 1. RSI
       m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);

       // 2. Pulse (Standard)
       m_handle_hybrid_macd = iCustom(symbol, period, path_hybrid,
           h_fast, h_slow, h_bb_per, h_bb_dev, h_bb_meth,
           h_kelt_per, h_kelt_dev, h_kelt_atr, h_kelt_meth,
           h_macd_scale, h_shift, h_scale, h_auto, h_lookback, h_divisor
       );

       // 3. Flow (Standard)
       MqlParam flow_params[13];
       flow_params[0].type = TYPE_STRING; flow_params[0].string_value = path_flow;
       flow_params[1].type = TYPE_BOOL;   flow_params[1].integer_value = _f_fixed;
       flow_params[2].type = TYPE_DOUBLE; flow_params[2].double_value = _f_min;
       flow_params[3].type = TYPE_DOUBLE; flow_params[3].double_value = _f_max;
       flow_params[4].type = TYPE_INT;    flow_params[4].integer_value = _f_mfi;
       flow_params[5].type = TYPE_BOOL;   flow_params[5].integer_value = _f_vroc;
       flow_params[6].type = TYPE_INT;    flow_params[6].integer_value = _f_vroc_p;
       flow_params[7].type = TYPE_DOUBLE; flow_params[7].double_value = _f_thresh;
       flow_params[8].type = TYPE_BOOL;   flow_params[8].integer_value = _f_approx;
       flow_params[9].type = TYPE_INT;    flow_params[9].integer_value = _f_smooth;
       flow_params[10].type = TYPE_INT;   flow_params[10].integer_value = _f_norm;
       flow_params[11].type = TYPE_DOUBLE; flow_params[11].double_value = _f_scale_f;
       flow_params[12].type = TYPE_DOUBLE; flow_params[12].double_value = _f_vis;
       m_handle_flow = IndicatorCreate(symbol, period, IND_CUSTOM, 13, flow_params);

       // 4. Context Indicator (v3.27 Style Fix + Reorder)
       PrintFormat("NavSystem: Loading Context (v3.27 StyleFix) from %s", ctx.path);
       m_handle_context = iCustom(symbol, period, ctx.path,
           ctx.show_pivots, ctx.show_trends, ctx.max_hist,
           false, 0, // Fibo Forced OFF
           ctx.m_use, ctx.m_depth, ctx.m_dev, ctx.m_back, ctx.m_style, ctx.m_width, ctx.m_c1, ctx.m_c2,
           ctx.s_use, ctx.s_depth, ctx.s_dev, ctx.s_back, ctx.s_style, ctx.s_width, ctx.s_c1, ctx.s_c2,
           ctx.t_use, ctx.t_depth, ctx.t_dev, ctx.t_back, ctx.t_style, ctx.t_width, ctx.t_c1, ctx.t_c2,
           ctx.tr_fast, ctx.tr_slow, ctx.tr_method
       );

       // 5. Momentum Indicator (Test/Reference)
       PrintFormat("NavSystem: Loading Momentum (v2.82) from %s", mom.path);
       m_handle_test_mom = iCustom(symbol, period, mom.path,
           mom.color_logic,
           mom.fast_p, mom.slow_p, mom.sig_p, mom.price, mom.kalman, mom.phase,
           mom.boost, mom.stoch_w, mom.stoch_k, mom.stoch_d, mom.stoch_s,
           mom.norm_p, mom.norm_sens
       );

       return true;
   }

   void AttachToChart(long chart_id)
   {
       // Main Window (0) - Context (Pivots/Trends overlay on price)
       if(m_handle_context != INVALID_HANDLE) {
           bool res = ChartIndicatorAdd(chart_id, 0, m_handle_context);
           if(!res) Print("Error attaching Context to Main Window: ", GetLastError());
           else Print("Context Indicator Attached to Main Window.");
       }

       // Sub Window 1 - Pulse
       if(m_handle_hybrid_macd != INVALID_HANDLE) ChartIndicatorAdd(chart_id, 1, m_handle_hybrid_macd);

       // Sub Window 2 - Flow
       if(m_handle_flow != INVALID_HANDLE) ChartIndicatorAdd(chart_id, 2, m_handle_flow);

       // Sub Window 3 - Momentum
       if(m_handle_test_mom != INVALID_HANDLE) ChartIndicatorAdd(chart_id, 3, m_handle_test_mom);

       ChartRedraw(chart_id);
   }

   void Refresh(string symbol, MqlTick& latest_tick)
   {
      // 1. Data Prep
      int copied = CopyRates(symbol, PERIOD_CURRENT, 0, m_lookback, m_rates);
      if(copied < 100) return;

      m_rates[copied-1].close = latest_tick.bid; // Realtime close

      // 2. Indicators
      m_val_rsi = CalcRSI(copied, 5);

      // Pulse
      if(m_handle_hybrid_macd != INVALID_HANDLE) {
          double buf_macd[1], buf_df[1];
          if(CopyBuffer(m_handle_hybrid_macd, 0, 0, 1, buf_macd) > 0) m_val_macd = buf_macd[0];
          if(CopyBuffer(m_handle_hybrid_macd, 2, 0, 1, buf_df) > 0) m_val_dfcurve = buf_df[0];
      }

      // Flow (Internal Calc fallback if handle fails, but usually we rely on handle if valid,
      // however v2.09 kept internal calc. We will keep internal calc for consistency if handles fail or for "raw" verification)
      // For this implementation, we will stick to v2.09 pattern: Calc internally for safety/speed.
      CalcHybridFlow(copied);

      // Context - MAPPING FOR v3.27 (Reordered logic)
      if(m_handle_context != INVALID_HANDLE) {
          double b[1];
          // Buffer Indices from HybridContextIndicator_v3.27
          // 0: MicroR (Data)
          // 1: MicroS (Data)
          // 2: SecR (Data)
          // 3: SecS (Data)
          // 4: TerR (Data)
          // 5: TerS (Data)
          // 6: TrendFast (Data)
          // 7: TrendSlow (Data)
          // 8: MicroP (Calc)
          // 9: SecP (Calc)
          // 10: TerP (Calc)

          if(CopyBuffer(m_handle_context, 0, 0, 1, b)>0) m_val_mic_r = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 1, 0, 1, b)>0) m_val_mic_s = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 8, 0, 1, b)>0) m_val_mic_p = (b[0]==EMPTY_VALUE)?0:b[0]; // Calc

          if(CopyBuffer(m_handle_context, 2, 0, 1, b)>0) m_val_sec_r = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 3, 0, 1, b)>0) m_val_sec_s = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 9, 0, 1, b)>0) m_val_sec_p = (b[0]==EMPTY_VALUE)?0:b[0]; // Calc

          if(CopyBuffer(m_handle_context, 4, 0, 1, b)>0) m_val_ter_r = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 5, 0, 1, b)>0) m_val_ter_s = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 10,0, 1, b)>0) m_val_ter_p = (b[0]==EMPTY_VALUE)?0:b[0]; // Calc

          if(CopyBuffer(m_handle_context, 6, 0, 1, b)>0) m_val_tr_fast = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_context, 7, 0, 1, b)>0) m_val_tr_slow = (b[0]==EMPTY_VALUE)?0:b[0];
      }

      // Momentum
      if(m_handle_test_mom != INVALID_HANDLE) {
          double b[1];
          // 0=Hist, 2=MACD, 3=Signal (v2.82)
          if(CopyBuffer(m_handle_test_mom, 0, 0, 1, b)>0) m_val_test_hist = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_test_mom, 2, 0, 1, b)>0) m_val_test_macd = (b[0]==EMPTY_VALUE)?0:b[0];
          if(CopyBuffer(m_handle_test_mom, 3, 0, 1, b)>0) m_val_test_signal = (b[0]==EMPTY_VALUE)?0:b[0];
      }
   }

   // --- Getters ---
   double GetRSI() { return m_val_rsi; }
   double GetPulse() { return m_val_dfcurve; }
   double GetHybridMACD() { return m_val_macd; }
   double GetFlowMFI() { return m_val_flow_mfi; }
   double GetFlowDelta() { return m_val_flow_delta; }
   double GetFlowROC() { return m_val_flow_roc; }

   double GetMicP() { return m_val_mic_p; } double GetMicR() { return m_val_mic_r; } double GetMicS() { return m_val_mic_s; }
   double GetSecP() { return m_val_sec_p; } double GetSecR() { return m_val_sec_r; } double GetSecS() { return m_val_sec_s; }
   double GetTerP() { return m_val_ter_p; } double GetTerR() { return m_val_ter_r; } double GetTerS() { return m_val_ter_s; }
   double GetTrendFast() { return m_val_tr_fast; } double GetTrendSlow() { return m_val_tr_slow; }

   double GetTestHist() { return m_val_test_hist; }
   double GetTestMACD() { return m_val_test_macd; }
   double GetTestSignal() { return m_val_test_signal; }

private:
   double CalcRSI(int total, int period)
   {
       if(total <= period) return 50.0;
       double avg_gain = 0, avg_loss = 0;
       int start_i = 1;
       for(int i=start_i; i<start_i+period; i++) {
           double change = m_rates[i].close - m_rates[i-1].close;
           if(change > 0) avg_gain += change; else avg_loss -= change;
       }
       avg_gain /= period; avg_loss /= period;
       for(int i=start_i+period; i<total; i++) {
           double change = m_rates[i].close - m_rates[i-1].close;
           double gain = (change > 0) ? change : 0.0;
           double loss = (change < 0) ? -change : 0.0;
           avg_gain = (avg_gain * (period - 1) + gain) / period;
           avg_loss = (avg_loss * (period - 1) + loss) / period;
       }
       if(avg_loss == 0) return 100.0;
       double rs = avg_gain / avg_loss;
       return 100.0 - (100.0 / (1.0 + rs));
   }

   void CalcHybridFlow(int total)
   {
       double pos_mf = 0, neg_mf = 0;
       for(int i=0; i<f_mfi_period; i++) {
           int idx = total - 1 - i;
           if(idx < 1) break;
           double tp_curr = (m_rates[idx].high + m_rates[idx].low + m_rates[idx].close) / 3.0;
           double tp_prev = (m_rates[idx-1].high + m_rates[idx-1].low + m_rates[idx-1].close) / 3.0;
           double vol = (double)m_rates[idx].tick_volume;
           if(vol <= 0) vol = (double)m_rates[idx].real_volume;
           double mf = tp_curr * vol;
           if(tp_curr > tp_prev) pos_mf += mf; else if(tp_curr < tp_prev) neg_mf += mf;
       }
       if(neg_mf != 0) m_val_flow_mfi = 100.0 - (100.0 / (1.0 + (pos_mf / neg_mf)));
       else if(pos_mf > 0) m_val_flow_mfi = 100.0;
       else m_val_flow_mfi = 50.0;

       double net_delta_accum = 0;
       int delta_lookback = f_mfi_period;
       for(int i=0; i<delta_lookback; i++) {
           int idx = total - 1 - i;
           if(idx < 0) break;
           double range = m_rates[idx].high - m_rates[idx].low;
           double delta = 0;
           if(range > 0) {
               double pos = (m_rates[idx].close - m_rates[idx].low) / range;
               double power = (pos - 0.5) * 2.0;
               double vol = (double)m_rates[idx].tick_volume;
               if(vol <= 0) vol = (double)m_rates[idx].real_volume;
               delta = vol * power;
           }
           net_delta_accum += delta;
       }
       m_val_flow_delta = net_delta_accum / (double)(delta_lookback * 10.0);

       if(total > f_vroc_period) {
           int vp = f_vroc_period;
           double v_curr = (double)m_rates[total-1].tick_volume;
           if(v_curr <= 0) v_curr = (double)m_rates[total-1].real_volume;
           double v_prev = (double)m_rates[total-1-vp].tick_volume;
           if(v_prev <= 0) v_prev = (double)m_rates[total-1-vp].real_volume;
           if (v_prev > 0) m_val_flow_roc = ((v_curr - v_prev) / v_prev) * 100.0;
           else m_val_flow_roc = 0.0;
       }
   }
};
