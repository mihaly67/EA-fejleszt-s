//+------------------------------------------------------------------+
//|                                    Hybrid_Synthetic_Bars_v1.09.mq5 |
//|                                                      Jules Agent |
//|                                     Hybrid System - Synthetic M1 |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.09"
#property description "Generates Synthetic M1 Candles based on DOM Flow"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 1
#property indicator_type1 DRAW_CANDLES
#property indicator_color1 clrMediumSeaGreen, clrCrimson, clrGray
#property indicator_label1 "Open;High;Low;Close"

// --- Inputs ---
input group "Beállítások"
input int InpSignalDepth = 1;                   // JEL Mélység: Csak az első N szintet figyeli
input double InpSensitivity = 0.1;              // Érzékenység: 1 Lot Flow mennyi 'Pontot' mozgat a gyertyán?
input long InpVolumeFilter = 5000;              // Zajszűrő

input group "Hybrid Logic"
input long InpSyntheticTickVolume = 1;          // Alap szintetikus volumen
input bool InpTrackLiquidityChanges = true;     // DOM Volumen változások figyelése

// --- Buffers ---
double ExtOpenBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];
double ExtCloseBuffer[];

// --- Globals ---
double g_current_price = 0.0;
double g_bar_open = 0.0;
datetime g_last_time = 0;

// DOM State
struct DOMLevel {
   double price;
   long volume;
   int type;
};
DOMLevel g_last_dom[];
double g_last_best_bid = 0.0;
double g_last_best_ask = 0.0;

bool g_subscribed = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtOpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtLowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ExtCloseBuffer, INDICATOR_DATA);

   ArraySetAsSeries(ExtOpenBuffer, false); // Normal indexing
   ArraySetAsSeries(ExtHighBuffer, false);
   ArraySetAsSeries(ExtLowBuffer, false);
   ArraySetAsSeries(ExtCloseBuffer, false);

   if(MarketBookAdd(_Symbol)) g_subscribed = true;

   g_current_price = 0;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_subscribed) MarketBookRelease(_Symbol);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 2) return 0;

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   // Initialize history with flat bars if needed (visual fix)
   for(int i=start; i<rates_total-1; i++)
     {
      ExtOpenBuffer[i] = close[i];
      ExtHighBuffer[i] = close[i];
      ExtLowBuffer[i] = close[i];
      ExtCloseBuffer[i] = close[i];
     }

   // --- Real Tick Processing (Only for current bar) ---
   MqlTick last_tick;
   if(SymbolInfoTick(_Symbol, last_tick))
     {
      ProcessTickFlow(last_tick, rates_total, time[rates_total-1], close[rates_total-1]);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;

   // We need 'rates_total' context. Since OnBookEvent doesn't have it,
   // we have to rely on the last known state or use iTime/iClose.
   // Ideally, we just update the buffers at 'Bars(_Symbol, _Period) - 1'.

   int rates_total = Bars(_Symbol, _Period);
   datetime current_time = iTime(_Symbol, _Period, 0);
   double real_close = iClose(_Symbol, _Period, 0); // Use real close as anchor? No, we build our own.

   // Actually, we maintain our own 'g_current_price'.

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      ProcessHybridLiquidity(book, rates_total);
     }
}

//+------------------------------------------------------------------+
//| Logic: Update the Synthetic Candle                               |
//+------------------------------------------------------------------+
void UpdateCandle(int rates_total, double price_delta)
  {
   int i = rates_total - 1;

   // Check for New Bar
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time != g_last_time)
     {
      // New Bar: Reset anchor
      // We start the new bar at the PREVIOUS synthetic close
      if(g_last_time != 0 && i > 0)
        {
         g_bar_open = ExtCloseBuffer[i-1];
        }
      else
        {
         g_bar_open = iOpen(_Symbol, _Period, 0); // First run fallback
         g_current_price = g_bar_open;
        }

      g_last_time = current_bar_time;

      // Init new bar
      ExtOpenBuffer[i] = g_bar_open;
      ExtHighBuffer[i] = g_bar_open;
      ExtLowBuffer[i] = g_bar_open;
      ExtCloseBuffer[i] = g_bar_open;
     }

   // Apply Delta
   // 1 Point movement in flow = InpSensitivity Points in Price
   double move = price_delta * _Point * InpSensitivity;
   g_current_price += move;

   // Update Buffers
   ExtCloseBuffer[i] = g_current_price;
   if(g_current_price > ExtHighBuffer[i]) ExtHighBuffer[i] = g_current_price;
   if(g_current_price < ExtLowBuffer[i]) ExtLowBuffer[i] = g_current_price;

   // Force redraw
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Logic: Hybrid Liquidity Delta (Identical to v1.08)               |
//+------------------------------------------------------------------+
void ProcessHybridLiquidity(const MqlBookInfo &book[], int rates_total)
  {
   int size = ArraySize(book);
   if(ArraySize(g_last_dom) == 0) { SaveSnapshot(book); return; }

   int limit = MathMin(size, InpSignalDepth);

   double total_flow = 0;

   for(int i=0; i<limit; i++)
     {
      long old_vol = GetVolumeFromSnapshot(book[i].price, book[i].type);
      long new_vol = book[i].volume;
      long delta = new_vol - old_vol;

      if(delta == 0) continue;

      if(InpTrackLiquidityChanges)
        {
         int signal = 0;
         if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
           {
            if(delta > 0) signal = 1;  // Bull
            if(delta < 0) signal = -1; // Bear
           }
         if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
           {
            if(delta > 0) signal = -1; // Bear
            if(delta < 0) signal = 1;  // Bull
           }

         // Weighting: 10 lots = 1 unit of flow
         double weight = (double)MathAbs(delta) / 10.0;
         if(weight < 1.0) weight = 1.0;

         total_flow += (signal * weight);
        }
     }

   SaveSnapshot(book);

   if(total_flow != 0)
     {
      UpdateCandle(rates_total, total_flow);
     }
  }

//+------------------------------------------------------------------+
//| Process Real Ticks                                               |
//+------------------------------------------------------------------+
void ProcessTickFlow(const MqlTick &tick, int rates_total, datetime time, double real_close)
  {
   // Initialize current price if 0
   if(g_current_price == 0) g_current_price = real_close;

   // 1. Price Action
   static double last_price = 0;
   if(last_price == 0) last_price = tick.last;

   double price_diff_points = (tick.last - last_price) / _Point;
   last_price = tick.last;

   // Real price moves count as 1:1 (or scaled?)
   // Let's say Real Price moves are dominant.
   // But wait, if the chart is flat, price_diff is 0.

   double flow = 0;
   if(price_diff_points != 0) flow = price_diff_points * 10; // Strong weight for real price

   // 2. Volume Flow (if no price change but volume exists)
   // ... (Simplified: just rely on DOM for the synthetic part)

   if(flow != 0)
     UpdateCandle(rates_total, flow);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void SaveSnapshot(const MqlBookInfo &book[])
  {
   int size = ArraySize(book);
   ArrayResize(g_last_dom, size);
   for(int i=0; i<size; i++)
     {
      g_last_dom[i].price = book[i].price;
      g_last_dom[i].volume = book[i].volume;
      g_last_dom[i].type = book[i].type;
     }
  }

long GetVolumeFromSnapshot(double price, int type)
  {
   int size = ArraySize(g_last_dom);
   for(int i=0; i<size; i++)
     {
      if(MathAbs(g_last_dom[i].price - price) < _Point/2 && g_last_dom[i].type == type)
        return g_last_dom[i].volume;
     }
   return 0;
  }
