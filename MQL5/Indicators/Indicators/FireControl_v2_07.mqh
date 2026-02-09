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

      // Use Arrow Operator for Pointers in MQL5!
      m_symbol_name = m_symbol->Name();
      m_point = m_symbol->Point();
      m_digits = m_symbol->Digits();

      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireBurst                                                        |
   //| Places a grid of BuyStop/SellStop orders (Breakout/BarbedWire).  |
   //| FIX v2.07: Adaptive Spacing (Min Spread Protection)              |
   //+------------------------------------------------------------------+
   void FireBurst(double center_price_unused, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_dist_points, int min_spread_limit)
   {
      if (layers <= 0) return;
      if (CheckPointer(m_symbol) == POINTER_INVALID || CheckPointer(m_trade) == POINTER_INVALID) return;

      m_symbol->RefreshRates();

      double current_bid = m_symbol->Bid();
      double current_ask = m_symbol->Ask();
      double raw_spread = current_ask - current_bid;

      // FIX v2.07: Adaptive Base Unit
      // Use the larger of Actual Spread OR Minimum Fixed Spread (e.g. 60 points)
      double min_base_spread = (double)min_spread_limit * m_point;
      double effective_spread = MathMax(raw_spread, min_base_spread);

      // Safety check for StopsLevel (Broker Requirement)
      int stops_level = m_symbol->StopsLevel();
      double min_safety = (double)stops_level * m_point;

      PrintFormat("🔥 FIRE BURST (Adapt): BaseSpread=%.1f pts (Raw=%.1f), Layers=%d", effective_spread/m_point, raw_spread/m_point, layers);

      for (int i = 1; i <= layers; i++)
      {
         // GEOMETRIC SPACING LOGIC
         // Formula: EffectiveSpread * (Start + (i-1)*Step)

         double multiplier = spread_mult_start + ((double)(i - 1) * spread_mult_step);
         double dist_from_edge = effective_spread * multiplier;

         // Ensure distance is valid (outside StopsLevel)
         if (dist_from_edge < min_safety) dist_from_edge = min_safety + (i * 2.0 * m_point);

         // Barbed Wire Breakout Logic:
         // Buy Stop: Ask + Dist
         double buy_price = NormalizeDouble(current_ask + dist_from_edge, m_digits);

         // Sell Stop: Bid - Dist
         double sell_price = NormalizeDouble(current_bid - dist_from_edge, m_digits);

         // Place Orders
         string comm = m_comment_prefix + "_L" + IntegerToString(i);

         if (m_trade->BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm)) {
            PrintFormat("   ✅ Buy Stop L%d @ %.5f (Gap: %.1f pts)", i, buy_price, (buy_price-current_ask)/m_point);
         } else {
            PrintFormat("   ❌ Buy Stop L%d Failed: %d", i, GetLastError());
         }

         if (m_trade->SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm)) {
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
