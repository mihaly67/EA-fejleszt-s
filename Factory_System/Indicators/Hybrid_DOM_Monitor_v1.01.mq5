//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.01.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Orderflow Monitor|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.01"
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

// MQL5 Standard Library már tartalmazza az ENUM_BASE_CORNER-t, ezért azt használjuk közvetlenül
// Törölve: ENUM_PANEL_CORNER definíció

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpSimHistory = 100;                  // Szimuláció: Hány tickre visszamenőleg?
input double InpImbalanceThreshold = 60.0;      // Túlsúly küszöb (%) a színezéshez

input group "Megjelenítés"
input ENUM_BASE_CORNER InpCorner = CORNER_RIGHT_UPPER;  // Panel pozíció
input int InpXOffset = 10;                              // X eltolás
input int InpYOffset = 50;                              // Y eltolás
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
         // Ellenőrizzük, hogy tényleg jön-e adat (később az OnBookEvent-ben dől el)
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
   // Ha valós DOM van, és az működik, akkor ezt figyelmen kívül hagyjuk a megjelenítésnél
   // De az adatgyűjtést futtathatjuk háttérben.

   // Itt csak tick eseményre reagálunk. A Tick logikát hatékonyabb az OnTick-ben vagy itt kezelni.
   // Az OnCalculate minden tickre lefut.

   MqlTick last_tick;
   if(SymbolInfoTick(_Symbol, last_tick))
     {
      UpdateSimulation(last_tick);
     }

   // Ha nincs DOM esemény (pl. hétvége vagy bróker nem ad), de Tick jön
   // És AUTO módban vagyunk, ellenőrizzük a DOM állapotát.
   if(InpMode == MODE_AUTO_DETECT && !g_has_dom)
     {
      // Ha még nem kaptunk DOM adatot, használjuk a szimulációt
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

         // Számítsuk ki az Imbalance-t
         double imbalance = CalculateDOMImbalance(book);
         UpdateVisuals(imbalance, "Real DOM");
        }
     }
  }

//+------------------------------------------------------------------+
//| Logika: DOM Imbalance Számítás                                   |
//+------------------------------------------------------------------+
double CalculateDOMImbalance(const MqlBookInfo &book[])
  {
   long total_bid = 0;
   long total_ask = 0;
   int size = ArraySize(book);

   for(int i=0; i<size; i++)
     {
      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
         total_bid += book[i].volume;

      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
         total_ask += book[i].volume;
     }

   long total = total_bid + total_ask;
   if(total == 0) return 0.0;

   // Visszatérünk -1.0 (Teljes Eladás) és +1.0 (Teljes Vétel) közötti értékkel
   // De a megjelenítéshez egyszerűbb a % (0..100)
   // Vevő Arány:
   double buy_ratio = (double)total_bid / (double)total;
   // Skálázzuk -100 tól +100-ig (ahol 0 a semleges)
   // (0.5 * 2 - 1) * 100 = 0
   // (1.0 * 2 - 1) * 100 = 100
   // (0.0 * 2 - 1) * 100 = -100

   return (buy_ratio * 2.0 - 1.0) * 100.0;
  }

//+------------------------------------------------------------------+
//| Logika: Szimuláció Frissítése                                    |
//+------------------------------------------------------------------+
void UpdateSimulation(const MqlTick &tick)
  {
   // Shifteljük a tömböt (egyszerű implementáció, körkörös jobb lenne de ez is gyors elég)
   for(int i=InpSimHistory-1; i>0; i--)
     {
      g_tick_history[i] = g_tick_history[i-1];
     }

   // Új elem
   int type = 0;
   bool isBuy = (tick.flags & TICK_FLAG_BUY) != 0;
   bool isSell = (tick.flags & TICK_FLAG_SELL) != 0;

   if(isBuy || (tick.last > tick.bid)) type = 1;       // Vétel (Ask-on kötés)
   else if(isSell || (tick.last < tick.ask)) type = -1; // Eladás (Bid-en kötés)

   // Ha nincs flag és ár nem mozdult, próbáljuk kitalálni az árváltozásból
   static double last_price = 0;
   if(type == 0 && last_price > 0)
     {
      if(tick.last > last_price) type = 1;
      else if(tick.last < last_price) type = -1;
     }
   last_price = tick.last;

   g_tick_history[0].volume = (long)tick.volume_real; // Vagy volume
   if(g_tick_history[0].volume == 0) g_tick_history[0].volume = 1; // Minimum 1
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
   // imbalance_percent: -100 (Full Sell) ... 0 (Neutral) ... +100 (Full Buy)

   int width = 200; // Panel szélesség pixelben
   int height = 20; // Sáv magasság
   int center = width / 2;

   // Vevő / Eladó sáv hossza
   // Ha pozitív (Vevő), akkor középről jobbra nő
   // Ha negatív (Eladó), akkor középről balra nő

   int bar_len = (int)(MathAbs(imbalance_percent) / 100.0 * (width / 2));
   if(bar_len > width/2) bar_len = width/2; // Clip

   // Szín meghatározása
   color bar_color = InpColorNeutral;
   if(imbalance_percent > 10) bar_color = InpColorBuy;
   else if(imbalance_percent < -10) bar_color = InpColorSell;

   // Objektumok frissítése
   // Ez a rész kicsit hacky, mert OBJ_RECTANGLE_LABEL koordinátáit állítgatjuk

   // Eladó Sáv (Bal oldal)
   if(imbalance_percent < 0)
     {
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, InpXOffset + center - bar_len); // Jobbra igazítva a középponthoz
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, bar_color);

      // Vevő sáv 0
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, 0);
     }
   // Vevő Sáv (Jobb oldal)
   else
     {
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XSIZE, bar_len);
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, InpXOffset + center); // Balra igazítva a középponthoz
      ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_BGCOLOR, bar_color);

      // Eladó sáv 0
      ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
     }

   // Szöveg frissítése
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
   int h = 40; // Teljes magasság
   int bar_h = 20;

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
   // Nem hozok létre külön objektumot, a sávok illeszkednek.

   // 3. Bal Sáv (Sell)
   ObjectCreate(0, g_obj_bar_sell, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XDISTANCE, x + w/2); // Kezdőpont (majd visszahúzzuk)
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_YDISTANCE, y + 20); // Alul
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_XSIZE, 0);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_YSIZE, bar_h);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BGCOLOR, InpColorSell);
   ObjectSetInteger(0, g_obj_bar_sell, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // 4. Jobb Sáv (Buy)
   ObjectCreate(0, g_obj_bar_buy, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_XDISTANCE, x + w/2); // Középről indul
   ObjectSetInteger(0, g_obj_bar_buy, OBJPROP_YDISTANCE, y + 20);
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
