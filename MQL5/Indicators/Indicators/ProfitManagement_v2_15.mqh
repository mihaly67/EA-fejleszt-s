//+------------------------------------------------------------------+
//|                                     ProfitManagement_v2_15.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.15  |
//+------------------------------------------------------------------+
#ifndef PROFITMANAGEMENT_V2_15_MQH
#define PROFITMANAGEMENT_V2_15_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Class CProfitManager                                             |
//| Handles "Invisible" (Virtual) Take Profit logic.                 |
//| v2.15: Supports Per-Position Virtual TP in Currency.             |
//+------------------------------------------------------------------+
class CProfitManager
{
private:
   CTrade         *m_trade;
   CPositionInfo  *m_position;
   ulong          m_magic;
   string         m_symbol;
   double         m_virtual_tp_currency;

public:
   CProfitManager() { m_trade = NULL; m_position = NULL; m_virtual_tp_currency = 0.0; }
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
   //| Check                                                            |
   //| Iterates all positions and closes those hitting the target.      |
   //| Returns: Number of positions closed in this check.               |
   //+------------------------------------------------------------------+
   int Check()
   {
      if (m_virtual_tp_currency <= 0.001) return 0; // Disabled
      if (m_trade == NULL || m_position == NULL) return 0;

      int closed_count = 0;
      int total = PositionsTotal();

      // Iterate backwards to safely close
      for(int i = total - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i)) // Dot syntax as per environment constraint
         {
            // Filter by Magic and Symbol
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol)
            {
               double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();

               // Check if Profit >= Target
               if(profit >= m_virtual_tp_currency)
               {
                  ulong ticket = m_position.Ticket();
                  string type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";

                  PrintFormat("💰 Virtual TP Hit! Closing #%d (%s) Profit: %.2f >= Target: %.2f",
                              ticket, type, profit, m_virtual_tp_currency);

                  // Close Position
                  if(m_trade.PositionClose(ticket))
                  {
                     closed_count++;
                     Print("✅ Closed #", ticket);
                  }
                  else
                  {
                     Print("❌ Failed to close #", ticket, " Error: ", GetLastError());
                  }
               }
            }
         }
      }
      return closed_count;
   }
};
#endif
