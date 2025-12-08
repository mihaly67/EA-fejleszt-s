//+------------------------------------------------------------------+
//|                                             TradingAssistant.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "..\Showcase_Indicators\MarketRegimeDetector.mqh"
#include "..\Profit_Management\TickVolatility.mqh"

//+------------------------------------------------------------------+
//| Enum: Assistant Advice                                           |
//+------------------------------------------------------------------+
enum ENUM_ASSISTANT_ADVICE
  {
   ADVICE_WAIT = 0,
   ADVICE_BUY_STRONG,
   ADVICE_BUY_WEAK,
   ADVICE_SELL_STRONG,
   ADVICE_SELL_WEAK,
   ADVICE_CLOSE_BUY,
   ADVICE_CLOSE_SELL,
   ADVICE_CLOSE_ALL,
   ADVICE_WARNING_VOLATILITY
  };

//+------------------------------------------------------------------+
//| Class: Trading Assistant (Logic Core)                            |
//+------------------------------------------------------------------+
class CTradingAssistant
  {
private:
   // Components
   CMarketRegimeDetector *m_regime;
   CTickVolatility       *m_tick_vol;

   // State
   double                 m_conviction_score; // -100 to +100
   ENUM_ASSISTANT_ADVICE  m_current_advice;

   // Parameters
   double                 m_weight_regime;    // 0.4
   double                 m_weight_momentum;  // 0.3 (Placeholder for now)
   double                 m_weight_volatility;// 0.2

   // Internal Helpers
   double                 CalcRegimeScore(ENUM_MARKET_REGIME regime);
   double                 CalcVolatilityScore(void);

public:
                     CTradingAssistant(void);
                    ~CTradingAssistant(void);

   // Initialization
   bool              Init(string symbol, ENUM_TIMEFRAMES period);

   // Main Tick Loop
   void              OnTick(double current_bid);

   // Getters for Dashboard
   double            GetConvictionScore(void) { return m_conviction_score; }
   string            GetAdviceText(void);
   ENUM_ASSISTANT_ADVICE GetAdvice(void)      { return m_current_advice;   }
   string            GetRegimeText(void);
   double            GetTickVolatility(void)  { return m_tick_vol->GetStdDev(); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradingAssistant::CTradingAssistant(void) : m_conviction_score(0),
                                             m_current_advice(ADVICE_WAIT),
                                             m_weight_regime(0.4),
                                             m_weight_momentum(0.3),
                                             m_weight_volatility(0.2)
  {
   m_regime = new CMarketRegimeDetector();
   m_tick_vol = new CTickVolatility();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradingAssistant::~CTradingAssistant(void)
  {
   if(CheckPointer(m_regime) == POINTER_DYNAMIC) delete m_regime;
   if(CheckPointer(m_tick_vol) == POINTER_DYNAMIC) delete m_tick_vol;
  }
//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTradingAssistant::Init(string symbol, ENUM_TIMEFRAMES period)
  {
   // Init Regime Detector
   if(!m_regime->Init(symbol, period)) return false;

   // Init Tick Volatility (window 1000 ticks)
   m_tick_vol->Init(1000);

   return true;
  }
//+------------------------------------------------------------------+
//| Main Logic Step                                                  |
//+------------------------------------------------------------------+
void CTradingAssistant::OnTick(double current_bid)
  {
   // 1. Update Volatility
   m_tick_vol->Update(current_bid);

   // 2. Detect Regime
   ENUM_MARKET_REGIME current_regime = m_regime->Detect();

   // 3. Calculate Scores
   double score_regime = CalcRegimeScore(current_regime);
   double score_vol    = CalcVolatilityScore();
   double score_mom    = 0.0; // Placeholder: Would come from MACD/FRAMA

   // If Trend Up, Momentum is assumed positive for now (simplified)
   if(score_regime > 0) score_mom = 50.0;
   if(score_regime < 0) score_mom = -50.0;

   // 4. Aggregate Conviction
   // Formula: Regime*W + Mom*W + Vol*W
   m_conviction_score = (score_regime * m_weight_regime) +
                        (score_mom * m_weight_momentum) +
                        (score_vol * m_weight_volatility);

   // Clamp -100 to 100
   if(m_conviction_score > 100) m_conviction_score = 100;
   if(m_conviction_score < -100) m_conviction_score = -100;

   // 5. Determine Advice
   if(m_conviction_score > 75) m_current_advice = ADVICE_BUY_STRONG;
   else if(m_conviction_score > 25) m_current_advice = ADVICE_BUY_WEAK;
   else if(m_conviction_score < -75) m_current_advice = ADVICE_SELL_STRONG;
   else if(m_conviction_score < -25) m_current_advice = ADVICE_SELL_WEAK;
   else m_current_advice = ADVICE_WAIT;

   // Safety Override
   if(m_tick_vol->GetStdDev() > 0.00050) // High tick noise example (50 points)
     {
      // m_current_advice = ADVICE_WARNING_VOLATILITY;
      // Keep advice but maybe warn? For now let's just stick to score.
     }
  }
//+------------------------------------------------------------------+
//| Helper: Regime Score                                             |
//+------------------------------------------------------------------+
double CTradingAssistant::CalcRegimeScore(ENUM_MARKET_REGIME regime)
  {
   switch(regime)
     {
      case REGIME_TREND_UP_STRONG:   return 100.0;
      case REGIME_TREND_UP_WEAK:     return 50.0;
      case REGIME_TREND_DOWN_STRONG: return -100.0;
      case REGIME_TREND_DOWN_WEAK:   return -50.0;
      case REGIME_RANGE_STABLE:      return 0.0;
      case REGIME_RANGE_VOLATILE:    return 0.0; // Or penalty?
      default: return 0.0;
     }
  }
//+------------------------------------------------------------------+
//| Helper: Volatility Score                                         |
//| Low vol = good for accumulation (0), High vol = breakout (100)?  |
//| Simplified: High volatility supports trend if trend exists.      |
//+------------------------------------------------------------------+
double CTradingAssistant::CalcVolatilityScore(void)
  {
   // This logic would need context.
   // For now, let's say normal volatility adds confidence, extreme reduces it.
   // returning 0 for neutral impact in this version.
   return 0.0;
  }
//+------------------------------------------------------------------+
//| Get Text Description                                             |
//+------------------------------------------------------------------+
string CTradingAssistant::GetAdviceText(void)
  {
   switch(m_current_advice)
     {
      case ADVICE_BUY_STRONG: return "STRONG BUY";
      case ADVICE_BUY_WEAK:   return "WEAK BUY (Wait for pull)";
      case ADVICE_SELL_STRONG:return "STRONG SELL";
      case ADVICE_SELL_WEAK:  return "WEAK SELL (Wait for bounce)";
      case ADVICE_WAIT:       return "WAIT / RANGE";
      case ADVICE_WARNING_VOLATILITY: return "WARNING: HIGH VOLATILITY";
      default: return "ANALYZING...";
     }
  }
//+------------------------------------------------------------------+
//| Get Regime Text                                                  |
//+------------------------------------------------------------------+
string CTradingAssistant::GetRegimeText(void)
  {
   // We can access m_regime last known state via a getter if we added one,
   // or just re-detect (cheap). Let's assume OnTick ran.
   // For display, we should store it.
   return "Regime Updated"; // Simplified for this snippet
  }
//+------------------------------------------------------------------+
