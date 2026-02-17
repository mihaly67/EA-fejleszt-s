//+------------------------------------------------------------------+
//|                                              FireControl_v2_21.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.21  |
//|                    (Stealth Engine Integration v1.0)             |
//+------------------------------------------------------------------+
#ifndef FIRECONTROL_V2_21_MQH
#define FIRECONTROL_V2_21_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_16.mqh" // For Enums v2.16
#include "StealthEngine.mqh" // v1.0

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Trap" logic for placing Breakout (Stop) orders.     |
//| v2.14: Instant Entry (Market) + Grid Logic + Directional Attack  |
//| v2.20: Version Bump & Stability Check                            |
//| v2.21: Stealth Engine Integration                                |
//+------------------------------------------------------------------+
class CFireControl
{
private:
   CTrade      *m_trade;
   CSymbolInfo *m_symbol;
   CStealthEngine *m_stealth; // Stealth Engine Pointer
   string      m_symbol_name;
   double      m_point;
   int         m_digits;
   string      m_comment_prefix;
   ulong       m_magic;

public:
   CFireControl() { m_trade = NULL; m_symbol = NULL; m_stealth = NULL; }
   ~CFireControl() {}

   void Init(CTrade *trade_ptr, CSymbolInfo *symbol_ptr, string comment, ulong magic, CStealthEngine *stealth_ptr = NULL)
   {
      m_trade = trade_ptr;
      m_symbol = symbol_ptr;
      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();
      m_comment_prefix = comment;
      m_magic = magic;
      m_stealth = stealth_ptr;
   }

