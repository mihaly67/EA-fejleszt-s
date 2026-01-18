//+------------------------------------------------------------------+
//|                                           Mimic_Trap_EA_v1.0.mq5 |
//|                                                      Jules Agent |
//|                       Focused Strategy: Liquidity Mimicry Trap   |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;

//--- Inputs
input group "Strategy Settings"
input int           InpTriggerTicks      = 2;      // Consecutive ticks to trigger
input int           InpDecoyCount        = 3;      // Number of Decoy trades
input int           InpTimeoutSec        = 60;     // Auto-reset trap after N seconds

input group "Position Size"
input double        InpDecoyLot          = 0.01;   // Decoy Lot (Fake Direction)
input double        InpTrojanLot         = 0.1;    // Trojan Lot (Real Direction)

input group "Risk Management"
input int           InpSlippage          = 10;
input ulong         InpMagicNumber       = 999001;
input string        InpComment           = "MimicTrap";

input group "Panel UI"
input int           InpX                 = 10;
input int           InpY                 = 80;
input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

//--- Globals
bool              g_trap_active = false;
ENUM_ORDER_TYPE   g_trap_direction = ORDER_TYPE_BUY; // The INTENDED Winner
int               g_trap_counter_ticks = 0;
ulong             g_trap_expire_time = 0;
double            g_last_price = 0.0;

//--- GUI Objects
string Prefix = "Mimic_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnTrapBuy = Prefix + "BtnTrapBuy";
string ObjBtnTrapSell = Prefix + "BtnTrapSell";
string ObjBtnCloseAll = Prefix + "BtnClose";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void DrawDealVisuals(ulong deal_ticket);
void ArmTrap(ENUM_ORDER_TYPE dir);
void ExecuteTrap();
void CloseAll();
double NormalizeLot(double lot);

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

   // --- CLEANUP & HYGIENE ---
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false); // No ghost objects
   CleanupChart();

   CreatePanel();
   UpdateUI();

   Print("Mimic Trap EA v1.0 Initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DestroyPanel();
   CleanupChart();
  }

void CleanupChart()
  {
   // Delete EA UI
   ObjectsDeleteAll(0, Prefix);

   // Delete Trade History Objects (Start with # or Standard Arrows)
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
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
      if(sparam == ObjBtnTrapBuy)
        {
         // Visual Click Feedback
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == ObjBtnTrapSell)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == ObjBtnCloseAll)
        {
         g_trap_active = false; // Disarm
         CloseAll();
         UpdateUI();
        }
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();

   // Initialize Last Price
   if(g_last_price == 0.0) { g_last_price = bid; return; }

   if(g_trap_active)
     {
      // Check Timeout
      if(GetTickCount() > g_trap_expire_time) {
         g_trap_active = false;
         Print("Mimic: Trap Timeout. Reset.");
         PlaySound("timeout.wav");
         UpdateUI();
         return;
      }

      // Check Price Movement
      if(bid != g_last_price)
        {
         bool price_up = (bid > g_last_price);
         bool price_down = (bid < g_last_price);

         // LOGIC: Wait for movement AGAINST the intended direction
         // Intended BUY -> Wait for DOWN (Bearish)
         // Intended SELL -> Wait for UP (Bullish)
         bool counter_move = (g_trap_direction == ORDER_TYPE_BUY && price_down) ||
                             (g_trap_direction == ORDER_TYPE_SELL && price_up);

         if(counter_move) {
            g_trap_counter_ticks++;
            Print("Mimic: Counter Tick ", g_trap_counter_ticks, "/", InpTriggerTicks);
            if(g_trap_counter_ticks >= InpTriggerTicks) {
               ExecuteTrap();
            }
         } else {
            // Reset if momentum breaks
            g_trap_counter_ticks = 0;
         }
        }
     }

   g_last_price = bid;
  }

//+------------------------------------------------------------------+
//| Trade Transaction (Visualization)                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      DrawDealVisuals(trans.deal);
     }
  }

