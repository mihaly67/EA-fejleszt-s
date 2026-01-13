//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.07.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Orderflow Monitor|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.07"
#property indicator_chart_window
#property indicator_plots 0

#include <Charts/Chart.mqh>

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Real DOM + Hybrid Ticks
   MODE_REAL_DOM,    // Csak Valós DOM (MarketBook)
   MODE_SIMULATION   // Csak Tick alapú szimuláció
  };

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpDepthLimit = 5;                    // Mélység szűrő (csak az első N szint)
input long InpVolumeFilter = 5000;              // Zajszűrő: ennél nagyobb volument figyelmen kívül hagy (CFD falak)
input int InpSimHistory = 100;                  // Szimuláció: Hány tickre visszamenőleg?
input double InpImbalanceThreshold = 60.0;      // Túlsúly küszöb (%) a színezéshez
input bool InpSimUseTickVolume = true;          // Szimulációnál: Ha real_volume=0, használja a tick_volume-ot?

input group "Hybrid Tick (Szintetikus)"
input long InpSyntheticTickVolume = 1;          // Szintetikus Tick volumene (DOM mozgásnál)

input group "Megjelenítés"
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_LOWER;   // Panel pozíció (Alap: Bal Alsó)
input int InpXOffset = 50;                              // X eltolás
input int InpYOffset = 100;                             // Y eltolás
input color InpColorBuy = clrMediumSeaGreen;            // Vevő szín
input color InpColorSell = clrCrimson;                  // Eladó szín
input color InpColorNeutral = clrDimGray;               // Semleges szín
input color InpTextColor = clrWhite;                    // Szöveg szín

// --- Globális változók ---
bool g_has_dom = false;
bool g_subscribed = false;
string g_obj_bg = "HybridDOM_BG";
string g_obj_bar_buy = "HybridDOM_BarBuy";
string g_obj_bar_sell = "HybridDOM_BarSell";
string g_obj_center = "HybridDOM_Center";
string g_obj_text = "HybridDOM_Text";

// Hybrid Tick State
double g_last_best_bid = 0.0;
double g_last_best_ask = 0.0;

// Szimulációs puffer
struct TickData {
   long volume;
   int type; // 1=Buy, -1=Sell
};
TickData g_tick_history[];

