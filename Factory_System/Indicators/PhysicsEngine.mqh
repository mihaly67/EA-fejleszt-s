//+------------------------------------------------------------------+
//|                                           PhysicsEngine.mqh |
//|                                                      Jules Agent |
//|                                     Market Physics Calculation Class |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"

struct PhysicsState {
   double velocity;      // Pips/sec
   double acceleration;  // Pips/sec^2
   double volatility;    // StdDev of last N ticks
   double spread_avg;    // Average spread
   long time_ms;         // Timestamp of last update
};

class PhysicsEngine {
private:
   struct TickNode {
      long time_msc;
      double price;
      double ask;
      double bid;
   };

   TickNode m_buffer[];
   int m_head;
   int m_size;
   int m_capacity;

   double m_current_velocity;
   double m_current_acceleration;
   double m_prev_velocity;

public:
   PhysicsEngine(int history_size = 50) {
      m_capacity = history_size;
      ArrayResize(m_buffer, m_capacity);
      Reset();
   }

   void Reset() {
      m_head = 0;
      m_size = 0;
      m_current_velocity = 0;
      m_current_acceleration = 0;
      m_prev_velocity = 0;
   }

   void Update(const MqlTick &tick) {
      // 1. Add to Circular Buffer
      m_buffer[m_head].time_msc = tick.time_msc;
      m_buffer[m_head].price = tick.last;
      if(m_buffer[m_head].price == 0) m_buffer[m_head].price = (tick.bid + tick.ask) / 2.0;
      m_buffer[m_head].ask = tick.ask;
      m_buffer[m_head].bid = tick.bid;

      m_head = (m_head + 1) % m_capacity;
      if(m_size < m_capacity) m_size++;

      // 2. Calculate Metrics (if enough data)
      if(m_size > 5) CalculateMetrics();
   }

   PhysicsState GetState() {
      PhysicsState s;
      s.velocity = m_current_velocity;
      s.acceleration = m_current_acceleration;
      s.volatility = CalculateVolatility();
      s.spread_avg = CalculateAvgSpread();
      s.time_ms = GetTickCount();
      return s;
   }

private:
   void CalculateMetrics() {
      // Simple Linear Regression for Velocity (Slope of Price vs Time)
      // or simpler: Delta Price / Delta Time over last N ticks (e.g. 1 sec window)

      long now = m_buffer[(m_head - 1 + m_capacity) % m_capacity].time_msc;
      long window_start = now - 1000; // 1 second window

      double price_now = m_buffer[(m_head - 1 + m_capacity) % m_capacity].price;
      double price_old = price_now;
      long time_old = now;

      // Find the tick ~1 sec ago
      for(int i=0; i<m_size; i++) {
         int idx = (m_head - 1 - i + m_capacity) % m_capacity;
         if(m_buffer[idx].time_msc <= window_start) {
            price_old = m_buffer[idx].price;
            time_old = m_buffer[idx].time_msc;
            break;
         }
         // If we reached the end of buffer but didn't reach 1 sec, take the oldest
         if(i == m_size - 1) {
            price_old = m_buffer[idx].price;
            time_old = m_buffer[idx].time_msc;
         }
      }

      long dt = now - time_old;
      if(dt < 10) dt = 10; // Avoid div by zero

      double dp = MathAbs(price_now - price_old);

      // Velocity in Points per Second
      double raw_velocity = (dp / _Point) / (dt / 1000.0);

      // Smoothing (EMA)
      double alpha = 0.2;
      m_current_velocity = alpha * raw_velocity + (1.0 - alpha) * m_current_velocity;

      // Acceleration
      double dv = m_current_velocity - m_prev_velocity;
      m_current_acceleration = dv;

      m_prev_velocity = m_current_velocity;
   }

   double CalculateVolatility() {
      // Standard Deviation of Price in buffer
      if(m_size < 2) return 0;

      double sum = 0;
      double sum_sq = 0;

      for(int i=0; i<m_size; i++) {
         int idx = (m_head - 1 - i + m_capacity) % m_capacity;
         double p = m_buffer[idx].price;
         sum += p;
         sum_sq += p * p;
      }

      double mean = sum / m_size;
      double variance = (sum_sq / m_size) - (mean * mean);
      return MathSqrt(variance) / _Point; // In points
   }

   double CalculateAvgSpread() {
      if(m_size < 1) return 0;
      double sum = 0;
      for(int i=0; i<m_size; i++) {
         int idx = (m_head - 1 - i + m_capacity) % m_capacity;
         sum += (m_buffer[idx].ask - m_buffer[idx].bid);
      }
      return (sum / m_size) / _Point;
   }
};
