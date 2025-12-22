//+------------------------------------------------------------------+
//|                                                   BrokerInfo.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.10"

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

   // Properties
   int               GetStopsLevel(void);
   int               GetSpread(void);
   double            GetPoint(void) { return m_symbol.Point(); }
   double            GetTickSize(void) { return m_symbol.TickSize(); }
   double            GetTickValue(void) { return m_symbol.TickValue(); }
   long              GetDigits(void) { return m_symbol.Digits(); }

   // Lot Limits
   double            GetMinLot(void) { return m_symbol.LotsMin(); }
   double            GetMaxLot(void) { return m_symbol.LotsMax(); }
   double            GetLotStep(void) { return m_symbol.LotsStep(); }

   // Financials
   long              GetLeverage(void);
   double            CalculateMargin(ENUM_ORDER_TYPE order_type, double volume, double price);
   double            CalculateProfit(ENUM_ORDER_TYPE order_type, double volume, double open_price, double close_price);

   // Utilities
   double            PointToPip(double points);
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
//| Get Leverage                                                     |
//+------------------------------------------------------------------+
long CBrokerInfo::GetLeverage(void)
  {
   return AccountInfoInteger(ACCOUNT_LEVERAGE);
  }
//+------------------------------------------------------------------+
//| Calculate Required Margin                                        |
//+------------------------------------------------------------------+
double CBrokerInfo::CalculateMargin(ENUM_ORDER_TYPE order_type, double volume, double price)
  {
   double margin = 0.0;
   if(OrderCalcMargin(order_type, m_name, volume, price, margin))
      return margin;
   return 0.0;
  }
//+------------------------------------------------------------------+
//| Calculate Potential Profit                                       |
//+------------------------------------------------------------------+
double CBrokerInfo::CalculateProfit(ENUM_ORDER_TYPE order_type, double volume, double open_price, double close_price)
  {
   double profit = 0.0;
   if(OrderCalcProfit(order_type, m_name, volume, open_price, close_price, profit))
      return profit;
   return 0.0;
  }
//+------------------------------------------------------------------+
//| Convert Point to Pip                                             |
//+------------------------------------------------------------------+
double CBrokerInfo::PointToPip(double points)
  {
   // Standard: 5 digits = 10 points per pip. 3 digits (JPY) = 10 points per pip.
   if(m_symbol.Digits() == 3 || m_symbol.Digits() == 5)
      return points / 10.0;
   return points;
  }
//+------------------------------------------------------------------+
