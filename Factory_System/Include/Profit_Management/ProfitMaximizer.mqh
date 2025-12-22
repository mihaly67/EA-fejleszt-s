//+------------------------------------------------------------------+
//|                                              ProfitMaximizer.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include "TickVolatility.mqh"

//+------------------------------------------------------------------+
//| Class: Profit Maximizer (Trailing TP & MAE Exit)                 |
//+------------------------------------------------------------------+
class CProfitMaximizer
  {
private:
   CTrade            m_trade;
   CTickVolatility  *m_tick_vol;

   // State
   double            m_peak_profit;       // Highest profit reached (points)
   bool              m_is_free_running;   // Is TP actively being pushed?

   // Parameters
   double            m_expansion_factor;  // e.g. 1.5 * Volatility
   double            m_mae_limit_factor;  // e.g. 2.0 * Volatility (Pullback limit)

public:
                     CProfitMaximizer(void);
                    ~CProfitMaximizer(void);

   void              Init(CTickVolatility *tick_vol);

   // Main Logic
   void              ManagePosition(ulong ticket, double current_price);

private:
   bool              CheckMAE(double current_profit_points, double tick_sd);
   void              ExpandTakeProfit(ulong ticket, ENUM_POSITION_TYPE type, double current_price, double tick_sd);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CProfitMaximizer::CProfitMaximizer(void) : m_tick_vol(NULL),
                                           m_peak_profit(0.0),
                                           m_is_free_running(false),
                                           m_expansion_factor(1.5),
                                           m_mae_limit_factor(2.0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CProfitMaximizer::~CProfitMaximizer(void)
  {
  }
//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CProfitMaximizer::Init(CTickVolatility *tick_vol)
  {
   m_tick_vol = tick_vol;
  }
//+------------------------------------------------------------------+
//| Manage Position                                                  |
//+------------------------------------------------------------------+
void CProfitMaximizer::ManagePosition(ulong ticket, double current_price)
  {
   if(!PositionSelectByTicket(ticket)) return;

   // Calculate Metrics
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   long type = PositionGetInteger(POSITION_TYPE);
   double profit_points = 0.0;

   if(type == POSITION_TYPE_BUY)
      profit_points = (current_price - open_price);
   else
      profit_points = (open_price - current_price);

   // Update Peak
   if(profit_points > m_peak_profit) m_peak_profit = profit_points;

   // Get Volatility
   // FIX: Use arrow operator for pointer access
   double tick_sd = (m_tick_vol != NULL) ? m_tick_vol->GetStdDev() : 0.0;
   if(tick_sd == 0) return; // Not enough data

   // 1. Check MAE (Pullback)
   if(CheckMAE(profit_points, tick_sd))
     {
      // If pulled back too much, maybe close or tighten hard?
      // For now, we just stop expanding. "Lock Mode".
      m_is_free_running = false;
      return;
     }

   // 2. Expand TP (Trend Chasing)
   // Only if in profit and momentum supports it (simplified here)
   if(profit_points > 0)
     {
      ExpandTakeProfit(ticket, (ENUM_POSITION_TYPE)type, current_price, tick_sd);
     }
  }
//+------------------------------------------------------------------+
//| Check Maximum Adverse Excursion                                  |
//+------------------------------------------------------------------+
bool CProfitMaximizer::CheckMAE(double current_profit_points, double tick_sd)
  {
   // Pullback = Peak - Current
   double pullback = m_peak_profit - current_profit_points;
   double limit = m_mae_limit_factor * tick_sd;

   if(pullback > limit) return true; // Too much pullback
   return false;
  }
//+------------------------------------------------------------------+
//| Expand Take Profit                                               |
//+------------------------------------------------------------------+
void CProfitMaximizer::ExpandTakeProfit(ulong ticket, ENUM_POSITION_TYPE type, double current_price, double tick_sd)
  {
   double current_tp = PositionGetDouble(POSITION_TP);
   double expansion = m_expansion_factor * tick_sd;

   double new_tp = 0.0;

   if(type == POSITION_TYPE_BUY)
     {
      double target = current_price + expansion;
      // Only move if new target is significantly higher than current TP
      if(target > current_tp + (tick_sd * 0.5)) // Optimization: Don't spam small updates
         new_tp = target;
     }
   else
     {
      double target = current_price - expansion;
      if(target < current_tp - (tick_sd * 0.5) || current_tp == 0)
         new_tp = target;
     }

   if(new_tp != 0.0)
     {
      // Use CTrade to modify
      m_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), new_tp);
      m_is_free_running = true;
     }
  }
//+------------------------------------------------------------------+
