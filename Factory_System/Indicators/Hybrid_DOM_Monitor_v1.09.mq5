//+------------------------------------------------------------------+
//|                                        Hybrid_DOM_Monitor_v1.09.mq5 |
//|                                                      Jules Agent |
//|                                   Hybrid System - Multi-Level DOM  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.09"
#property description "Hybrid Multi-Level DOM Monitor"
#property description "Visualizes Imbalance with Velocity-Based Simulation for Gaps"
#property indicator_chart_window
#property indicator_plots 0

#include <Charts/Chart.mqh>
#include "PhysicsEngine.mqh"

// --- Struct Definition (Global) ---
struct Item {
   double price;
   long volume;
   bool simulated; // Marker for simulated levels
};

// --- Enumok ---
enum ENUM_DOM_MODE
  {
   MODE_AUTO_DETECT, // Automatikus: Real DOM + Simulation if missing
   MODE_REAL_DOM,    // Csak Valós DOM
   MODE_SIMULATION   // Csak Tick alapú szimuláció
  };

// --- Bemeneti paraméterek ---
input group "Beállítások"
input ENUM_DOM_MODE InpMode = MODE_AUTO_DETECT; // Működési mód
input int InpVisualDepth = 5;                   // Megjelenített szintek száma (Max 10)
input long InpVolumeFilter = 0;                 // Zajszűrő (0 = Kikapcsolva debugra)

input group "Szimuláció (Gap Filling)"
input bool InpSimulateMissingLevels = true;     // Hiányzó szintek kitöltése?
input double InpSimDecayBase = 0.8;             // Alap csökkenés szintenként (80%)
input double InpVelocitySens = 5.0;             // Sebesség érzékenység (Pips/Sec -> Thinning)

input group "Megjelenítés"
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_LOWER;   // Panel pozíció
input int InpXOffset = 50;                              // X eltolás
input int InpYOffset = 100;                             // Y eltolás
input color InpColorBg = clrDarkSlateGray;              // Háttérszín
input color InpColorBuy = clrMediumSeaGreen;            // Vevő szín
input color InpColorSell = clrCrimson;                  // Eladó szín
input color InpColorSim = clrGray;                      // Szimulált sáv színe (opcionális)
input color InpTextColor = clrWhite;                    // Szöveg szín

// --- Globális változók ---
bool g_subscribed = false;
int g_visual_depth = 5;
PhysicsEngine g_physics(50);

string g_obj_bg = "HybridDOM_BG";
string g_obj_text = "HybridDOM_Text";
string g_obj_info = "HybridDOM_Info";

// Multi-Level Objects Arrays
string g_bars_buy[];
string g_bars_sell[];
string g_labels[];

// Layout Constants
const int ROW_HEIGHT = 12;
const int ROW_GAP = 3;
const int HEADER_HEIGHT = 25;
const int LABEL_WIDTH = 25;
const int BAR_MAX_WIDTH = 90;

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
   EventSetTimer(1); // Heartbeat for redraw
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
   // Keep alive redraw
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
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      g_physics.Update(tick);

      // If we are in Simulation Mode only, trigger update here
      if(InpMode == MODE_SIMULATION) {
         MqlBookInfo empty[]; // Dummy
         UpdateMultiLevelVisuals(empty);
      }
   }
   return(rates_total);
  }

// --- BookEvent ---
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;
   if(InpMode == MODE_SIMULATION) return; // Ignore real book in Sim mode

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      UpdateMultiLevelVisuals(book);
      ChartRedraw();
     }
  }

