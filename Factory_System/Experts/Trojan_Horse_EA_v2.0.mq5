//+------------------------------------------------------------------+
//|                                         Trojan_Horse_EA_v2.0.mq5 |
//|                                                      Jules Agent |
//|                       Smart Stress Tester (Hybrid Manual/Auto)   |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Indicators/PhysicsEngine.mqh"

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
PhysicsEngine m_physics(50); // Physics Engine Instance

//--- Enums
enum ENUM_EA_STATE
  {
   STATE_STOPPED,
   STATE_AUTO_ACTIVE, // Automated Stress Test
   STATE_MANUAL_READY // Manual Trading Mode
  };

enum ENUM_TRADING_MODE
  {
   MODE_ALWAYS_BUY,     // Mindig Vétel (Always Buy)
   MODE_ALWAYS_SELL,    // Mindig Eladás (Always Sell)
   MODE_COUNTER_TICK,   // Tickkel Ellentétes (Price Up -> Sell, Price Down -> Buy)
   MODE_FOLLOW_TICK,    // Tickkel Azonos (Price Up -> Buy, Price Down -> Sell)
   MODE_RANDOM          // Random (Véletlenszerű)
  };

//--- Inputs
input group "Main Settings"
input ulong         InpMagicNumber       = 20260120;
input string        InpComment           = "TrojanHorse_v2";
input ENUM_TRADING_MODE InpAutoMode      = MODE_COUNTER_TICK; // Logic for Auto Mode
input double        InpBaseLot           = 0.01;   // Default Auto Lot
input int           InpMaxPositions      = 100;
input int           InpSlippage          = 10;     // Slippage (Points)

input group "Trojan: Manual Tactics"
input double        InpDecoyLot          = 0.01;   // 'Small' Button Lot
input double        InpTrojanLot         = 1.0;    // 'Big' Button Lot

input group "Trojan: Profit Management"
input bool          InpCloseProfitOnly   = true;   // Close only winners?
input double        InpMinProfit         = 500.0;  // Target Profit (Currency)
input int           InpRetryAttempts     = 5;      // Retry closing on error

input group "Trojan: Stealth Mode"
input bool          InpStealthMode       = false;  // Enable Stealth?
input int           InpMinIntervalMS     = 100;    // Min Time between trades
input int           InpMaxIntervalMS     = 1000;   // Max Time between trades
input double        InpLotVarPercent     = 0.0;    // Lot Variation % (0-100)

input group "Diagnostics"
input bool          InpAutoStartLogger   = true;   // Auto-Start DOM Logger?

input group "Panel UI"
input int           InpX                 = 10;
input int           InpY                 = 80;
input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

//--- Globals
ENUM_EA_STATE g_state = STATE_STOPPED;
double        g_last_price = 0.0;
double        g_current_lot = 0.01;
ulong         g_next_trade_tick = 0;
int           g_log_handle = INVALID_HANDLE;
bool          g_book_subscribed = false;

//--- Struct to hold simplified level data
struct LevelData {
   double price;
   long volume;
};

//--- GUI Object Names
string Prefix = "Trojan_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
// Control Buttons
string ObjBtnAuto = Prefix + "BtnAuto";
string ObjBtnManual = Prefix + "BtnManual";
string ObjBtnStop = Prefix + "BtnStop"; // Acts as "Stop & Close All"
// Manual Grid
string ObjBtnDecoyBuy = Prefix + "DecoyBuy";
string ObjBtnDecoySell = Prefix + "DecoySell";
string ObjBtnTrojanBuy = Prefix + "TrojanBuy";
string ObjBtnTrojanSell = Prefix + "TrojanSell";
// Edits
string ObjEditDecoy = Prefix + "EditDecoy";
string ObjEditTrojan = Prefix + "EditTrojan";

