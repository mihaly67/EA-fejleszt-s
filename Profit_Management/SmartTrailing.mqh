//+------------------------------------------------------------------+
//|                                                SmartTrailing.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "..\Trailings.mqh"
#include "..\Profit_Management\TickVolatility.mqh"

//+------------------------------------------------------------------+
//| Class: Smart Trailing (Tick Volatility Aware)                    |
//+------------------------------------------------------------------+
class CTickSmartTrailing : public CSimpleTrailing
  {
private:
   CTickVolatility  *m_tick_vol;
   double            m_proximity_factor; // Default 3.0 (3 sigma)

protected:
   // Override standard check logic
   virtual bool      CheckCriterion(ENUM_POSITION_TYPE pos_type, double pos_open, double pos_sl, double value_sl, MqlTick &tick);

public:
                     CTickSmartTrailing(void);
                    ~CTickSmartTrailing(void);

   // Configuration
   void              SetTickVolatility(CTickVolatility *tick_vol) { m_tick_vol = tick_vol; }
   void              SetProximityFactor(double factor)            { m_proximity_factor = factor; }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTickSmartTrailing::CTickSmartTrailing(void) : m_tick_vol(NULL),
                                               m_proximity_factor(3.0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTickSmartTrailing::~CTickSmartTrailing(void)
  {
  }
//+------------------------------------------------------------------+
//| Check Criterion (Override)                                       |
//+------------------------------------------------------------------+
bool CTickSmartTrailing::CheckCriterion(ENUM_POSITION_TYPE pos_type, double pos_open, double pos_sl, double value_sl, MqlTick &tick)
  {
   // 1. Basic Check (Inherited logic from CSimpleTrailing)
   // We manually replicate basic checks because CSimpleTrailing::CheckCriterion is private/protected logic
   // but CSimpleTrailing::CheckCriterion is accessible if protected.
   // Wait, Trailings.mqh defines CheckCriterion as PRIVATE in CSimpleTrailing.
   // This is a problem with the original library design if we want to extend it easily.
   // However, we can reimplement the logic here or modify Trailings.mqh (if allowed).
   // Assuming we can't mod Trailings.mqh, we must reimplement the basic distance check.

   if(NormalizeDouble(pos_sl - value_sl, m_digits) == 0 || value_sl == 0)
      return false;

   // 2. Proximity Rule (The "Smart" Part)
   if(m_tick_vol != NULL)
     {
      double tick_sd = m_tick_vol->GetStdDev();
      double safe_dist = tick_sd * m_proximity_factor;

      // Get Take Profit
      double pos_tp = PositionGetDouble(POSITION_TP);

      if(pos_tp > 0)
        {
         // If New SL is too close to TP, freeze it.
         // Buy: SL is below price. TP is above.
         // Logic: If (TP - NewSL) < SafeDist, risk of noise hitting SL before TP is high?
         // Actually, usually "Knockout" means price hits SL just before TP.
         // If NewSL is very close to current price (Tight Trailing), we check Price vs SL.

         // Let's implement the specific user request: "TS ha közel van a tp hez egy tick kiutheti"
         // This implies: Distance(NewSL, TP) must be large enough?
         // Or Distance(Price, NewSL) must be > TickNoise?

         // Interpretation: Don't move SL so high that it enters the noise zone of the TP target?
         // More likely: Don't trail if (TP - CurrentPrice) is small (we are about to win),
         // because a trailing stop update might tighten the stop too much right at the end.

         double dist_to_tp = MathAbs(pos_tp - value_sl);

         if(dist_to_tp < safe_dist)
           {
            // Too close to TP. Do not modify. Let it hit TP.
            return false;
           }
        }

      // 3. Noise Filter (Distance from Price)
      // Ensure New SL is not within spread + noise of current price
      double spread = (tick.ask - tick.bid);
      double dist_to_price = 0.0;

      if(pos_type == POSITION_TYPE_BUY)
         dist_to_price = tick.bid - value_sl;
      else
         dist_to_price = value_sl - tick.ask;

      if(dist_to_price < (spread + safe_dist))
        {
         // Proposed SL is within noise. Reject modification.
         return false;
        }
     }

   // 4. Standard "Step" check
   double trailing_step = m_trail_step * m_point;

   if(pos_type == POSITION_TYPE_BUY)
     {
      if(pos_sl + trailing_step < value_sl) return true;
     }
   else
     {
      if(pos_sl - trailing_step > value_sl || pos_sl == 0) return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
