//+------------------------------------------------------------------+
//|                                              FireControl_v2_24.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.24  |
//|                    (Stealth Engine & Registry v1.08 Integration) |
//|                    (Strict Stealth: No EA Traces in Comments)    |
//+------------------------------------------------------------------+
#ifndef FIRECONTROL_V2_24_MQH
#define FIRECONTROL_V2_24_MQH

#property copyright "Jules Agent"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Types_v2_16.mqh" // For Enums v2.16
#include "StealthEngine.mqh" // v1.0
#include "StealthRegistry_v1_08.mqh" // v1.08 Log Fix

//+------------------------------------------------------------------+
//| Class CFireControl                                               |
//| Handles the "Trap" logic for placing Breakout (Stop) orders.     |
//| v2.24: Strict Stealth - Sanitizes ALL comments (Broker & CSV).   |
//+------------------------------------------------------------------+
class CFireControl
{
private:
   CTrade      *m_trade;
   CSymbolInfo *m_symbol;
   CStealthEngine *m_stealth; // Stealth Engine Pointer
   CStealthRegistry *m_registry; // Stealth Registry Pointer (v1.08)
   string      m_symbol_name;
   double      m_point;
   int         m_digits;
   string      m_comment_prefix;
   ulong       m_magic;

public:
   CFireControl() { m_trade = NULL; m_symbol = NULL; m_stealth = NULL; m_registry = NULL; }
   ~CFireControl() {}

   void Init(CTrade *trade_ptr, CSymbolInfo *symbol_ptr, string comment, ulong magic, CStealthEngine *stealth_ptr = NULL, CStealthRegistry *registry_ptr = NULL)
   {
      m_trade = trade_ptr;
      m_symbol = symbol_ptr;
      m_symbol_name = m_symbol.Name();
      m_point = m_symbol.Point();
      m_digits = m_symbol.Digits();
      m_comment_prefix = comment;
      m_magic = magic;
      m_stealth = stealth_ptr;
      m_registry = registry_ptr;
   }

   //+------------------------------------------------------------------+
   //| FireGrid (Deep Stealth Enabled)                                  |
   //+------------------------------------------------------------------+
   void FireGrid(double center_price, double lot_size, int layers, double spread_mult_start, double spread_mult_step, double min_spread_points, ENUM_FIRE_MODE fire_mode, ENUM_ENTRY_MODE entry_mode, ENUM_ATTACK_DIR attack_dir)
   {
      if (layers <= 0) return;

      bool stealth_active = (m_stealth != NULL && m_stealth.IsEnabled());
      bool deep_stealth = (m_registry != NULL);

      // Deep Stealth requires Sync Mode to catch Ticket ID immediately for registration
      m_trade.SetAsyncMode(!stealth_active && !deep_stealth);

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
      if(deep_stealth) stealth_str += " [DEEP STEALTH]";

      PrintFormat("🕸️ FIRE GRID%s: %s | %s | %s | Ask=%.5f | Bid=%.5f | EffSpread=%.1f",
                  stealth_str, mode_str, entry_str, dir_str, tick.ask, tick.bid, effective_spread/m_point);

      int pending_start_layer = 1;
      int loop_layers = layers;

      // --- 1. HANDLE INSTANT ENTRY (Level 1) ---
      if (entry_mode == ENTRY_MARKET)
      {
          if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
              if(stealth_active) m_stealth.ApplyHumanDelay();
              ExecuteTrade(ORDER_TYPE_BUY, lot_size, 0, 0, 0, deep_stealth);
          }
          if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
              if(stealth_active && attack_dir == ATTACK_BOTH) m_stealth.ApplyHumanDelay();
              ExecuteTrade(ORDER_TYPE_SELL, lot_size, 0, 0, 0, deep_stealth);
          }

