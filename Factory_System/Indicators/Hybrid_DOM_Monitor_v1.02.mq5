//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.02.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Orderflow Monitor|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.02"
#property indicator_chart_window
#property indicator_plots 0

#include <Charts/Chart.mqh>

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Ha van DOM, azt használja, ha nincs, Tícket
   MODE_REAL_DOM,    // Csak Valós DOM (MarketBook)
   MODE_SIMULATION   // Szimuláció (Tick Flow alapján)
  };

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpDepthLimit = 3;                    // Mélység szűrő (csak az első N szint)
input long InpVolumeFilter = 5000;              // Zajszűrő: ennél nagyobb volument figyelmen kívül hagy (CFD falak)
input int InpSimHistory = 100;                  // Szimuláció: Hány tickre visszamenőleg?
input double InpImbalanceThreshold = 60.0;      // Túlsúly küszöb (%) a színezéshez

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
string g_obj_center = "HybridDOM_Center"; // Új középvonal objektum
string g_obj_text = "HybridDOM_Text";
string g_obj_label = "HybridDOM_Label";

// Szimulációs puffer (körkörös puffer helyett egyszerű tömbök)
struct TickData {
   long volume;
   int type; // 1=Buy, -1=Sell
};
TickData g_tick_history[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Tiszta lappal indulunk
   ObjectsDeleteAll(0, "HybridDOM_");

   // Tömb méretezése
   ArrayResize(g_tick_history, InpSimHistory);
   // Inicializálás nullával
   for(int i=0; i<InpSimHistory; i++) { g_tick_history[i].volume = 0; g_tick_history[i].type = 0; }

   // DOM Feliratkozás
   if(InpMode != MODE_SIMULATION)
     {
      if(MarketBookAdd(_Symbol))
        {
         g_subscribed = true;
        }
     }

   // Panel létrehozása
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
   // Szimulációs adatok frissítése (Tick alapú)
   MqlTick last_tick;
   if(SymbolInfoTick(_Symbol, last_tick))
     {
      UpdateSimulation(last_tick);
     }

   // Ha nincs DOM esemény (pl. hétvége vagy bróker nem ad), de Tick jön
   // És AUTO módban vagyunk, ellenőrizzük a DOM állapotát.
   if(InpMode == MODE_AUTO_DETECT && !g_has_dom)
     {
      UpdateVisuals(CalculateSimulationImbalance(), "SIM (Tick)");
     }
   else if(InpMode == MODE_SIMULATION)
     {
      UpdateVisuals(CalculateSimulationImbalance(), "SIM (Tick)");
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;

   if(InpMode == MODE_SIMULATION) return; // Ha kényszerített szimuláció van

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      int size = ArraySize(book);
      if(size > 0)
        {
         g_has_dom = true; // Jelezzük, hogy van élő adat

         // Számítsuk ki az Imbalance-t (Most már szűréssel)
         double imbalance = CalculateDOMImbalance(book);
         UpdateVisuals(imbalance, "Real DOM");
        }
     }
  }

