//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.08.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Orderflow Monitor|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.08"
#property description "Hybrid Tick & Liquidity Delta Monitor"
#property description "Tracks Price Changes AND Volume Changes in DOM"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 0 // No standard lines, visual panel only

#include <Charts/Chart.mqh>

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Real DOM + Hybrid Ticks (Price + Vol Delta)
   MODE_REAL_DOM,    // Csak Valós DOM (Static View)
   MODE_SIMULATION   // Csak Tick alapú szimuláció
  };

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpSignalDepth = 1;                   // JEL Mélység: Csak az első N szintet figyeli a Flow-hoz (1 = Best Bid/Ask)
input int InpVisualDepth = 5;                   // VIZUÁLIS Mélység: Ennyi szintet jelenít meg a 'Real DOM' módban
input long InpVolumeFilter = 5000;              // Zajszűrő: ennél nagyobb volument figyelmen kívül hagy
input int InpSimHistory = 100;                  // Szimuláció: Hány tickre visszamenőleg?
input double InpImbalanceThreshold = 60.0;      // Túlsúly küszöb (%)
input bool InpSimUseTickVolume = true;          // Szimulációnál: Ha real_volume=0, használja a tick_volume-ot?

input group "Hybrid Logic"
input long InpSyntheticTickVolume = 1;          // Alap szintetikus volumen
input bool InpTrackLiquidityChanges = true;     // DOM Volumen változások figyelése (Delta)

input group "Megjelenítés"
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_LOWER;   // Panel pozíció
input int InpXOffset = 50;                              // X eltolás
input int InpYOffset = 100;                             // Y eltolás
input color InpColorBg = clrDarkSlateGray;              // Háttérszín (Kontrasztos)
input color InpColorBuy = clrMediumSeaGreen;            // Vevő (Bull) szín
input color InpColorSell = clrCrimson;                  // Eladó (Bear) szín
input color InpColorNeutral = clrWhite;                 // Semleges/Marker szín (Fehér a láthatóságért)
input color InpTextColor = clrWhite;                    // Szöveg szín

// --- Indicator Buffers (EA Interface) ---
double BufferImbalance[]; // Index 0: Current Imbalance % (-100 to +100)
double BufferBuyFlow[];   // Index 1: Buy Volume Flow
double BufferSellFlow[];  // Index 2: Sell Volume Flow

// --- Globális változók ---
bool g_has_dom = false;
bool g_subscribed = false;
string g_obj_bg = "HybridDOM_BG";
string g_obj_bar_buy = "HybridDOM_BarBuy";
string g_obj_bar_sell = "HybridDOM_BarSell";
string g_obj_center = "HybridDOM_Center";
string g_obj_text = "HybridDOM_Text";
string g_obj_label_buy = "HybridDOM_LabelBuy";
string g_obj_label_sell = "HybridDOM_LabelSell";

// DOM Snapshot a Delta számításhoz
struct DOMLevel {
   double price;
   long volume;
   int type;
};
DOMLevel g_last_dom[]; // Előző állapot másolata

// Szimulációs puffer
struct TickData {
   long volume;
   int type; // 1=Buy, -1=Sell
};
TickData g_tick_history[];