//--- Forward Declarations
void ManualTrade(ENUM_ORDER_TYPE dir, double lot, string type);
void ManageProfit();
void CloseAll();
void CloseWorstLoser();
int CountPositions();
double NormalizeLot(double lot);
void SetState(ENUM_EA_STATE s);
void Log(string action, ulong ticket, double price, double vol, double profit);
string GetDOMSnapshot();
void SortBids(LevelData &arr[], int count);
void SortAsks(LevelData &arr[], int count);
void CreatePanel();
void CreateBtn(string name, string text, int x, int y, int w, color bg);
void CreateEdit(string name, string text, int x, int y, int w);
void UpdateUI();
void DestroyPanel();

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;
   else Print("Trojan: Failed to subscribe to MarketBook!");

   // Init Log
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", "");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ".", "");
   string filename = "Trojan_Horse_Log_" + _Symbol + "_" + time_str + ".csv";

   ResetLastError();
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(g_log_handle != INVALID_HANDLE)
     {
      string header = "Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,BestBid,BestAsk,Velocity,Acceleration,Spread,BidV1,BidV2,BidV3,BidV4,BidV5,AskV1,AskV2,AskV3,AskV4,AskV5\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle);
      Print("Trojan Horse: Log file created: ", filename);
     }

   CreatePanel();
   UpdateUI();

   MathSrand(GetTickCount());

   // Auto-Start Logger
   if(InpAutoStartLogger)
     {
      int logger_handle = iCustom(NULL, 0, "Factory_System\\Diagnostics\\Hybrid_DOM_Logger");
      if(logger_handle != INVALID_HANDLE) ChartIndicatorAdd(0, 0, logger_handle);
     }

   Print("Trojan Horse v2.0 Initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(reason == REASON_REMOVE) CloseAll(); // Safety first

   DestroyPanel();
   ObjectsDeleteAll(0, Prefix);

   if(InpAutoStartLogger) ChartIndicatorDelete(0, 0, "Hybrid_DOM_Logger_Service");

   if(g_book_subscribed) MarketBookRelease(_Symbol);
   if(g_log_handle != INVALID_HANDLE) FileClose(g_log_handle);
  }

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // Mode Switches
      if(sparam == ObjBtnAuto) SetState(STATE_AUTO_ACTIVE);
      else if(sparam == ObjBtnManual) SetState(STATE_MANUAL_READY);
      else if(sparam == ObjBtnStop) { SetState(STATE_STOPPED); CloseAll(); }

      // Manual Trades (Only valid in MANUAL mode)
      else if(g_state == STATE_MANUAL_READY)
        {
         if(sparam == ObjBtnDecoyBuy) ManualTrade(ORDER_TYPE_BUY, StringToDouble(ObjectGetString(0, ObjEditDecoy, OBJPROP_TEXT)), "MANUAL_DECOY");
         else if(sparam == ObjBtnDecoySell) ManualTrade(ORDER_TYPE_SELL, StringToDouble(ObjectGetString(0, ObjEditDecoy, OBJPROP_TEXT)), "MANUAL_DECOY");
         else if(sparam == ObjBtnTrojanBuy) ManualTrade(ORDER_TYPE_BUY, StringToDouble(ObjectGetString(0, ObjEditTrojan, OBJPROP_TEXT)), "MANUAL_TROJAN");
         else if(sparam == ObjBtnTrojanSell) ManualTrade(ORDER_TYPE_SELL, StringToDouble(ObjectGetString(0, ObjEditTrojan, OBJPROP_TEXT)), "MANUAL_TROJAN");
        }

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // Unpress
      UpdateUI();
     }
   // On-The-Fly Lot Edits
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
       // Just ensures the text is valid, no special logic needed as we read text on click
     }
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Always Update Physics
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      m_physics.Update(tick);
   }

   // Always Run Profit Management (if enabled)
   if(g_state != STATE_STOPPED && InpCloseProfitOnly)
     {
      ManageProfit();
     }

   // Auto-Trading Logic (Only in AUTO Mode)
   if(g_state != STATE_AUTO_ACTIVE) return;

   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();

   if(g_last_price == 0.0) { g_last_price = bid; return; }

   // Stealth Logic (Same as v1)
   if(InpStealthMode)
     {
      if(GetTickCount() < g_next_trade_tick) return;
      int delay = InpMinIntervalMS + MathRand() % (InpMaxIntervalMS - InpMinIntervalMS + 1);
      g_next_trade_tick = GetTickCount() + delay;
     }
   else if(bid == g_last_price) return;

   // Direction
   ENUM_ORDER_TYPE dir = ORDER_TYPE_BUY;
   bool up = (bid > g_last_price);

   switch(InpAutoMode)
     {
      case MODE_ALWAYS_BUY: dir = ORDER_TYPE_BUY; break;
      case MODE_ALWAYS_SELL: dir = ORDER_TYPE_SELL; break;
      case MODE_FOLLOW_TICK: dir = up ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
      case MODE_COUNTER_TICK: dir = up ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; break;
      case MODE_RANDOM: dir = (MathRand()%2==0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
     }

   // Max Position Logic
   if(CountPositions() >= InpMaxPositions) CloseWorstLoser();

   if(m_trade.PositionOpen(_Symbol, dir, NormalizeLot(InpBaseLot), m_symbol.Ask(), 0, 0, InpComment))
     {
      Log("AUTO_OPEN", 0, m_symbol.Ask(), InpBaseLot, 0);
     }

   g_last_price = bid;
  }

