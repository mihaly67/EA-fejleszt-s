//+------------------------------------------------------------------+
//|                                     ProfitManagement_v2_16.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.16  |
//+------------------------------------------------------------------+
#ifndef PROFITMANAGEMENT_V2_16_MQH
#define PROFITMANAGEMENT_V2_16_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Class CProfitManager                                             |
//| Handles "Invisible" (Virtual) Take Profit and Stop Loss.         |
//| v2.15: Supports Per-Position Virtual TP/SL in Currency.          |
//| v2.16: Version Bump                                              |
//+------------------------------------------------------------------+
class CProfitManager
{
private:
   CTrade         *m_trade;
   CPositionInfo  *m_position;
   ulong          m_magic;
   string         m_symbol;
   double         m_virtual_tp_currency;
   double         m_virtual_sl_currency;

public:
   CProfitManager() { m_trade = NULL; m_position = NULL; m_virtual_tp_currency = 0.0; m_virtual_sl_currency = 0.0; }
   ~CProfitManager() {}

   //+------------------------------------------------------------------+
   //| Init                                                             |
   //| Initializes the Profit Manager with trade pointers.              |
   //+------------------------------------------------------------------+
   void Init(CTrade *trade_ptr, CPositionInfo *pos_ptr, ulong magic, string symbol)
   {
      m_trade = trade_ptr;
      m_position = pos_ptr;
      m_magic = magic;
      m_symbol = symbol;
   }

   //+------------------------------------------------------------------+
   //| SetVirtualTP                                                     |
   //| Sets the target profit in currency (0.0 = Disabled).             |
   //+------------------------------------------------------------------+
   void SetVirtualTP(double tp_currency)
   {
      m_virtual_tp_currency = tp_currency;
   }

   //+------------------------------------------------------------------+
   //| SetVirtualSL                                                     |
   //| Sets the max loss in currency (0.0 = Disabled).                  |
   //| Input should be positive (e.g. 50 means stop at -50).            |
   //+------------------------------------------------------------------+
   void SetVirtualSL(double sl_currency)
   {
      m_virtual_sl_currency = sl_currency;
   }

   //+------------------------------------------------------------------+
   //| Check                                                            |
   //| Iterates all positions and closes those hitting TP or SL.        |
   //| Returns: Number of positions closed in this check.               |
   //+------------------------------------------------------------------+
   int Check()
   {
      if (m_trade == NULL || m_position == NULL) return 0;
      if (m_virtual_tp_currency <= 0.001 && m_virtual_sl_currency <= 0.001) return 0; // Both Disabled

      int closed_count = 0;
      int total = PositionsTotal();

      // Iterate backwards to safely close
      for(int i = total - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            // Filter by Magic and Symbol
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol)
            {
               double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();
               ulong ticket = m_position.Ticket();
               string type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";

               // Check TP
               if(m_virtual_tp_currency > 0.001 && profit >= m_virtual_tp_currency)
               {
                  PrintFormat("💰 Virtual TP Hit! Closing #%d (%s) Profit: %.2f >= Target: %.2f",
                              ticket, type, profit, m_virtual_tp_currency);

                  if(m_trade.PositionClose(ticket)) closed_count++;
                  continue; // Next position
               }

               // Check SL (Loss is negative profit)
               // e.g. Profit -60 <= -50 (SL) -> TRUE
               if(m_virtual_sl_currency > 0.001 && profit <= -m_virtual_sl_currency)
               {
                  PrintFormat("🛑 Virtual SL Hit! Closing #%d (%s) Profit: %.2f <= Stop: -%.2f",
                              ticket, type, profit, m_virtual_sl_currency);

                  if(m_trade.PositionClose(ticket)) closed_count++;
                  continue;
               }
            }
         }
      }
      return closed_count;
   }

   //+------------------------------------------------------------------+
   //| CloseAllProfit                                                   |
   //| Closes ALL positions that are currently in net profit (>0).      |
   //| Used by the "Close Profit" button.                               |
   //+------------------------------------------------------------------+
   int CloseAllProfit()
   {
      if (m_trade == NULL || m_position == NULL) return 0;

      int closed_count = 0;
      int total = PositionsTotal();

      for(int i = total - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol)
            {
               double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();

               if(profit > 0.0) // Strictly profitable
               {
                  ulong ticket = m_position.Ticket();
                  PrintFormat("💸 Closing Profitable Position #%d Profit: %.2f", ticket, profit);
                  if(m_trade.PositionClose(ticket)) closed_count++;
               }
            }
         }
      }
      return closed_count;
   }
};
#endif
