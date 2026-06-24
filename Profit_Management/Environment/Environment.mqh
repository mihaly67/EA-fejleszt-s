//+------------------------------------------------------------------+
//|                                                  Environment.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "BrokerInfo.mqh"
#include "TimeManager.mqh"
#include "NewsWatcher.mqh"

//+------------------------------------------------------------------+
//| Class: Global Environment                                        |
//+------------------------------------------------------------------+
class CEnvironment
  {
private:
   CBrokerInfo       *m_broker;
   CTimeManager      *m_time;
   CNewsWatcher      *m_news;

public:
                     CEnvironment(void);
                    ~CEnvironment(void);

   bool              Init(string symbol);
   void              OnTick(void);

   // Status Queries
   bool              IsSafeToTrade(void);
   string            GetBlockReason(void);

   // Accessors
   CBrokerInfo*      Broker(void) { return m_broker; }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEnvironment::CEnvironment(void)
  {
   m_broker = new CBrokerInfo();
   m_time   = new CTimeManager();
   m_news   = new CNewsWatcher();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEnvironment::~CEnvironment(void)
  {
   delete m_broker;
   delete m_time;
   delete m_news;
  }
//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEnvironment::Init(string symbol)
  {
   return m_broker->Init(symbol);
  }
//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void CEnvironment::OnTick(void)
  {
   m_broker->Refresh();
   // News refresh optimized (e.g., once per hour or minute)
  }
//+------------------------------------------------------------------+
//| Safety Check                                                     |
//+------------------------------------------------------------------+
bool CEnvironment::IsSafeToTrade(void)
  {
   if(!m_broker->IsTradeAllowed()) return false;
   if(m_time->IsRolloverTime()) return false;
   if(m_news->IsHighImpactIncoming(15)) return false;

   return true;
  }
//+------------------------------------------------------------------+
//| Get Reason                                                       |
//+------------------------------------------------------------------+
string CEnvironment::GetBlockReason(void)
  {
   if(!m_broker->IsTradeAllowed()) return "MARKET CLOSED";
   if(m_time->IsRolloverTime()) return "ROLLOVER";
   if(m_news->IsHighImpactIncoming(15)) return "NEWS EVENT";
   return "";
  }
//+------------------------------------------------------------------+
