//+------------------------------------------------------------------+
//|                                         Trojan_Horse_EA_v3.0.mq5 |
//|                                                      Jules Agent |
//|                       Smart Stress Tester (Hybrid Manual/Auto)   |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "3.20"
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
input string        InpComment           = "TrojanHorse_v3";
input ENUM_TRADING_MODE InpAutoMode      = MODE_COUNTER_TICK; // Default Start Mode
input double        InpBaseLot           = 0.01;   // Default Auto Lot
input int           InpMaxPositions      = 100;
input int           InpSlippage          = 10;     // Slippage (Points)

input group "Trojan: Manual Tactics"
input double        InpDecoyLot          = 0.01;   // 'Small' Button Lot
input double        InpTrojanLot         = 1.0;    // 'Big' Button Lot

input group "Trojan: Mimic Trap"
input int           InpMimicTriggerTicks = 2;      // Ticks against us to trigger
input int           InpMimicDecoyCount   = 3;      // Number of Decoy trades
input int           InpTrapTimeout       = 30;     // Timeout (seconds) to reset trap

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
ENUM_EA_STATE     g_state = STATE_STOPPED;
ENUM_TRADING_MODE g_auto_mode = MODE_COUNTER_TICK; // Live Auto Mode Variable
double            g_last_price = 0.0;
double            g_current_lot = 0.01;
double            g_auto_lot = 0.01;   // Live Auto Lot Variable
ulong             g_next_trade_tick = 0;
int               g_log_handle = INVALID_HANDLE;
bool              g_book_subscribed = false;

//--- Trap State
bool              g_mimic_mode_enabled = false; // UI Toggle State
bool              g_trap_active = false;        // Logic State (Waiting for ticks)
ENUM_ORDER_TYPE   g_trap_direction = ORDER_TYPE_BUY; // The INTENDED Winner
int               g_trap_counter_ticks = 0;
ulong             g_trap_expire_time = 0;

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
string ObjEditAutoLot = Prefix + "EditAutoLot"; // New Auto Lot Edit
// Auto Mode Strategy Switcher
string ObjBtnModeBuy = Prefix + "ModeBuy";
string ObjBtnModeSell = Prefix + "ModeSell";
string ObjBtnModeCounter = Prefix + "ModeCounter";
string ObjBtnModeFollow = Prefix + "ModeFollow";
string ObjBtnModeRandom = Prefix + "ModeRandom";
// Manual Grid
string ObjBtnTrap = Prefix + "BtnTrap"; // Toggle Trap Mode
string ObjBtnDecoyBuy = Prefix + "DecoyBuy";
string ObjBtnDecoySell = Prefix + "DecoySell";
string ObjBtnTrojanBuy = Prefix + "TrojanBuy";
string ObjBtnTrojanSell = Prefix + "TrojanSell";
// Edits
string ObjEditDecoy = Prefix + "EditDecoy";
string ObjEditTrojan = Prefix + "EditTrojan";

//--- Forward Declarations
void ManualTrade(ENUM_ORDER_TYPE dir, double lot, string type);
void ArmTrap(ENUM_ORDER_TYPE intended_dir);
void ExecuteTrap();
void ManageProfit();
void CloseAll();
void CloseWorstLoser();
int CountPositions();
double NormalizeLot(double lot);
void SetState(ENUM_EA_STATE s);
void SetAutoMode(ENUM_TRADING_MODE m);
void Log(string action, ulong ticket, double price, double vol, double profit);
string GetDOMSnapshot();
void SortBids(LevelData &arr[], int count);
void SortAsks(LevelData &arr[], int count);
void CreatePanel();
void CreateBtn(string name, string text, int x, int y, int w, color bg, int fontSize=8);
void CreateEdit(string name, string text, int x, int y, int w);
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void DrawDealVisuals(ulong deal_ticket);

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

   // --- CLEANUP & SETTINGS ---
   // Disable auto-history to prevent "Ghost Objects" (arrows/lines) from reappearing
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   CleanupChart(); // Clear any existing artifacts immediately

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;
   else Print("Trojan: Failed to subscribe to MarketBook!");

   // Init Runtime Globals
   g_auto_mode = InpAutoMode;
   g_auto_lot = InpBaseLot;

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

   Print("Trojan Horse v3.0 Initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(reason == REASON_REMOVE) CloseAll(); // Safety first

   DestroyPanel();
   CleanupChart();

   if(InpAutoStartLogger) ChartIndicatorDelete(0, 0, "Hybrid_DOM_Logger_Service");

   if(g_book_subscribed) MarketBookRelease(_Symbol);
   if(g_log_handle != INVALID_HANDLE) FileClose(g_log_handle);
  }

