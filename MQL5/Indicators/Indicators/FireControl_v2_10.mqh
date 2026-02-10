//+------------------------------------------------------------------+
//|                                                  FireControl.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.10  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Burst" logic for placing Grid/Trap orders.          |
//| v2.10: Implements Adaptive Spread Logic for Low-Spread Assets    |
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
   //| FireBurst                                                        |
   //| Places a grid of BuyLimit/SellLimit orders around center price.  |
   //| Uses Adaptive Spread Logic: EffectiveSpread = Max(Spread, Min)   |
   //+------------------------------------------------------------------+
   void FireBurst(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points)
   {
      if (layers <= 0) return;

      m_symbol.RefreshRates();
      double real_spread = m_symbol.Ask() - m_symbol.Bid();

      // v2.10: Adaptive Spread Calculation
      // If market spread is too low (e.g., Gold), use the manual minimum.
      double effective_spread = MathMax(real_spread, min_spread_points * m_point);

      // Standard Safety Checks
      int stops_level = m_symbol.StopsLevel();
      double min_safety = stops_level * m_point;

      // Ensure we respect the broker's StopsLevel absolutely
      if (min_safety == 0) min_safety = 10 * m_point; // Fallback if StopsLevel is 0

      PrintFormat("🔥 FIRE BURST (v2.10): Center=%.5f, RealSpread=%.1f, EffSpread=%.1f, Layers=%d",
                  center_price, real_spread/m_point, effective_spread/m_point, layers);

      for (int i = 1; i <= layers; i++)
      {
         // Calculate Distance based on Adaptive Spread
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = effective_spread * current_mult;

         // Final Safety Override (should rarely trigger if MinSpread is healthy)
         if (dist < min_safety) {
             dist = min_safety + (i * 10 * m_point);
             PrintFormat("   ⚠️ L%d Adjusted to Safety Min: %.1f pts", i, dist/m_point);
         }

         double buy_price = NormalizeDouble(center_price - dist, m_digits);
         double sell_price = NormalizeDouble(center_price + dist, m_digits);

         // Double Check Logic (Validate against current Ask/Bid to prevent "Invalid Price" errors)
         // BuyLimit must be below Ask - StopsLevel
         if (buy_price > m_symbol.Ask() - min_safety) {
             buy_price = m_symbol.Ask() - min_safety - (i * m_point);
             PrintFormat("   ⚠️ L%d BuyPrice Adjusted to Market Structure", i);
         }

         // SellLimit must be above Bid + StopsLevel
         if (sell_price < m_symbol.Bid() + min_safety) {
             sell_price = m_symbol.Bid() + min_safety + (i * m_point);
             PrintFormat("   ⚠️ L%d SellPrice Adjusted to Market Structure", i);
         }

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (m_trade.BuyLimit(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) {
            PrintFormat("   ✅ Buy Limit L%d @ %.5f (Dist: %.1f pts)", i, buy_price, (center_price-buy_price)/m_point);
         } else {
            PrintFormat("   ❌ Buy Limit L%d Failed: %d", i, GetLastError());
         }

         if (m_trade.SellLimit(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) {
             PrintFormat("   ✅ Sell Limit L%d @ %.5f (Dist: %.1f pts)", i, sell_price, (sell_price-center_price)/m_point);
         } else {
             PrintFormat("   ❌ Sell Limit L%d Failed: %d", i, GetLastError());
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
