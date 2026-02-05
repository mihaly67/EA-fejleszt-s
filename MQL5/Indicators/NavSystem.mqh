//+------------------------------------------------------------------+
//|                                              Mimic_NavSystem.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| Navigation System - Indicators & Sensors                         |
//+------------------------------------------------------------------+
class CMimicNavSystem
{
private:
   // -- Handles for Visual Attachment Only --
   int      m_handle_rsi;  // Visual only (if needed) - actually usually not attached
   int      m_handle_cci;  // Visual only
   int      m_handle_hybrid_macd; // Visual (Pulse)
   int      m_handle_flow; // Visual (Flow)

   // -- Internal Data --
   MqlRates m_rates[];
   int      m_lookback;

   // -- Calculated Values (The "Truth") --
   double   m_val_rsi;
   double   m_val_cci;

   // Pulse
   double   m_val_macd;
   double   m_val_dfcurve;

   // Flow
   double   m_val_flow_mfi;
   double   m_val_flow_delta; // Net Delta (Up/Down combined logic)
   double   m_val_flow_dup;   // For backwards compatibility/logging separate
   double   m_val_flow_ddown; // For backwards compatibility/logging separate
   double   m_val_flow_roc;

   // -- Parameters (Stored for Calculation) --
   // Pulse
   int      p_macd_fast;
   int      p_macd_slow;
   double   p_macd_scale;
   double   p_df_scale;
   bool     p_df_auto;
   // Flow
   int      f_mfi_period;
   int      f_vroc_period; // Added member
   int      f_smooth;
   int      f_norm_len;
   double   f_scale;
   double   f_vis_gain;
   bool     f_approx;

   bool     m_use_real_indicators;

public:
   CMimicNavSystem()
   {
      m_handle_rsi = INVALID_HANDLE;
      m_handle_cci = INVALID_HANDLE;
      m_handle_hybrid_macd = INVALID_HANDLE;
      m_handle_flow = INVALID_HANDLE;

      m_lookback = 300; // Sufficient for EMA calc stability
      ArrayResize(m_rates, m_lookback);

      m_val_rsi = 50.0;
      m_val_cci = 0.0;
      m_val_macd = 0.0;
      m_val_dfcurve = 0.0;
      m_val_flow_mfi = 50.0;
      m_val_flow_delta = 50.0;
      m_val_flow_roc = 0.0;

      m_use_real_indicators = false;
   }

   ~CMimicNavSystem()
   {
      IndicatorRelease(m_handle_rsi);
      IndicatorRelease(m_handle_cci);
      IndicatorRelease(m_handle_hybrid_macd);
      IndicatorRelease(m_handle_flow);
   }

   // Standard Initialize (v1.04 mode - Legacy)
   bool Initialize(string symbol, ENUM_TIMEFRAMES period)
   {
      return false; // Deprecated for Barbed Wire v1.05
   }

   // Barbed Wire Initialize
   bool InitializeBarbedWire(
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
       m_use_real_indicators = true;

       // 1. Store Params for Internal Calc
       p_macd_fast = h_fast;
       p_macd_slow = h_slow;
       p_macd_scale = h_macd_scale;
       p_df_scale = h_scale;
       p_df_auto = h_auto; // Note: Auto-scaling in EA logic might be tricky without history. We might assume fixed or point-based.

       f_mfi_period = _f_mfi;
       f_vroc_period = _f_vroc_p; // Store VROC period
       f_smooth = _f_smooth;
       f_norm_len = _f_norm;
       f_scale = _f_scale_f;
       f_vis_gain = _f_vis;
       f_approx = _f_approx;

       // 2. Create Handles for VISUALIZATION ONLY
       // We do NOT use these handles for Getters anymore.

       // RSI/CCI Visuals (Standard 5)
       m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);
       m_handle_cci = iCCI(symbol, period, 5, PRICE_CLOSE); // Using Close for consistency with code 5-period request

