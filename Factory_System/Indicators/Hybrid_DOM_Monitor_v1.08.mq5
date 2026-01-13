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

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Real DOM + Hybrid Ticks
   MODE_REAL_DOM,    // Csak Valós DOM (Static View) - Ezt használjuk a Multi-Levelhez
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
string g_obj_bg = "HybridDOM_BG";
string g_obj_text = "HybridDOM_Text";

// Multi-Level Objects Arrays
string g_bars_buy[];
string g_bars_sell[];
string g_labels[];

// --- Init ---
int OnInit()
  {
   ObjectsDeleteAll(0, "HybridDOM_");

   if(InpVisualDepth > 10) InpVisualDepth = 10;
   if(InpVisualDepth < 1) InpVisualDepth = 1;

   ArrayResize(g_bars_buy, InpVisualDepth);
   ArrayResize(g_bars_sell, InpVisualDepth);
   ArrayResize(g_labels, InpVisualDepth);

   // Subscribe
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
   // Hybrid Ticks (Price Action) fallback Logic could go here,
   // but for Multi-Level visuals we need Real DOM mostly.
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

   // Separate Bids and Asks
   // Note: MqlBookInfo is usually ordered by price.
   // Sell (Ask) prices are higher, Buy (Bid) prices are lower.
   // We need to sort/filter them into Levels (1 = Best, 2 = Next Best, etc.)

   long bids[]; ArrayResize(bids, InpVisualDepth); ArrayInitialize(bids, 0);
   long asks[]; ArrayResize(asks, InpVisualDepth); ArrayInitialize(asks, 0);

   int bid_idx = 0;
   int ask_idx = 0;

   // Sort/Find Levels
   // Standard MT5 Book:
   // - SELLs are typically at the start (Descending price?) or End?
   // Let's iterate and classify.
   // Correct way: Best Bid is highest Bid price. Best Ask is lowest Ask price.

   // Strategy: Find Max Bid and Min Ask, then next max, etc.
   // But simpler: The array is usually sorted.
   // Sells: Price Ascending (Lowest Ask first? No, usually ordered by type)

   // Robust Logic: Collect all Bids and Asks, Sort them.

   // 1. Collect
   struct Item { double price; long volume; };
   Item all_bids[];
   Item all_asks[];

   for(int i=0; i<size; i++)
     {
      if(book[i].volume > InpVolumeFilter) continue; // Filter Walls

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
   // Bids: Descending Price (Highest = Best = Level 1)
   // Asks: Ascending Price (Lowest = Best = Level 1)
   SortBids(all_bids);
   SortAsks(all_asks);

   // 3. Map to Levels
   for(int i=0; i<InpVisualDepth; i++)
     {
      long b_vol = (i < ArraySize(all_bids)) ? all_bids[i].volume : 0;
      long a_vol = (i < ArraySize(all_asks)) ? all_asks[i].volume : 0;

      DrawLevelBar(i, b_vol, a_vol);
     }
  }

// --- Sorting Helpers ---
void SortBids(Item &arr[]) // Descending
  {
   int n = ArraySize(arr);
   for(int i=0; i<n-1; i++)
     for(int j=0; j<n-i-1; j++)
       if(arr[j].price < arr[j+1].price)
         {
          Item temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

void SortAsks(Item &arr[]) // Ascending
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
void DrawLevelBar(int level, long bid_vol, long ask_vol)
  {
   // Objects
   string obj_b = g_bars_buy[level];
   string obj_s = g_bars_sell[level];
   string obj_l = g_labels[level];

   // Calculate Imbalance for this Level
   long total = bid_vol + ask_vol;

   int max_width_half = 100; // 100 px per side
   int center_x = InpXOffset + 110; // Panel width 220, center 110

   int b_len = 0;
   int s_len = 0;

   if(total > 0)
     {
      // Proportional to volume share? Or normalized to max width?
      // User wants to see "dominance".
      // Let's use simple scaling: 100% width = Max possible? No.
      // Let's use Share % * Width.

      double b_ratio = (double)bid_vol / (double)total;
      double a_ratio = (double)ask_vol / (double)total;

      // If total volume is tiny, bars should be small?
      // Or just show pure ratio? pure ratio is better for "Imbalance".
      // But we can scale by volume relative to "Average"?
      // Let's stick to simple Ratio for now (Imbalance).

      b_len = (int)(b_ratio * max_width_half);
      s_len = (int)(a_ratio * max_width_half);
     }

   // Update Objects
   // Sell Bar (Left)
   ObjectSetInteger(0, obj_s, OBJPROP_XSIZE, s_len);
   ObjectSetInteger(0, obj_s, OBJPROP_XDISTANCE, center_x - s_len);

   // Buy Bar (Right)
   ObjectSetInteger(0, obj_b, OBJPROP_XSIZE, b_len);
   // XDISTANCE stays center_x

   // Label (Optional: Update text with Volume?)
   string txt = StringFormat("L%d", level+1);
   ObjectSetString(0, obj_l, OBJPROP_TEXT, txt);
  }

// --- Creation ---
void CreateMultiLevelPanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int row_h = 15;
   int gap = 2;
   int w = 220;
   int h = (row_h + gap) * InpVisualDepth + 30; // +Header

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

   int start_y = y + 25;
   int center_x = x + 110;

   for(int i=0; i<InpVisualDepth; i++)
     {
      int row_y = start_y + i*(row_h+gap);

      // Init Array Names
      g_bars_sell[i] = "HybridDOM_S_" + (string)i;
      g_bars_buy[i]  = "HybridDOM_B_" + (string)i;
      g_labels[i]    = "HybridDOM_L_" + (string)i;

      // Sell Bar (Left)
      ObjectCreate(0, g_bars_sell[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XDISTANCE, center_x); // Starts at 0 width
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YSIZE, row_h);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BGCOLOR, InpColorSell);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Buy Bar (Right)
      ObjectCreate(0, g_bars_buy[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_XDISTANCE, center_x);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_YSIZE, row_h);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_BGCOLOR, InpColorBuy);
      ObjectSetInteger(0, g_bars_buy[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Level Label
      ObjectCreate(0, g_labels[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_labels[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_labels[i], OBJPROP_XDISTANCE, x + 2);
      ObjectSetInteger(0, g_labels[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetString(0, g_labels[i], OBJPROP_TEXT, "L"+(string)(i+1));
      ObjectSetInteger(0, g_labels[i], OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, g_labels[i], OBJPROP_FONTSIZE, 8);
     }
  }
