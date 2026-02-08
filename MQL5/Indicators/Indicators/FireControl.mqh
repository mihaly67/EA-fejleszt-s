//+------------------------------------------------------------------+
//|                                                  FireControl.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                      STABLE BASE - NO STEALTH    |
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
      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();
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

      m_symbol->RefreshRates();
      double spread = m_symbol->Ask() - m_symbol->Bid();
      int stops_level = m_symbol->StopsLevel();

      // Safety: Minimum distance (StopsLevel + SafeZone)
      double min_safety = stops_level * m_point;
      if (min_dist_points * m_point > min_safety) min_safety = min_dist_points * m_point;

      PrintFormat("🔥 FIRE BURST: Center=%.5f, Spread=%.1f pts, Layers=%d", center_price, spread/m_point, layers);

      double buy_start_mult = spread_mult_start;
      double sell_start_mult = spread_mult_start;
      double buy_step = spread_mult_step;
      double sell_step = spread_mult_step;

      for (int i = 1; i <= layers; i++)
      {
         // Distinct Distance Calculations
         double buy_mult = buy_start_mult + (i - 1) * buy_step;
         double sell_mult = sell_start_mult + (i - 1) * sell_step;

         double dist_buy = spread * buy_mult;
         double dist_sell = spread * sell_mult;

         // ENFORCE SAFETY
         if (dist_buy < min_safety) dist_buy = min_safety + (i*10 * m_point);
         if (dist_sell < min_safety) dist_sell = min_safety + (i*10 * m_point);

         double buy_price = NormalizeDouble(center_price - dist_buy, m_digits);
         double sell_price = NormalizeDouble(center_price + dist_sell, m_digits);

         // Double Check Logic (Validate against current Ask/Bid)
         if (buy_price > m_symbol->Ask() - min_safety) buy_price = m_symbol->Ask() - min_safety - (i*m_point);
         if (sell_price < m_symbol->Bid() + min_safety) sell_price = m_symbol->Bid() + min_safety + (i*m_point);

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         ENUM_ORDER_TYPE_TIME type_time = ORDER_TIME_GTC;
         datetime expiration = 0;

         // Execute Buy Limit
         if (m_trade->OrderOpen(m_symbol_name, ORDER_TYPE_BUY_LIMIT, lot_size, 0.0, buy_price, 0, 0, type_time, expiration, comm)) {
            PrintFormat("   ✅ Buy Limit L%d @ %.5f", i, buy_price);
         } else {
            PrintFormat("   ❌ Buy Limit L%d Failed: %d", i, GetLastError());
         }

         // Execute Sell Limit
         if (m_trade->OrderOpen(m_symbol_name, ORDER_TYPE_SELL_LIMIT, lot_size, 0.0, sell_price, 0, 0, type_time, expiration, comm)) {
             PrintFormat("   ✅ Sell Limit L%d @ %.5f", i, sell_price);
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