       // Hybrid Pulse Visual
       m_handle_hybrid_macd = iCustom(symbol, period, path_hybrid,
           h_fast, h_slow, h_bb_per, h_bb_dev, h_bb_meth,
           h_kelt_per, h_kelt_dev, h_kelt_atr, h_kelt_meth,
           h_macd_scale, h_shift, h_scale, h_auto, h_lookback
       );

       // Hybrid Flow Visual
       MqlParam params[13];
       params[0].type = TYPE_STRING; params[0].string_value = path_flow;
       params[1].type = TYPE_BOOL;   params[1].integer_value = _f_fixed;
       params[2].type = TYPE_DOUBLE; params[2].double_value = _f_min;
       params[3].type = TYPE_DOUBLE; params[3].double_value = _f_max;
       params[4].type = TYPE_INT;    params[4].integer_value = _f_mfi;
       params[5].type = TYPE_BOOL;   params[5].integer_value = _f_vroc;
       params[6].type = TYPE_INT;    params[6].integer_value = _f_vroc_p;
       params[7].type = TYPE_DOUBLE; params[7].double_value = _f_thresh;
       params[8].type = TYPE_BOOL;   params[8].integer_value = _f_approx;
       params[9].type = TYPE_INT;    params[9].integer_value = _f_smooth;
       params[10].type = TYPE_INT;   params[10].integer_value = _f_norm;
       params[11].type = TYPE_DOUBLE; params[11].double_value = _f_scale_f;
       params[12].type = TYPE_DOUBLE; params[12].double_value = _f_vis;

       m_handle_flow = IndicatorCreate(symbol, period, IND_CUSTOM, 13, params);

       return true;
   }

   void AttachIndicatorsToChart(long chart_id, int subwin_hybrid, int subwin_flow)
   {
       // Attach Custom Indicators for visual reference
       if(m_handle_hybrid_macd != INVALID_HANDLE)
           ChartIndicatorAdd(chart_id, subwin_hybrid, m_handle_hybrid_macd);

       if(m_handle_flow != INVALID_HANDLE)
           ChartIndicatorAdd(chart_id, subwin_flow, m_handle_flow);
   }

   //-- Update Sensor Readings (INTERNAL MATH)
   void Refresh(string symbol)
   {
      // 1. Get Raw Data (Tick-by-Tick Freshness)
      int copied = CopyRates(symbol, PERIOD_CURRENT, 0, m_lookback, m_rates);
      if(copied < 200) return; // Not enough data

      // IMPORTANT: Overwrite the latest bar's close/high/low with the absolute latest Tick
      // because CopyRates might be slightly lagged or cached?
      // Actually, standard practice is CopyRates is reliable.
      // But for "Tick" precision, we can augment.
      MqlTick tick;
      if(SymbolInfoTick(symbol, tick)) {
          // Update index [copied-1] (the latest bar)
          m_rates[copied-1].close = tick.bid; // Using Bid for Close
          if(tick.last > m_rates[copied-1].high) m_rates[copied-1].high = tick.last;
          if(tick.last < m_rates[copied-1].low) m_rates[copied-1].low = tick.last;
          // Volume is tricky, CopyRates volume is usually reliable for the count.
      }

      // 2. Calculate Indicators
      m_val_rsi = CalcRSI(copied, 5);
      m_val_cci = CalcCCI(copied, 5);

      CalcHybridPulse(copied);
      CalcHybridFlow(copied);
   }

   //-- Getters
   double GetRSI() { return m_val_rsi; }
   double GetCCI() { return m_val_cci; }
   double GetPulse() { return m_val_dfcurve; }
   double GetHybridMACD() { return m_val_macd; }

   //-- Barbed Wire Specific Getters
   void GetBarbedWireFlow(double &mfi, double &dup, double &ddown)
   {
       // Mapping:
       // mfi -> Hybrid MFI Value
       // dup -> Delta Up End (if positive) or 50 (if negative) - Used for logging
       // ddown -> Delta Down End (if negative) or 50 (if positive)

       mfi = m_val_flow_mfi;

       // Reconstruct Split logic for CSV consistency
       double delta_visual = m_val_flow_delta; // This is the offset from 50.0?
       // Wait, CalcHybridFlow computes the raw delta offset.

       double center = 50.0;
       double val_hist = center + delta_visual;

       // Mimic logic:
       if(delta_visual >= 0) {
           dup = val_hist;
           ddown = center;
       } else {
           dup = center;
           ddown = val_hist;
       }
   }

   double GetFlowROC() { return m_val_flow_roc; }

