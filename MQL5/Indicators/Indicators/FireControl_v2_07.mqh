//+------------------------------------------------------------------+
//|                                            FireControl_v2_07.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                   Version 2.07   |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Burst" logic for placing Grid/Trap orders.          |
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

   // Updated Init: Accepts objects by reference, stores pointers
   void Init(CTrade &trade_obj, CSymbolInfo &symbol_obj, string comment, ulong magic)
   {
      m_trade = GetPointer(trade_obj);
      m_symbol = GetPointer(symbol_obj);

      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();

      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireBurst                                                        |
   //| Places a grid of BuyStop/SellStop orders (Breakout/BarbedWire).  |
   //| FIX v2.07: Direction Correction (Long Above, Short Below).       |
   //+------------------------------------------------------------------+
   void FireBurst(double center_price_unused, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_dist_points)
   {
      if (layers <= 0) return;
      if (CheckPointer(m_symbol) == POINTER_INVALID || CheckPointer(m_trade) == POINTER_INVALID) return;

      m_symbol.RefreshRates();
      double spread = m_symbol.Ask() - m_symbol.Bid();
      double current_bid = m_symbol.Bid();
      double current_ask = m_symbol.Ask();

      int stops_level = m_symbol.StopsLevel();

      // Safety: Minimum distance (StopsLevel + SafeZone)
      double min_safety = stops_level * m_point;
      if (min_dist_points * m_point > min_safety) min_safety = min_dist_points * m_point;

      PrintFormat("🔥 FIRE BURST (Breakout): Anchor=Ask/Bid, Spread=%.1f pts, Layers=%d", spread/m_point, layers);

      for (int i = 1; i <= layers; i++)
      {
         // Calculate distance for this layer
         double dist_from_edge = spread * spread_mult_start;
         if (i > 1) {
             dist_from_edge += spread * spread_mult_step * (i - 1);
         }

         // ENFORCE SAFETY (Min Dist)
         if (dist_from_edge < min_safety) {
             dist_from_edge = min_safety + (i*10 * m_point); // Add small step to avoid stacking
         }

         // FIX v2.07: Barbed Wire Breakout Logic
         // Long Above Price -> Buy Stop (Anchor: Ask)
         double buy_price = NormalizeDouble(current_ask + dist_from_edge, m_digits);

         // Short Below Price -> Sell Stop (Anchor: Bid)
         double sell_price = NormalizeDouble(current_bid - dist_from_edge, m_digits);

         // Double Check Logic (Validate against StopsLevel)
         // Buy Stop must be > Ask + StopsLevel
         if (buy_price < current_ask + min_safety) buy_price = current_ask + min_safety + (i*m_point);

         // Sell Stop must be < Bid - StopsLevel
         if (sell_price > current_bid - min_safety) sell_price = current_bid - min_safety - (i*m_point);

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (m_trade.BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) {
            PrintFormat("   ✅ Buy Stop L%d @ %.5f (Gap: %.1f pts)", i, buy_price, (buy_price-current_ask)/m_point);
         } else {
            PrintFormat("   ❌ Buy Stop L%d Failed: %d", i, GetLastError());
         }

         if (m_trade.SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) {
            PrintFormat("   ✅ Sell Stop L%d @ %.5f (Gap: %.1f pts)", i, sell_price, (current_bid-sell_price)/m_point);
         } else {
             PrintFormat("   ❌ Sell Stop L%d Failed: %d", i, GetLastError());
         }
      }
   }

   //+------------------------------------------------------------------+
   //| CloseAll                                                         |
   //| Rapidly closes all positions and deletes pending orders.         |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       if (CheckPointer(m_trade) == POINTER_INVALID) return;

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
       Print("🏳️ CEASE FIRE: All orders/positions cleared.");
   }
};
