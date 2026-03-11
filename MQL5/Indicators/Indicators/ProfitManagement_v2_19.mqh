//+------------------------------------------------------------------+
//|                                     ProfitManagement_v2_19.mqh |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 2.19            |
//|         (Async Group Operations for High-Speed Position Close)   |
//+------------------------------------------------------------------+
#ifndef PROFITMANAGEMENT_V2_19_MQH
#define PROFITMANAGEMENT_V2_19_MQH

#property copyright "Jules (Mimic)"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "StealthRegistry_v1_08.mqh" // Deep Stealth v1.08 Log Fix

//+------------------------------------------------------------------+
//| CProfitManager                                                   |
//| Handles Virtual TP/SL and Profit Closing Logic.                  |
//| v2.17: Supports Ticket Registry for Deep Stealth.                |
//| v2.18: Updated for StealthRegistry v1.08 (Log Fix).              |
//| v2.19: OrderSendAsync implementation for faster Group Closing.   |
//+------------------------------------------------------------------+
class CProfitManager
{
private:
   CTrade         *m_trade;
   CPositionInfo  *m_position;
   CStealthRegistry *m_registry; // Registry Pointer
   ulong          m_magic;
   string         m_symbol;
   ulong          m_slippage;
   double         m_virtual_tp;
   double         m_virtual_sl;

public:
   CProfitManager() { m_trade=NULL; m_position=NULL; m_registry=NULL; m_slippage=10; m_virtual_tp=0.0; m_virtual_sl=0.0; }
   ~CProfitManager() {}

   void Init(CTrade *trade_ptr, CPositionInfo *pos_ptr, ulong magic, string symbol, CStealthRegistry *registry_ptr = NULL)
   {
      m_trade = trade_ptr;
      m_position = pos_ptr;
      m_magic = magic;
      m_symbol = symbol;
      m_registry = registry_ptr;
   }

   void SetSlippage(ulong slp)  { m_slippage = slp; }
   void SetVirtualTP(double tp) { m_virtual_tp = tp; }
   void SetVirtualSL(double sl) { m_virtual_sl = sl; }

   // Check and Close Positions based on Virtual TP/SL
   int Check()
   {
      int closed_count = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
             // Check Ownership: Registry OR Magic Fallback
             bool is_mine = false;
             ulong ticket = m_position.Ticket();

             if(m_registry != NULL) {
                 is_mine = m_registry.IsMyTicket(ticket);
             } else {
                 is_mine = (m_position.Magic() == m_magic);
             }

             if(is_mine && m_position.Symbol() == m_symbol)
             {
                 double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();
                 bool close = false;

                 // Virtual TP
                 if(m_virtual_tp > 0 && profit >= m_virtual_tp) close = true;

                 // Virtual SL (Input is usually positive, so check if profit <= -SL)
                 // Or if user input negative, handle accordingly. Assuming positive input for "Loss Amount".
                 if(m_virtual_sl > 0 && profit <= -m_virtual_sl) close = true;

                 if(close)
                 {
                     MqlTradeRequest request;
                     MqlTradeResult  result;
                     ZeroMemory(request);
                     ZeroMemory(result);

                     request.action = TRADE_ACTION_DEAL;
                     request.position = ticket;
                     request.symbol = m_symbol;
                     request.volume = m_position.Volume();
                     request.deviation = m_slippage;
                     request.magic = m_magic;

                     if(m_position.PositionType() == POSITION_TYPE_BUY) {
                         request.type = ORDER_TYPE_SELL;
                         request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                     } else {
                         request.type = ORDER_TYPE_BUY;
                         request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                     }

                     if(OrderSendAsync(request, result)) {
                         closed_count++;
                         // Unregister from Stealth Registry if successful
                         if(m_registry != NULL) m_registry.UnregisterTicket(ticket);
                     }
                 }
             }
         }
      }
      return closed_count;
   }

   // Close All Profitable Positions (Manual Button)
   int CloseAllProfit()
   {
      int closed_count = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
             // Check Ownership
             bool is_mine = false;
             ulong ticket = m_position.Ticket();

             if(m_registry != NULL) {
                 is_mine = m_registry.IsMyTicket(ticket);
             } else {
                 is_mine = (m_position.Magic() == m_magic);
             }

             if(is_mine && m_position.Symbol() == m_symbol)
             {
                 double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();
                 if(profit > 0)
                 {
                     MqlTradeRequest request;
                     MqlTradeResult  result;
                     ZeroMemory(request);
                     ZeroMemory(result);

                     request.action = TRADE_ACTION_DEAL;
                     request.position = ticket;
                     request.symbol = m_symbol;
                     request.volume = m_position.Volume();
                     request.deviation = m_slippage;
                     request.magic = m_magic;

                     if(m_position.PositionType() == POSITION_TYPE_BUY) {
                         request.type = ORDER_TYPE_SELL;
                         request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                     } else {
                         request.type = ORDER_TYPE_BUY;
                         request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                     }

                     if(OrderSendAsync(request, result)) {
                         closed_count++;
                         if(m_registry != NULL) m_registry.UnregisterTicket(ticket);
                     }
                 }
             }
         }
      }
      return closed_count;
   }
};
#endif