// --- Core Logic ---
void UpdateMultiLevelVisuals(const MqlBookInfo &book[])
  {
   int size = ArraySize(book);
   PhysicsState phys = g_physics.GetState();

   // --- 1. Process Real Data ---
   Item real_bids[];
   Item real_asks[];

   // Collect Real
   for(int i=0; i<size; i++) {
      if(book[i].volume <= InpVolumeFilter) continue;

      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET) {
         int k = ArraySize(real_bids); ArrayResize(real_bids, k+1);
         real_bids[k].price = book[i].price;
         real_bids[k].volume = book[i].volume;
         real_bids[k].simulated = false;
      }
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET) {
         int k = ArraySize(real_asks); ArrayResize(real_asks, k+1);
         real_asks[k].price = book[i].price;
         real_asks[k].volume = book[i].volume;
         real_asks[k].simulated = false;
      }
   }

   SortBids(real_bids);
   SortAsks(real_asks);

   // --- 2. Simulation / Hybrid Logic ---
   Item final_bids[]; ArrayResize(final_bids, g_visual_depth);
   Item final_asks[]; ArrayResize(final_asks, g_visual_depth);

   // Determine Base Volume for Simulation (Level 1 Real or Tick Based)
   long base_bid_vol = 100; // Default fallback
   long base_ask_vol = 100;

   // If we have Real L1, use it as base
   if(ArraySize(real_bids) > 0) base_bid_vol = real_bids[0].volume;
   if(ArraySize(real_asks) > 0) base_ask_vol = real_asks[0].volume;

   // Calculate Decay Factor based on Velocity
   // Higher Velocity -> More Thinning -> Lower Decay Factor (e.g. 0.8 -> 0.4)
   double velocity_impact = phys.velocity * (InpVelocitySens / 100.0);
   if(velocity_impact > 0.5) velocity_impact = 0.5; // Cap impact

   double current_decay = InpSimDecayBase - velocity_impact;
   if(current_decay < 0.1) current_decay = 0.1; // Min decay

   // Build Final Lists
   for(int i=0; i<g_visual_depth; i++) {
      // --- BIDS ---
      if(i < ArraySize(real_bids)) {
         // Have Real Data
         final_bids[i] = real_bids[i];
      } else {
         // Missing Data
         if(InpSimulateMissingLevels) {
            long prev_vol = (i==0) ? base_bid_vol : final_bids[i-1].volume;
            final_bids[i].volume = (long)(prev_vol * current_decay);
            final_bids[i].simulated = true;
         } else {
            final_bids[i].volume = 0;
         }
      }

      // --- ASKS ---
      if(i < ArraySize(real_asks)) {
         final_asks[i] = real_asks[i];
      } else {
         if(InpSimulateMissingLevels) {
            long prev_vol = (i==0) ? base_ask_vol : final_asks[i-1].volume;
            final_asks[i].volume = (long)(prev_vol * current_decay);
            final_asks[i].simulated = true;
         } else {
            final_asks[i].volume = 0;
         }
      }
   }

   // --- 3. Scaling & Drawing ---
   long max_vol = 1;
   for(int i=0; i<g_visual_depth; i++) {
      if(final_bids[i].volume > max_vol) max_vol = final_bids[i].volume;
      if(final_asks[i].volume > max_vol) max_vol = final_asks[i].volume;
   }

   for(int i=0; i<g_visual_depth; i++) {
      DrawLevelBar(i, final_bids[i], final_asks[i], max_vol);
   }

   // Update Info Text
   string info = StringFormat("Vel: %.1f p/s | Decay: %.2f", phys.velocity, current_decay);
   ObjectSetString(0, g_obj_info, OBJPROP_TEXT, info);
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
void DrawLevelBar(int level, Item &bid, Item &ask, long max_vol_scale)
  {
   string obj_b = g_bars_buy[level];
   string obj_s = g_bars_sell[level];
   string obj_l = g_labels[level];

   int center_x = InpXOffset + LABEL_WIDTH + BAR_MAX_WIDTH;
   int b_len = 0;
   int s_len = 0;

   if(max_vol_scale > 0)
     {
      double b_ratio = (double)bid.volume / (double)max_vol_scale;
      double a_ratio = (double)ask.volume / (double)max_vol_scale;
      b_len = (int)(b_ratio * BAR_MAX_WIDTH);
      s_len = (int)(a_ratio * BAR_MAX_WIDTH);
     }

   // Set Colors (Simulated vs Real)
   color c_buy = bid.simulated ? InpColorSim : InpColorBuy;
   color c_sell = ask.simulated ? InpColorSim : InpColorSell;

   // Update Objects
   ObjectSetInteger(0, obj_s, OBJPROP_XSIZE, s_len);
   ObjectSetInteger(0, obj_s, OBJPROP_XDISTANCE, center_x - s_len);
   ObjectSetInteger(0, obj_s, OBJPROP_BGCOLOR, c_sell);

   ObjectSetInteger(0, obj_b, OBJPROP_XSIZE, b_len);
   ObjectSetInteger(0, obj_b, OBJPROP_BGCOLOR, c_buy);

   string txt = StringFormat("L%d", level+1);
   ObjectSetString(0, obj_l, OBJPROP_TEXT, txt);
  }

// --- Creation ---
void CreateMultiLevelPanel()
  {
   int x = InpXOffset;
   int y = InpYOffset;
   int w = LABEL_WIDTH + 2 * BAR_MAX_WIDTH + 10;
   int h = HEADER_HEIGHT + (g_visual_depth * (ROW_HEIGHT + ROW_GAP)) + 20; // +20 for Info footer

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
   ObjectSetString(0, g_obj_text, OBJPROP_TEXT, "Hybrid DOM v1.09");
   ObjectSetInteger(0, g_obj_text, OBJPROP_COLOR, InpTextColor);

   // Info Footer
   ObjectCreate(0, g_obj_info, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_obj_info, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, g_obj_info, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, g_obj_info, OBJPROP_YDISTANCE, y + h - 15);
   ObjectSetString(0, g_obj_info, OBJPROP_TEXT, "Initializing...");
   ObjectSetInteger(0, g_obj_info, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, g_obj_info, OBJPROP_FONTSIZE, 7);

   int start_y = y + HEADER_HEIGHT;
   int center_x = x + LABEL_WIDTH + BAR_MAX_WIDTH;

   for(int i=0; i<g_visual_depth; i++)
     {
      int row_y = start_y + i*(ROW_HEIGHT+ROW_GAP);

      g_bars_sell[i] = "HybridDOM_S_" + (string)i;
      g_bars_buy[i]  = "HybridDOM_B_" + (string)i;
      g_labels[i]    = "HybridDOM_L_" + (string)i;

      // Sell Bar
      ObjectCreate(0, g_bars_sell[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_CORNER, InpCorner);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XDISTANCE, center_x);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YDISTANCE, row_y);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_XSIZE, 0);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_YSIZE, ROW_HEIGHT);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BGCOLOR, InpColorSell);
      ObjectSetInteger(0, g_bars_sell[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);

      // Buy Bar
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
