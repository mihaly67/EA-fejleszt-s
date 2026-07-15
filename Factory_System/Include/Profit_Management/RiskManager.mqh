//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.10"

#include "..\Profit_Management\TickVolatility.mqh"
#include "..\Profit_Management\Environment\BrokerInfo.mqh"

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
   CBrokerInfo      *m_broker;               // Pointer to Broker Info

public:
                     CRiskManager(void);
                    ~CRiskManager(void);

   // Configuration
   void              Init(double base_risk, double max_dd);
   void              SetTickVolatility(CTickVolatility *tick_vol) { m_tick_vol = tick_vol; }
   void              SetBrokerInfo(CBrokerInfo *broker)           { m_broker = broker; }
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
                                   m_tick_vol(NULL),
                                   m_broker(NULL)
  {
   m_start_day_equity = AccountInfoDouble(ACCOUNT_EQUITY);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager(void)
  {
   // m_tick_vol, m_broker are external
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
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // 1. Adjust Risk % based on Conviction
   double adjusted_risk = m_base_risk_percent;
   if(conviction_score > 80.0) adjusted_risk *= 1.5;
   else if(conviction_score < 50.0) adjusted_risk *= 0.5;

   // 2. Adjust for Volatility (Normalization)
   if(m_tick_vol != NULL && m_broker != NULL)
     {
      double tick_sd_points = m_tick_vol->GetStdDev() / m_broker->GetPoint();
      double min_safe_sl = tick_sd_points * 3.0; // 3 sigma

      // If requested SL is tighter than noise, use noise-based SL for risk calc (Safety)
      if(sl_points < min_safe_sl && sl_points > 0)
        {
         sl_points = min_safe_sl;
        }
     }

   if(sl_points <= 0) return 0.0;

   // 3. Calculate Money Risk
   double risk_money = equity * (adjusted_risk / 100.0);

   // 4. Convert to Lots using Broker Info
   if(m_broker == NULL) return 0.0; // Broker info required

   double tick_value = m_broker->GetTickValue();
   double tick_size  = m_broker->GetTickSize();
   double point      = m_broker->GetPoint();

   if(tick_size == 0 || tick_value == 0) return 0.0;

   double points_per_tick = tick_size / point;
   double sl_ticks = sl_points / points_per_tick;

   double raw_lots = risk_money / (sl_ticks * tick_value);

   // 5. Margin Check (Leverage)
   // Ensure we have enough free margin. OrderCalcMargin is safer.
   double required_margin = m_broker->CalculateMargin(ORDER_TYPE_BUY, raw_lots, SymbolInfoDouble(symbol, SYMBOL_ASK));

   // If margin required > X% of Free Margin (User requested 70% max), reduce lots.
   if(required_margin > free_margin * 0.7)
     {
      double ratio = (free_margin * 0.7) / required_margin;
      raw_lots *= ratio;
     }

   // 6. Normalize to Lot Steps
   double lot_step = m_broker->GetLotStep();
   double lots = MathFloor(raw_lots / lot_step) * lot_step;

   double min_lot = m_broker->GetMinLot();
   double max_lot = m_broker->GetMaxLot();

   if(lots < min_lot) lots = 0.0;
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