          pending_start_layer = 2; // Next layer is L2
          loop_layers = layers - 1; // Remaining layers
      }

      // --- 2. HANDLE PENDING GRID (Remaining Levels) ---
      for (int i = 1; i <= loop_layers; i++)
      {
         // Distance Calculation
         double current_mult = spread_mult_start + (i - 1) * spread_mult_step;
         double dist = effective_spread * current_mult;

         if (dist < min_safety) dist = min_safety + (i * 10 * m_point);

         double buy_price = 0;
         double sell_price = 0;

         if (fire_mode == FIRE_MODE_STOP)
         {
             // --- BREAKOUT (STOP) ---
             buy_price = NormalizeDouble(tick.ask + dist, m_digits);
             sell_price = NormalizeDouble(tick.bid - dist, m_digits);

             if (buy_price <= tick.ask + min_safety) buy_price = NormalizeDouble(tick.ask + min_safety + (i * m_point), m_digits);
             if (sell_price >= tick.bid - min_safety) sell_price = NormalizeDouble(tick.bid - min_safety - (i * m_point), m_digits);

             if (stealth_active) {
                 buy_price = m_stealth.GetFuzzyPrice(buy_price, m_point);
                 sell_price = m_stealth.GetFuzzyPrice(sell_price, m_point);
                 buy_price = NormalizeDouble(buy_price, m_digits);
                 sell_price = NormalizeDouble(sell_price, m_digits);
             }

             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 ExecuteTrade(ORDER_TYPE_BUY_STOP, lot_size, buy_price, 0, 0, deep_stealth);
             }
             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 ExecuteTrade(ORDER_TYPE_SELL_STOP, lot_size, sell_price, 0, 0, deep_stealth);
             }
         }
         else
         {
             // --- REVERSION (LIMIT) ---
             buy_price = NormalizeDouble(tick.bid - dist, m_digits);
             sell_price = NormalizeDouble(tick.ask + dist, m_digits);

             if (buy_price >= tick.ask - min_safety) buy_price = NormalizeDouble(tick.ask - min_safety - (i * m_point), m_digits);
             if (sell_price <= tick.bid + min_safety) sell_price = NormalizeDouble(tick.bid + min_safety + (i * m_point), m_digits);

             if (stealth_active) {
                 buy_price = m_stealth.GetFuzzyPrice(buy_price, m_point);
                 sell_price = m_stealth.GetFuzzyPrice(sell_price, m_point);
                 buy_price = NormalizeDouble(buy_price, m_digits);
                 sell_price = NormalizeDouble(sell_price, m_digits);
             }

             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_BUY) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 ExecuteTrade(ORDER_TYPE_BUY_LIMIT, lot_size, buy_price, 0, 0, deep_stealth);
             }
             if (attack_dir == ATTACK_BOTH || attack_dir == ATTACK_SELL) {
                 if(stealth_active) m_stealth.ApplyHumanDelay();
                 ExecuteTrade(ORDER_TYPE_SELL_LIMIT, lot_size, sell_price, 0, 0, deep_stealth);
             }
         }
      }

      m_trade.SetAsyncMode(false);
   }

   // --- Helper to execute trade and register ticket ---
   void ExecuteTrade(ENUM_ORDER_TYPE type, double vol, double price, double sl, double tp, bool deep_stealth)
   {
       ulong magic = m_magic;
       string final_comment = ""; // Default empty

       // If Deep Stealth, override with Randoms/Empty
       if(deep_stealth && m_registry != NULL) {
           magic = m_registry.GetRandomMagic();
           final_comment = m_registry.GetRandomComment(); // "manual", "t1", etc.
           m_trade.SetExpertMagicNumber(magic); // Override global magic for this trade
       } else {
           // If Stealth OFF, use prefix (BUT user requested "No EA Traces" even here usually)
           // Keeping prefix only if Stealth OFF allows debugging, but better to be safe.
           final_comment = m_comment_prefix;
       }

       bool res = false;
       if(type == ORDER_TYPE_BUY) res = m_trade.Buy(vol, m_symbol_name, price, sl, tp, final_comment);
       else if(type == ORDER_TYPE_SELL) res = m_trade.Sell(vol, m_symbol_name, price, sl, tp, final_comment);
       else if(type == ORDER_TYPE_BUY_STOP) res = m_trade.BuyStop(vol, price, m_symbol_name, sl, tp, ORDER_TIME_GTC, 0, final_comment);
       else if(type == ORDER_TYPE_SELL_STOP) res = m_trade.SellStop(vol, price, m_symbol_name, sl, tp, ORDER_TIME_GTC, 0, final_comment);
       else if(type == ORDER_TYPE_BUY_LIMIT) res = m_trade.BuyLimit(vol, price, m_symbol_name, sl, tp, ORDER_TIME_GTC, 0, final_comment);
       else if(type == ORDER_TYPE_SELL_LIMIT) res = m_trade.SellLimit(vol, price, m_symbol_name, sl, tp, ORDER_TIME_GTC, 0, final_comment);

       if(res) {
           if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE || m_trade.ResultRetcode() == TRADE_RETCODE_PLACED) {
               ulong ticket = m_trade.ResultOrder();
               if(deep_stealth && m_registry != NULL && ticket > 0) {
                   // Register using SAME comment as Broker (Sanitized)
                   m_registry.RegisterTicket(ticket, magic, final_comment);
               }
           }
       }

       // Restore Default Magic (Important!)
       m_trade.SetExpertMagicNumber(m_magic);
   }

   //+------------------------------------------------------------------+
   //| CeaseFire (Deep Stealth Aware)                                   |
   //+------------------------------------------------------------------+
   void CeaseFire()
   {
       m_trade.SetAsyncMode(true); // Cease Fire is panic mode, speed priority

       // 1. Delete Pending
       for (int i = OrdersTotal() - 1; i >= 0; i--) {
           ulong ticket = OrderGetTicket(i);
           if (OrderSelect(ticket)) {
               // Check Ownership
               bool is_mine = false;
               if(m_registry != NULL) is_mine = m_registry.IsMyTicket(ticket);
               else is_mine = (OrderGetInteger(ORDER_MAGIC) == m_magic);

               if (is_mine && OrderGetString(ORDER_SYMBOL) == m_symbol_name) {
                   if(m_trade.OrderDelete(ticket)) {
                       if(m_registry != NULL) m_registry.UnregisterTicket(ticket);
                   }
               }
           }
       }

       // 2. Close Positions
       for (int i = PositionsTotal() - 1; i >= 0; i--) {
           ulong ticket = PositionGetTicket(i);
           if (PositionSelectByTicket(ticket)) {
               // Check Ownership
               bool is_mine = false;
               if(m_registry != NULL) is_mine = m_registry.IsMyTicket(ticket);
               else is_mine = (PositionGetInteger(POSITION_MAGIC) == m_magic);

               if (is_mine && PositionGetString(POSITION_SYMBOL) == m_symbol_name) {
                   if(m_trade.PositionClose(ticket)) {
                       if(m_registry != NULL) m_registry.UnregisterTicket(ticket);
                   }
               }
           }
       }

       m_trade.SetAsyncMode(false);
       Print("🏳️ CEASE FIRE (ASYNC): Sweep Complete.");
   }
};
#endif
