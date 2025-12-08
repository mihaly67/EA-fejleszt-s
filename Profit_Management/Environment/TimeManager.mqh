//+------------------------------------------------------------------+
//|                                                  TimeManager.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

enum ENUM_SESSION_TYPE
  {
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_CLOSED
  };

//+------------------------------------------------------------------+
//| Class: Time Manager                                              |
//+------------------------------------------------------------------+
class CTimeManager
  {
private:
   int               m_london_open;
   int               m_ny_open;
   int               m_rollover_start; // e.g., 23
   int               m_rollover_end;   // e.g., 0

public:
                     CTimeManager(void);
                    ~CTimeManager(void);

   // Simple Session Logic (GMT offset handling usually required, simplified here)
   ENUM_SESSION_TYPE GetCurrentSession(void);

   // Safety
   bool              IsRolloverTime(void);
   bool              IsFridayClose(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimeManager::CTimeManager(void) : m_london_open(8), m_ny_open(13), m_rollover_start(23), m_rollover_end(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimeManager::~CTimeManager(void)
  {
  }
//+------------------------------------------------------------------+
//| Get Session                                                      |
//+------------------------------------------------------------------+
ENUM_SESSION_TYPE CTimeManager::GetCurrentSession(void)
  {
   MqlDateTime dt;
   TimeCurrent(dt);

   if(dt.hour >= m_london_open && dt.hour < m_ny_open) return SESSION_LONDON;
   if(dt.hour >= m_ny_open && dt.hour < 22) return SESSION_NY;
   if(dt.hour < m_london_open) return SESSION_ASIAN;

   return SESSION_CLOSED; // Late NY
  }
//+------------------------------------------------------------------+
//| Is Rollover?                                                     |
//+------------------------------------------------------------------+
bool CTimeManager::IsRolloverTime(void)
  {
   MqlDateTime dt;
   TimeCurrent(dt);

   // Filter 23:55 to 00:05
   if(dt.hour == 23 && dt.min >= 55) return true;
   if(dt.hour == 0 && dt.min <= 5) return true;

   return false;
  }
//+------------------------------------------------------------------+
//| Is Friday Close?                                                 |
//+------------------------------------------------------------------+
bool CTimeManager::IsFridayClose(void)
  {
   MqlDateTime dt;
   TimeCurrent(dt);

   if(dt.day_of_week == 5 && dt.hour >= 21) return true;
   return false;
  }
//+------------------------------------------------------------------+