// Globális statisztika a vizualizációhoz
long g_total_bid_display = 0;
long g_total_ask_display = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, "HybridDOM_");

   ArrayResize(g_tick_history, InpSimHistory);
   for(int i=0; i<InpSimHistory; i++) { g_tick_history[i].volume = 0; g_tick_history[i].type = 0; }

   // Inicializáljuk a DOM változókat
   g_last_best_bid = 0.0;
   g_last_best_ask = 0.0;

   // Feliratkozás DOM-ra, kivéve ha csak SIMULATION mód van
   if(InpMode != MODE_SIMULATION)
     {
      if(MarketBookAdd(_Symbol))
        {
         g_subscribed = true;
         Print("Hybrid DOM: MarketBook feliratkozás sikeres.");
        }
      else
        {
         Print("Hybrid DOM: Hiba a MarketBook feliratkozásnál! (Csak Tick mód)");
        }
     }

   CreatePanel();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_subscribed) MarketBookRelease(_Symbol);
   ObjectsDeleteAll(0, "HybridDOM_");
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
   MqlTick last_tick;
   if(SymbolInfoTick(_Symbol, last_tick))
     {
      // 1. Valós Tick Feldolgozása
      ProcessRealTick(last_tick);
     }

   // 2. Megjelenítés Frissítése (Szimulációs Puffer alapján)
   // Ha REAL_DOM módban vagyunk, akkor az OnBookEvent frissíti a vizuált,
   // de ha AUTO vagy SIM módban, akkor a puffer (Tick Flow) a mérvadó.

   if(InpMode != MODE_REAL_DOM)
     {
      double imb = CalculateSimulationImbalance();
      UpdateVisuals(imb, "Hybrid Flow");
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function (Hybrid Logic)                                |
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

         // A) Szintetikus Tick Generálás (Hybrid Tick)
         if(InpMode == MODE_AUTO_DETECT)
           {
            bool updated = ProcessHybridTicks(book);
            // KULCSFONTOSSÁGÚ: Ha történt szintetikus tick (vagy csak frissíteni akarjuk a nézetet),
            // azonnal rajzoljuk újra, ne várjunk a következő OnCalculate-re!
            if(updated)
              {
               double imb = CalculateSimulationImbalance();
               UpdateVisuals(imb, "Hybrid Flow");
               ChartRedraw();
              }
           }

         // B) Real DOM Vizualizáció (Ha ez a választott mód)
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
//| Core Logic: Puffer Hozzáadás (Fusion Point)                      |
//+------------------------------------------------------------------+
void AddTickToHistory(int type, long volume)
  {
   if(volume <= 0) return;
   if(type == 0) return;

   // Shift history
   for(int i=InpSimHistory-1; i>0; i--)
     {
      g_tick_history[i] = g_tick_history[i-1];
     }

   // Új adat mentése
   g_tick_history[0].volume = volume;
   g_tick_history[0].type = type;
  }

//+------------------------------------------------------------------+
//| Logic: Valós Tick Feldolgozása (v1.07)                           |
//+------------------------------------------------------------------+
void ProcessRealTick(const MqlTick &tick)
  {
   // 1. Irány meghatározása
   bool isBuy = (tick.flags & TICK_FLAG_BUY) != 0;
   bool isSell = (tick.flags & TICK_FLAG_SELL) != 0;

   // 2. Volumen
   long vol = (long)tick.volume_real;
   if(vol == 0 && InpSimUseTickVolume) vol = (long)tick.volume;

   static double last_price = 0;
   if(last_price == 0) { last_price = tick.last; return; }

   bool priceChanged = (tick.last != last_price);

   // Zajszűrés: Ha nincs volumen és nincs ármozgás, eldobjuk (keep alive tick)
   if(vol == 0 && !priceChanged && !isBuy && !isSell) return;

   int type = 0;
   if(isBuy) type = 1;
   else if(isSell) type = -1;
   else
     {
      // Fallback Price Action
      if(tick.last > last_price) type = 1;
      else if(tick.last < last_price) type = -1;
     }

   last_price = tick.last;

   // Ha sikerült típust meghatározni, hozzáadjuk a pufferhez
   // Ha a volumen 0, de volt mozgás, akkor 1-nek vesszük (hogy látszódjon)
   if(type != 0)
     {
      long final_vol = (vol > 0) ? vol : 1;
      AddTickToHistory(type, final_vol);
     }
  }

//+------------------------------------------------------------------+
//| Logic: Hybrid Tick Generálás (DOM alapján)                       |
//+------------------------------------------------------------------+
bool ProcessHybridTicks(const MqlBookInfo &book[])
  {
   // 1. Legjobb Bid/Ask keresése
   double best_bid = 0;
   double best_ask = 0;
   int size = ArraySize(book);

   // Feltételezzük, hogy a tömb rendezett, de a biztonság kedvéért keressük meg
   // MQL5 BookInfo: Sell orders (Ask) are usually at the beginning/end depending on view,
   // but generally defined by TYPE.

   // Egyszerűsítés: Keressük a legmagasabb Bid-et és legalacsonyabb Ask-ot
   double max_bid = 0;
   double min_ask = DBL_MAX;

   bool found_bid = false;
   bool found_ask = false;

   for(int i=0; i<size; i++)
     {
      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
        {
         if(book[i].price > max_bid) max_bid = book[i].price;
         found_bid = true;
        }
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
        {
         if(book[i].price < min_ask) min_ask = book[i].price;
         found_ask = true;
        }
     }

   if(!found_bid || !found_ask) return false; // Nincs teljes könyv

   best_bid = max_bid;
   best_ask = min_ask;

   // 2. Inicializálás
   if(g_last_best_bid == 0.0) { g_last_best_bid = best_bid; g_last_best_ask = best_ask; return false; }

   bool tick_generated = false;

   // 3. Változás Detektálása (Hybrid Logic)

   // A) Buy Pressure: A vevők feljebb léptették a Bid-et (Aggresszív)
   if(best_bid > g_last_best_bid)
     {
      // Szintetikus BUY
      AddTickToHistory(1, InpSyntheticTickVolume);
      tick_generated = true;
     }

   // B) Sell Pressure: Az eladók lejjebb léptették az Ask-ot (Aggresszív)
   if(best_ask < g_last_best_ask)
     {
      // Szintetikus SELL
      AddTickToHistory(-1, InpSyntheticTickVolume);
      tick_generated = true;
     }

   // C) Frissítés
   g_last_best_bid = best_bid;
   g_last_best_ask = best_ask;

   return tick_generated;
  }

//+------------------------------------------------------------------+
//| Logika: DOM Imbalance Számítás (Hagyományos)                     |
//+------------------------------------------------------------------+
double CalculateDOMImbalance(const MqlBookInfo &book[])
  {
   long total_bid = 0;
   long total_ask = 0;
   int size = ArraySize(book);

   int bid_count = 0;
   int ask_count = 0;

   for(int i=0; i<size; i++)
     {
      if(book[i].volume > InpVolumeFilter) continue; // Fal szűrés

      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
        {
         if(bid_count < InpDepthLimit)
           {
            total_bid += book[i].volume;
            bid_count++;
           }
        }

      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
        {
         if(ask_count < InpDepthLimit)
           {
            total_ask += book[i].volume;
            ask_count++;
           }
        }
     }

   g_total_bid_display = total_bid;
   g_total_ask_display = total_ask;

   long total = total_bid + total_ask;
   if(total == 0) return 0.0;

   double buy_ratio = (double)total_bid / (double)total;
   return (buy_ratio * 2.0 - 1.0) * 100.0;
  }

//+------------------------------------------------------------------+
//| Logika: Szimuláció Imbalance (Flow alapú)                        |
//+------------------------------------------------------------------+
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
//| Megjelenítés Frissítése                                          |
//+------------------------------------------------------------------+
void UpdateVisuals(double imbalance_percent, string source_label)
  {
   int width = 200;
   int center = width / 2;

   int bar_len = (int)(MathAbs(imbalance_percent) / 100.0 * (width / 2));
   if(bar_len > width/2) bar_len = width/2; // Clip
   if(bar_len < 1) bar_len = 1; // Minimum

   color bar_color = InpColorNeutral;
   if(imbalance_percent > 10) bar_color = InpColorBuy;
   else if(imbalance_percent < -10) bar_color = InpColorSell;

   // Objektumok frissítése
   if(imbalance_percent < -0.1) // Eladás
     {
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, InpXOffset + center - bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
     }
   else if(imbalance_percent > 0.1) // Vétel
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, InpXOffset + center);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }
   else // 0
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }

   // Szöveg: % és Abszolút Volumenek
   string txt = StringFormat("%s: %.1f%% (B:%d S:%d)",
                             source_label,
                             imbalance_percent,
                             g_total_bid_display,
                             g_total_ask_display);

   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, txt);
  }

//+------------------------------------------------------------------+
//| Panel Létrehozása                                                |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int w = 220;
   int h = 40;
   int bar_h = 20;
   int bar_y = y + 20;

   // 1. Háttér
   ObjectCreate(0, g_obj_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // 2. Középvonal
   ObjectCreate(0, g_obj_center, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_center, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_center, OBJPROP_XDISTANCE, x + w/2 - 1);
   ObjectSetInteger(0, g_obj_center, OBJPROP_YDISTANCE, bar_y);
   ObjectSetInteger(0, g_obj_center, OBJPROP_XSIZE, 2);
   ObjectSetInteger(0, g_obj_center, OBJPROP_YSIZE, bar_h);
   ObjectSetInteger(0, g_obj_center, OBJPROP_BGCOLOR, clrDarkGray);
   ObjectSetInteger(0, g_obj_center, OBJPROP_BORDER_TYPE, BORDER_FLAT);

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
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, "Waiting for Hybrid Data...");
   ObjectSetString(0, g_obj_text, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, g_obj_text, OBJPROP_FONTSIZE, 10);
  }
