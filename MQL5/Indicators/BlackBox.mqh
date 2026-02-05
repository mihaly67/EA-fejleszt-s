//+------------------------------------------------------------------+
//|                                                Mimic_BlackBox.mqh|
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| Forensic Recorder - CSV Logging with Precision                   |
//+------------------------------------------------------------------+
class CMimicBlackBox
{
private:
   int      m_file_handle;
   string   m_filename;
   string   m_headers;
   bool     m_is_active;

   // PL Cache to avoid recalculating every tick if not needed
   double   m_cached_floating_pl;
   double   m_cached_realized_pl;
   double   m_cached_session_pl;

public:
   CMimicBlackBox()
   {
      m_file_handle = INVALID_HANDLE;
      m_is_active = false;
      m_headers = "Time,TickMS,Phase,MimicMode,Verdict,Bid,Ask,Spread,BidVol,AskVol," +
                  "Bar_Open,Bar_High,Bar_Low,Bar_Close,RSI,CCI,Velocity,Acceleration," +
                  "Hybrid_MACD,Hybrid_DFCurve,Flow_MFI,Flow_ROC,Flow_Delta," + // UPDATED HEADERS
                  "Balance,Margin,MarginPercent,Floating_PL,Realized_PL,Session_PL," +
                  "PosCount,LotDir,TotalLots,SLTP_Levels,ActionDetails,LastEvent";
   }

   ~CMimicBlackBox()
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

      m_filename = "Mimic_Merkava_" + symbol + "_" + version + "_" + date + "_" + time + ".csv";

      m_file_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");

      if(m_file_handle == INVALID_HANDLE)
      {
         Print("CRITICAL: Failed to create log file: ", m_filename);
         m_is_active = false;
         return false;
      }

      FileWrite(m_file_handle, m_headers);
      m_is_active = true;
      Print("BlackBox Recording to: ", m_filename);
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

   //-- The Main Logging Function
   void RecordTick(
      string phase, int mimic_mode, string verdict,
      double bid, double ask, double spread,
      long bid_vol, long ask_vol,
      double b_open, double b_high, double b_low, double b_close,
      double rsi, double cci, double velocity, double accel,
      double h_macd, double h_dfcurve, double f_mfi, double f_roc, double f_delta, // Indicators
      double balance, double margin, double margin_pct,
      double floating_pl, double realized_pl, double session_pl, // Financials
      int pos_count, string lot_dir, double total_lots,
      string sltp_levels, string action_details, string last_event
   )
   {
      if(!m_is_active || m_file_handle == INVALID_HANDLE) return;

      string base_time = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      int tick_ms = (int)(GetTickCount() % 1000);
      string time_str = StringFormat("%s.%03d", base_time, tick_ms);

      string row = StringFormat(
         "%s,%d,%s,%d,%s,%.5f,%.5f,%.1f,%d,%d," +
         "%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.5f,%.5f," +
         "%.5f,%.2f,%.2f,%.2f,%.2f," + // Hybrids
         "%.2f,%.2f,%.2f,%.2f,%.2f,%.2f," + // Financials
         "%d,%s,%.2f,%s,%s,%s",

         time_str, tick_ms, phase, mimic_mode, verdict, bid, ask, spread, bid_vol, ask_vol,
         b_open, b_high, b_low, b_close, rsi, cci, velocity, accel,
         h_macd, h_dfcurve, f_mfi, f_roc, f_delta,
         balance, margin, margin_pct, floating_pl, realized_pl, session_pl,
         pos_count, lot_dir, total_lots, sltp_levels, action_details, last_event
      );

      FileWrite(m_file_handle, row);
      FileFlush(m_file_handle);
   }

   //-- Helpers for PL Calculation (To be called by Main EA)
   //-- Fixes the v1.02/1.03 duplication bug
   void CalculateFinancials(long magic_number, double &float_pl, double &real_pl, double &sess_pl)
   {
       float_pl = 0.0;
       // Realized PL & Session PL should be tracked by the EA globally,
       // but here we can iterate open positions for Floating PL.

       for(int i = PositionsTotal() - 1; i >= 0; i--)
       {
           ulong ticket = PositionGetTicket(i);
           if(PositionSelectByTicket(ticket))
           {
               if(PositionGetInteger(POSITION_MAGIC) == magic_number)
               {
                   float_pl += PositionGetDouble(POSITION_PROFIT);
                   float_pl += PositionGetDouble(POSITION_SWAP); // Don't forget swap
               }
           }
       }

       // Note: Realized PL needs HistoryDeals scanning, usually done on OnTradeTransaction.
       // We pass it through arguments to keep BlackBox simple.
   }
};
