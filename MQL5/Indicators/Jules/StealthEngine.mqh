//+------------------------------------------------------------------+
//|                                                 StealthEngine.mqh |
//|                                  Copyright 2026, Jules (AI Agent) |
//|                                         https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Jules (AI Agent)"
#property link      "https://www.mql5.com"
#property version   "1.0"

//+------------------------------------------------------------------+
//| CStealthEngine: Human-like behavior simulation for EAs           |
//+------------------------------------------------------------------+
class CStealthEngine
  {
private:
   bool              m_Enabled;
   int               m_BaseDelay;
   int               m_Jitter;
   string            m_HumanComments[];

public:
                     CStealthEngine();
                    ~CStealthEngine();

   void              Init(bool enabled, int base_delay_ms, int jitter_ms);

   // Core Stealth Methods
   void              ApplyHumanDelay();
   double            GetFuzzyPrice(double price, double point);
   string            GetHumanComment();

   // Advanced (Future Placeholder)
   bool              IsFatFinger(); // Returns true with low probability
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStealthEngine::CStealthEngine()
  {
   m_Enabled = false;
   m_BaseDelay = 0;
   m_Jitter = 0;
   ArrayResize(m_HumanComments, 5);
   m_HumanComments[0] = "";
   m_HumanComments[1] = "manual";
   m_HumanComments[2] = "t1";
   m_HumanComments[3] = "test";
   m_HumanComments[4] = "news";
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStealthEngine::~CStealthEngine()
  {
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CStealthEngine::Init(bool enabled, int base_delay_ms, int jitter_ms)
  {
   m_Enabled = enabled;
   m_BaseDelay = base_delay_ms;
   m_Jitter = jitter_ms;

   // Seed the random generator
   MathSrand(GetTickCount());
  }

//+------------------------------------------------------------------+
//| ApplyHumanDelay: Sleeps for a random duration                    |
//+------------------------------------------------------------------+
void CStealthEngine::ApplyHumanDelay()
  {
   if(!m_Enabled) return;

   // Simple randomization: Base + Random(-Jitter to +Jitter)
   int random_jitter = (MathRand() % (m_Jitter * 2 + 1)) - m_Jitter;
   int sleep_time = m_BaseDelay + random_jitter;

   if(sleep_time < 0) sleep_time = 0;

   Sleep(sleep_time);
  }

//+------------------------------------------------------------------+
//| GetFuzzyPrice: Adds micro-pip noise to price                     |
//+------------------------------------------------------------------+
double CStealthEngine::GetFuzzyPrice(double price, double point)
  {
   if(!m_Enabled) return price;

   // Add +/- 0 to 2 points of fuzz
   int fuzz_points = (MathRand() % 5) - 2; // Range: -2 to +2

   return price + (fuzz_points * point);
  }

//+------------------------------------------------------------------+
//| GetHumanComment: Returns a random "human" string                 |
//+------------------------------------------------------------------+
string CStealthEngine::GetHumanComment()
  {
   if(!m_Enabled) return "Merkava_Algo"; // Default if disabled

   int idx = MathRand() % ArraySize(m_HumanComments);
   return m_HumanComments[idx];
  }

//+------------------------------------------------------------------+
//| IsFatFinger: Returns true with very low probability (e.g. 0.1%)  |
//+------------------------------------------------------------------+
bool CStealthEngine::IsFatFinger()
  {
   if(!m_Enabled) return false;

   // 1 in 1000 chance
   return (MathRand() % 1000) == 0;
  }
