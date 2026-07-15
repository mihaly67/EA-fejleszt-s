//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.08.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Multi-Level DOM  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.08"
#property description "Hybrid Multi-Level DOM Monitor"
#property description "Visualizes Imbalance separately for Top 5 Levels"
#property indicator_chart_window
#property indicator_plots 0

#include <Charts/Chart.mqh>

// --- Struct Definition (Global) ---
struct Item {
   double price;
   long volume;
};

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Real DOM + Hybrid Ticks
   MODE_REAL_DOM,    // Csak Valós DOM (Static View)
   MODE_SIMULATION   // Csak Tick alapú szimuláció (Fallback)
  };

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpVisualDepth = 5;                   // Megjelenített szintek száma (Max 10)
input long InpVolumeFilter = 5000;              // Zajszűrő: ennél nagyobb volument figyelmen kívül hagy
input int InpSimHistory = 100;                  // Szimuláció (csak fallback esetén)

input group "Megjelenítés"
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_LOWER;   // Panel pozíció
input int InpXOffset = 50;                              // X eltolás
input int InpYOffset = 100;                             // Y eltolás
input color InpColorBg = clrDarkSlateGray;              // Háttérszín
input color InpColorBuy = clrMediumSeaGreen;            // Vevő szín
input color InpColorSell = clrCrimson;                  // Eladó szín
input color InpColorNeutral = clrSilver;                // Semleges/Marker szín
input color InpTextColor = clrWhite;                    // Szöveg szín

// --- Globális változók ---
bool g_has_dom = false;
bool g_subscribed = false;
int g_visual_depth = 5;

string g_obj_bg = "HybridDOM_BG";
string g_obj_text = "HybridDOM_Text";

// Multi-Level Objects Arrays
string g_bars_buy[];
string g_bars_sell[];
string g_labels[];

// Layout Constants
const int ROW_HEIGHT = 12; // Csökkentve 15 -> 12 (20%-kal kisebb)
const int ROW_GAP = 3;
const int HEADER_HEIGHT = 25;
const int LABEL_WIDTH = 25;
const int BAR_MAX_WIDTH = 90; // Oldalanként

// --- Init ---
int OnInit()
  {
   ObjectsDeleteAll(0, "HybridDOM_");

   g_visual_depth = InpVisualDepth;
   if(g_visual_depth > 10) g_visual_depth = 10;
   if(g_visual_depth < 1) g_visual_depth = 1;

   ArrayResize(g_bars_buy, g_visual_depth);
   ArrayResize(g_bars_sell, g_visual_depth);
   ArrayResize(g_labels, g_visual_depth);

   if(InpMode != MODE_SIMULATION)
     {
      if(MarketBookAdd(_Symbol)) g_subscribed = true;
     }

   CreateMultiLevelPanel();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

// --- Deinit ---
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_subscribed) MarketBookRelease(_Symbol);
   ObjectsDeleteAll(0, "HybridDOM_");
   ChartRedraw();
  }

// --- Timer ---
void OnTimer()
  {
   ChartRedraw();
  }

// --- Calc ---
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
   return(rates_total);
  }

// --- BookEvent ---
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      UpdateMultiLevelVisuals(book);
      ChartRedraw();
     }
  }

// --- Visualization Logic ---
void UpdateMultiLevelVisuals(const MqlBookInfo &book[])
  {
   int size = ArraySize(book);

   Item all_bids[];
   Item all_asks[];

   long max_volume_in_view = 1; // Hogy elkerüljük a 0-val osztást

   // 1. Collect & Find Max
   for(int i=0; i<size; i++)
     {
      if(book[i].volume > InpVolumeFilter) continue;

      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
        {
         int k = ArraySize(all_bids); ArrayResize(all_bids, k+1);
         all_bids[k].price = book[i].price;
         all_bids[k].volume = book[i].volume;
        }
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
        {
         int k = ArraySize(all_asks); ArrayResize(all_asks, k+1);
         all_asks[k].price = book[i].price;
         all_asks[k].volume = book[i].volume;
        }
     }

   // 2. Sort
   SortBids(all_bids);
   SortAsks(all_asks);

   // 3. Determine Scaling Factor (Max Volume among visible levels)
   for(int i=0; i<g_visual_depth; i++)
     {
      long b = (i < ArraySize(all_bids)) ? all_bids[i].volume : 0;
      long a = (i < ArraySize(all_asks)) ? all_asks[i].volume : 0;
      if(b > max_volume_in_view) max_volume_in_view = b;
      if(a > max_volume_in_view) max_volume_in_view = a;
     }

   // 4. Map to Levels
   for(int i=0; i<g_visual_depth; i++)
     {
      long b_vol = (i < ArraySize(all_bids)) ? all_bids[i].volume : 0;
      long a_vol = (i < ArraySize(all_asks)) ? all_asks[i].volume : 0;

      DrawLevelBar(i, b_vol, a_vol, max_volume_in_view);
     }
  }

