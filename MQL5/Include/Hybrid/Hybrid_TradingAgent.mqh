//+------------------------------------------------------------------+
//|                                           Hybrid_TradingAgent.mqh |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Simplified Trading Agent wrapping CTrade              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.0"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

class Hybrid_TradingAgent
{
private:
   CTrade         m_trade;
   CPositionInfo  m_position;
   CAccountInfo   m_account;

   int            m_magic;
   double         m_slippage;

public:
   Hybrid_TradingAgent();
   ~Hybrid_TradingAgent();

   bool Init(int magic, double slippage=3);

   //--- Actions
   void OrderBuy(double volume, double sl_pips, double tp_pips);
   void OrderSell(double volume, double sl_pips, double tp_pips);
   void OrderCloseAll();
   void OrderCloseAllBuy();
   void OrderCloseAllSell();

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

   //--- Helper
   double CalcLots() { return 0.01; } // Placeholder for Money Management

   //--- Deprecated/Unused (Mocked for compatibility with Panel logic if needed)
   void TradeUpdate() {}
   void TradeClose() {}
   void ResetLines(string type) {}
   double CalcBreakEvenBuy() { return 0.0; }
   double CalcBreakEvenSell() { return 0.0; }
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
   return true;
}

void Hybrid_TradingAgent::OrderBuy(double volume, double sl_pips, double tp_pips)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = (sl_pips > 0) ? price - sl_pips * _Point * 10 : 0; // *10 assuming 5 digit broker for "pips"
   double tp = (tp_pips > 0) ? price + tp_pips * _Point * 10 : 0;

   m_trade.Buy(volume, _Symbol, price, sl, tp, "Hybrid Panel Buy");
}

void Hybrid_TradingAgent::OrderSell(double volume, double sl_pips, double tp_pips)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (sl_pips > 0) ? price + sl_pips * _Point * 10 : 0;
   double tp = (tp_pips > 0) ? price - tp_pips * _Point * 10 : 0;

   m_trade.Sell(volume, _Symbol, price, sl, tp, "Hybrid Panel Sell");
}

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
