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
   // Placeholder for Flow handles if we had the custom indicator file
   // For now, we simulate/calculate internal Flow logic if external is missing

   // Buffers for data
   double   m_rsi_buffer[];
   double   m_cci_buffer[];
   double   m_hybrid_macd_buffer[];
   double   m_hybrid_signal_buffer[];

   // Flow Internal State
   double   m_last_flow_mfi;
   double   m_flow_roc;
   double   m_flow_delta;

public:
   CMimicNavSystem()
   {
      m_handle_rsi = INVALID_HANDLE;
      m_handle_cci = INVALID_HANDLE;
      m_handle_hybrid_macd = INVALID_HANDLE;
      m_last_flow_mfi = 50.0;
      m_flow_roc = 0.0;
      m_flow_delta = 0.0;
   }

   ~CMimicNavSystem()
   {
      IndicatorRelease(m_handle_rsi);
      IndicatorRelease(m_handle_cci);
      IndicatorRelease(m_handle_hybrid_macd);
   }

   bool Initialize(string symbol, ENUM_TIMEFRAMES period)
   {
      // 1. Standard Indicators (Scalping Setup: 5-period)
      m_handle_rsi = iRSI(symbol, period, 5, PRICE_CLOSE);
      m_handle_cci = iCCI(symbol, period, 5, PRICE_TYPICAL);

      // 2. Hybrid Indicator (MACD approximation for Pulse if custom not available)
      // Using standard MACD as placeholder for the "Hybrid" logic source
      // In production, this would be iCustom(..., "Hybrid_Indicator")
      m_handle_hybrid_macd = iMACD(symbol, period, 12, 26, 9, PRICE_CLOSE);

      if(m_handle_rsi == INVALID_HANDLE || m_handle_cci == INVALID_HANDLE)
      {
         Print("NavSystem: Failed to create standard indicators.");
         return false;
      }

      return true;
   }

   //-- Update Sensor Readings
   void Refresh(string symbol)
   {
      CopyBuffer(m_handle_rsi, 0, 0, 3, m_rsi_buffer);
      CopyBuffer(m_handle_cci, 0, 0, 3, m_cci_buffer);
      CopyBuffer(m_handle_hybrid_macd, 0, 0, 3, m_hybrid_macd_buffer);
      CopyBuffer(m_handle_hybrid_macd, 1, 0, 3, m_hybrid_signal_buffer);

      // -- FLOW CALCULATION FIX --
      // Since the external Flow indicator was returning 50.0 (broken),
      // we implement a Tick-Based Flow Logic here ("Synthetic Flow").

      // Calculate ROC (Rate of Change) based on price
      double price_now = SymbolInfoDouble(symbol, SYMBOL_BID);
      // We need previous price. In a real tick loop, we store it.
      // Simplified here: use difference from generic buffers or stored state.

      // Calculate Flow Delta (Buying vs Selling Volume Pressure)
      // Requires real Tick Volume analysis.
      long tick_vol = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
      // Determine if tick was Up or Down (roughly)
      // This is a placeholder for the deep logic.

      // For now, let's ensure we return *something* active for ROC.
      // In the full EA, we will feed this with real tick data.
   }

   //-- Getters
   double GetRSI() { return (ArraySize(m_rsi_buffer)>0) ? m_rsi_buffer[0] : 50.0; }
   double GetCCI() { return (ArraySize(m_cci_buffer)>0) ? m_cci_buffer[0] : 0.0; }

   //-- Pulse (Hybrid DFCurve approximation)
   //-- Returns difference between MACD Main and Signal (Histogram)
   double GetPulse()
   {
      if(ArraySize(m_hybrid_macd_buffer)>0 && ArraySize(m_hybrid_signal_buffer)>0)
         return m_hybrid_macd_buffer[0] - m_hybrid_signal_buffer[0];
      return 0.0;
   }

   //-- Fix for Flow Blindness
   //-- Accepts raw tick data to calculate Delta/ROC internally
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
