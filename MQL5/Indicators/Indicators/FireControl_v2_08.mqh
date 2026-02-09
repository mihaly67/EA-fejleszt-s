//+------------------------------------------------------------------+
//|                                                  FireControl.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.08  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Burst" logic for placing Grid/Trap orders.          |
//| v2.08: Barbed Wire Trap Logic (Stop Orders / Breakout)           |
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
      m_symbol_name = m_symbol->Name();
      m_point = m_symbol->Point();
      m_digits = m_symbol->Digits();
      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireBurst                                                        |
   //| Places a symmetric TRAP grid (BuyStop above, SellStop below).    |
   //| Logic: "Barbed Wire" - Breakout Trap                             |
   //+------------------------------------------------------------------+
   void FireBurst(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points)
   {
      if (layers <= 0) return;

      m_symbol->RefreshRates();
      double raw_spread = m_symbol->Ask() - m_symbol->Bid();
      int stops_level = m_symbol->StopsLevel();

      // Adaptive Spread Logic: Use larger of Market Spread or User Min Spread (e.g. 60 pts)
      double effective_spread = raw_spread;
      double min_spread_val = min_spread_points * m_point;

      if (effective_spread < min_spread_val) {
          effective_spread = min_spread_val;
          PrintFormat("⚠️ FireControl: Low Spread (%.1f pts) -> Using MinSpread (%.1f pts)", raw_spread/m_point, min_spread_points);
      } else {
          PrintFormat("✅ FireControl: Using Market Spread (%.1f pts)", effective_spread/m_point);
      }

      // Safety: Minimum distance (StopsLevel + small buffer)
      double min_safety = (stops_level + 5) * m_point; // Extra buffer for Stop orders

      PrintFormat("🔥 FIRE BURST (v2.08 Trap): Layers=%d, BaseSpread=%.1f pts", layers, effective_spread/m_point);

      // Tracking prices for cumulative steps
      double prev_buy_price = m_symbol->Ask();
      double prev_sell_price = m_symbol->Bid();

      for (int i = 1; i <= layers; i++)
      {
         double dist = 0;

         if (i == 1) {
             // Layer 1: Distance from CURRENT PRICE
             dist = effective_spread * spread_mult_start;
         } else {
             // Layer 2+: Distance from PREVIOUS LAYER
             dist = effective_spread * spread_mult_step;
         }

         // Enforce Safety per step
         if (dist < min_safety) dist = min_safety;

         // Calculate Order Prices
         // Buy Stop: Go HIGHER
         double buy_price = NormalizeDouble(prev_buy_price + dist, m_digits);

         // Sell Stop: Go LOWER
         double sell_price = NormalizeDouble(prev_sell_price - dist, m_digits);

         // Update tracking for next layer
         prev_buy_price = buy_price;
         prev_sell_price = sell_price;

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         // BUY STOP (Breakout Up)
         if (m_trade->BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) {
            PrintFormat("   ✅ Buy Stop L%d @ %.5f (Gap: %.1f pts)", i, buy_price, dist/m_point);
         } else {
            PrintFormat("   ❌ Buy Stop L%d Failed: %d", i, GetLastError());
         }

         // SELL STOP (Breakout Down)
         if (m_trade->SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) {
             PrintFormat("   ✅ Sell Stop L%d @ %.5f (Gap: %.1f pts)", i, sell_price, dist/m_point);
         } else {
             PrintFormat("   ❌ Sell Stop L%d Failed: %d", i, GetLastError());
         }
      }
   }

   //+------------------------------------------------------------------+
   //| CeaseFire                                                        |
   //| Rapidly closes all positions and deletes pending orders.         |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       // 1. Delete Pending
       for (int i = OrdersTotal() - 1; i >= 0; i--) {
           ulong ticket = OrderGetTicket(i);
           if (OrderSelect(ticket)) {
               if (OrderGetString(ORDER_SYMBOL) == m_symbol_name && OrderGetInteger(ORDER_MAGIC) == m_magic) {
                   m_trade->OrderDelete(ticket);
               }
           }
       }

       // 2. Close Positions
       for (int i = PositionsTotal() - 1; i >= 0; i--) {
           ulong ticket = PositionGetTicket(i);
           if (PositionSelectByTicket(ticket)) {
               if (PositionGetString(POSITION_SYMBOL) == m_symbol_name && PositionGetInteger(POSITION_MAGIC) == m_magic) {
                   m_trade->PositionClose(ticket);
               }
           }
       }
       Print("🏳️ CEASE FIRE: All orders/positions cleared.");
   }
};
