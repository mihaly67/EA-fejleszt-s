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
   int      m_handle_rsi;
   int      m_handle_cci;
   int      m_handle_hybrid_macd;
   int      m_handle_flow; // New: For Barbed Wire mode

   // Buffers for data
   double   m_rsi_buffer[];
   double   m_cci_buffer[];
   double   m_hybrid_macd_buffer[];
   double   m_hybrid_signal_buffer[];

   // Barbed Wire Specific Buffers
   double   m_hybrid_dfcurve_buffer[];
   double   m_flow_mfi_buffer[];
   double   m_flow_dup_buffer[];
   double   m_flow_ddown_buffer[];

   // Flow Internal State (Synthetic - Backup/v1.04)
   double   m_last_flow_mfi;
   double   m_flow_roc;
   double   m_flow_delta;

   bool     m_use_real_indicators; // Flag to indicate mode

public:
   CMimicNavSystem()
   {
      m_handle_rsi = INVALID_HANDLE;
      m_handle_cci = INVALID_HANDLE;
      m_handle_hybrid_macd = INVALID_HANDLE;
      m_handle_flow = INVALID_HANDLE;
      m_last_flow_mfi = 50.0;
      m_flow_roc = 0.0;
      m_flow_delta = 0.0;
      m_use_real_indicators = false;
   }

   ~CMimicNavSystem()
   {
      IndicatorRelease(m_handle_rsi);
      IndicatorRelease(m_handle_cci);
      IndicatorRelease(m_handle_hybrid_macd);
      IndicatorRelease(m_handle_flow);
   }

   // Standard Initialize (v1.04 mode)
   bool Initialize(string symbol, ENUM_TIMEFRAMES period)
   {
      m_use_real_indicators = false;
      // 1. Standard Indicators (Scalping Setup: 5-period)
      m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);
      m_handle_cci = iCCI(symbol, period, 5, PRICE_TYPICAL);

      // 2. Hybrid Indicator (MACD approximation for Pulse if custom not available)
      m_handle_hybrid_macd = iMACD(symbol, period, 12, 26, 9, PRICE_CLOSE);

      if(m_handle_rsi == INVALID_HANDLE || m_handle_cci == INVALID_HANDLE)
      {
         Print("NavSystem: Failed to create standard indicators.");
         return false;
      }
      return true;
   }

   // Barbed Wire Initialize (v1.05 Exact Copy mode)
   bool InitializeBarbedWire(
       string symbol, ENUM_TIMEFRAMES period,
       // Hybrid Params
       string path_hybrid,
       int h_fast, int h_slow, int h_bb_per, double h_bb_dev, ENUM_MA_METHOD h_bb_meth,
       int h_kelt_per, double h_kelt_dev, int h_kelt_atr, ENUM_MA_METHOD h_kelt_meth,
       double h_macd_scale, int h_shift, double h_scale, bool h_auto, int h_lookback,
       // Flow Params
       string path_flow,
       bool f_fixed, double f_min, double f_max, int f_mfi, bool f_vroc, int f_vroc_p,
       double f_thresh, bool f_approx, int f_smooth, int f_norm, double f_scale_f, double f_vis
   )
   {
       m_use_real_indicators = true;

       // 1. Standard ML Baselines
       m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);
       m_handle_cci = iCCI(symbol, period, 5, PRICE_TYPICAL); // v1.03 used 14? Checked code: 5 is implicit or user?
       // Checked BarbedWire code: h_rsi = iRSI(..., 14, ...); h_cci = iCCI(..., 14, ...);
       // WAIT! BarbedWire v1.03 used 14 for RSI/CCI in OnInit.
       // "h_rsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);"
       // "h_cci = iCCI(_Symbol, _Period, 14, PRICE_CLOSE);"
       // Correcting initialization for Barbed Wire mode.
       IndicatorRelease(m_handle_rsi); IndicatorRelease(m_handle_cci);
       m_handle_rsi = iRSI(symbol, period, 14, PRICE_CLOSE);
       m_handle_cci = iCCI(symbol, period, 14, PRICE_CLOSE);


       // 2. Real Hybrid Indicator
       m_handle_hybrid_macd = iCustom(symbol, period, path_hybrid,
           h_fast, h_slow, h_bb_per, h_bb_dev, h_bb_meth,
           h_kelt_per, h_kelt_dev, h_kelt_atr, h_kelt_meth,
           h_macd_scale, h_shift, h_scale, h_auto, h_lookback
       );

       // 3. Real Flow Indicator
       MqlParam params[13];
       params[0].type = TYPE_STRING; params[0].string_value = path_flow;
       params[1].type = TYPE_BOOL;   params[1].integer_value = f_fixed;
       params[2].type = TYPE_DOUBLE; params[2].double_value = f_min;
       params[3].type = TYPE_DOUBLE; params[3].double_value = f_max;
       params[4].type = TYPE_INT;    params[4].integer_value = f_mfi;
       params[5].type = TYPE_BOOL;   params[5].integer_value = f_vroc;
       params[6].type = TYPE_INT;    params[6].integer_value = f_vroc_p;
       params[7].type = TYPE_DOUBLE; params[7].double_value = f_thresh;
       params[8].type = TYPE_BOOL;   params[8].integer_value = f_approx;
       params[9].type = TYPE_INT;    params[9].integer_value = f_smooth;
       params[10].type = TYPE_INT;   params[10].integer_value = f_norm;
       params[11].type = TYPE_DOUBLE; params[11].double_value = f_scale_f;
       params[12].type = TYPE_DOUBLE; params[12].double_value = f_vis;

       m_handle_flow = IndicatorCreate(symbol, period, IND_CUSTOM, 13, params);

       if(m_handle_hybrid_macd == INVALID_HANDLE || m_handle_flow == INVALID_HANDLE) {
           Print("NavSystem: Failed to load Custom Indicators!");
           return false;
       }
       return true;
   }

   void AttachIndicatorsToChart(long chart_id, int subwin_hybrid, int subwin_flow)
   {
       if(m_handle_hybrid_macd != INVALID_HANDLE)
           ChartIndicatorAdd(chart_id, subwin_hybrid, m_handle_hybrid_macd);

       if(m_handle_flow != INVALID_HANDLE)
           ChartIndicatorAdd(chart_id, subwin_flow, m_handle_flow);
   }

   //-- Update Sensor Readings
   void Refresh(string symbol)
   {
      // Ensure fresh data by clearing or checking result
      if(CopyBuffer(m_handle_rsi, 0, 0, 3, m_rsi_buffer) < 3) Print("NavSystem: RSI Copy Failed");
      if(CopyBuffer(m_handle_cci, 0, 0, 3, m_cci_buffer) < 3) Print("NavSystem: CCI Copy Failed");

      if(m_use_real_indicators) {
          // Barbed Wire Mode
          if(CopyBuffer(m_handle_hybrid_macd, 0, 0, 3, m_hybrid_macd_buffer) < 3) Print("NavSystem: Hybrid MACD Copy Failed");
          if(CopyBuffer(m_handle_hybrid_macd, 2, 0, 3, m_hybrid_dfcurve_buffer) < 3) Print("NavSystem: Hybrid DF Copy Failed");

          // v1.125 Indices: 4 (MFI), 1 (DUp End), 3 (DDown End)
          if(CopyBuffer(m_handle_flow, 4, 0, 3, m_flow_mfi_buffer) < 3) Print("NavSystem: Flow MFI Copy Failed");
          if(CopyBuffer(m_handle_flow, 1, 0, 3, m_flow_dup_buffer) < 3) Print("NavSystem: Flow DUp Copy Failed");
          if(CopyBuffer(m_handle_flow, 3, 0, 3, m_flow_ddown_buffer) < 3) Print("NavSystem: Flow DDown Copy Failed");
      } else {
          // Standard v1.04 Mode
          CopyBuffer(m_handle_hybrid_macd, 0, 0, 3, m_hybrid_macd_buffer);
          CopyBuffer(m_handle_hybrid_macd, 1, 0, 3, m_hybrid_signal_buffer);
      }
   }

   //-- Getters
   double GetRSI() { return (ArraySize(m_rsi_buffer)>0) ? m_rsi_buffer[0] : 50.0; }
   double GetCCI() { return (ArraySize(m_cci_buffer)>0) ? m_cci_buffer[0] : 0.0; }

   //-- Pulse (Hybrid DFCurve approximation)
   double GetPulse()
   {
      if (m_use_real_indicators) {
          return (ArraySize(m_hybrid_dfcurve_buffer)>0) ? m_hybrid_dfcurve_buffer[0] : 0.0;
      }
      // v1.04 Approx
      if(ArraySize(m_hybrid_macd_buffer)>0 && ArraySize(m_hybrid_signal_buffer)>0)
         return m_hybrid_macd_buffer[0] - m_hybrid_signal_buffer[0];
      return 0.0;
   }

   double GetHybridMACD() {
       return (ArraySize(m_hybrid_macd_buffer)>0) ? m_hybrid_macd_buffer[0] : 0.0;
   }

   //-- Barbed Wire Specific Getters
   void GetBarbedWireFlow(double &mfi, double &dup, double &ddown)
   {
       mfi = 50.0; dup = 50.0; ddown = 50.0;
       if(ArraySize(m_flow_mfi_buffer)>0) mfi = m_flow_mfi_buffer[0];
       if(ArraySize(m_flow_dup_buffer)>0) dup = m_flow_dup_buffer[0];
       if(ArraySize(m_flow_ddown_buffer)>0) ddown = m_flow_ddown_buffer[0];
   }

   //-- Fix for Flow Blindness (v1.04)
   void UpdateFlowPhysics(double price, double last_price, long volume)
   {
      // 1. ROC (Rate of Change)
      if(last_price > 0)
         m_flow_roc = ((price - last_price) / last_price) * 10000.0; // Scaled
      else
         m_flow_roc = 0.0;

      // 2. Delta (Simple Up/Down Volume)
      if(price > last_price) m_flow_delta += (double)volume;
      else if(price < last_price) m_flow_delta -= (double)volume;

      // Decay Delta slightly to keep it local (Flow memory)
      m_flow_delta *= 0.95;
   }

   double GetFlowROC() { return m_flow_roc; }
   double GetFlowDelta() { return m_flow_delta; }
   double GetFlowMFI() { return 50.0 + (m_flow_delta / 100.0); } // Synthetic MFI based on Delta
};
