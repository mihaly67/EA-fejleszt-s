//+------------------------------------------------------------------+
//|                                         Trojan_Horse_EA_v1.01.mq5|
//|                                                      Jules Agent |
//|                       Smart Stress Tester (formerly TickRoller)  |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "1.01"
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
   STATE_ACTIVE,
   STATE_PAUSED
  };

enum ENUM_TRADING_MODE
  {
   MODE_COUNTER_TICK, // Price Up -> Sell
   MODE_SAME_TICK,    // Price Up -> Buy
   MODE_ALWAYS_BUY,   // Always Buy
   MODE_ALWAYS_SELL,  // Always Sell
   MODE_RANDOM        // Random Direction
  };

//--- Inputs
input group "Main Settings"
input ulong         InpMagicNumber       = 20260115;
input string        InpComment           = "TrojanHorse_v1.01";
input ENUM_TRADING_MODE InpMode          = MODE_COUNTER_TICK;
input double        InpBaseLot           = 0.01;
input int           InpMaxPositions      = 100;
input int           InpSlippage          = 10;     // Slippage (Points)

input group "Trojan: Profit Management"
input bool          InpCloseProfitOnly   = true;   // Close only winners?
input double        InpMinProfit         = 500.0;  // Target Profit (Currency)
input int           InpRetryAttempts     = 5;      // Retry closing on error

input group "Trojan: Stealth Mode"
input bool          InpStealthMode       = false;  // Enable Stealth?
input int           InpMinIntervalMS     = 100;    // Min Time between trades
input int           InpMaxIntervalMS     = 1000;   // Max Time between trades
input double        InpLotVarPercent     = 0.0;    // Lot Variation % (0-100)

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

//--- Struct to hold simplified level data (Local to avoid conflict if already defined)
struct LevelData {
   double price;
   long volume;
};