//+------------------------------------------------------------------+
//| Strategy Functions                                               |
//+------------------------------------------------------------------+
void ArmTrap(ENUM_ORDER_TYPE dir)
  {
   g_trap_active = true;
   g_trap_direction = dir;
   g_trap_counter_ticks = 0;
   g_trap_expire_time = GetTickCount() + (InpTimeoutSec * 1000);
   UpdateUI();

   string d = (dir==ORDER_TYPE_BUY) ? "BUY" : "SELL";
   Print("Mimic: TRAP ARMED for ", d, ". Waiting for ", InpTriggerTicks, " counter ticks.");
  }

void ExecuteTrap()
  {
   g_trap_active = false; // Disarm

   // 1. DECOY PHASE (Opposite Direction)
   ENUM_ORDER_TYPE decoy_dir = (g_trap_direction == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   double d_lot = NormalizeLot(InpDecoyLot);

   for(int i=0; i<InpDecoyCount; i++) {
      if(m_trade.PositionOpen(_Symbol, decoy_dir, d_lot, (decoy_dir==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), 0, 0, InpComment+"_Decoy"))
         Sleep(20); // Minimal spacing
   }

   // 2. TROJAN PHASE (Real Direction)
   double t_lot = NormalizeLot(InpTrojanLot);
   m_trade.PositionOpen(_Symbol, g_trap_direction, t_lot, (g_trap_direction==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), 0, 0, InpComment+"_Trojan");

   PlaySound("ok.wav");
   Print("Mimic: TRAP EXECUTED!");
   UpdateUI();
  }

void CloseAll()
  {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber)
         m_trade.PositionClose(m_position.Ticket());
   }
   Print("Mimic: All positions closed.");
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
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, 130);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Status Label
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, InpY+5);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "READY");

   // Buttons
   // Row 1: TRAP BUY (Green)
   ObjectCreate(0, ObjBtnTrapBuy, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YDISTANCE, InpY+30);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnTrapBuy, OBJPROP_TEXT, "TRAP BUY (Wait Dip)");
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_COLOR, clrWhite);

   // Row 2: TRAP SELL (Red)
   ObjectCreate(0, ObjBtnTrapSell, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YDISTANCE, InpY+65);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnTrapSell, OBJPROP_TEXT, "TRAP SELL (Wait Rise)");
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, clrFireBrick);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_COLOR, clrWhite);

   // Row 3: CLOSE ALL
   ObjectCreate(0, ObjBtnCloseAll, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YDISTANCE, InpY+100);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YSIZE, 20);
   ObjectSetString(0, ObjBtnCloseAll, OBJPROP_TEXT, "CLOSE ALL / RESET");
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   if(g_trap_active) {
      string dir = (g_trap_direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      ObjectSetString(0, ObjStat, OBJPROP_TEXT, "ARMED: " + dir + " (" + IntegerToString(g_trap_counter_ticks) + "/" + IntegerToString(InpTriggerTicks) + ")");
      // Highlight active button
      ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, (dir=="BUY") ? clrOrange : clrDimGray);
      ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, (dir=="SELL") ? clrOrange : clrDimGray);
   } else {
      ObjectSetString(0, ObjStat, OBJPROP_TEXT, "READY (In: " + DoubleToString(InpDecoyLot,2) + " / " + DoubleToString(InpTrojanLot,2) + ")");
      ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, clrForestGreen);
      ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, clrFireBrick);
   }
   ChartRedraw();
  }

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG);
   ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnTrapBuy);
   ObjectDelete(0, ObjBtnTrapSell);
   ObjectDelete(0, ObjBtnCloseAll);
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

void DrawDealVisuals(ulong deal_ticket)
  {
   if(!HistoryDealSelect(deal_ticket)) return;
   long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   long time = HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   string name = Prefix + "Arrow_" + (string)deal_ticket;

   if(entry == DEAL_ENTRY_IN) {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      ObjectCreate(0, name, obj_type, 0, (datetime)time, price);
   } else if(entry == DEAL_ENTRY_OUT) {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      if(ObjectCreate(0, name, obj_type, 0, (datetime)time, price))
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   }
   ChartRedraw();
  }