private:
   // --- INTERNAL MATH HELPERS ---

   // RSI Calculation
   double CalcRSI(int total, int period)
   {
       if(total <= period) return 50.0;

       // Calculate RSI for the LAST bar (index total-1).
       // Need to calculate EMA of Gains/Losses.
       // For efficiency, we can just run the loop over the last 100 bars to stabilize.

       double avg_gain = 0;
       double avg_loss = 0;

       // Initial SMA part (not strictly Wilder's but standard approx starts with SMA)
       // Let's do Wilder's smoothing correctly by iterating.
       // Start index:
       int start_i = 1;

       // Initialize first 'period' bars
       for(int i=start_i; i<start_i+period; i++) {
           double change = m_rates[i].close - m_rates[i-1].close;
           if(change > 0) avg_gain += change;
           else avg_loss -= change;
       }
       avg_gain /= period;
       avg_loss /= period;

       // Smooth remaining
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

   // CCI Calculation
   double CalcCCI(int total, int period)
   {
       if(total <= period) return 0.0;

       // Target: Last bar (total-1)
       // TP = (H+L+C)/3
       // SMA of TP over period

       double current_tp = (m_rates[total-1].high + m_rates[total-1].low + m_rates[total-1].close) / 3.0;
       double sma = 0.0;

       // Calculate SMA of Typical Price
       for(int i=0; i<period; i++) {
           int idx = total - 1 - i;
           // Safety check
           if(idx < 0) break;
           double tp = (m_rates[idx].high + m_rates[idx].low + m_rates[idx].close) / 3.0;
           sma += tp;
       }
       sma /= (double)period;

       // Calculate Mean Deviation
       double mean_dev = 0.0;
       for(int i=0; i<period; i++) {
           int idx = total - 1 - i;
           if(idx < 0) break;
           double tp = (m_rates[idx].high + m_rates[idx].low + m_rates[idx].close) / 3.0;
           mean_dev += MathAbs(tp - sma);
       }
       mean_dev /= (double)period;

       // Prevent division by zero
       if(mean_dev == 0.0) return 0.0;

       return (current_tp - sma) / (0.015 * mean_dev);
   }

   // Hybrid Pulse Calculation (MACD + DeltaForce)
   void CalcHybridPulse(int total)
   {
       // 1. MACD
       // EMA 12, EMA 26
       double ema_fast = CalcEMA(total, p_macd_fast);
       double ema_slow = CalcEMA(total, p_macd_slow);
       m_val_macd = (ema_fast - ema_slow) * p_macd_scale;

       // 2. DeltaForce Curve
       // Logic: Accumulate price changes (close - prev_close) in points.
       // Reset if sign flips.
       // Need to iterate to build state.

       double curr_h = 0;
       double curr_l = 0;

       // Iterate from sufficient history to build state
       int start = MathMax(1, total - 100);

       for(int i=start; i<total; i++)
       {
           double diff = (m_rates[i].close - m_rates[i-1].close) / Point();

           // Accumulate
           if(diff > 0) {
               curr_h += diff;
               curr_l = 0;
           } else if(diff < 0) {
               curr_l += diff;
               curr_h = 0;
           }
       }

       double df_raw = (curr_h != 0) ? curr_h : curr_l;

       // Scaling
       double scale = p_df_auto ? Point() : p_df_scale;
       m_val_dfcurve = df_raw * scale;
   }

   double CalcEMA(int total, int period)
   {
       double k = 2.0 / (period + 1.0);
       double ema = m_rates[0].close; // Seed

       // Stabilize
       int start = 1;
       if(total > 200) { start = total - 200; ema = m_rates[start-1].close; }

       for(int i=start; i<total; i++) {
           ema = (m_rates[i].close * k) + (ema * (1.0 - k));
       }
       return ema;
   }

   // Hybrid Flow Calculation
   void CalcHybridFlow(int total)
   {
       // Need history for Smoothing and Normalization
       // Recalculate last few bars to get Smooth Delta

       int calc_len = f_norm_len + f_smooth + 10;
       int start = MathMax(1, total - calc_len);

       double smooth_deltas[]; // Temp buffer for smoothing
       ArrayResize(smooth_deltas, total);

       // 1. Raw Delta Loop
       for(int i=start; i<total; i++)
       {
           double range = m_rates[i].high - m_rates[i].low;
           double delta = 0;
           if(range > 0 && f_approx) {
               double pos = (m_rates[i].close - m_rates[i].low) / range;
               double power = (pos - 0.5) * 2.0;
               delta = (double)m_rates[i].tick_volume * power;
           }
           smooth_deltas[i] = delta;
       }

       // 2. Smooth Delta (Last Bar)
       double s_delta = 0;
       int count = 0;
       for(int j=0; j<f_smooth; j++) {
           int idx = total - 1 - j;
           if(idx >= start) {
               s_delta += smooth_deltas[idx];
               count++;
           }
       }
       if(count>0) s_delta /= count;

       // 3. Normalization (Max Vol in last N)
       double max_vol = 1.0;
       for(int i=0; i<f_norm_len; i++) {
           int idx = total - 1 - i;
           if(idx >= 0) {
               if((double)m_rates[idx].tick_volume > max_vol) max_vol = (double)m_rates[idx].tick_volume;
           }
       }

       double offset_curve = 0;
       double offset_hist = 0; // The visual delta output

       if(max_vol > 0) {
           double ratio = s_delta / max_vol;
           offset_curve = ratio * f_scale;
           offset_hist = offset_curve * f_vis_gain;
       }

       m_val_flow_delta = offset_hist; // Store the visual offset for CSV

       // 4. MFI Calculation
       // Standard MFI(5)
       // MFI = 100 - 100 / (1+MFR)
       // MFR = PosMF / NegMF

       double pos_mf = 0;
       double neg_mf = 0;

       for(int i=0; i<f_mfi_period; i++) {
           int idx = total - 1 - i;
           if(idx < 1) break;

           double tp_curr = (m_rates[idx].high + m_rates[idx].low + m_rates[idx].close) / 3.0;
           double tp_prev = (m_rates[idx-1].high + m_rates[idx-1].low + m_rates[idx-1].close) / 3.0;

           double mf = tp_curr * (double)m_rates[idx].tick_volume;

           if(tp_curr > tp_prev) pos_mf += mf;
           else if(tp_curr < tp_prev) neg_mf += mf;
       }

       double mfi_raw = 50.0;
       if(neg_mf != 0) mfi_raw = 100.0 - (100.0 / (1.0 + (pos_mf / neg_mf)));
       else if(pos_mf > 0) mfi_raw = 100.0;
       else mfi_raw = 0.0; // No volume?

       // 5. Hybrid MFI (Layering)
       m_val_flow_mfi = mfi_raw + offset_curve;

       // 6. ROC (Tick Vol)
       if(total > f_vroc_period) {
           int vp = f_vroc_period;
           if (m_rates[total-1-vp].tick_volume > 0)
              m_val_flow_roc = ((double)m_rates[total-1].tick_volume - (double)m_rates[total-1-vp].tick_volume) / (double)m_rates[total-1-vp].tick_volume * 100.0;
           else
              m_val_flow_roc = 0.0;
       }
   }
};
