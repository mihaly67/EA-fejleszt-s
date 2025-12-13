//+------------------------------------------------------------------+
//|                                            Amplitude_Booster.mqh |
//|                                                   Jules Assistant|
//|                                  Automatic Gain Control (AGC) Lib|
//|                                       Verified Compilation Header|
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property strict

//+------------------------------------------------------------------+
//| Class: CAmplitudeBooster                                         |
//| Purpose: Restores signal amplitude after heavy smoothing         |
//+------------------------------------------------------------------+
class CAmplitudeBooster
  {
private:
   double            m_buffer[];
   int               m_period;
   int               m_index;
   int               m_count;
   bool              m_use_ift;
   double            m_ift_gain;

public:
   // Constructor
   CAmplitudeBooster(void) : m_period(50), m_index(0), m_count(0), m_use_ift(true), m_ift_gain(1.5)
     {
      ArrayResize(m_buffer, m_period);
      ArrayInitialize(m_buffer, 0.0);
     }

   ~CAmplitudeBooster(void) {}

   // Initialization
   void Init(int lookback_period, bool use_ift = true, double ift_gain = 1.5)
     {
      if(lookback_period < 2) lookback_period = 2;
      m_period = lookback_period;
      m_use_ift = use_ift;
      m_ift_gain = ift_gain;

      ArrayResize(m_buffer, m_period);
      ArrayInitialize(m_buffer, 0.0);
      m_index = 0;
      m_count = 0;
     }

   // Core Update Function: Adds new value and returns normalized boost
   double Update(double raw_input)
     {
      // 1. Update Circular Buffer
      m_buffer[m_index] = raw_input;
      m_index++;
      if(m_index >= m_period) m_index = 0;
      if(m_count < m_period) m_count++;

      // Need enough data
      if(m_count < m_period) return 0.0;

      // 2. Find Range (Min/Max)
      double min_val = m_buffer[0];
      double max_val = m_buffer[0];

      for(int i = 1; i < m_count; i++)
        {
         if(m_buffer[i] < min_val) min_val = m_buffer[i];
         if(m_buffer[i] > max_val) max_val = m_buffer[i];
        }

      // 3. AGC Calculation
      // Normalize to 0..1 then -0.5..0.5
      double range = max_val - min_val;
      double normalized = 0.0;

      if(range > 0.00000001) // Avoid div by zero
        {
         normalized = (raw_input - min_val) / range; // 0..1
         normalized = normalized - 0.5;              // -0.5..0.5
        }

      // 4. Boost / IFT
      // Scale to approx -2..2 for IFT to work well
      double scaled = normalized * 4.0;

      if(m_use_ift)
        {
         return IFT(scaled);
        }
      else
        {
         // Linear boost to -1..1 range
         return normalized * 2.0;
        }
     }

   // Inverse Fisher Transform
   double IFT(double x)
     {
      double e2x = MathExp(2 * x * m_ift_gain);
      return (e2x - 1) / (e2x + 1);
     }
  };
//+------------------------------------------------------------------+
