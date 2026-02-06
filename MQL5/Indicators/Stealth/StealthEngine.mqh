//+------------------------------------------------------------------+
//|                                                StealthEngine.mqh |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property strict

//+------------------------------------------------------------------+
//| StealthEngine - The Core of "Total Chaos"                        |
//| Implements advanced obfuscation:                                 |
//| 1. Temporal Chaos (Latency, Jitter, Non-linear Delays)           |
//| 2. Spatial Chaos (Grid Asymmetry, Price Offsets)                 |
//| 3. Identity Obfuscation (Magic Rotation, Nonces)                 |
//|                                                                  |
//| Based on research from "Thief's Library" (Hummingbot) and        |
//| "Colombo" (Adversarial Detection avoidance).                     |
//+------------------------------------------------------------------+
class StealthEngine
{
private:
   bool   m_initialized;
   double m_chaos_level;
   int    m_lat_min;
   int    m_lat_max;

   // Box-Muller Transform for Gaussian Noise
   // Returns a standard normal deviate (mean=0, std=1)
   double MathRandGaussian()
   {
      double u1 = 0.0;
      double u2 = 0.0;

      // Avoid 0 for log
      while(u1 <= 0.0) u1 = (double)MathRand() / 32767.0;
      u2 = (double)MathRand() / 32767.0;

      double r = MathSqrt(-2.0 * MathLog(u1));
      double theta = 2.0 * M_PI * u2;

      return r * MathCos(theta);
   }

public:
   StealthEngine()
   {
      m_initialized = false;
      m_chaos_level = 1.0;
      m_lat_min = 50;
      m_lat_max = 200;
   }

   void Initialize(double chaos_level, int lat_min, int lat_max)
   {
      m_chaos_level = chaos_level;
      m_lat_min = lat_min;
      m_lat_max = lat_max;

      // Seeding global generator
      MathSrand(GetTickCount());
      m_initialized = true;
   }

   //------------------------------------------------------------------
   // TEMPORAL CHAOS
   //------------------------------------------------------------------

   // Returns a randomized delay in milliseconds
   // Uses Log-Normal distribution tendency (skewed towards faster but with tails)
   // or simple Uniform depending on 'chaos_level'
   int GetExecutionDelay(int min_ms, int max_ms)
   {
      if(min_ms >= max_ms) return min_ms;

      // Simple uniform for now, but could be upgraded
      int range = max_ms - min_ms;
      int delay = min_ms + (MathRand() % range);
      return delay;
   }

   // Inject a thread sleep (Use carefully in main loop!)
   void ApplyLatency(int min_ms, int max_ms)
   {
      // Use class members as primary configuration
      int lower = (m_lat_min > 0) ? m_lat_min : min_ms;
      int upper = (m_lat_max > 0) ? m_lat_max : max_ms;

      int delay = GetExecutionDelay(lower, upper);
      if(delay > 0) Sleep(delay);
   }

   // Calculate next wake-up time with Jitter
   ulong GetNextWakeup(ulong current_time, int base_interval_sec, double jitter_pct=0.2)
   {
      double noise = MathRandGaussian() * (base_interval_sec * jitter_pct);
      // Ensure we don't go negative or too short
      long interval = (long)(base_interval_sec + noise);
      if(interval < 1) interval = 1;

      return current_time + (ulong)interval;
   }

   //------------------------------------------------------------------
   // SPATIAL CHAOS
   //------------------------------------------------------------------

   // Apply Gaussian Jitter to Spread Target
   // base_spread: The tactical target (e.g. 15 points)
   // intensity: Deviation factor (e.g. 0.1 for 10% deviation)
   double GetJitterSpread(double base_spread, double intensity=0.15)
   {
      intensity *= m_chaos_level; // Scale by User Config
      double noise = MathRandGaussian() * (base_spread * intensity);
      double res = base_spread + noise;
      if(res < 0) res = base_spread; // Safety
      return res;
   }

   // Apply Jitter to Grid Step
   // Ensures that grid lines are not perfectly spaced
   double GetJitterStep(double base_step, double intensity=0.1)
   {
      intensity *= m_chaos_level; // Scale by User Config
      double noise = MathRandGaussian() * (base_step * intensity);
      double res = base_step + noise;
      if(res < base_step * 0.5) res = base_step * 0.5; // Don't collapse too much
      return res;
   }

   // Apply Micro-Offset to Price (Anti-Clustering)
   // Prevents orders from stacking exactly on Round Numbers or exact Spread lines
   double GetJitterPrice(double price, double point, int max_points_offset=2)
   {
      int offset = (MathRand() % (max_points_offset * 2 + 1)) - max_points_offset;
      // e.g. -2 to +2 points
      return price + (offset * point);
   }

   //------------------------------------------------------------------
   // ASYMMETRY (Total Chaos)
   //------------------------------------------------------------------

   // Generates distinct parameters for Buy vs Sell to avoid Mirroring
   void GetAsymmetricParams(
      double base_step,
      double &out_buy_step,
      double &out_sell_step
   )
   {
      // Independent calls to RNG ensure divergence
      out_buy_step = GetJitterStep(base_step, 0.12); // Slightly different intensity
      out_sell_step = GetJitterStep(base_step, 0.15);

      // Force at least some difference?
      // No, let the Gaussian chaos handle it.
   }

   //------------------------------------------------------------------
   // IDENTITY & METADATA
   //------------------------------------------------------------------

   // Rotate Magic Number within a safe range
   long GetRotatedMagic(long base_magic, int variance=500)
   {
      // e.g. 12345000 -> 12345492
      return base_magic + (MathRand() % variance);
   }

   // Create a unique Action Nonce (Timestamp + Random)
   string GetActionNonce()
   {
      return StringFormat("%I64u-%d", GetTickCount(), MathRand() % 1000);
   }

   //------------------------------------------------------------------
   // FINGERPRINT CHAOS (Metadata & Behavioral)
   //------------------------------------------------------------------

   // Decide whether to use Atomic (Immediate) SL/TP or Human (Delayed) mode
   // Returns: 0 = Atomic, 1 = Human (Split)
   int GetOrderMode()
   {
      // 30% chance of "Human" split execution to mix patterns
      if ((MathRand() % 100) < 30) return 1;
      return 0;
   }

   // Generate a disguised comment
   string GetHumanizedComment(string prefix)
   {
      string comments[] = {"", " ", "mobile", "ios", "android", "web", "sl", "tp", "target"};
      int r = MathRand() % 15; // Range larger than array to allow 'default'

      if(r < ArraySize(comments)) return comments[r];

      // Otherwise, use prefix + random hash
      return prefix + "_" + IntegerToString(MathRand()%100);
   }

   // Randomize Order Expiration (Day vs Specified vs GTC)
   // In MT5, GTC is default. We can mix it up.
   void GetRandomExpiration(ENUM_ORDER_TYPE_TIME &out_type, datetime &out_time)
   {
      int r = MathRand() % 100;

      if(r < 80) {
         out_type = ORDER_TIME_GTC;
         out_time = 0;
      } else if (r < 95) {
         out_type = ORDER_TIME_DAY;
         out_time = 0;
      } else {
         out_type = ORDER_TIME_SPECIFIED;
         // Expire in 24-48 hours randomly
         out_time = TimeCurrent() + 86400 + (MathRand() % 86400);
      }
   }
};
