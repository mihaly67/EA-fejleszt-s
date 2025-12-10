//+------------------------------------------------------------------+
//|                                               TickVolatility.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Class for calculating running Tick Standard Deviation (Welford)  |
//+------------------------------------------------------------------+
class CTickVolatility
  {
private:
   double            m_mean;              // Running mean of price changes
   double            m_M2;                // Sum of squares of differences
   int               m_count;             // Number of ticks processed
   int               m_window_size;       // Rolling window size (if we were limited, but Welford is infinite stream usually.
                                          // Here we reset after N ticks to keep local volatility relevance).

   double            m_last_price;        // Price of the previous tick

public:
                     CTickVolatility(void);
                    ~CTickVolatility(void);

   // Initialize with window size (e.g., 1000 ticks for short-term volatility)
   void              Init(int window_size=1000);

   // Add a new tick price (usually Bid)
   void              Update(double current_price);

   // Get the current Standard Deviation of price changes
   double            GetStdDev(void);

   // Get the current Variance
   double            GetVariance(void);

   // Reset statistics (e.g., on new bar or session start)
   void              Reset(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTickVolatility::CTickVolatility(void) : m_mean(0.0),
                                         m_M2(0.0),
                                         m_count(0),
                                         m_window_size(1000),
                                         m_last_price(0.0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTickVolatility::~CTickVolatility(void)
  {
  }
//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CTickVolatility::Init(int window_size)
  {
   m_window_size = window_size;
   Reset();
  }
//+------------------------------------------------------------------+
//| Reset statistics                                                 |
//+------------------------------------------------------------------+
void CTickVolatility::Reset(void)
  {
   m_mean  = 0.0;
   m_M2    = 0.0;
   m_count = 0;
   m_last_price = 0.0;
  }
//+------------------------------------------------------------------+
//| Update with new tick price                                       |
//+------------------------------------------------------------------+
void CTickVolatility::Update(double current_price)
  {
   // If first tick, just store price
   if(m_last_price == 0.0)
     {
      m_last_price = current_price;
      return;
     }

   // Calculate price change (delta)
   double delta_price = current_price - m_last_price;

   // Update last price
   m_last_price = current_price;

   // If window full, simple reset to keep it "local" (Approximate rolling)
   // A true rolling Welford is complex, this "Reset & Rebuild" is a safe approximation for scalping regimes.
   // Or better: Decay the stats.
   // Let's implement Decay factor for "Exponential Moving Variance" behavior which is better for "Local" volatility.
   // Actually, let's stick to standard Welford but reset every Window Size to avoid infinite history weight.

   m_count++;

   // Welford's Algorithm
   double delta = delta_price - m_mean;
   m_mean += delta / m_count;
   double delta2 = delta_price - m_mean;
   m_M2 += delta * delta2;

   // Auto-reset if window exceeded to keep adaptation high
   if(m_count >= m_window_size)
     {
      // Keep current mean, but reduce weight (M2) to 50% to "forget" old history slowly
      // This is a heuristic. For strict correctness, we'd just Reset().
      Reset();
      // Re-initialize with current price to avoid jump
      m_last_price = current_price;
     }
  }
//+------------------------------------------------------------------+
//| Get Variance                                                     |
//+------------------------------------------------------------------+
double CTickVolatility::GetVariance(void)
  {
   if(m_count < 2) return 0.0;
   return m_M2 / (m_count - 1);
  }
//+------------------------------------------------------------------+
//| Get Standard Deviation                                           |
//+------------------------------------------------------------------+
double CTickVolatility::GetStdDev(void)
  {
   return MathSqrt(GetVariance());
  }
//+------------------------------------------------------------------+
