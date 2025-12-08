//+------------------------------------------------------------------+
//|                                                   BrokerInfo.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class: Broker Info Wrapper                                       |
//+------------------------------------------------------------------+
class CBrokerInfo
  {
private:
   CSymbolInfo       m_symbol;
   string            m_name;

public:
                     CBrokerInfo(void);
                    ~CBrokerInfo(void);

   bool              Init(string symbol);
   void              Refresh(void);

   // Checks
   bool              IsSpreadAcceptable(int max_points);
   bool              IsTradeAllowed(void);

   // Getters
   int               GetStopsLevel(void);
   int               GetSpread(void);
   double            GetPoint(void) { return m_symbol.Point(); }
   double            GetTickSize(void) { return m_symbol.TickSize(); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBrokerInfo::CBrokerInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBrokerInfo::~CBrokerInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CBrokerInfo::Init(string symbol)
  {
   m_name = symbol;
   return m_symbol.Name(symbol);
  }
//+------------------------------------------------------------------+
//| Refresh                                                          |
//+------------------------------------------------------------------+
void CBrokerInfo::Refresh(void)
  {
   m_symbol.RefreshRates();
  }
//+------------------------------------------------------------------+
//| Check Spread                                                     |
//+------------------------------------------------------------------+
bool CBrokerInfo::IsSpreadAcceptable(int max_points)
  {
   return (m_symbol.Spread() <= max_points);
  }
//+------------------------------------------------------------------+
//| Check Trade Allowed                                              |
//+------------------------------------------------------------------+
bool CBrokerInfo::IsTradeAllowed(void)
  {
   return m_symbol.TradeMode() == SYMBOL_TRADE_MODE_FULL;
  }
//+------------------------------------------------------------------+
//| Get Stops Level                                                  |
//+------------------------------------------------------------------+
int CBrokerInfo::GetStopsLevel(void)
  {
   return m_symbol.StopsLevel();
  }
//+------------------------------------------------------------------+
//| Get Spread                                                       |
//+------------------------------------------------------------------+
int CBrokerInfo::GetSpread(void)
  {
   return m_symbol.Spread();
  }
//+------------------------------------------------------------------+
