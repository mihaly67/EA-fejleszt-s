//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "..\Profit_Management\TickVolatility.mqh"

//+------------------------------------------------------------------+
//| Class: Advanced Risk Manager                                     |
//+------------------------------------------------------------------+
class CRiskManager
  {
private:
   double            m_base_risk_percent;    // e.g. 1.0%
   double            m_max_daily_dd;         // e.g. 5.0%
   double            m_start_day_equity;

   CTickVolatility  *m_tick_vol;             // Pointer to shared volatility object

public:
                     CRiskManager(void);
                    ~CRiskManager(void);

   // Configuration
   void              Init(double base_risk, double max_dd);
   void              SetTickVolatility(CTickVolatility *tick_vol) { m_tick_vol = tick_vol; }
   void              OnNewDay(void);

   // Main Calculation
   double            CalculateLotSize(string symbol, double sl_points, double conviction_score);

   // Validation
   bool              CheckSafety(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(void) : m_base_risk_percent(1.0),
                                   m_max_daily_dd(5.0),
                                   m_start_day_equity(0.0),
                                   m_tick_vol(NULL)
  {
   m_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager(void)
  {
   // m_tick_vol is external, do not delete
  }
//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CRiskManager::Init(double base_risk, double max_dd)
  {
   m_base_risk_percent = base_risk;
   m_max_daily_dd      = max_dd;
   m_start_day_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
  }
//+------------------------------------------------------------------+
//| New Day Reset                                                    |
//+------------------------------------------------------------------+
void CRiskManager::OnNewDay(void)
  {
   m_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
  }
//+------------------------------------------------------------------+
//| Calculate Optimal Lot Size                                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(string symbol, double sl_points, double conviction_score)
  {
   if(!CheckSafety()) return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // 1. Adjust Risk % based on Conviction
   // Base = 1.0%. Strong (>80) = 1.5%. Weak (<50) = 0.5%.
   double adjusted_risk = m_base_risk_percent;

   if(conviction_score > 80.0) adjusted_risk *= 1.5;
   else if(conviction_score < 50.0) adjusted_risk *= 0.5;

   // 2. Adjust for Volatility (if available)
   // If SL is too tight vs Tick Noise, we must enforce minimum SL distance math
   // effectively reducing lot size for the same risk amount.
   if(m_tick_vol != NULL)
     {
      // Fix: Use arrow operator for pointer access
      double tick_sd_points = m_tick_vol->GetStdDev() / SymbolInfoDouble(symbol, SYMBOL_POINT);
      double min_safe_sl = tick_sd_points * 3.0; // 3 sigma

      if(sl_points < min_safe_sl && sl_points > 0)
        {
         // User wants tight SL (e.g. 50 pts), but Noise is 30 pts (3sig=90).
         // Option A: Forbid trade. Option B: Use 90 pts for calculation to reduce lot size.
         // We choose Option B (Capital Protection).
         sl_points = min_safe_sl;
        }
     }

   if(sl_points <= 0) return 0.0; // Invalid SL

   // 3. Calculate Money Risk
   double risk_money = equity * (adjusted_risk / 100.0);

   // 4. Convert to Lots
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(tick_size == 0 || tick_value == 0) return 0.0;

   double points_per_tick = tick_size / point;
   double sl_ticks = sl_points / points_per_tick;

   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double raw_lots = risk_money / (sl_ticks * tick_value);

   // Normalize
   double lots = MathFloor(raw_lots / lot_step) * lot_step;

   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   if(lots < min_lot) lots = 0.0; // Too small risk
   if(lots > max_lot) lots = max_lot;

   return lots;
  }
//+------------------------------------------------------------------+
//| Safety Check (Drawdown)                                          |
//+------------------------------------------------------------------+
bool CRiskManager::CheckSafety(void)
  {
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd_percent = (m_start_day_equity - current_equity) / m_start_day_equity * 100.0;

   if(dd_percent >= m_max_daily_dd)
     {
      Print("RiskManager: Daily Drawdown Limit Hit! Trading Halted.");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
