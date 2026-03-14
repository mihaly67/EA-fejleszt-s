//+------------------------------------------------------------------+
//|                                            DataMiner_BlackBox_v1_00.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 1.00 (DataMiner ML Custom)   |
//| (Combined Logging: Context v3.28 4 EMAs + Momentum + Physics)    |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| Forensic Recorder - CSV Logging (v2.10)                          |
//| Unified Logging for Hybrid Context (v3.28) & Momentum (v1.04)    |
//+------------------------------------------------------------------+
class CDataMiner_BlackBox
{
private:
   int      m_file_handle;
   string   m_filename;
   string   m_headers;
   bool     m_is_active;

public:
   CDataMiner_BlackBox()
   {
      m_file_handle = INVALID_HANDLE;
      m_is_active = false;

      // Unified Headers:
      // Standard -> Physics -> Pulse -> Flow -> Context (13) -> Momentum (2) -> Account
      m_headers = "Time,TickMSC,Bid,Ask,Spread,BidVol,AskVol," +
                  "Bar_Open,Bar_High,Bar_Low,Bar_Close,RSI,Velocity,Acceleration," +
                  "Hybrid_MACD,Hybrid_DFCurve," +
                  "Flow_MFI,Flow_ROC,Flow_Delta," +
                  "Ctx_EMA_25,Ctx_EMA_50,Ctx_EMA_150,Ctx_EMA_300," + // Context v3.28 EMAs
                  "WPR,Stoch_K," + // Momentum v1.04
                  "Ping_MS"; // Lag/Latency Tracking
   }

   ~CDataMiner_BlackBox()
   {
      CloseLog();
   }

   //-- Initialize the Log File
   bool Initialize(string symbol, string version)
   {
      string date = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(date, ".", "");
      string time = TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS);
      StringReplace(time, ":", "");

      m_filename = "Merkava_" + symbol + "_" + version + "_" + date + "_" + time + ".csv";

      m_file_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");

      if(m_file_handle == INVALID_HANDLE)
      {
         Print("CRITICAL: Failed to create log file: ", m_filename);
         m_is_active = false;
         return false;
      }

      FileWrite(m_file_handle, m_headers);
      m_is_active = true;
      Print("BlackBox v2.10 Recording to: ", m_filename);
      return true;
   }

   void CloseLog()
   {
      if(m_file_handle != INVALID_HANDLE)
      {
         FileClose(m_file_handle);
         m_file_handle = INVALID_HANDLE;
         m_is_active = false;
      }
   }

   //-- The Main Logging Function (Zero Latency)
   void RecordTick(
      long tick_time_msc, // Master Source of Truth (Epoch MS)
      double bid, double ask, double spread,
      long bid_vol, long ask_vol,
      double b_open, double b_high, double b_low, double b_close,
      double rsi, double velocity, double accel,
      double h_macd, double h_dfcurve,
      double f_mfi, double f_roc, double f_delta,
      // Context EMAs
      double ctx_ema_25, double ctx_ema_50, double ctx_ema_150, double ctx_ema_300,
      double wpr, double stoch_k,
      long ping_ms // Ping for Anomaly Detection
   )
   {
      if(!m_is_active || m_file_handle == INVALID_HANDLE) return;

      // Timestamp Formatting from MSC
      datetime time_sec = (datetime)(tick_time_msc / 1000);
      int ms = (int)(tick_time_msc % 1000);
      string time_str = TimeToString(time_sec, TIME_DATE|TIME_SECONDS) + StringFormat(".%03d", ms);

      string row = StringFormat(
         "%s,%I64d,%.5f,%.5f,%.1f,%d,%d," +
         "%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f," +
         "%.5f,%.5f," +
         "%.3f,%.3f,%.3f," +
         "%.5f,%.5f,%.5f,%.5f," + // Context EMAs
         "%.3f,%.3f," + // Momentum
         "%I64d", // Ping_MS

         time_str, tick_time_msc, bid, ask, spread, bid_vol, ask_vol,
         b_open, b_high, b_low, b_close, rsi, velocity, accel,
         h_macd, h_dfcurve,
         f_mfi, f_roc, f_delta,
         ctx_ema_25, ctx_ema_50, ctx_ema_150, ctx_ema_300,
         wpr, stoch_k,
         ping_ms
      );

      FileWrite(m_file_handle, row);
      // FileFlush(m_file_handle); // Removed to prevent massive I/O overhead on millions of ticks
   }
};
