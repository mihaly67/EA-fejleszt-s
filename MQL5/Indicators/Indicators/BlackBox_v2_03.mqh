//+------------------------------------------------------------------+
//|                                            BlackBox_v2_02.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.02   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| Forensic Recorder - CSV Logging (v2.02)                          |
//| Core Improvement: High Precision Decimals & Safe Timestamps      |
//+------------------------------------------------------------------+
class CBlackBox
{
private:
   int      m_file_handle;
   string   m_filename;
   string   m_headers;
   bool     m_is_active;

public:
   CBlackBox()
   {
      m_file_handle = INVALID_HANDLE;
      m_is_active = false;
      // v2.02 Unified Headers
      m_headers = "Time,TickMSC,Phase,MimicMode,Verdict,Bid,Ask,Spread,BidVol,AskVol," +
                  "Bar_Open,Bar_High,Bar_Low,Bar_Close,RSI,Velocity,Acceleration," +
                  "Hybrid_MACD,Hybrid_DFCurve," +
                  "Flow_MFI,Flow_ROC,Flow_Delta," + // Unified
                  "Balance,Margin,MarginPercent,Floating_PL,Realized_PL,Session_PL," +
                  "PosCount,LotDir,TotalLots,SLTP_Levels,ActionDetails,LastEvent";
   }

   ~CBlackBox()
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
      Print("BlackBox v2.02 Recording to: ", m_filename);
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
      string phase, int mimic_mode, string verdict,
      double bid, double ask, double spread,
      long bid_vol, long ask_vol,
      double b_open, double b_high, double b_low, double b_close,
      double rsi, double velocity, double accel,
      double h_macd, double h_dfcurve,
      double f_mfi, double f_roc, double f_delta, // v2.02 Inputs
      double balance, double margin, double margin_pct,
      double floating_pl, double realized_pl, double session_pl,
      int pos_count, string lot_dir, double total_lots,
      string sltp_levels, string action_details, string last_event
   )
   {
      if(!m_is_active || m_file_handle == INVALID_HANDLE) return;

      // Timestamp Formatting from MSC
      datetime time_sec = (datetime)(tick_time_msc / 1000);
      int ms = (int)(tick_time_msc % 1000);
      string time_str = TimeToString(time_sec, TIME_DATE|TIME_SECONDS) + StringFormat(".%03d", ms);

      // Formatting Updates v2.03:
      // ALL Indicators set to %.5f precision as requested.
      // TickMSC: %I64d (Safe Long Int)

      string row = StringFormat(
         "%s,%I64d,%s,%d,%s,%.5f,%.5f,%.1f,%d,%d," +
         "%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f," +
         "%.5f,%.5f," +
         "%.5f,%.5f,%.5f," +
         "%.2f,%.2f,%.2f,%.2f,%.2f,%.2f," +
         "%d,%s,%.2f,%s,%s,%s",

         time_str, tick_time_msc, phase, mimic_mode, verdict, bid, ask, spread, bid_vol, ask_vol,
         b_open, b_high, b_low, b_close, rsi, velocity, accel,
         h_macd, h_dfcurve,
         f_mfi, f_roc, f_delta,
         balance, margin, margin_pct, floating_pl, realized_pl, session_pl,
         pos_count, lot_dir, total_lots, sltp_levels, action_details, last_event
      );

      FileWrite(m_file_handle, row);
      FileFlush(m_file_handle);
   }
};