   //+------------------------------------------------------------------+
   //| FireGrid (formerly FireTrap/FireBurst)                           |
   //| Places a grid of orders relative to ASK/BID.                     |
   //| v2.13: Supports Instant Entry (Market) via 'entry_mode'.         |
   //| v2.14: Supports Directional Attack via 'attack_dir'.             |
   //| v2.21: Applies Stealth Delays & Fuzzing if active.               |
   //+------------------------------------------------------------------+
   void FireGrid(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points, ENUM_FIRE_MODE fire_mode, ENUM_ENTRY_MODE entry_mode, ENUM_ATTACK_DIR attack_dir)
   {
      if (layers <= 0) return;

      bool stealth_active = (m_stealth != NULL && m_stealth.IsEnabled());

      // If Stealth is ON, disable Async to ensure human-like delays work sequentially.
      // If Stealth is OFF, enable Async for "Carpet Bombing" speed.
      m_trade.SetAsyncMode(!stealth_active);

      // USE DIRECT TICK DATA for maximum reliability
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol_name, tick)) {
          Print("🔥 CRITICAL: Failed to get tick data for FireGrid.");
          return;
      }

      double real_spread = tick.ask - tick.bid;
      double effective_spread = MathMax(real_spread, min_spread_points * m_point);

      int stops_level = (int)SymbolInfoInteger(m_symbol_name, SYMBOL_TRADE_STOPS_LEVEL);
      double min_safety = stops_level * m_point;
      if (min_safety == 0) min_safety = 10 * m_point; // Absolute minimum fallback

      string mode_str = (fire_mode == FIRE_MODE_STOP) ? "STOP (Breakout)" : "LIMIT (Reversion)";
      string entry_str = (entry_mode == ENTRY_MARKET) ? "MARKET (Instant)" : "PENDING";
      string dir_str = (attack_dir == ATTACK_BOTH) ? "BOTH" : (attack_dir == ATTACK_BUY ? "BUY ONLY" : "SELL ONLY");
      string stealth_str = stealth_active ? " [STEALTH ACTIVE]" : "";

      PrintFormat("🕸️ FIRE GRID%s: %s | %s | %s | Ask=%.5f | Bid=%.5f | EffSpread=%.1f",
                  stealth_str, mode_str, entry_str, dir_str, tick.ask, tick.bid, effective_spread/m_point);

      int pending_start_layer = 1;
      int loop_layers = layers;

      // --- 1. HANDLE INSTANT ENTRY (Level 1) ---
      if (entry_mode == ENTRY_MARKET)
      {
          // Fire Hedge (Buy + Sell) at Market depending on Direction
          string comm = m_comment_prefix + "_L1";

          if (stealth_active) {
              m_stealth.ApplyHumanDelay();
              comm = m_stealth.GetHumanComment(); // Override comment
          }

          // Note: In Async mode, result is not checked immediately.
          if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
              m_trade.Buy(lot_size, m_symbol_name, 0, 0, 0, comm);
              if(stealth_active && attack_dir == ATTACK_BOTH) m_stealth.ApplyHumanDelay(); // Delay between dual entries if both
          }
          if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
              m_trade.Sell(lot_size, m_symbol_name, 0, 0, 0, comm);
          }

          Print("🚀 FIRED MARKET L1 (" + dir_str + ")");

          // Adjust loop for pending orders
          pending_start_layer = 2; // Next layer is L2
          loop_layers = layers - 1; // Remaining layers
      }

      // --- 2. HANDLE PENDING GRID (Remaining Levels) ---
      for (int i = 1; i <= loop_layers; i++)
      {
         // Distance Calculation
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = effective_spread * current_mult;

         // Ensure distance is at least MinSafety (StopsLevel)
         if (dist < min_safety) dist = min_safety + (i * 10 * m_point);

         double buy_price = 0;
         double sell_price = 0;

         // Determine Layer ID (L1, L2...)
         int current_layer_id = (entry_mode == ENTRY_MARKET) ? (i + 1) : i;
         string comm = m_comment_prefix + "_L" + IntegerToString(current_layer_id);

         if (stealth_active) {
             comm = m_stealth.GetHumanComment();
         }

         if (fire_mode == FIRE_MODE_STOP)
         {
             // --- BREAKOUT (STOP) ---
             // Calculate from EDGE (Ask/Bid) outwards
             buy_price = NormalizeDouble(tick.ask + dist, m_digits);
             sell_price = NormalizeDouble(tick.bid - dist, m_digits);

             // Final Validation (Push out if somehow still inside)
             if (buy_price <= tick.ask + min_safety) buy_price = NormalizeDouble(tick.ask + min_safety + (i * m_point), m_digits);
             if (sell_price >= tick.bid - min_safety) sell_price = NormalizeDouble(tick.bid - min_safety - (i * m_point), m_digits);

             // Apply Fuzzy Price if Stealth Active
             if (stealth_active) {
                 buy_price = m_stealth.GetFuzzyPrice(buy_price, m_point);
                 sell_price = m_stealth.GetFuzzyPrice(sell_price, m_point);
                 // Re-Normalize after fuzzing
                 buy_price = NormalizeDouble(buy_price, m_digits);
                 sell_price = NormalizeDouble(sell_price, m_digits);
             }

             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 m_trade.BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             }
             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 m_trade.SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm);
             }
         }
         else
         {
             // --- REVERSION (LIMIT) ---
             // Calculate from EDGE (Bid/Ask) outwards (Reversion means buying below Bid, Selling above Ask)
             buy_price = NormalizeDouble(tick.bid - dist, m_digits);
             sell_price = NormalizeDouble(tick.ask + dist, m_digits);

             // Final Validation
             if (buy_price >= tick.ask - min_safety) buy_price = NormalizeDouble(tick.ask - min_safety - (i * m_point), m_digits);
             if (sell_price <= tick.bid + min_safety) sell_price = NormalizeDouble(tick.bid + min_safety + (i * m_point), m_digits);

             // Apply Fuzzy Price if Stealth Active
             if (stealth_active) {
                 buy_price = m_stealth.GetFuzzyPrice(buy_price, m_point);
                 sell_price = m_stealth.GetFuzzyPrice(sell_price, m_point);
                 // Re-Normalize after fuzzing
                 buy_price = NormalizeDouble(buy_price, m_digits);
                 sell_price = NormalizeDouble(sell_price, m_digits);
             }

             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 m_trade.BuyLimit(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             }
             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 m_trade.SellLimit(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm);
             }
         }
      }

      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| CeaseFire                                                        |
   //| Rapidly closes all positions and deletes pending orders.         |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       // Cease Fire is a Panic Button. Speed is prioritized over Stealth.
       // Async Mode is forced ON.
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
#endif
