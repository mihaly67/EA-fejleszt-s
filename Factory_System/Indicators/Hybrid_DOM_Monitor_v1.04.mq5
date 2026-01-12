//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.04.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Orderflow Monitor|
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.04"
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
input int InpDepthLimit = 5;                    // Mélység szűrő (csak az első N szint)
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

   if(InpMode != MODE_SIMULATION)
     {
      if(MarketBookAdd(_Symbol))
        {
         g_subscribed = true;
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
      UpdateSimulation(last_tick);
     }

   if(InpMode == MODE_AUTO_DETECT && !g_has_dom)
     {
      double imb = CalculateSimulationImbalance();
      UpdateVisuals(imb, "SIM (Tick)");
     }
   else if(InpMode == MODE_SIMULATION)
     {
      double imb = CalculateSimulationImbalance();
      UpdateVisuals(imb, "SIM (Tick)");
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;

   if(InpMode == MODE_SIMULATION) return;

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      int size = ArraySize(book);
      if(size > 0)
        {
         g_has_dom = true;
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

   int bid_count = 0;
   int ask_count = 0;

   for(int i=0; i<size; i++)
     {
      // 1. Szűrő: Túl nagy volumen (Bróker fal)
      if(book[i].volume > InpVolumeFilter) continue;

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
//| Logika: Szimuláció Frissítése (Javított)                         |
//+------------------------------------------------------------------+
void UpdateSimulation(const MqlTick &tick)
  {
   // Szűrés: Csak akkor tekintjük kereskedésnek, ha van volumen,
   // VAGY ha a flagek kifejezetten jelzik.
   // Puszta árfolyam változás (Quote update) nem kereskedés.

   bool isBuy = (tick.flags & TICK_FLAG_BUY) != 0;
   bool isSell = (tick.flags & TICK_FLAG_SELL) != 0;
   bool hasVolume = (tick.volume_real > 0 || tick.volume > 0);

   // Ha nincs flag és nincs volumen, akkor ez csak egy Quote (Bid/Ask) update.
   // Ezt figyelmen kívül hagyjuk a szimulációban, különben eltorzítja az eredményt ("Always Red").
   if(!isBuy && !isSell && !hasVolume) return;

   // Shift history
   for(int i=InpSimHistory-1; i>0; i--)
     {
      g_tick_history[i] = g_tick_history[i-1];
     }

   int type = 0;

   if(isBuy) type = 1;
   else if(isSell) type = -1;
   else
     {
      // Ha nincs flag, de van volumen, próbáljuk kitalálni az árból
      if(tick.last > tick.bid) type = 1; // Ask közelében -> Buy
      else if(tick.last < tick.ask) type = -1; // Bid közelében -> Sell
      else
        {
         // Ha pont középen van (ritka), vagy spreaden belül
         // Megnézzük az előző tickhez képest
         static double last_price = 0;
         if(last_price > 0)
           {
            if(tick.last > last_price) type = 1;
            else if(tick.last < last_price) type = -1;
           }
        }
     }

   static double save_last_price = 0;
   save_last_price = tick.last;

   g_tick_history[0].volume = (long)tick.volume_real;
   if(g_tick_history[0].volume == 0) g_tick_history[0].volume = 1; // Fallback ha van flag de nincs volumen
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

   // Bővített szöveg: % és Abszolút Volumenek
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
   int w = 220; // Kicsit szélesebb a szöveg miatt
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
