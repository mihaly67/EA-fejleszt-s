//+------------------------------------------------------------------+
//|                                              FireControl_v2_14.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.14  |
//+------------------------------------------------------------------+
#ifndef FIRECONTROL_V2_14_MQH
#define FIRECONTROL_V2_14_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_14.mqh" // For Enums

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Trap" logic for placing Breakout (Stop) orders.     |
//| v2.14: Instant Entry + Directional Attack (Buy/Sell)             |
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
      // Reverted to dot syntax (.) as MQL5 pointers to objects often use dot
      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();
      m_comment_prefix = comment;
      m_magic = magic;
   }

   //+------------------------------------------------------------------+
   //| FireGrid                                                         |
   //| Places a grid of orders relative to ASK/BID.                     |
   //| v2.14: Supports Directional Attack (Buy/Sell/Both) + Solo Mode.  |
   //+------------------------------------------------------------------+
   void FireGrid(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points,
                 ENUM_FIRE_MODE fire_mode, ENUM_ENTRY_MODE entry_mode, ENUM_ATTACK_DIR attack_dir, ENUM_ACTION_TYPE action_type)
   {
      if (layers <= 0 && action_type == ACTION_COMBO) return; // Allow 0 layers if Solo

      // Enable Async Mode for "Carpet Bombing" speed
      m_trade.SetAsyncMode(true);

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
      string dir_str = (attack_dir == ATTACK_BUY) ? "BUY ONLY" : (attack_dir == ATTACK_SELL) ? "SELL ONLY" : "BOTH (Trap)";
      string act_str = (action_type == ACTION_SOLO) ? "SOLO (Single Shot)" : "COMBO (Burst+Grid)";

      PrintFormat("🕸️ FIRE GRID (ASYNC): %s | %s | %s | %s | Ask=%.5f | Bid=%.5f",
                  mode_str, entry_str, dir_str, act_str, tick.ask, tick.bid);

      int pending_start_layer = 1;
      int loop_layers = (action_type == ACTION_SOLO) ? 0 : layers; // Skip pending loop if Solo

      // --- 1. HANDLE INSTANT ENTRY (Level 1) ---
      if (entry_mode == ENTRY_MARKET)
      {
          string comm = m_comment_prefix + "_L1";

          // Fire BUY if direction is BOTH or BUY
          if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
              m_trade.Buy(lot_size, m_symbol_name, 0, 0, 0, comm);
              Print("🚀 FIRED MARKET BUY L1");
          }

          // Fire SELL if direction is BOTH or SELL
          if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
              m_trade.Sell(lot_size, m_symbol_name, 0, 0, 0, comm);
              Print("🚀 FIRED MARKET SELL L1");
          }

          // Adjust loop for pending orders
          pending_start_layer = 2; // Next layer is L2
          if(action_type == ACTION_COMBO) loop_layers = layers - 1; // Decrease pending count
      }

      // --- 2. HANDLE PENDING GRID (Remaining Levels) ---
      // If Action is SOLO, loop_layers is 0, so this is skipped.
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

         if (fire_mode == FIRE_MODE_STOP)
         {
             // --- BREAKOUT (STOP) ---
             // BUY logic (Ask + Dist)
             if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 buy_price = NormalizeDouble(tick.ask + dist, m_digits);
                 if (buy_price <= tick.ask + min_safety) buy_price = NormalizeDouble(tick.ask + min_safety + (i * m_point), m_digits);
                 m_trade.BuyStop(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             }

             // SELL logic (Bid - Dist)
             if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 sell_price = NormalizeDouble(tick.bid - dist, m_digits);
                 if (sell_price >= tick.bid - min_safety) sell_price = NormalizeDouble(tick.bid - min_safety - (i * m_point), m_digits);
                 m_trade.SellStop(lot_size, sell_price, m_symbol_name, 0, 0, 0, 0, comm);
             }
         }
         else
         {
             // --- REVERSION (LIMIT) ---
             // BUY logic (Bid - Dist)
             if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 buy_price = NormalizeDouble(tick.bid - dist, m_digits);
                 if (buy_price >= tick.ask - min_safety) buy_price = NormalizeDouble(tick.ask - min_safety - (i * m_point), m_digits);
                 m_trade.BuyLimit(lot_size, buy_price, m_symbol_name, 0, 0, 0, 0, comm);
             }

             // SELL logic (Ask + Dist)
             if(attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 sell_price = NormalizeDouble(tick.ask + dist, m_digits);
                 if (sell_price <= tick.bid + min_safety) sell_price = NormalizeDouble(tick.bid + min_safety + (i * m_point), m_digits);
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
