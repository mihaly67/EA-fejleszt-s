//+------------------------------------------------------------------+
//|                                        MarketRegimeDetector.mqh  |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enum: Market Regimes                                             |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
  {
   REGIME_UNKNOWN = 0,
   REGIME_TREND_UP_STRONG,    // Strong Bull Trend (ADX>25, +DI > -DI)
   REGIME_TREND_DOWN_STRONG,  // Strong Bear Trend (ADX>25, -DI > +DI)
   REGIME_TREND_UP_WEAK,      // Weak Bull
   REGIME_TREND_DOWN_WEAK,    // Weak Bear
   REGIME_RANGE_STABLE,       // Low Volatility Range (ADX<20, Low ATR)
   REGIME_RANGE_VOLATILE      // High Volatility Range (Choppy)
  };

//+------------------------------------------------------------------+
//| Class: Regime Detector                                           |
//| Logic: Combines ADX (Trend Strength) and ATR (Volatility)        |
//+------------------------------------------------------------------+
class CMarketRegimeDetector
  {
private:
   int               m_handle_adx;
   int               m_handle_atr;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_period;

   // Thresholds
   double            m_adx_trend_level;   // Default 25.0
   double            m_adx_range_level;   // Default 20.0
   int               m_atr_ma_period;     // Period to compare current ATR vs Average ATR

public:
                     CMarketRegimeDetector(void);
                    ~CMarketRegimeDetector(void);

   // Initialize indicators
   bool              Init(string symbol, ENUM_TIMEFRAMES period, int adx_period=14, int atr_period=14);

   // Detect current regime based on last closed bar (shift=1)
   ENUM_MARKET_REGIME Detect(void);

   // Get raw metrics for dashboard
   double            GetADX(void);
   double            GetTrendStrength(void); // Normalized 0-100
   double            GetVolatilityRatio(void); // Current ATR / Avg ATR
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketRegimeDetector::CMarketRegimeDetector(void) : m_handle_adx(INVALID_HANDLE),
                                                     m_handle_atr(INVALID_HANDLE),
                                                     m_adx_trend_level(25.0),
                                                     m_adx_range_level(20.0),
                                                     m_atr_ma_period(100)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketRegimeDetector::~CMarketRegimeDetector(void)
  {
   if(m_handle_adx!=INVALID_HANDLE) IndicatorRelease(m_handle_adx);
   if(m_handle_atr!=INVALID_HANDLE) IndicatorRelease(m_handle_atr);
  }
//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::Init(string symbol, ENUM_TIMEFRAMES period, int adx_period, int atr_period)
  {
   m_symbol = symbol;
   m_period = period;

   m_handle_adx = iADX(m_symbol, m_period, adx_period);
   m_handle_atr = iATR(m_symbol, m_period, atr_period);

   if(m_handle_adx == INVALID_HANDLE || m_handle_atr == INVALID_HANDLE)
     {
      Print("Error creating Regime Detector indicators");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Detect Regime                                                    |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CMarketRegimeDetector::Detect(void)
  {
   double adx[], pdi[], mdi[], atr[];
   ArrayResize(adx, 1); ArrayResize(pdi, 1); ArrayResize(mdi, 1); ArrayResize(atr, 1);

   // Copy bar 1 (last closed)
   if(CopyBuffer(m_handle_adx, 0, 1, 1, adx) <= 0) return REGIME_UNKNOWN;
   if(CopyBuffer(m_handle_adx, 1, 1, 1, pdi) <= 0) return REGIME_UNKNOWN; // +DI
   if(CopyBuffer(m_handle_adx, 2, 1, 1, mdi) <= 0) return REGIME_UNKNOWN; // -DI

   double adx_val = adx[0];
   double pdi_val = pdi[0];
   double mdi_val = mdi[0];

   // Trend Logic
   if(adx_val > m_adx_trend_level)
     {
      if(pdi_val > mdi_val) return REGIME_TREND_UP_STRONG;
      if(mdi_val > pdi_val) return REGIME_TREND_DOWN_STRONG;
     }
   else if(adx_val < m_adx_range_level)
     {
      // Range: Check volatility
      // (Simplified: if ADX is very low, it's usually stable range)
      return REGIME_RANGE_STABLE;
     }
   else
     {
      // Transition zone (20-25)
      if(pdi_val > mdi_val) return REGIME_TREND_UP_WEAK;
      if(mdi_val > pdi_val) return REGIME_TREND_DOWN_WEAK;
     }

   return REGIME_RANGE_VOLATILE;
  }
//+------------------------------------------------------------------+
//| Get ADX Value                                                    |
//+------------------------------------------------------------------+
double CMarketRegimeDetector::GetADX(void)
  {
   double buf[1];
   if(CopyBuffer(m_handle_adx, 0, 1, 1, buf) > 0) return buf[0];
   return 0.0;
  }
//+------------------------------------------------------------------+
