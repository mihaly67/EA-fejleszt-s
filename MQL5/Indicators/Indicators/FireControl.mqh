//+------------------------------------------------------------------+
//|                                                  FireControl.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
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

   void Init(CTrade *trade_ptr, CSymbolInfo *symbol_ptr, string comment, ulong magic)
   {
      m_trade = trade_ptr;
      m_symbol = symbol_ptr;
      m_symbol_name = m_symbol->Name(); // Fixed: ->
      m_point = m_symbol->Point();      // Fixed: ->
      m_digits = m_symbol->Digits();    // Fixed: ->
      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireBurst                                                        |
   //| Places a grid of BuyLimit/SellLimit orders around center price.  |
   //+------------------------------------------------------------------+
   void FireBurst(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_dist_points)
   {
      if (layers <= 0) return;

      m_symbol->RefreshRates(); // Fixed: ->
      double spread = m_symbol->Ask() - m_symbol->Bid(); // Fixed: ->
      int stops_level = m_symbol->StopsLevel(); // Fixed: ->

      // Safety: Minimum distance (StopsLevel + SafeZone)
      double min_safety = stops_level * m_point;
      if (min_dist_points * m_point > min_safety) min_safety = min_dist_points * m_point;

      PrintFormat("🔥 FIRE BURST: Center=%.5f, Spread=%.1f pts, Layers=%d", center_price, spread/m_point, layers);

      for (int i = 1; i <= layers; i++)
      {
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = spread * current_mult;

         // ENFORCE SAFETY (The Fix)
         if (dist < min_safety) {
             dist = min_safety + (i*10 * m_point); // Add small step to avoid stacking
         }

         double buy_price = NormalizeDouble(center_price - dist, m_digits);
         double sell_price = NormalizeDouble(center_price + dist, m_digits);

         // Double Check Logic (Validate against current Ask/Bid)
         // BuyLimit must be below Ask - StopsLevel
         if (buy_price > m_symbol->Ask() - min_safety) buy_price = m_symbol->Ask() - min_safety - (i*m_point); // Fixed: ->

         // SellLimit must be above Bid + StopsLevel
         if (sell_price < m_symbol->Bid() + min_safety) sell_price = m_symbol->Bid() + min_safety + (i*m_point); // Fixed: ->

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (m_trade->BuyLimit(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) { // Fixed: ->
            PrintFormat("   ✅ Buy Limit L%d @ %.5f (Dist: %.1f pts)", i, buy_price, (center_price-buy_price)/m_point);
         } else {
            PrintFormat("   ❌ Buy Limit L%d Failed: %d", i, GetLastError());
         }

         if (m_trade->SellLimit(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) { // Fixed: ->
            PrintFormat("   ✅ Sell Limit L%d @ %.5f (Dist: %.1f pts)", i, sell_price, (sell_price-center_price)/m_point);
         } else {
             PrintFormat("   ❌ Sell Limit L%d Failed: %d", i, GetLastError());
         }
      }
   }

   //+------------------------------------------------------------------+
   //| CloseAll                                                         |
   //| Rapidly closes all positions and deletes pending orders.         |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       // 1. Delete Pending
       for (int i = OrdersTotal() - 1; i >= 0; i--) {
           ulong ticket = OrderGetTicket(i);
           if (OrderSelect(ticket)) {
               if (OrderGetString(ORDER_SYMBOL) == m_symbol_name && OrderGetInteger(ORDER_MAGIC) == m_magic) {
                   m_trade->OrderDelete(ticket); // Fixed: ->
               }
           }
       }

       // 2. Close Positions
       for (int i = PositionsTotal() - 1; i >= 0; i--) {
           ulong ticket = PositionGetTicket(i);
           if (PositionSelectByTicket(ticket)) {
               if (PositionGetString(POSITION_SYMBOL) == m_symbol_name && PositionGetInteger(POSITION_MAGIC) == m_magic) {
                   m_trade->PositionClose(ticket); // Fixed: ->
               }
           }
       }
       Print("🏳️ CEASE FIRE: All orders/positions cleared.");
   }
};