// Globális statisztika
long g_total_bid_display = 0;
long g_total_ask_display = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Buffer Mapping
   SetIndexBuffer(0, BufferImbalance, INDICATOR_DATA);
   SetIndexBuffer(1, BufferBuyFlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufferSellFlow, INDICATOR_DATA);

   // Init Arrays
   ArrayResize(g_tick_history, InpSimHistory);
   for(int i=0; i<InpSimHistory; i++) { g_tick_history[i].volume = 0; g_tick_history[i].type = 0; }

   // Init DOM Snapshot
   ArrayResize(g_last_dom, 0);

   ObjectsDeleteAll(0, "HybridDOM_");

   if(InpMode != MODE_SIMULATION)
     {
      if(MarketBookAdd(_Symbol))
        {
         g_subscribed = true;
         Print("Hybrid DOM v1.08: MarketBook feliratkozás OK (Full Liquidity Tracking).");
        }
      else
        {
         Print("Hybrid DOM v1.08: MarketBook Hiba! Csak Tick módban fut.");
        }
     }

   CreatePanel();
   EventSetTimer(1); // Heartbeat: 1 másodpercenként frissít
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_subscribed) MarketBookRelease(_Symbol);
   ObjectsDeleteAll(0, "HybridDOM_");
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Timer Event (Heartbeat to fix freezing)                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Ha 'MODE_REAL_DOM' módban vagyunk, vagy 'AUTO'-ban, akkor is frissítsük a vizuált,
   // hogy biztosan ne fagyjon be a kép.
   ChartRedraw();
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
   // --- Real Tick Processing ---
   MqlTick last_tick;
   if(SymbolInfoTick(_Symbol, last_tick))
     {
      ProcessRealTick(last_tick);
     }

   // --- Visualization & EA Output ---
   if(InpMode != MODE_REAL_DOM)
     {
      double imb = CalculateSimulationImbalance();
      UpdateVisuals(imb, "Hybrid Flow");

      // EA Output (Save to buffer 0 of current bar)
      BufferImbalance[rates_total-1] = imb;
      BufferBuyFlow[rates_total-1] = (double)g_total_bid_display;
      BufferSellFlow[rates_total-1] = (double)g_total_ask_display;
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function (Liquidity Delta Logic)                       |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      int size = ArraySize(book);
      if(size > 0)
        {
         g_has_dom = true;

         // A) Hybrid: Price Action + Liquidity Delta
         if(InpMode == MODE_AUTO_DETECT)
           {
            bool updated = ProcessHybridLiquidity(book);

            if(updated)
              {
               double imb = CalculateSimulationImbalance();
               UpdateVisuals(imb, "Hybrid Flow");
               ChartRedraw();
              }
           }

         // B) Real DOM (Static View)
         if(InpMode == MODE_REAL_DOM)
           {
            double imbalance = CalculateDOMImbalance(book);
            UpdateVisuals(imbalance, "Real DOM");
            ChartRedraw();
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Logic: Hybrid Liquidity Delta (Symmetric & Depth-Limited)        |
//+------------------------------------------------------------------+
bool ProcessHybridLiquidity(const MqlBookInfo &book[])
  {
   bool activity_detected = false;
   int size = ArraySize(book);

   // 1. Snapshot inicializálás, ha üres
   if(ArraySize(g_last_dom) == 0)
     {
      SaveSnapshot(book);
      return false;
     }

   // 2. Összehasonlítás (Delta Keresés)
   // !!! FONTOS: Csak az InpSignalDepth mélységig vizsgálódunk a jelekhez !!!
   int limit = MathMin(size, InpSignalDepth);

   for(int i=0; i<limit; i++)
     {
      // Szűrés (bár ha Depth=1, akkor ez kevésbé kritikus)
      if(book[i].volume > InpVolumeFilter) continue;

      long old_vol = GetVolumeFromSnapshot(book[i].price, book[i].type);
      long new_vol = book[i].volume;

      long delta = new_vol - old_vol;

      if(delta == 0) continue;

      // --- Szimmetrikus Értelmezés ---
      if(InpTrackLiquidityChanges)
        {
         int signal_type = 0;

         // BID Oldal (Vevők)
         if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
           {
            if(delta > 0) signal_type = 1;  // Support Added (Bullish)
            if(delta < 0) signal_type = -1; // Support Removed (Bearish)
           }

         // ASK Oldal (Eladók)
         if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
           {
            if(delta > 0) signal_type = -1; // Resistance Added (Bearish)
            if(delta < 0) signal_type = 1;  // Resistance Removed (Bullish)
           }

         if(signal_type != 0)
           {
            // Delta súlyozás
            long weight = (long)MathMax(1, MathAbs(delta) / 10);
            if(weight < InpSyntheticTickVolume) weight = InpSyntheticTickVolume;

            AddTickToHistory(signal_type, weight);
            activity_detected = true;
           }
        }
     }

   // 3. Best Price Aggression (Marad a régi logika is)
   CheckBestPriceChange(book, activity_detected);

   // 4. Snapshot Frissítése
   SaveSnapshot(book);

   return activity_detected;
  }

//+------------------------------------------------------------------+
//| Helper: Snapshot kezelés                                         |
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
      // Pontos ár egyezés (double)
      if(MathAbs(g_last_dom[i].price - price) < _Point/2 && g_last_dom[i].type == type)
        {
         return g_last_dom[i].volume;
        }
     }
   return 0; // Új árszint
  }

//+------------------------------------------------------------------+
//| Logic: Best Price Aggression (v1.07 Legacy)                      |
//+------------------------------------------------------------------+
void CheckBestPriceChange(const MqlBookInfo &book[], bool &activity_flag)
  {
   static double last_best_bid = 0;
   static double last_best_ask = 0;

   double best_bid = 0;
   double best_ask = DBL_MAX;

   int size = ArraySize(book);
   for(int i=0; i<size; i++)
     {
      if(book[i].type == BOOK_TYPE_BUY) if(book[i].price > best_bid) best_bid = book[i].price;
      if(book[i].type == BOOK_TYPE_SELL) if(book[i].price < best_ask) best_ask = book[i].price;
     }

   if(best_bid == 0 || best_ask == DBL_MAX) return;

   if(last_best_bid != 0)
     {
      if(best_bid > last_best_bid) { AddTickToHistory(1, InpSyntheticTickVolume); activity_flag = true; }
     }
   if(last_best_ask != 0)
     {
      if(best_ask < last_best_ask) { AddTickToHistory(-1, InpSyntheticTickVolume); activity_flag = true; }
     }

   last_best_bid = best_bid;
   last_best_ask = best_ask;
  }

//+------------------------------------------------------------------+
//| Core Logic: Puffer Hozzáadás                                     |
//+------------------------------------------------------------------+
void AddTickToHistory(int type, long volume)
  {
   if(volume <= 0) return;
   if(type == 0) return;

   for(int i=InpSimHistory-1; i>0; i--)
     {
      g_tick_history[i] = g_tick_history[i-1];
     }

   g_tick_history[0].volume = volume;
   g_tick_history[0].type = type;
  }

//+------------------------------------------------------------------+
//| Logic: Valós Tick Feldolgozása                                   |
//+------------------------------------------------------------------+
void ProcessRealTick(const MqlTick &tick)
  {
   bool isBuy = (tick.flags & TICK_FLAG_BUY) != 0;
   bool isSell = (tick.flags & TICK_FLAG_SELL) != 0;
   long vol = (long)tick.volume_real;
   if(vol == 0 && InpSimUseTickVolume) vol = (long)tick.volume;

   static double last_price = 0;
   if(last_price == 0) { last_price = tick.last; return; }
   bool priceChanged = (tick.last != last_price);

   if(vol == 0 && !priceChanged && !isBuy && !isSell) return;

   int type = 0;
   if(isBuy) type = 1;
   else if(isSell) type = -1;
   else
     {
      if(tick.last > last_price) type = 1;
      else if(tick.last < last_price) type = -1;
     }
   last_price = tick.last;

   if(type != 0)
     {
      long final_vol = (vol > 0) ? vol : 1;
      AddTickToHistory(type, final_vol);
     }
  }

//+------------------------------------------------------------------+
//| Logika: DOM Imbalance Számítás (Visual/Static)                   |
//+------------------------------------------------------------------+
double CalculateDOMImbalance(const MqlBookInfo &book[])
  {
   long total_bid = 0;
   long total_ask = 0;
   int size = ArraySize(book);
   int bid_count = 0;
   int ask_count = 0;

   // Itt használjuk az InpVisualDepth-et!
   for(int i=0; i<size; i++)
     {
      if(book[i].volume > InpVolumeFilter) continue;

      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
        {
         if(bid_count < InpVisualDepth) { total_bid += book[i].volume; bid_count++; }
        }
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
        {
         if(ask_count < InpVisualDepth) { total_ask += book[i].volume; ask_count++; }
        }
     }

   g_total_bid_display = total_bid;
   g_total_ask_display = total_ask;

   long total = total_bid + total_ask;
   if(total == 0) return 0.0;
   double buy_ratio = (double)total_bid / (double)total;
   return (buy_ratio * 2.0 - 1.0) * 100.0;
  }

double CalculateSimulationImbalance()
  {
   long buy_vol = 0;
   long sell_vol = 0;
   for(int i=0; i<InpSimHistory; i++)
     {
      if(g_tick_history[i].type == 1) buy_vol += g_tick_history[i].volume;
      else if(g_tick_history[i].type == -1) sell_vol += g_tick_history[i].volume;
     }
   g_total_bid_display = buy_vol;
   g_total_ask_display = sell_vol;
   long total = buy_vol + sell_vol;
   if(total == 0) return 0.0;
   double buy_ratio = (double)buy_vol / (double)total;
   return (buy_ratio * 2.0 - 1.0) * 100.0;
  }

//+------------------------------------------------------------------+
//| Megjelenítés (Vizuális Fixek v1.08)                              |
//+------------------------------------------------------------------+
void UpdateVisuals(double imbalance_percent, string source_label)
  {
   int width = 200;
   int center = width / 2;

   int bar_len = (int)(MathAbs(imbalance_percent) / 100.0 * (width / 2));
   if(bar_len > width/2) bar_len = width/2;
   if(bar_len < 1) bar_len = 1;

   color bar_color = InpColorNeutral;
   if(imbalance_percent > 10) bar_color = InpColorBuy;
   else if(imbalance_percent < -10) bar_color = InpColorSell;

   if(imbalance_percent < -0.1) // Sell
     {
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, InpXOffset + center - bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
     }
   else if(imbalance_percent > 0.1) // Buy
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, InpXOffset + center);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }
   else
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }

   string txt = StringFormat("%s: %.1f%% (B:%d S:%d)", source_label, imbalance_percent, g_total_bid_display, g_total_ask_display);
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, txt);
  }

void CreatePanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int w = 220;
   int h = 60; // Növelt magasság a szövegeknek
   int bar_h = 20;
   int bar_y = y + 30;

   // 1. Háttér (Kontrasztos)
   ObjectCreate(0, g_obj_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BGCOLOR, InpColorBg);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BACK, false); // Előtérben legyen

   // 2. Középvonal (Széles és Fehér)
   ObjectCreate(0, g_obj_center, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_center, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_center, OBJPROP_XDISTANCE, x + w/2 - 1);
   ObjectSetInteger(0, g_obj_center, OBJPROP_YDISTANCE, bar_y - 2); // Kicsit túllóg
   ObjectSetInteger(0, g_obj_center, OBJPROP_XSIZE, 3); // Vastagabb!
   ObjectSetInteger(0, g_obj_center, OBJPROP_YSIZE, bar_h + 4);
   ObjectSetInteger(0, g_obj_center, OBJPROP_BGCOLOR, InpColorNeutral);
   ObjectSetInteger(0, g_obj_center, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_obj_center, OBJPROP_ZORDER, 10); // Minden felett

   // 3. Bal Sáv (Sell)
   ObjectCreate(0, g_obj_bar_sell, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, x + w/2);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_YDISTANCE, bar_y);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_YSIZE, bar_h);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, InpColorSell);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // 4. Jobb Sáv (Buy)
   ObjectCreate(0, g_obj_bar_buy, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, x + w/2);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_YDISTANCE, bar_y);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_YSIZE, bar_h);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BGCOLOR, InpColorBuy);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // 5. Szöveg
   ObjectCreate(0, g_obj_text, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_text, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_text, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, g_obj_text, OBJPROP_YDISTANCE, y + 2);
   ObjectSetInteger(0, g_obj_text, OBJPROP_COLOR, InpTextColor);
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, "Init...");
   ObjectSetString(0, g_obj_text, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, g_obj_text, OBJPROP_FONTSIZE, 9);

   // 6. Címkék (BUY / SELL)
   ObjectCreate(0, g_obj_label_sell, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_label_sell, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_label_sell, OBJPROP_XDISTANCE, x + 10);
   ObjectSetInteger(0, g_obj_label_sell, OBJPROP_YDISTANCE, bar_y + bar_h + 2);
   ObjectSetInteger(0, g_obj_label_sell, OBJPROP_COLOR, InpColorSell);
   ObjectSetString(0, g_obj_label_sell, OBJPROP_TEXT, "SELL");

   ObjectCreate(0, g_obj_label_buy, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_label_buy, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_label_buy, OBJPROP_XDISTANCE, x + w - 40);
   ObjectSetInteger(0, g_obj_label_buy, OBJPROP_YDISTANCE, bar_y + bar_h + 2);
   ObjectSetInteger(0, g_obj_label_buy, OBJPROP_COLOR, InpColorBuy);
   ObjectSetString(0, g_obj_label_buy, OBJPROP_TEXT, "BUY");
  }
