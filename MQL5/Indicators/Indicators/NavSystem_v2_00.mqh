//+------------------------------------------------------------------+
//|                                            NavSystem_v2_00.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.00   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| Navigation System - Indicators & Sensors (v2.00)                 |
//| Core Improvement: Internal Math, No Split Buffers, Unified MFI   |
//+------------------------------------------------------------------+
class CNavSystem
{
private:
   // -- Handles for Visual Attachment Only --
   int      m_handle_rsi;
   int      m_handle_hybrid_macd;
   int      m_handle_flow;

   // -- Internal Data --
   MqlRates m_rates[];
   int      m_lookback;

   // -- Calculated Values (The "Truth") --
   double   m_val_rsi;
   double   m_val_macd;
   double   m_val_dfcurve;

   // Flow v2.00 Unified
   double   m_val_flow_mfi;   // Single 0-100 value
   double   m_val_flow_delta; // Net Delta (Unified Scale)
   double   m_val_flow_roc;   // Volume ROC

   // -- Parameters --
   int      p_macd_fast;
   int      p_macd_slow;
   double   p_macd_scale;
   double   p_df_scale;
   bool     p_df_auto;

   int      f_mfi_period;
   int      f_vroc_period;
   int      f_smooth;
   int      f_norm_len;
   double   f_scale;
   double   f_vis_gain;
   bool     f_approx;

public:
   CNavSystem()
   {
      m_handle_rsi = INVALID_HANDLE;
      m_handle_hybrid_macd = INVALID_HANDLE;
      m_handle_flow = INVALID_HANDLE;

      m_lookback = 300;
      ArrayResize(m_rates, m_lookback);

      m_val_rsi = 50.0;
      m_val_macd = 0.0;
      m_val_dfcurve = 0.0;
      m_val_flow_mfi = 50.0;
      m_val_flow_delta = 0.0;
      m_val_flow_roc = 0.0;
   }

   ~CNavSystem()
   {
      IndicatorRelease(m_handle_rsi);
      IndicatorRelease(m_handle_hybrid_macd);
      IndicatorRelease(m_handle_flow);
   }

   // Initialize with Params
   bool Initialize(
       string symbol, ENUM_TIMEFRAMES period,
       // Hybrid Params
       string path_hybrid,
       int h_fast, int h_slow, int h_bb_per, double h_bb_dev, ENUM_MA_METHOD h_bb_meth,
       int h_kelt_per, double h_kelt_dev, int h_kelt_atr, ENUM_MA_METHOD h_kelt_meth,
       double h_macd_scale, int h_shift, double h_scale, bool h_auto, int h_lookback,
       // Flow Params
       string path_flow,
       bool _f_fixed, double _f_min, double _f_max, int _f_mfi, bool _f_vroc, int _f_vroc_p,
       double _f_thresh, bool _f_approx, int _f_smooth, int _f_norm, double _f_scale_f, double _f_vis
   )
   {
       // 1. Store Params
       p_macd_fast = h_fast;
       p_macd_slow = h_slow;
       p_macd_scale = h_macd_scale;
       p_df_scale = h_scale;
       p_df_auto = h_auto;

       f_mfi_period = _f_mfi;
       f_vroc_period = _f_vroc_p;
       f_smooth = _f_smooth;
       f_norm_len = _f_norm;
       f_scale = _f_scale_f;
       f_vis_gain = _f_vis;
       f_approx = _f_approx;

       // 2. Visuals (Optional - we don't read them for data)
       m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);

       // Note: We keep iCustom calls if the user wants to see them on chart,
       // but for strict EA calculation, we will compute internally.

       return true;
   }

   //-- Update Sensor Readings (INTERNAL MATH)
   void Refresh(string symbol, MqlTick& latest_tick)
   {
      // 1. Get Raw Data
      int copied = CopyRates(symbol, PERIOD_CURRENT, 0, m_lookback, m_rates);
      if(copied < 100) return;

      // 2. Overwrite latest bar with TICK Precision
      // This ensures "Zero Latency" calculation against the very latest price/vol
      m_rates[copied-1].close = latest_tick.bid;
      if(latest_tick.bid > m_rates[copied-1].high) m_rates[copied-1].high = latest_tick.bid;
      if(latest_tick.bid < m_rates[copied-1].low && latest_tick.bid > 0) m_rates[copied-1].low = latest_tick.bid;
      // Volume Accumulation (Tick Vol or Real Vol fallback)
      if((long)latest_tick.volume_real > m_rates[copied-1].real_volume) m_rates[copied-1].real_volume = (long)latest_tick.volume_real;
      // Note: MqlTick doesn't have 'tick_volume' field explicitly in standard struct, but often 'volume' is mapped.
      // We assume CopyRates provided the base. We just ensure we don't regress.

      // 3. Calculate Indicators
      m_val_rsi = CalcRSI(copied, 5);
      CalcHybridPulse(copied);
      CalcHybridFlow(copied);
   }

   //-- Getters (Unified)
   double GetRSI() { return m_val_rsi; }
   double GetPulse() { return m_val_dfcurve; }
   double GetHybridMACD() { return m_val_macd; }

   // v2.00 Specific Getters
   double GetFlowMFI() { return m_val_flow_mfi; }
   double GetFlowDelta() { return m_val_flow_delta; }
   double GetFlowROC() { return m_val_flow_roc; }