//--- GUI Object Names
string Prefix = "Trojan_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnStart = Prefix + "BtnStart";
string ObjBtnPause = Prefix + "BtnPause";
string ObjBtnStop = Prefix + "BtnStop";
string ObjEditLot = Prefix + "EditLot";
string ObjLblLot = Prefix + "LblLot";

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage); // Set Slippage

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   // Subscribe to MarketBook for Logging
   if(MarketBookAdd(_Symbol))
     {
      g_book_subscribed = true;
      Print("Trojan Horse: MarketBook Subscribed.");
     }
   else
     {
      Print("Trojan Horse: Failed to subscribe to MarketBook! Depth logs will be empty.");
     }

   // Init Lot
   g_current_lot = NormalizeLot(InpBaseLot);

   // Init Log (Saved to local MQL5/Files)
   string filename = "Trojan_Horse_Log_" + _Symbol + "_" + IntegerToString((long)TimeCurrent()) + ".csv";
   // Using FILE_TXT | FILE_ANSI to match Hybrid_DOM_Logger and ensure manual CSV formatting works correctly
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(g_log_handle != INVALID_HANDLE)
     {
      // Header: EA Columns + DOM/Physics Columns
      string header = "Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,";
      header += "BestBid,BestAsk,Velocity,Acceleration,Spread,";
      header += "BidV1,BidV2,BidV3,BidV4,BidV5,AskV1,AskV2,AskV3,AskV4,AskV5\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle); // Flush header to ensure file creation is visible
      Print("Trojan Horse: Log file created: ", filename);
     }
   else
     {
      Print("Trojan Horse: Failed to create log file! Error: ", GetLastError());
     }

   // UI
   CreatePanel();
   UpdateUI();

   // Random Seed
   MathSrand(GetTickCount());

   Print("Trojan Horse v1.01 Initialized. Stealth: ", InpStealthMode);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_state != STATE_STOPPED && reason == REASON_REMOVE)
     {
      Print("EA Removed. Closing All Positions...");
      CloseAll();
     }

   DestroyPanel();

   // Full Chart Cleanup as requested
   ObjectsDeleteAll(0, -1, -1);

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
      if(sparam == ObjBtnStart) SetState(STATE_ACTIVE);
      else if(sparam == ObjBtnPause) SetState(STATE_PAUSED);
      else if(sparam == ObjBtnStop) SetState(STATE_STOPPED);

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // Unpress button
     }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == ObjEditLot)
     {
      string txt = ObjectGetString(0, ObjEditLot, OBJPROP_TEXT);
      double val = StringToDouble(txt);
      if(val > 0) g_current_lot = NormalizeLot(val);
      UpdateUI();
     }
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Update Physics
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      m_physics.Update(tick);
   }

   // 1. Profit Management (Runs even in Pause if ProfitClose is ON)
   if(g_state != STATE_STOPPED && InpCloseProfitOnly)
     {
      ManageProfit();
     }

   // 2. Trading Logic (Only ACTIVE)
   if(g_state != STATE_ACTIVE) return;

   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();

   // Init Last Price
   if(g_last_price == 0.0) { g_last_price = bid; return; }

   // Stealth Timing Check
   if(InpStealthMode)
     {
      if(GetTickCount() < g_next_trade_tick) return; // Wait

      // Set next time
      int delay = InpMinIntervalMS + MathRand() % (InpMaxIntervalMS - InpMinIntervalMS + 1);
      g_next_trade_tick = GetTickCount() + delay;
     }
   else
     {
      // Standard Tick Mode: Require Price Change
      if(bid == g_last_price) return;
     }

   // Direction Logic
   ENUM_ORDER_TYPE dir = ORDER_TYPE_BUY;
   bool up = (bid > g_last_price);

   switch(InpMode)
     {
      case MODE_ALWAYS_BUY: dir = ORDER_TYPE_BUY; break;
      case MODE_ALWAYS_SELL: dir = ORDER_TYPE_SELL; break;
      case MODE_SAME_TICK: dir = up ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
      case MODE_COUNTER_TICK: dir = up ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; break;
      case MODE_RANDOM: dir = (MathRand()%2==0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
     }

   // Lot Calculation
   double lot = g_current_lot;
   if(InpStealthMode && InpLotVarPercent > 0)
     {
      // Variation +/- Percent
      double rnd = (MathRand() % 200 - 100) / 100.0; // -1.0 to 1.0
      double factor = 1.0 + (rnd * InpLotVarPercent / 100.0);
      lot = NormalizeLot(lot * factor);
     }

   // Check Max Positions
   if(CountPositions() >= InpMaxPositions)
     {
      if(!InpCloseProfitOnly) CloseWorstLoser(); // Close biggest loser to free up space
      g_last_price = bid;
      return;
     }

   // Execute
   if(m_trade.PositionOpen(_Symbol, dir, lot, m_symbol.Ask(), 0, 0, InpComment))
     {
      Log("OPEN", 0, m_symbol.Ask(), lot, 0);
     }

   g_last_price = bid;
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void ManageProfit()
  {
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            double profit = m_position.Profit(); // Net profit check recommended but using raw
            if(profit >= InpMinProfit)
              {
               ulong ticket = m_position.Ticket();
               // Retry Loop
               for(int k=0; k<InpRetryAttempts; k++)
                 {
                  if(m_trade.PositionClose(ticket))
                    {
                     Log("CLOSE_PROFIT", ticket, m_position.PriceOpen(), m_position.Volume(), profit);
                     Print("Trojan: Closed Profit ", profit, " Ticket: ", ticket);
                     break;
                    }
                  Sleep(10);
                  m_symbol.RefreshRates();
                 }
              }
           }
        }
     }
  }

void CloseAll()
  {
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            m_trade.PositionClose(m_position.Ticket());
           }
        }
     }
   Print("Trojan: All positions closed.");
  }

void CloseWorstLoser()
  {
   ulong worst_ticket = 0;
   double min_profit = 1000000.0; // Start high

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber)
        {
         double p = m_position.Profit();
         if(p < min_profit)
           {
            min_profit = p;
            worst_ticket = m_position.Ticket();
           }
        }
     }

   if(worst_ticket > 0)
     {
      Print("Trojan: Max positions reached. Closing worst loser (#", worst_ticket, ") Profit: ", min_profit);
      m_trade.PositionClose(worst_ticket);
     }
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
   if(s == STATE_STOPPED) CloseAll();
   if(s == STATE_ACTIVE)
     {
      g_last_price = 0;
      g_next_trade_tick = 0;
      m_physics.Reset();
     }
   UpdateUI();
  }