void CleanupChart()
  {
   // 1. Delete EA UI
   ObjectsDeleteAll(0, Prefix);

   // 2. Delete Trade History Objects (Arrows & Lines)
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      // Delete if it starts with '#' (Standard Trade Object) OR is a Trade Arrow
      if(StringFind(name, "#") == 0 ||
         ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_BUY ||
         ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_SELL)
        {
         ObjectDelete(0, name);
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // Main Control
      if(sparam == ObjBtnAuto) SetState(STATE_AUTO_ACTIVE);
      else if(sparam == ObjBtnManual) SetState(STATE_MANUAL_READY);
      else if(sparam == ObjBtnStop) { SetState(STATE_STOPPED); CloseAll(); }

      // Trap Toggle
      else if(sparam == ObjBtnTrap) {
         g_mimic_mode_enabled = !g_mimic_mode_enabled; // Toggle Global State

         // Update Visuals
         ObjectSetInteger(0, ObjBtnTrap, OBJPROP_STATE, g_mimic_mode_enabled);
         ObjectSetInteger(0, ObjBtnTrap, OBJPROP_BGCOLOR, g_mimic_mode_enabled ? clrRed : clrDimGray);
         ObjectSetString(0, ObjBtnTrap, OBJPROP_TEXT, g_mimic_mode_enabled ? "TRAP: ON" : "TRAP: OFF");

         if(!g_mimic_mode_enabled) {
            g_trap_active = false; // Force Disarm
            Print("Trojan: Trap Mode DISABLED. Pending traps cleared.");
         } else {
            Print("Trojan: Trap Mode ENABLED. Use S-BUY/S-SELL to arm.");
         }
         UpdateUI();
      }

      // Strategy Switcher (On-The-Fly)
      else if(sparam == ObjBtnModeBuy) SetAutoMode(MODE_ALWAYS_BUY);
      else if(sparam == ObjBtnModeSell) SetAutoMode(MODE_ALWAYS_SELL);
      else if(sparam == ObjBtnModeCounter) SetAutoMode(MODE_COUNTER_TICK);
      else if(sparam == ObjBtnModeFollow) SetAutoMode(MODE_FOLLOW_TICK);
      else if(sparam == ObjBtnModeRandom) SetAutoMode(MODE_RANDOM);

      // Manual Trades
      else if(g_state == STATE_MANUAL_READY)
        {
         if(sparam == ObjBtnDecoyBuy) {
            if(g_mimic_mode_enabled) ArmTrap(ORDER_TYPE_BUY);
            else ManualTrade(ORDER_TYPE_BUY, StringToDouble(ObjectGetString(0, ObjEditDecoy, OBJPROP_TEXT)), "MANUAL_DECOY");
         }
         else if(sparam == ObjBtnDecoySell) {
            if(g_mimic_mode_enabled) ArmTrap(ORDER_TYPE_SELL);
            else ManualTrade(ORDER_TYPE_SELL, StringToDouble(ObjectGetString(0, ObjEditDecoy, OBJPROP_TEXT)), "MANUAL_DECOY");
         }
         // T-Buttons (Trojan) are always Direct Entry (Emergency/Override)
         else if(sparam == ObjBtnTrojanBuy) ManualTrade(ORDER_TYPE_BUY, StringToDouble(ObjectGetString(0, ObjEditTrojan, OBJPROP_TEXT)), "MANUAL_TROJAN");
         else if(sparam == ObjBtnTrojanSell) ManualTrade(ORDER_TYPE_SELL, StringToDouble(ObjectGetString(0, ObjEditTrojan, OBJPROP_TEXT)), "MANUAL_TROJAN");
        }

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // Unpress
      UpdateUI();
     }
   // On-The-Fly Lot Edits
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      if(sparam == ObjEditAutoLot)
        {
         double val = StringToDouble(ObjectGetString(0, ObjEditAutoLot, OBJPROP_TEXT));
         if(val > 0)
           {
            g_auto_lot = NormalizeLot(val);
            Print("Trojan: Auto Lot Updated to ", g_auto_lot);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Trade Transaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   // Visualize new deals manually since native history is disabled
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      DrawDealVisuals(trans.deal);
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

   // --- TRAP LOGIC ---
   if(g_trap_active)
     {
      if(GetTickCount() > g_trap_expire_time) {
         g_trap_active = false;
         Print("Trojan: Trap Timeout. Reset.");
         UpdateUI(); // To show status
      }
      else if(bid != g_last_price) {
         // Check Direction
         bool price_up = (bid > g_last_price);
         bool price_down = (bid < g_last_price);

         // We want COUNTER ticks to the intended direction
         // If intended BUY, we wait for DOWN ticks.
         // If intended SELL, we wait for UP ticks.
         bool counter_move = (g_trap_direction == ORDER_TYPE_BUY && price_down) ||
                             (g_trap_direction == ORDER_TYPE_SELL && price_up);

         if(counter_move) {
            g_trap_counter_ticks++;
            Print("Trojan Trap: Counter Tick ", g_trap_counter_ticks, "/", InpMimicTriggerTicks);
            if(g_trap_counter_ticks >= InpMimicTriggerTicks) {
               ExecuteTrap();
            }
         } else {
            // Price moved in our favor or flat? strict reset or loose?
            // Strict: Reset if any tick is not counter.
            g_trap_counter_ticks = 0;
         }
      }
     }

   // Stealth Logic
   if(InpStealthMode)
     {
      if(GetTickCount() < g_next_trade_tick) return;
      int delay = InpMinIntervalMS + MathRand() % (InpMaxIntervalMS - InpMinIntervalMS + 1);
      g_next_trade_tick = GetTickCount() + delay;
     }
   else if(bid == g_last_price) return;

   // Direction based on LIVE Global Mode
   ENUM_ORDER_TYPE dir = ORDER_TYPE_BUY;
   bool up = (bid > g_last_price);

   switch(g_auto_mode)
     {
      case MODE_ALWAYS_BUY: dir = ORDER_TYPE_BUY; break;
      case MODE_ALWAYS_SELL: dir = ORDER_TYPE_SELL; break;
      case MODE_FOLLOW_TICK: dir = up ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
      case MODE_COUNTER_TICK: dir = up ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; break;
      case MODE_RANDOM: dir = (MathRand()%2==0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
     }

   // Max Position Logic
   if(CountPositions() >= InpMaxPositions) CloseWorstLoser();

   if(m_trade.PositionOpen(_Symbol, dir, NormalizeLot(g_auto_lot), m_symbol.Ask(), 0, 0, InpComment))
     {
      Log("AUTO_OPEN", 0, m_symbol.Ask(), g_auto_lot, 0);
     }

   g_last_price = bid;
  }

//+------------------------------------------------------------------+
//| Trade Functions                                                  |
//+------------------------------------------------------------------+
void ManualTrade(ENUM_ORDER_TYPE dir, double lot, string type)
  {
   m_symbol.RefreshRates(); // Ensure fresh prices for manual execution
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

void ArmTrap(ENUM_ORDER_TYPE intended_dir)
  {
   g_trap_active = true;
   g_trap_direction = intended_dir;
   g_trap_counter_ticks = 0;
   g_trap_expire_time = GetTickCount() + (InpTrapTimeout * 1000);

   string dir_str = (intended_dir == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   Print("Trojan: TRAP ARMED for ", dir_str, ". Waiting for ", InpMimicTriggerTicks, " counter ticks (Price moving AGAINST target).");
   UpdateUI();
  }

void ExecuteTrap()
  {
   g_trap_active = false; // Disarm immediately

   // 1. MIMIC: Send Decoys (Opposite Direction)
   ENUM_ORDER_TYPE decoy_dir = (g_trap_direction == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   double decoy_lot = NormalizeLot(InpDecoyLot);

   for(int i=0; i<InpMimicDecoyCount; i++) {
      ManualTrade(decoy_dir, decoy_lot, "MIMIC_DECOY");
      Sleep(20); // Tiny delay to ensure distinct order arrival? Or remove for speed.
   }

   // 2. TROJAN: Send Real Trade (Intended Direction)
   double trojan_lot = NormalizeLot(InpTrojanLot);
   ManualTrade(g_trap_direction, trojan_lot, "MIMIC_TROJAN");

   Print("Trojan: TRAP EXECUTED!");
   UpdateUI();
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

void SetAutoMode(ENUM_TRADING_MODE m)
  {
   g_auto_mode = m;
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
//| Visualization Helpers                                            |
//+------------------------------------------------------------------+
void DrawDealVisuals(ulong deal_ticket)
  {
   if(!HistoryDealSelect(deal_ticket)) return;

   long reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
   long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   long time = HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   long pos_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

   string name_arrow = Prefix + "Arrow_" + (string)deal_ticket;
   string name_line = Prefix + "Line_" + (string)deal_ticket;

   // 1. Draw Entry Arrow
   if(entry == DEAL_ENTRY_IN)
     {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      ObjectCreate(0, name_arrow, obj_type, 0, (datetime)time, price);
      // Optional: Set color if needed, but standard arrows are usually fine (Blue/Red)
     }
   // 2. Draw Exit Arrow & Line
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
     {
      // Exit Arrow
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      if(ObjectCreate(0, name_arrow, obj_type, 0, (datetime)time, price))
        {
         ObjectSetInteger(0, name_arrow, OBJPROP_COLOR, clrOrange); // Distinguish exits
        }

      // Connect to Entry
      if(HistorySelectByPosition(pos_id))
        {
         int total = HistoryDealsTotal();
         for(int i=0; i<total; i++)
           {
            ulong t = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN)
              {
               // Found Entry
               datetime t_in = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
               double p_in = HistoryDealGetDouble(t, DEAL_PRICE);

               // Draw Line
               if(ObjectCreate(0, name_line, OBJ_TREND, 0, t_in, p_in, (datetime)time, price))
                 {
                  ObjectSetInteger(0, name_line, OBJPROP_COLOR, (p_in < price && type==DEAL_TYPE_SELL) || (p_in > price && type==DEAL_TYPE_BUY) ? clrRed : clrBlue); // Profit/Loss color?
                  ObjectSetInteger(0, name_line, OBJPROP_RAY_RIGHT, false);
                  ObjectSetInteger(0, name_line, OBJPROP_STYLE, STYLE_DOT);
                 }
               break;
              }
           }
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| GUI Implementation                                               |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   // Taller Background (240px)
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, InpX);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, InpY);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, 240); // Increased height for Mode Row
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Status
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, InpY+5);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);

   // --- TOP ROW: MAIN CONTROLS ---
   CreateBtn(ObjBtnAuto, "AUTO", InpX+10, InpY+30, 60, clrDimGray);
   CreateEdit(ObjEditAutoLot, DoubleToString(InpBaseLot, 2), InpX+10, InpY+65, 50); // New Auto Lot Edit (moved down slightly)
   CreateBtn(ObjBtnManual, "MANUAL", InpX+80, InpY+30, 60, clrDimGray);
   CreateBtn(ObjBtnStop, "CLOSE ALL", InpX+150, InpY+30, 70, clrRed);

   // --- NEW ROW: STRATEGY SWITCHER (Small Buttons) ---
   // Y = 100. 5 Buttons. Width ~40px each. (Shifted down to make room for Edit Box)
   int rowY = InpY + 100;
   CreateBtn(ObjBtnModeBuy, "[BUY]", InpX+10, rowY, 40, clrDimGray, 7);
   CreateBtn(ObjBtnModeSell, "[SELL]", InpX+52, rowY, 40, clrDimGray, 7);
   CreateBtn(ObjBtnModeCounter, "[CNTR]", InpX+94, rowY, 40, clrDimGray, 7);
   CreateBtn(ObjBtnModeFollow, "[FLLW]", InpX+136, rowY, 40, clrDimGray, 7);
   CreateBtn(ObjBtnModeRandom, "[RND]", InpX+178, rowY, 40, clrDimGray, 7);

   // --- MANUAL ROW 1: DECOY (Small) & TRAP ---
   // Shifted down to Y=140
   CreateBtn(ObjBtnTrap, "TRAP: OFF", InpX+10, rowY+40, 60, clrDimGray, 7); // Trap Toggle
   CreateEdit(ObjEditDecoy, DoubleToString(InpDecoyLot, 2), InpX+75, rowY+40, 40); // Moved right
   CreateBtn(ObjBtnDecoyBuy, "S-BUY", InpX+120, rowY+40, 50, clrGreen);
   CreateBtn(ObjBtnDecoySell, "S-SELL", InpX+175, rowY+40, 50, clrRed);

   // --- MANUAL ROW 2: TROJAN (Big) ---
   // Shifted down to Y=180
   CreateEdit(ObjEditTrojan, DoubleToString(InpTrojanLot, 1), InpX+10, rowY+80, 50);
   CreateBtn(ObjBtnTrojanBuy, "T-BUY", InpX+70, rowY+80, 70, clrGreen);
   CreateBtn(ObjBtnTrojanSell, "T-SELL", InpX+150, rowY+80, 70, clrRed);
  }

void CreateBtn(string name, string text, int x, int y, int w, color bg, int fontSize)
  {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
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
   if(g_state == STATE_AUTO_ACTIVE) st = "AUTO RUNNING (" + EnumToString(g_auto_mode) + ")";
   if(g_state == STATE_MANUAL_READY) {
      st = "MANUAL READY";
      if(g_trap_active) st += " [TRAP ARMED]";
   }
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "Status: " + st);

   // Highlight Main Mode
   ObjectSetInteger(0, ObjBtnAuto, OBJPROP_BGCOLOR, (g_state == STATE_AUTO_ACTIVE) ? clrGreen : clrDimGray);
   ObjectSetInteger(0, ObjBtnManual, OBJPROP_BGCOLOR, (g_state == STATE_MANUAL_READY) ? clrOrange : clrDimGray);

   // Highlight Strategy Buttons
   ObjectSetInteger(0, ObjBtnModeBuy, OBJPROP_BGCOLOR, (g_auto_mode == MODE_ALWAYS_BUY) ? clrSteelBlue : clrDimGray);
   ObjectSetInteger(0, ObjBtnModeSell, OBJPROP_BGCOLOR, (g_auto_mode == MODE_ALWAYS_SELL) ? clrSteelBlue : clrDimGray);
   ObjectSetInteger(0, ObjBtnModeCounter, OBJPROP_BGCOLOR, (g_auto_mode == MODE_COUNTER_TICK) ? clrSteelBlue : clrDimGray);
   ObjectSetInteger(0, ObjBtnModeFollow, OBJPROP_BGCOLOR, (g_auto_mode == MODE_FOLLOW_TICK) ? clrSteelBlue : clrDimGray);
   ObjectSetInteger(0, ObjBtnModeRandom, OBJPROP_BGCOLOR, (g_auto_mode == MODE_RANDOM) ? clrSteelBlue : clrDimGray);

   // Manual Dimming
   bool man = (g_state == STATE_MANUAL_READY);
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
   ObjectDelete(0, ObjBtnModeBuy); ObjectDelete(0, ObjBtnModeSell); ObjectDelete(0, ObjBtnModeCounter); ObjectDelete(0, ObjBtnModeFollow); ObjectDelete(0, ObjBtnModeRandom);
   ObjectDelete(0, ObjBtnTrap); ObjectDelete(0, ObjBtnDecoyBuy); ObjectDelete(0, ObjBtnDecoySell); ObjectDelete(0, ObjEditDecoy);
   ObjectDelete(0, ObjBtnTrojanBuy); ObjectDelete(0, ObjBtnTrojanSell); ObjectDelete(0, ObjEditTrojan);
  }