//+------------------------------------------------------------------+
//| Trade Functions                                                  |
//+------------------------------------------------------------------+
void ManualTrade(ENUM_ORDER_TYPE dir, double lot, string type)
  {
   lot = NormalizeLot(lot);
   double price = (dir == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();

   if(m_trade.PositionOpen(_Symbol, dir, lot, price, 0, 0, InpComment))
     {
      string action = (dir==ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Log(type + "_" + action, 0, price, lot, 0);
      Print("Trojan Manual: ", action, " ", lot, " Lot");
     }
   else
     {
      Print("Trojan Manual Failed: ", GetLastError());
     }
  }

void ManageProfit()
  {
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            double profit = m_position.Profit();
            if(profit >= InpMinProfit)
              {
               ulong ticket = m_position.Ticket();
               if(m_trade.PositionClose(ticket))
                  Log("CLOSE_PROFIT", ticket, m_position.PriceOpen(), m_position.Volume(), profit);
              }
           }
        }
     }
  }

void CloseAll()
  {
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber)
         m_trade.PositionClose(m_position.Ticket());
     }
   Print("Trojan: All positions closed.");
  }

void CloseWorstLoser()
  {
   ulong worst_ticket = 0;
   double min_profit = 1000000.0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber)
        {
         if(m_position.Profit() < min_profit) { min_profit = m_position.Profit(); worst_ticket = m_position.Ticket(); }
        }
     }
   if(worst_ticket > 0) m_trade.PositionClose(worst_ticket);
  }

int CountPositions()
  {
   int cnt = 0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber)
         cnt++;
     }
   return cnt;
  }

double NormalizeLot(double lot)
  {
   double step = m_symbol.LotsStep();
   double min = m_symbol.LotsMin();
   double max = m_symbol.LotsMax();
   if(step > 0) lot = MathFloor(lot / step) * step;
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   return lot;
  }

void SetState(ENUM_EA_STATE s)
  {
   g_state = s;
   UpdateUI();
  }

//+------------------------------------------------------------------+
//| Logging & Physics                                                |
//+------------------------------------------------------------------+
void Log(string action, ulong ticket, double price, double vol, double profit)
  {
   if(g_log_handle == INVALID_HANDLE) return;
   string t = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount()%1000);
   string ea_part = StringFormat("%s,%s,%s,%d,%.5f,%.2f,%.2f,%s", t, ms, action, ticket, price, vol, profit, InpComment);
   string dom_part = GetDOMSnapshot();
   FileWriteString(g_log_handle, ea_part + "," + dom_part + "\r\n");
   FileFlush(g_log_handle);
  }

string GetDOMSnapshot()
  {
   MqlBookInfo book[];
   LevelData bids[]; LevelData asks[];
   double best_bid=0, best_ask=0;
   long bid_v[5]={0}, ask_v[5]={0};

   if(g_book_subscribed && MarketBookGet(_Symbol, book))
     {
      int size = ArraySize(book);
      ArrayResize(bids, size); ArrayResize(asks, size);
      int b=0, a=0;
      for(int i=0; i<size; i++) {
         if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET) { bids[b].price=book[i].price; bids[b].volume=book[i].volume; b++; }
         else if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET) { asks[a].price=book[i].price; asks[a].volume=book[i].volume; a++; }
      }
      SortBids(bids, b); SortAsks(asks, a);
      if(b>0) best_bid=bids[0].price;
      if(a>0) best_ask=asks[0].price;
      for(int i=0; i<5; i++) {
         if(i<b) bid_v[i]=bids[i].volume;
         if(i<a) ask_v[i]=asks[i].volume;
      }
     }
   PhysicsState p = m_physics.GetState();
   string s = DoubleToString(best_bid,_Digits)+","+DoubleToString(best_ask,_Digits)+","+DoubleToString(p.velocity,5)+","+DoubleToString(p.acceleration,5)+","+DoubleToString(p.spread_avg,1)+",";
   for(int i=0;i<5;i++) s+=IntegerToString(bid_v[i])+",";
   for(int i=0;i<5;i++) { s+=IntegerToString(ask_v[i]); if(i<4) s+=","; }
   return s;
  }