// --- Sorting Helpers ---
void SortBids(Item &arr[])
  {
   int n = ArraySize(arr);
   for(int i=0; i<n-1; i++)
     for(int j=0; j<n-i-1; j++)
       if(arr[j].price < arr[j+1].price)
         {
          Item temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

void SortAsks(Item &arr[])
  {
   int n = ArraySize(arr);
   for(int i=0; i<n-1; i++)
     for(int j=0; j<n-i-1; j++)
       if(arr[j].price > arr[j+1].price)
         {
          Item temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

// --- Drawing ---
void DrawLevelBar(int level, long bid_vol, long ask_vol, long max_vol_scale)
  {
   string obj_b = g_bars_buy[level];
   string obj_s = g_bars_sell[level];
   string obj_l = g_labels[level];

   int center_x = InpXOffset + LABEL_WIDTH + BAR_MAX_WIDTH;

   int b_len = 0;
   int s_len = 0;

   // Scaling Logic: Relative to Max Volume
   // Ez megoldja a "Level 1 kis volumen = Teljes Sáv" hibát.
   if(max_vol_scale > 0)
     {
      double b_ratio = (double)bid_vol / (double)max_vol_scale;
      double a_ratio = (double)ask_vol / (double)max_vol_scale;

      b_len = (int)(b_ratio * BAR_MAX_WIDTH);
      s_len = (int)(a_ratio * BAR_MAX_WIDTH);
     }

   // Update Objects
   ObjectSetInteger(0, obj_s, OBJPROP_XSIZE, s_len);
   ObjectSetInteger(0, obj_s, OBJPROP_XDISTANCE, center_x - s_len);

   ObjectSetInteger(0, obj_b, OBJPROP_XSIZE, b_len);

   // Label update with volume info?
   string txt = StringFormat("L%d", level+1);
   ObjectSetString(0, obj_l, OBJPROP_TEXT, txt);
  }

// --- Creation ---
void CreateMultiLevelPanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int w = LABEL_WIDTH + 2 * BAR_MAX_WIDTH + 10; // ~215
   // Dinamikus Magasság: Header + Sorok + Margó
   int h = HEADER_HEIGHT + (g_visual_depth * (ROW_HEIGHT + ROW_GAP)) + 5;

   // Background
   ObjectCreate(0, g_obj_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BGCOLOR, InpColorBg);
   ObjectSetInteger(0, g_obj_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Header Text
   ObjectCreate(0, g_obj_text, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_text, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_text, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, g_obj_text, OBJPROP_YDISTANCE, y + 2);
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, "DOM Levels");
   ObjectSetInteger(0, g_obj_text, OBJPROP_COLOR, InpTextColor);

   int start_y = y + HEADER_HEIGHT;
   int center_x = x + LABEL_WIDTH + BAR_MAX_WIDTH;

   for(int i=0; i<g_visual_depth; i++)
     {
      int row_y = start_y + i*(ROW_HEIGHT+ROW_GAP);

      g_bars_sell[i] = "HybridDOM_S_" + (string)i;
      g_bars_buy[i]  = "HybridDOM_B_" + (string)i;
      g_labels[i]    = "HybridDOM_L_" + (string)i;

      // Sell Bar (Left)
      ObjectCreate(0, g_bars_sell[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XDISTANCE, center_x);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YSIZE, ROW_HEIGHT);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BGCOLOR, InpColorSell);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Buy Bar (Right)
      ObjectCreate(0, g_bars_buy[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_XDISTANCE, center_x);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_YSIZE, ROW_HEIGHT);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_BGCOLOR, InpColorBuy);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Level Label
      ObjectCreate(0, g_labels[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_labels[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_labels[i], OBJPROP_XDISTANCE, x + 2);
      ObjectSetInteger(0, g_labels[i], OBJPROP_YDISTANCE, row_y - 1);
      ObjectSetString(0, g_labels[i], OBJPROP_TEXT, "L"+(string)(i+1));
      ObjectSetInteger(0, g_labels[i], OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, g_labels[i], OBJPROP_FONTSIZE, 8);
     }
  }
