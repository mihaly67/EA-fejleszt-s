//+------------------------------------------------------------------+
//|                                                 StealthEngine.mqh |
//|                                  Copyright 2026, Jules (AI Agent) |
//|                                         https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Jules (AI Agent)"
#property link      "https://www.mql5.com"
#property version   "1.0"

//+------------------------------------------------------------------+
//| CStealthEngine: Emberi viselkedés szimulációja EA-k számára      |
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

   // Fő Stealth Módszerek (Core Stealth Methods)
   void              ApplyHumanDelay(); // Emberi késleltetés alkalmazása
   double            GetFuzzyPrice(double price, double point); // Árfolyam zajosítása (Price Fuzzing)
   string            GetHumanComment(); // Emberi megjegyzés generálása

   // Haladó (Jövőbeli Helyőrző - Advanced Placeholder)
   bool              IsFatFinger(); // 'Fat Finger' hiba szimulálása alacsony valószínűséggel
  };

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
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
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CStealthEngine::~CStealthEngine()
  {
  }

//+------------------------------------------------------------------+
//| Inicializálás                                                    |
//+------------------------------------------------------------------+
void CStealthEngine::Init(bool enabled, int base_delay_ms, int jitter_ms)
  {
   m_Enabled = enabled;
   m_BaseDelay = base_delay_ms;
   m_Jitter = jitter_ms;

   // Véletlenszám-generátor inicializálása (Seed)
   MathSrand(GetTickCount());
  }

//+------------------------------------------------------------------+
//| ApplyHumanDelay: Véletlenszerű várakozás (Sleep)                 |
//+------------------------------------------------------------------+
void CStealthEngine::ApplyHumanDelay()
  {
   if(!m_Enabled) return;

   // Egyszerű randomizáció: Alap (Base) + Véletlen(-Jitter-től +Jitter-ig)
   int random_jitter = (MathRand() % (m_Jitter * 2 + 1)) - m_Jitter;
   int sleep_time = m_BaseDelay + random_jitter;

   if(sleep_time < 0) sleep_time = 0;

   Sleep(sleep_time);
  }

//+------------------------------------------------------------------+
//| GetFuzzyPrice: Mikro-pip zaj hozzáadása az árhoz                 |
//+------------------------------------------------------------------+
double CStealthEngine::GetFuzzyPrice(double price, double point)
  {
   if(!m_Enabled) return price;

   // +/- 0-tól 2 pontig terjedő zaj hozzáadása
   int fuzz_points = (MathRand() % 5) - 2; // Tartomány: -2-től +2-ig

   return price + (fuzz_points * point);
  }

//+------------------------------------------------------------------+
//| GetHumanComment: Véletlenszerű "emberi" string visszaadása       |
//+------------------------------------------------------------------+
string CStealthEngine::GetHumanComment()
  {
   if(!m_Enabled) return "Merkava_Algo"; // Alapértelmezett, ha ki van kapcsolva

   int idx = MathRand() % ArraySize(m_HumanComments);
   return m_HumanComments[idx];
  }

//+------------------------------------------------------------------+
//| IsFatFinger: Igaz érték nagyon alacsony valószínűséggel (pl. 0.1%)|
//+------------------------------------------------------------------+
bool CStealthEngine::IsFatFinger()
  {
   if(!m_Enabled) return false;

   // 1 az 1000-hez esély
   return (MathRand() % 1000) == 0;
  }
