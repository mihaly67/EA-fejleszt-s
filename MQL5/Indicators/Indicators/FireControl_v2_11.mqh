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
   //| Uses Adaptive Spread Logic: EffectiveSpread = Max(Spread, Min)   |
   //+------------------------------------------------------------------+
   void FireGrid(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points, ENUM_FIRE_MODE mode)
   {
      if (layers <= 0) return;

      m_symbol.RefreshRates();
      double real_spread = m_symbol.Ask() - m_symbol.Bid();

      // v2.11: Adaptive Spread Logic (Same as v2.10)
      double effective_spread = MathMax(real_spread, min_spread_points * m_point);

      // Safety Checks (Broker Constraints)
      int stops_level = m_symbol.StopsLevel();
      double min_safety = stops_level * m_point;
      if (min_safety == 0) min_safety = 10 * m_point; // Fallback

      string mode_str = (mode == FIRE_MODE_STOP) ? "STOP (Breakout)" : "LIMIT (Reversion)";
      PrintFormat("🕸️ SET TRAP (v2.11 - %s): Center=%.5f, EffSpread=%.1f pts, Layers=%d",
                  mode_str, center_price, effective_spread/m_point, layers);

      for (int i = 1; i <= layers; i++)
      {
         // Calculate Distance
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = effective_spread * current_mult;

         // Safety Override
         if (dist < min_safety) {
             dist = min_safety + (i * 10 * m_point);
             PrintFormat("   ⚠️ L%d Adjusted to Safety Min: %.1f pts", i, dist/m_point);
         }

         double buy_price = 0;
         double sell_price = 0;
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (mode == FIRE_MODE_STOP)
         {
             // --- BREAKOUT LOGIC (STOP ORDERS) ---
             // Buy Stop is placed ABOVE the Ask price (Breakout Up)
             // Sell Stop is placed BELOW the Bid price (Breakout Down)
             buy_price = NormalizeDouble(center_price + dist, m_digits); // PLUS distance
             sell_price = NormalizeDouble(center_price - dist, m_digits); // MINUS distance

             // Validation (Must be valid Stop prices)
             if (buy_price < m_symbol.Ask() + min_safety) {
                 buy_price = m_symbol.Ask() + min_safety + (i * m_point);
             }
             if (sell_price > m_symbol.Bid() - min_safety) {
                 sell_price = m_symbol.Bid() - min_safety - (i * m_point);
             }

             // Place STOP Orders
             if (m_trade.BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) {
                PrintFormat("   ✅ Buy Stop L%d @ %.5f (Dist: %.1f pts)", i, buy_price, (buy_price-center_price)/m_point);
             } else {
                PrintFormat("   ❌ Buy Stop L%d Failed: %d", i, GetLastError());
             }

             if (m_trade.SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) {
                 PrintFormat("   ✅ Sell Stop L%d @ %.5f (Dist: %.1f pts)", i, sell_price, (center_price-sell_price)/m_point);
             } else {
                 PrintFormat("   ❌ Sell Stop L%d Failed: %d", i, GetLastError());
             }
         }
         else
         {
             // --- REVERSION LOGIC (LIMIT ORDERS) ---
             // Buy Limit is placed BELOW the Ask price (Reversion Up/Trap)
             // Sell Limit is placed ABOVE the Bid price (Reversion Down/Trap)
             buy_price = NormalizeDouble(center_price - dist, m_digits); // MINUS distance
             sell_price = NormalizeDouble(center_price + dist, m_digits); // PLUS distance

             // Validation (Must be valid Limit prices)
             if (buy_price > m_symbol.Ask() - min_safety) {
                 buy_price = m_symbol.Ask() - min_safety - (i * m_point);
             }
             if (sell_price < m_symbol.Bid() + min_safety) {
                 sell_price = m_symbol.Bid() + min_safety + (i * m_point);
             }

             // Place LIMIT Orders
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