void SortBids(LevelData &arr[], int count) {
   for(int i=0; i<count-1; i++) for(int j=0; j<count-i-1; j++) if(arr[j].price < arr[j+1].price) { LevelData t=arr[j]; arr[j]=arr[j+1]; arr[j+1]=t; }
}
void SortAsks(LevelData &arr[], int count) {
   for(int i=0; i<count-1; i++) for(int j=0; j<count-i-1; j++) if(arr[j].price > arr[j+1].price) { LevelData t=arr[j]; arr[j]=arr[j+1]; arr[j+1]=t; }
}

//+------------------------------------------------------------------+
//| GUI Implementation                                               |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   // Taller Background for more buttons
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, InpX);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, InpY);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, 200); // Increased height
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Status
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, InpY+5);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);

   // --- TOP ROW: MODE CONTROLS ---
   CreateBtn(ObjBtnAuto, "AUTO", InpX+10, InpY+30, 60, clrDimGray);
   CreateBtn(ObjBtnManual, "MANUAL", InpX+80, InpY+30, 60, clrDimGray);
   CreateBtn(ObjBtnStop, "CLOSE ALL", InpX+150, InpY+30, 70, clrRed);

   // --- MANUAL ROW 1: DECOY (Small) ---
   CreateEdit(ObjEditDecoy, DoubleToString(InpDecoyLot, 2), InpX+10, InpY+80, 50);
   CreateBtn(ObjBtnDecoyBuy, "S-BUY", InpX+70, InpY+80, 70, clrGreen);
   CreateBtn(ObjBtnDecoySell, "S-SELL", InpX+150, InpY+80, 70, clrRed);

   // --- MANUAL ROW 2: TROJAN (Big) ---
   CreateEdit(ObjEditTrojan, DoubleToString(InpTrojanLot, 1), InpX+10, InpY+120, 50);
   CreateBtn(ObjBtnTrojanBuy, "T-BUY", InpX+70, InpY+120, 70, clrGreen);
   CreateBtn(ObjBtnTrojanSell, "T-SELL", InpX+150, InpY+120, 70, clrRed);
  }

void CreateBtn(string name, string text, int x, int y, int w, color bg)
  {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
  }

void CreateEdit(string name, string text, int x, int y, int w)
  {
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
  }

void UpdateUI()
  {
   // Update Status Text
   string st = "STOPPED";
   if(g_state == STATE_AUTO_ACTIVE) st = "AUTO RUNNING";
   if(g_state == STATE_MANUAL_READY) st = "MANUAL READY";
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "Status: " + st);

   // Highlight Active Mode
   ObjectSetInteger(0, ObjBtnAuto, OBJPROP_BGCOLOR, (g_state == STATE_AUTO_ACTIVE) ? clrGreen : clrDimGray);
   ObjectSetInteger(0, ObjBtnManual, OBJPROP_BGCOLOR, (g_state == STATE_MANUAL_READY) ? clrOrange : clrDimGray);

   // Disable Manual Buttons if not in Manual Mode (Visual Cue only)
   bool man = (g_state == STATE_MANUAL_READY);
   color active = clrGreen;
   color inactive = clrSilver;

   // We keep buttons clickable but they won't do anything in logic.
   // Visually dimming them helps:
   ObjectSetInteger(0, ObjBtnDecoyBuy, OBJPROP_BGCOLOR, man ? clrGreen : clrDimGray);
   ObjectSetInteger(0, ObjBtnDecoySell, OBJPROP_BGCOLOR, man ? clrRed : clrDimGray);
   ObjectSetInteger(0, ObjBtnTrojanBuy, OBJPROP_BGCOLOR, man ? clrForestGreen : clrDimGray);
   ObjectSetInteger(0, ObjBtnTrojanSell, OBJPROP_BGCOLOR, man ? clrFireBrick : clrDimGray);

   ChartRedraw();
  }

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnAuto); ObjectDelete(0, ObjBtnManual); ObjectDelete(0, ObjBtnStop);
   ObjectDelete(0, ObjBtnDecoyBuy); ObjectDelete(0, ObjBtnDecoySell); ObjectDelete(0, ObjEditDecoy);
   ObjectDelete(0, ObjBtnTrojanBuy); ObjectDelete(0, ObjBtnTrojanSell); ObjectDelete(0, ObjEditTrojan);
  }