//+------------------------------------------------------------------+
//| Logika: DOM Imbalance Számítás (Szűrt)                           |
//+------------------------------------------------------------------+
double CalculateDOMImbalance(const MqlBookInfo &book[])
  {
   long total_bid = 0;
   long total_ask = 0;
   int size = ArraySize(book);

   // A tömb általában Sell (végén) és Buy (elején) vagy fordítva van rendezve, de a típust nézzük.
   // Csak a legjobb szinteket akarjuk.
   // A MarketBookGet tömbje Ár szerint rendezett.
   // Sell: Magasabb árak. Buy: Alacsonyabb árak.
   // A "Best Bid" a Buy tömb legmagasabb ára.
   // A "Best Ask" a Sell tömb legalacsonyabb ára.

   // Egyszerűbb iterálni és számolni, hányat találtunk már az adott típusból.
   int bid_count = 0;
   int ask_count = 0;

   // Fontos: MQL5-ben a tömb indexelése változó lehet, de a típus attribútum biztos.
   // Az algoritmus: Végigmegyünk, és csak az első N 'valid' (szűrőnek megfelelő) tételt adjuk össze típusonként.
   // De mivel ár szerint van rendezve, a könyv "közepe" (legjobb árak) a tömb közepén lehetnek, vagy a két végén.
   // Általában: [Sell High ... Sell Low | Buy High ... Buy Low] vagy fordítva.
   // A legbiztosabb, ha megkeressük a legjobb árakat, és onnan terjeszkedünk.
   // De egyszerűsítésként: Ha szűrjük a kiugró nagy értékeket (Outliers), az már sokat segít.

   for(int i=0; i<size; i++)
     {
      // 1. Szűrő: Túl nagy volumen (Bróker fal)
      if(book[i].volume > InpVolumeFilter) continue;

      // 2. Szűrő: Mélység (Ez kicsit trükkös rendezés nélkül, de a volumen szűrő a fontosabb most)
      // Ha a mélységet is korlátozni akarjuk, ahhoz tudni kellene, melyik a "legjobb" ár.
      // A CFD brókernél (Admirals) láttuk, hogy 6 sor van. 3 Sell, 3 Buy.
      // A belső (piaci) sorok kicsik (100-200), a külsők nagyok (10000).
      // Tehát ha csak a kicsiket adjuk össze, az pont jó lesz.

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

   long total = total_bid + total_ask;
   if(total == 0) return 0.0;

   double buy_ratio = (double)total_bid / (double)total;
   return (buy_ratio * 2.0 - 1.0) * 100.0;
  }

//+------------------------------------------------------------------+
//| Logika: Szimuláció Frissítése                                    |
//+------------------------------------------------------------------+
void UpdateSimulation(const MqlTick &tick)
  {
   // Shift
   for(int i=InpSimHistory-1; i>0; i--)
     {
      g_tick_history[i] = g_tick_history[i-1];
     }

   int type = 0;
   bool isBuy = (tick.flags & TICK_FLAG_BUY) != 0;
   bool isSell = (tick.flags & TICK_FLAG_SELL) != 0;

   if(isBuy || (tick.last > tick.bid)) type = 1;
   else if(isSell || (tick.last < tick.ask)) type = -1;

   static double last_price = 0;
   if(type == 0 && last_price > 0)
     {
      if(tick.last > last_price) type = 1;
      else if(tick.last < last_price) type = -1;
     }
   last_price = tick.last;

   g_tick_history[0].volume = (long)tick.volume_real;
   if(g_tick_history[0].volume == 0) g_tick_history[0].volume = 1;
   g_tick_history[0].type = type;
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
   if(bar_len < 1) bar_len = 1; // Minimum láthatóság

   color bar_color = InpColorNeutral;
   if(imbalance_percent > 10) bar_color = InpColorBuy;
   else if(imbalance_percent < -10) bar_color = InpColorSell;

   // Objektumok frissítése
   if(imbalance_percent < -0.1) // Eladás
     {
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, InpXOffset + center - bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0); // Hide other
     }
   else if(imbalance_percent > 0.1) // Vétel
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, InpXOffset + center);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0); // Hide other
     }
   else // 0 (vagy nagyon kicsi)
     {
      // Középen egy kis semleges jelzés
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }

   string txt = StringFormat("%s: %.1f%%", source_label, imbalance_percent);
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, txt);
  }

//+------------------------------------------------------------------+
//| Panel Létrehozása                                                |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int w = 200;
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

   // 2. Középvonal (Marker)
   ObjectCreate(0, g_obj_center, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_center, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_center, OBJPROP_XDISTANCE, x + w/2 - 1); // 2px széles
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
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, "Waiting for Data...");
   ObjectSetString(0, g_obj_text, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, g_obj_text, OBJPROP_FONTSIZE, 10);
  }