private:
   // --- INTERNAL MATH HELPERS ---

   double CalcRSI(int total, int period)
   {
       if(total <= period) return 50.0;
       double avg_gain = 0;
       double avg_loss = 0;
       int start_i = 1;

       for(int i=start_i; i<start_i+period; i++) {
           double change = m_rates[i].close - m_rates[i-1].close;
           if(change > 0) avg_gain += change;
           else avg_loss -= change;
       }
       avg_gain /= period;
       avg_loss /= period;

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

   void CalcHybridPulse(int total)
   {
       // MACD
       double ema_fast = CalcEMA(total, p_macd_fast);
       double ema_slow = CalcEMA(total, p_macd_slow);
       m_val_macd = (ema_fast - ema_slow) * p_macd_scale;

       // DeltaForce Curve
       double curr_h = 0;
       double curr_l = 0;
       int start = MathMax(1, total - 100);

       for(int i=start; i<total; i++)
       {
           double diff = (m_rates[i].close - m_rates[i-1].close) / Point();
           if(diff > 0) { curr_h += diff; curr_l = 0; }
           else if(diff < 0) { curr_l += diff; curr_h = 0; }
       }
       double df_raw = (curr_h != 0) ? curr_h : curr_l;
       double scale = p_df_auto ? Point() : p_df_scale;
       m_val_dfcurve = df_raw * scale;
   }

   double CalcEMA(int total, int period)
   {
       double k = 2.0 / (period + 1.0);
       double ema = m_rates[0].close;
       int start = 1;
       if(total > 200) { start = total - 200; ema = m_rates[start-1].close; }
       for(int i=start; i<total; i++) {
           ema = (m_rates[i].close * k) + (ema * (1.0 - k));
       }
       return ema;
   }

   void CalcHybridFlow(int total)
   {
       // 1. MFI Calculation (Unified)
       // Standard MFI = 100 - 100 / (1 + PosMF / NegMF)
       double pos_mf = 0;
       double neg_mf = 0;

       for(int i=0; i<f_mfi_period; i++) {
           int idx = total - 1 - i;
           if(idx < 1) break;

           double tp_curr = (m_rates[idx].high + m_rates[idx].low + m_rates[idx].close) / 3.0;
           double tp_prev = (m_rates[idx-1].high + m_rates[idx-1].low + m_rates[idx-1].close) / 3.0;
           // Use Real Volume if Tick Volume is missing (common in Crypto)
           double vol = (double)m_rates[idx].tick_volume;
           if(vol <= 0) vol = (double)m_rates[idx].real_volume;

           double mf = tp_curr * vol;

           if(tp_curr > tp_prev) pos_mf += mf;
           else if(tp_curr < tp_prev) neg_mf += mf;
           // If equal, discard or split? Standard discards.
       }

       if(neg_mf != 0) m_val_flow_mfi = 100.0 - (100.0 / (1.0 + (pos_mf / neg_mf)));
       else if(pos_mf > 0) m_val_flow_mfi = 100.0;
       else m_val_flow_mfi = 50.0;

       // 2. Net Delta (Unified)
       // Approx Delta based on Candle Shape and Volume
       double net_delta_accum = 0;
       int delta_lookback = f_mfi_period;

       for(int i=0; i<delta_lookback; i++) {
           int idx = total - 1 - i;
           if(idx < 0) break;

           double range = m_rates[idx].high - m_rates[idx].low;
           double delta = 0;
           if(range > 0) {
               // Approx: Position of Close in Range maps to -1..1
               double pos = (m_rates[idx].close - m_rates[idx].low) / range; // 0..1
               double power = (pos - 0.5) * 2.0; // -1..1

               double vol = (double)m_rates[idx].tick_volume;
               if(vol <= 0) vol = (double)m_rates[idx].real_volume;

               delta = vol * power;
           }
           net_delta_accum += delta;
       }

       // Normalize Delta slightly so it's readable
       m_val_flow_delta = net_delta_accum / (double)(delta_lookback * 10.0); // Rough scaling

       // 3. ROC (Volume ROC)
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
