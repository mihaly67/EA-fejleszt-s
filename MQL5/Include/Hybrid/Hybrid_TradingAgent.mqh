//+------------------------------------------------------------------+
//|                                           Hybrid_TradingAgent.mqh |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Hybrid Agent with Advanced Profit/Risk Management     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.1"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Profit Management Modules
#include <Profit_Management\RiskManager.mqh>
#include <Profit_Management\ProfitMaximizer.mqh>
#include <Profit_Management\TickVolatility.mqh>
#include <Profit_Management\Environment\BrokerInfo.mqh>

class Hybrid_TradingAgent
{
private:
   CTrade            m_trade;
   CPositionInfo     m_position;
   CAccountInfo      m_account;

   //--- Logic Modules
   CRiskManager      m_risk;
   CProfitMaximizer  m_profit;
   CTickVolatility   m_vol;
   CBrokerInfo       m_broker;

   int               m_magic;
   double            m_slippage;

public:
   Hybrid_TradingAgent();
   ~Hybrid_TradingAgent();

   bool Init(int magic, double slippage=3);

   //--- Periodic Updates
   void OnTick();
   void OnNewDay();

   //--- Actions
   void OrderBuy(double volume_override, double sl_pips, double tp_pips, double score=0.0);
   void OrderSell(double volume_override, double sl_pips, double tp_pips, double score=0.0);
   void OrderCloseAll();
   void OrderCloseAllBuy();
   void OrderCloseAllSell();

   //--- Calculation
   double CalcLots(double sl_pips, double score);

   //--- Info
   int PositionsBuy();
   int PositionsSell();
   double LotsBuy();
   double LotsSell();
   double CalcProfitBuy();
   double CalcProfitSell();

   double Equity() { return m_account.Equity(); }
   double MarginLevel() { return m_account.MarginLevel(); }
   string Leverage() { return IntegerToString(m_account.Leverage()); }
};

Hybrid_TradingAgent::Hybrid_TradingAgent()
{
}

Hybrid_TradingAgent::~Hybrid_TradingAgent()
{
}

bool Hybrid_TradingAgent::Init(int magic, double slippage=3)
{
   m_magic = magic;
   m_slippage = slippage;
   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints((ulong)slippage);

   // Init Sub-modules
   m_broker.Init();
   m_vol.Init();

   m_risk.Init(1.0, 5.0); // Base Risk 1%, Max DD 5% (Default)
   m_risk.SetTickVolatility(&m_vol);
   m_risk.SetBrokerInfo(&m_broker);

   m_profit.Init(&m_vol);

   return true;
}

void Hybrid_TradingAgent::OnTick()
{
   m_vol.OnTick(); // Update Volatility

   // Update Profit Maximizer for all open positions
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic) {
            // Call Profit Maximizer
            m_profit.ManagePosition(m_position.Ticket(), m_broker.GetLastTick().last); // Assuming last price
         }
      }
   }
}

void Hybrid_TradingAgent::OnNewDay()
{
   m_risk.OnNewDay();
}

double Hybrid_TradingAgent::CalcLots(double sl_pips, double score)
{
   // Convert Pips to Points
   double sl_points = sl_pips * 10.0; // Assuming 5-digit broker
   return m_risk.CalculateLotSize(_Symbol, sl_points, score);
}

void Hybrid_TradingAgent::OrderBuy(double volume_override, double sl_pips, double tp_pips, double score=0.0)
{
   // 1. Calculate Risk-Based Lot if override is 0 or "Auto"
   double lots = volume_override;
   if(lots <= 0) {
      lots = CalcLots(sl_pips, score);
   }

   // 2. Validate Minimum Profit Distance (1.5x Spread)
   double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   double min_tp_pips = (spread_points * 1.5) / 10.0;

   if(tp_pips < min_tp_pips && tp_pips > 0) {
      Print("Warning: TP too close (Spread Rule). Adjusted to ", min_tp_pips);
      tp_pips = min_tp_pips;
   }

   // 3. Execute
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = (sl_pips > 0) ? price - sl_pips * _Point * 10 : 0;
   double tp = (tp_pips > 0) ? price + tp_pips * _Point * 10 : 0;

   if(lots > 0)
      m_trade.Buy(lots, _Symbol, price, sl, tp, "Hybrid Buy (RiskManaged)");
   else
      Print("RiskManager rejected trade (Zero Lots).");
}

void Hybrid_TradingAgent::OrderSell(double volume_override, double sl_pips, double tp_pips, double score=0.0)
{
   double lots = volume_override;
   if(lots <= 0) {
      lots = CalcLots(sl_pips, score);
   }

   double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   double min_tp_pips = (spread_points * 1.5) / 10.0;

   if(tp_pips < min_tp_pips && tp_pips > 0) {
      tp_pips = min_tp_pips;
   }

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (sl_pips > 0) ? price + sl_pips * _Point * 10 : 0;
   double tp = (tp_pips > 0) ? price - tp_pips * _Point * 10 : 0;

   if(lots > 0)
      m_trade.Sell(lots, _Symbol, price, sl, tp, "Hybrid Sell (RiskManaged)");
   else
      Print("RiskManager rejected trade (Zero Lots).");
}

//--- Standard Wrappers
void Hybrid_TradingAgent::OrderCloseAll()
{
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic)
            m_trade.PositionClose(m_position.Ticket());
      }
   }
}

void Hybrid_TradingAgent::OrderCloseAllBuy()
{
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_BUY)
            m_trade.PositionClose(m_position.Ticket());
      }
   }
}

void Hybrid_TradingAgent::OrderCloseAllSell()
{
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_SELL)
            m_trade.PositionClose(m_position.Ticket());
      }
   }
}

int Hybrid_TradingAgent::PositionsBuy()
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_BUY)
            count++;
      }
   }
   return count;
}

int Hybrid_TradingAgent::PositionsSell()
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_SELL)
            count++;
      }
   }
   return count;
}

double Hybrid_TradingAgent::LotsBuy()
{
   double vol = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_BUY)
            vol += m_position.Volume();
      }
   }
   return vol;
}

double Hybrid_TradingAgent::LotsSell()
{
   double vol = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_SELL)
            vol += m_position.Volume();
      }
   }
   return vol;
}

double Hybrid_TradingAgent::CalcProfitBuy()
{
   double prof = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_BUY)
            prof += m_position.Profit();
      }
   }
   return prof;
}

double Hybrid_TradingAgent::CalcProfitSell()
{
   double prof = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic && m_position.PositionType()==POSITION_TYPE_SELL)
            prof += m_position.Profit();
      }
   }
   return prof;
}