void Log(string action, ulong ticket, double price, double vol, double profit)
  {
   if(g_log_handle == INVALID_HANDLE) return;

   string t = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount()%1000);

   // Base EA Log
   string ea_part = StringFormat("%s.%s,%s,%d,%.5f,%.2f,%.2f", t, ms, action, ticket, price, vol, profit);

   // DOM & Physics Snapshot
   string dom_part = GetDOMSnapshot();

   // Write
   FileWriteString(g_log_handle, ea_part + "," + dom_part + "\r\n");
   // No FileFlush for performance
  }

//+------------------------------------------------------------------+
//| DOM & Physics Logic                                              |
//+------------------------------------------------------------------+
string GetDOMSnapshot()
  {
   MqlBookInfo book[];
   LevelData bids[];
   LevelData asks[];

   // Defaults
   double best_bid = 0;
   double best_ask = 0;
   long bid_v[5] = {0,0,0,0,0};
   long ask_v[5] = {0,0,0,0,0};

   if(g_book_subscribed && MarketBookGet(_Symbol, book))
     {
      int size = ArraySize(book);
      ArrayResize(bids, size);
      ArrayResize(asks, size);
      int bid_cnt = 0;
      int ask_cnt = 0;

      for(int i=0; i<size; i++)
        {
         if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
           {
            bids[bid_cnt].price = book[i].price;
            bids[bid_cnt].volume = book[i].volume;
            bid_cnt++;
           }
         else if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
           {
            asks[ask_cnt].price = book[i].price;
            asks[ask_cnt].volume = book[i].volume;
            ask_cnt++;
           }
        }

      SortBids(bids, bid_cnt);
      SortAsks(asks, ask_cnt);

      if(bid_cnt > 0) best_bid = bids[0].price;
      if(ask_cnt > 0) best_ask = asks[0].price;

      for(int i=0; i<5; i++)
        {
         if(i < bid_cnt) bid_v[i] = bids[i].volume;
         if(i < ask_cnt) ask_v[i] = asks[i].volume;
        }
     }

   // Physics State
   PhysicsState phys = m_physics.GetState();

   string s = DoubleToString(best_bid, _Digits) + "," + DoubleToString(best_ask, _Digits) + ",";
   s += DoubleToString(phys.velocity, 5) + ",";
   s += DoubleToString(phys.acceleration, 5) + ",";
   s += DoubleToString(phys.spread_avg, 1) + ",";

   // Bid Volumes
   for(int i=0; i<5; i++) s += IntegerToString(bid_v[i]) + ",";
   // Ask Volumes
   for(int i=0; i<5; i++) {
      s += IntegerToString(ask_v[i]);
      if(i < 4) s += ",";
   }

   return s;
  }

void SortBids(LevelData &arr[], int count)
  {
   for(int i=0; i<count-1; i++)
     for(int j=0; j<count-i-1; j++)
       if(arr[j].price < arr[j+1].price)
         {
          LevelData temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

void SortAsks(LevelData &arr[], int count)
  {
   for(int i=0; i<count-1; i++)
     for(int j=0; j<count-i-1; j++)
       if(arr[j].price > arr[j+1].price)
         {
          LevelData temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   // Background
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, InpX);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, InpY);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Status Label
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, InpY+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);

   // Lot Edit
   ObjectCreate(0, ObjLblLot, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, ObjLblLot, OBJPROP_TEXT, "Lot:");
   ObjectSetInteger(0, ObjLblLot, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjLblLot, OBJPROP_YDISTANCE, InpY+40);
   ObjectSetInteger(0, ObjLblLot, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, InpX+50);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, InpY+40);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 60);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);

   // Buttons
   CreateBtn(ObjBtnStart, "START", InpX+10, InpY+70, 60, clrGreen);
   CreateBtn(ObjBtnPause, "PAUSE", InpX+80, InpY+70, 60, clrOrange);
   CreateBtn(ObjBtnStop, "STOP", InpX+150, InpY+70, 60, clrRed);
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
  }

void UpdateUI()
  {
   string st = "STOPPED";
   if(g_state == STATE_ACTIVE) st = "ACTIVE (Trojan)";
   if(g_state == STATE_PAUSED) st = "PAUSED";
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "Status: " + st);
   ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(g_current_lot, 2));
   ChartRedraw();
  }

void DestroyPanel()
  {
   // Specific UI Destruction
   ObjectDelete(0, ObjBG);
   ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnStart);
   ObjectDelete(0, ObjBtnPause);
   ObjectDelete(0, ObjBtnStop);
   ObjectDelete(0, ObjEditLot);
   ObjectDelete(0, ObjLblLot);
  }
