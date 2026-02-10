//+------------------------------------------------------------------+
//|                                                  FireControl.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.11  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

enum ENUM_FIRE_MODE
{
   FIRE_MODE_LIMIT = 0, // Reversion (Buy Low, Sell High)
   FIRE_MODE_STOP  = 1  // Breakout (Buy High, Sell Low)
};

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Trap" logic for placing Breakout (Stop) orders.     |
//| v2.11: Dual Mode (Switchable Limit/Stop Logic)                   |
//+------------------------------------------------------------------+
class CFireControl
{
private:
   CTrade      *m_trade;
   CSymbolInfo *m_symbol;
   string      m_symbol_name;
   double      m_point;
   int         m_digits;
   string      m_comment_prefix;
   ulong       m_magic;

public:
   CFireControl() { m_trade = NULL; m_symbol = NULL; }
   ~CFireControl() {}

   void Init(CTrade *trade_ptr, CSymbolInfo *symbol_ptr, string comment, ulong magic)
   {
      m_trade = trade_ptr;
      m_symbol = symbol_ptr;
      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();
      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireGrid (formerly FireTrap/FireBurst)                           |
   //| Places a grid of orders around center price based on mode.       |
   //| Uses ASYNC MODE for instant "Carpet Bombing" placement.          |
   //+------------------------------------------------------------------+
   void FireGrid(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points, ENUM_FIRE_MODE mode)
   {
      if (layers <= 0) return;

      // Enable Async Mode for Instant Execution (No waiting for Server Confirmation)
      m_trade.SetAsyncMode(true);

      m_symbol.RefreshRates();
      double real_spread = m_symbol.Ask() - m_symbol.Bid();
      double effective_spread = MathMax(real_spread, min_spread_points * m_point);

      int stops_level = m_symbol.StopsLevel();
      double min_safety = stops_level * m_point;
      if (min_safety == 0) min_safety = 10 * m_point;

      string mode_str = (mode == FIRE_MODE_STOP) ? "STOP (Breakout)" : "LIMIT (Reversion)";
      PrintFormat("🕸️ FIRE GRID (ASYNC): %s | Center=%.5f | Layers=%d", mode_str, center_price, layers);

      for (int i = 1; i <= layers; i++)
      {
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = effective_spread * current_mult;

         if (dist < min_safety) dist = min_safety + (i * 10 * m_point);

         double buy_price = 0;
         double sell_price = 0;
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (mode == FIRE_MODE_STOP)
         {
             // BREAKOUT (STOP)
             buy_price = NormalizeDouble(center_price + dist, m_digits);
             sell_price = NormalizeDouble(center_price - dist, m_digits);

             if (buy_price < m_symbol.Ask() + min_safety) buy_price = m_symbol.Ask() + min_safety + (i * m_point);
             if (sell_price > m_symbol.Bid() - min_safety) sell_price = m_symbol.Bid() - min_safety - (i * m_point);

             m_trade.BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             m_trade.SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm);
         }
         else
         {
             // REVERSION (LIMIT)
             buy_price = NormalizeDouble(center_price - dist, m_digits);
             sell_price = NormalizeDouble(center_price + dist, m_digits);

             if (buy_price > m_symbol.Ask() - min_safety) buy_price = m_symbol.Ask() - min_safety - (i * m_point);
             if (sell_price < m_symbol.Bid() + min_safety) sell_price = m_symbol.Bid() + min_safety + (i * m_point);

             m_trade.BuyLimit(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             m_trade.SellLimit(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm);
         }
      }

      // Reset Async Mode (Optional, but good practice if CTrade is shared)
      // m_trade.SetAsyncMode(false);
      // Keeping it True might affect other parts if not careful, but for this specific "Weapon" class,
      // resetting it at the end of the loop ensures predictable behavior elsewhere.
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| CeaseFire                                                        |
   //| Rapidly closes all positions and deletes pending orders.         |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       // Use Async for rapid deletion too
       m_trade.SetAsyncMode(true);

       // 1. Delete Pending
       for (int i = OrdersTotal() - 1; i >= 0; i--) {
           ulong ticket = OrderGetTicket(i);
           if (OrderSelect(ticket)) {
               if (OrderGetString(ORDER_SYMBOL) == m_symbol_name && OrderGetInteger(ORDER_MAGIC) == m_magic) {
                   m_trade.OrderDelete(ticket);
               }
           }
       }

       // 2. Close Positions
       for (int i = PositionsTotal() - 1; i >= 0; i--) {
           ulong ticket = PositionGetTicket(i);
           if (PositionSelectByTicket(ticket)) {
               if (PositionGetString(POSITION_SYMBOL) == m_symbol_name && PositionGetInteger(POSITION_MAGIC) == m_magic) {
                   m_trade.PositionClose(ticket);
               }
           }
       }

       m_trade.SetAsyncMode(false);
       Print("🏳️ CEASE FIRE (ASYNC): Sweep Complete.");
   }
};
