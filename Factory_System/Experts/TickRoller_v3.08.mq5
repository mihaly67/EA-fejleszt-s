//+------------------------------------------------------------------+
//|                                     TickRoller_v3.08.mq5           |
//|                      Copyright 2024, Gemini & User Collaboration |
//|        Verzió: 3.08 - Trojan Horse Edition (Profit Close, Stealth)|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.08"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Globális Objektumok
CTrade        trade;
CSymbolInfo   symbol_info;
CPositionInfo position_info;

//--- Panel Objektum Nevek
string        panel_bg_name     = "TickRoller_Panel_BG";
string        panel_status_name = "TickRoller_Panel_Status";
string        start_button_name = "TickRoller_Start_Button";
string        pause_button_name = "TickRoller_Pause_Button";
string        stop_button_name  = "TickRoller_Stop_Button";
string        lot_label_name    = "TickRoller_Lot_Label";
string        lot_edit_name     = "TickRoller_Lot_Edit";

//--- EA Állapot Enum
enum ENUM_EA_STATE
{
    STATE_STOPPED,
    STATE_ACTIVE,
    STATE_PAUSED
};

//--- Kereskedési Mód Enum
enum ENUM_TRADING_MODE
{
    MODE_COUNTER_TICK, // Ellentétes tick irány
    MODE_SAME_TICK,    // Azonos tick irány
    MODE_ALWAYS_BUY,   // Mindig csak Buy
    MODE_ALWAYS_SELL   // Mindig csak Sell
};

//--- Globális Változók
ENUM_EA_STATE g_ea_state = STATE_STOPPED;
double        g_previous_tick_price = 0;
double        g_current_lot_size = 0.01;
ulong         g_next_trade_time = 0; // Stealth módhoz
int           g_log_handle = INVALID_HANDLE;

//--- Bemeneti Paraméterek
input group "EA Settings"
input ulong         InpMagicNumber        = 202501;
input string        InpEaComment          = "TickRoller_v3.08";
input ENUM_TRADING_MODE InpTradingMode    = MODE_COUNTER_TICK;
input double        InpFixedLot           = 0.01;
input int           InpMaxPositions       = 100;

input group "Trojan Horse - Profit Management"
input bool          InpCloseProfitOnly    = true;   // Csak a profitosokat zárja?
input double        InpMinProfitCurrency  = 500.0;  // Cél Profit (Devizában)
input int           InpSlippageRetry      = 5;      // Zárási próbálkozások száma (Slippage ellen)

input group "Trojan Horse - Stealth Mode"
input bool          InpStealthMode        = false;  // Stealth Mód (Random időzítés & Lot)
input int           InpMinIntervalMS      = 100;    // Min. idő két kötés között (ms)
input int           InpMaxIntervalMS      = 1000;   // Max. idő két kötés között (ms)
input double        InpLotVariationPercent= 0.0;    // Lot szórás % (pl. 10 = +/- 10%)

input group "Panel Settings"
input int           InpPanelInitialX      = 10;
input int           InpPanelInitialY      = 80;
input int           InpPanelWidth         = 250;
input int           InpPanelHeight        = 130;
input color         InpPanelBGColor       = clrDarkSlateGray;
input color         InpPanelTextColor     = clrWhite;

//+------------------------------------------------------------------+
//|                  LOGGING FUNCTION                                |
//+------------------------------------------------------------------+
void WriteLog(string action, ulong ticket, double price, double vol, double profit)
{
   if(g_log_handle == INVALID_HANDLE) return;

   string time = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount() % 1000);
   string line = StringFormat("%s.%s,%s,%I64u,%.5f,%.2f,%.2f", time, ms, action, ticket, price, vol, profit);
   FileWrite(g_log_handle, line);
}

//+------------------------------------------------------------------+
//|                  SEGÉDFÜGGVÉNYEK                                 |
//+------------------------------------------------------------------+

//--- Megkeresi a legrégebbi pozíció ticketjét (FIFO) ---
ulong FindOldestPositionTicket()
  {
   ulong oldest_ticket = 0;
   datetime oldest_time = D'3000.01.01';
   int total_positions = PositionsTotal();
   for(int i = 0; i < total_positions; i++) {
      if(position_info.SelectByIndex(i) && position_info.Magic() == InpMagicNumber && position_info.Symbol() == _Symbol) {
         if(position_info.Time() < oldest_time) {
            oldest_time = position_info.Time();
            oldest_ticket = position_info.Ticket();
         }
      }
   }
   return oldest_ticket;
  }

//--- Bezárja az összes pozíciót (STOP gomb) ---
void CloseAllPositions()
  {
   int closed_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(position_info.SelectByIndex(i)) {
         if(position_info.Magic() == InpMagicNumber && position_info.Symbol() == _Symbol) {
            if(trade.PositionClose(position_info.Ticket())) {
               closed_count++;
               WriteLog("CLOSE_ALL", position_info.Ticket(), position_info.PriceOpen(), position_info.Volume(), position_info.Profit());
            }
         }
      }
   }
   if(closed_count > 0) Print("TickRoller: ", closed_count, " pozíció bezárva (Stop gomb).");
  }

//--- ÚJ: Profitos Pozíciók Zárása (Agresszív) ---
void CheckAndCloseProfitablePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position_info.SelectByIndex(i))
      {
         if(position_info.Magic() == InpMagicNumber && position_info.Symbol() == _Symbol)
         {
            double profit = position_info.Profit(); // Swap + Commission nélkül, vagy vele? MT5 Profit usually includes swap/comm in Account history but PositionProfit is raw.
            // Jobb a net profitot nézni ha lehet, de itt a PositionGetDouble(POSITION_PROFIT) a lebegő PnL.

            if(profit >= InpMinProfitCurrency)
            {
               ulong ticket = position_info.Ticket();
               bool closed = false;

               // Retry Loop Slippage ellen
               for(int attempt=0; attempt < InpSlippageRetry; attempt++)
               {
                  if(trade.PositionClose(ticket))
                  {
                     closed = true;
                     Print("PROFIT CLOSE: Ticket #", ticket, " Profit: ", profit);
                     WriteLog("CLOSE_TP", ticket, position_info.PriceOpen(), position_info.Volume(), profit);
                     break; // Siker
                  }
                  else
                  {
                     Print("Close Failed (#", ticket, ") Retcode: ", trade.ResultRetcode(), ". Retrying...");
                     Sleep(10); // Kicsi pihi
                     trade.RequestRefresh(); // Árfolyam frissítés
                  }
               }
            }
         }
      }
   }
}

//--- Panel Létrehozása ---
void CreateSimplePanel()
  {
   ObjectCreate(0, panel_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_XDISTANCE, InpPanelInitialX);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_YDISTANCE, InpPanelInitialY);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_XSIZE, InpPanelWidth);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_YSIZE, InpPanelHeight);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_BGCOLOR, InpPanelBGColor);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_ZORDER, 0);

   ObjectCreate(0, panel_status_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_status_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_status_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_YDISTANCE, InpPanelInitialY + 10);
   ObjectSetString(0, panel_status_name, OBJPROP_TEXT, "Status: Stopped");
   ObjectSetInteger(0, panel_status_name, OBJPROP_COLOR, InpPanelTextColor);
   ObjectSetInteger(0, panel_status_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_status_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, lot_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lot_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, lot_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, lot_label_name, OBJPROP_YDISTANCE, InpPanelInitialY + 40);
   ObjectSetString(0, lot_label_name, OBJPROP_TEXT, "Lot Size:");
   ObjectSetInteger(0, lot_label_name, OBJPROP_COLOR, InpPanelTextColor);
   ObjectSetInteger(0, lot_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, lot_label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lot_label_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, lot_edit_name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_XDISTANCE, InpPanelInitialX + 70);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_YDISTANCE, InpPanelInitialY + 38);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_XSIZE, InpPanelWidth - 80);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_YSIZE, 20);
   ObjectSetString(0, lot_edit_name, OBJPROP_TEXT, DoubleToString(g_current_lot_size, _Digits));
   ObjectSetInteger(0, lot_edit_name, OBJPROP_BGCOLOR, clrGray);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_ALIGN, ALIGN_RIGHT);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, lot_edit_name, OBJPROP_ZORDER, 1);

   // Gombok (3 darab)
   int button_y = InpPanelInitialY + 70;
   int button_width = (InpPanelWidth - 40) / 3;
   int button_height = 40;
   int button_x1 = InpPanelInitialX + 10;
   int button_x2 = button_x1 + button_width + 10;
   int button_x3 = button_x2 + button_width + 10;

   // Start Gomb
   ObjectCreate(0, start_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, start_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, start_button_name, OBJPROP_XDISTANCE, button_x1);
   ObjectSetInteger(0, start_button_name, OBJPROP_YDISTANCE, button_y);
   ObjectSetInteger(0, start_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, start_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, start_button_name, OBJPROP_TEXT, "Start");
   ObjectSetInteger(0, start_button_name, OBJPROP_BGCOLOR, clrGreen);
   ObjectSetInteger(0, start_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, start_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, start_button_name, OBJPROP_ZORDER, 1);

   // Pause Gomb
   ObjectCreate(0, pause_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, pause_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, pause_button_name, OBJPROP_XDISTANCE, button_x2);
   ObjectSetInteger(0, pause_button_name, OBJPROP_YDISTANCE, button_y);
   ObjectSetInteger(0, pause_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, pause_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, pause_button_name, OBJPROP_TEXT, "Pause");
   ObjectSetInteger(0, pause_button_name, OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, pause_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, pause_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, pause_button_name, OBJPROP_ZORDER, 1);

   // Stop Gomb
   ObjectCreate(0, stop_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, stop_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, stop_button_name, OBJPROP_XDISTANCE, button_x3);
   ObjectSetInteger(0, stop_button_name, OBJPROP_YDISTANCE, button_y);
   ObjectSetInteger(0, stop_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, stop_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, stop_button_name, OBJPROP_TEXT, "Stop");
   ObjectSetInteger(0, stop_button_name, OBJPROP_BGCOLOR, clrRed);
   ObjectSetInteger(0, stop_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, stop_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, stop_button_name, OBJPROP_ZORDER, 1);
  }

//--- Panel Törlése ---
void DeleteSimplePanel()
  {
   ObjectDelete(0, panel_bg_name);
   ObjectDelete(0, panel_status_name);
   ObjectDelete(0, start_button_name);
   ObjectDelete(0, pause_button_name);
   ObjectDelete(0, stop_button_name);
   ObjectDelete(0, lot_label_name);
   ObjectDelete(0, lot_edit_name);
  }

//--- Panel Státusz Frissítése ---
void UpdateSimplePanelStatus()
  {
   string status_text;
   switch(g_ea_state)
   {
       case STATE_STOPPED: status_text = "Status: Stopped"; break;
       case STATE_ACTIVE:  status_text = "Status: ACTIVE (Trojan)"; break;
       case STATE_PAUSED:  status_text = "Status: Paused"; break;
   }
   ObjectSetString(0, panel_status_name, OBJPROP_TEXT, status_text);
   ObjectSetString(0, lot_edit_name, OBJPROP_TEXT, DoubleToString(g_current_lot_size, _Digits));
  }

//+------------------------------------------------------------------+
//|                 MQL5 ESEMÉNYKEZELŐK                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   if(!symbol_info.Name(_Symbol)) { Print("Hiba: SymbolInfo init!"); return(INIT_FAILED); }

   // --- Lot Méret Validálás ---
   double min_lot = symbol_info.LotsMin();
   double max_lot = symbol_info.LotsMax();
   double step_lot = symbol_info.LotsStep();
   double initial_lot = InpFixedLot;
   double lot = MathMax(min_lot, initial_lot); lot = MathMin(max_lot, lot);
   if(step_lot > 0) { lot = floor(lot / step_lot) * step_lot; lot = MathMax(min_lot, lot); }
   g_current_lot_size = lot;

   // --- Log File Init ---
   string filename = "TickRoller_Log.csv";
   g_log_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_SHARE_READ|FILE_COMMON);
   if(g_log_handle != INVALID_HANDLE)
   {
      FileWrite(g_log_handle, "Time,MS,Action,Ticket,Price,Vol,Profit");
   }

   // --- Kezdeti Állapot ---
   g_ea_state = STATE_STOPPED;
   mathSrand(GetTickCount()); // Random seed

   CreateSimplePanel();
   symbol_info.RefreshRates();
   g_previous_tick_price = symbol_info.Bid();

   Print("TickRoller v3.08 (Trojan) Initialized.");
   Print(" - Target Profit: ", InpMinProfitCurrency);
   Print(" - Stealth Mode: ", InpStealthMode ? "ON" : "OFF");

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if((g_ea_state == STATE_ACTIVE || g_ea_state == STATE_PAUSED) && reason == REASON_REMOVE)
     {
        Print("TickRoller: EA removed. Closing positions...");
        CloseAllPositions();
     }
   DeleteSimplePanel();
   if(g_log_handle != INVALID_HANDLE) FileClose(g_log_handle);
   Print("TickRoller Deinitialized.");
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == start_button_name)
        {
         if(g_ea_state != STATE_ACTIVE)
           {
            g_ea_state = STATE_ACTIVE;
            g_previous_tick_price = 0;
            g_next_trade_time = 0; // Azonnali indulás (vagy random ha stealth)
            UpdateSimplePanelStatus();
            Print("TickRoller: STARTED.");
           }
         ObjectSetInteger(0, start_button_name, OBJPROP_STATE, false); ChartRedraw();
        }
      else if(sparam == pause_button_name)
        {
         if(g_ea_state == STATE_ACTIVE)
           {
             g_ea_state = STATE_PAUSED;
             UpdateSimplePanelStatus();
             Print("TickRoller: PAUSED.");
           }
          ObjectSetInteger(0, pause_button_name, OBJPROP_STATE, false); ChartRedraw();
        }
      else if(sparam == stop_button_name)
        {
         if(g_ea_state != STATE_STOPPED)
           {
            g_ea_state = STATE_STOPPED;
            UpdateSimplePanelStatus();
            Print("TickRoller: STOPPED. Closing all...");
            CloseAllPositions();
           }
         ObjectSetInteger(0, stop_button_name, OBJPROP_STATE, false); ChartRedraw();
        }
     }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == lot_edit_name)
     {
      string new_lot_str = ObjectGetString(0, lot_edit_name, OBJPROP_TEXT);
      double new_lot_input = StringToDouble(new_lot_str);
      // Validálás (egyszerűsített)
      if (new_lot_input > 0) {
         g_current_lot_size = new_lot_input;
         Print("TickRoller: Lot size changed manually to ", g_current_lot_size);
      }
      ObjectSetString(0, lot_edit_name, OBJPROP_TEXT, DoubleToString(g_current_lot_size, _Digits)); ChartRedraw();
   }
  }

void OnTick()
  {
   // --- Profit Zárás mindig fusson, ha nem STOPPED ---
   // Így Pause alatt is zárja a profitot (ha az árfolyam mozog)
   if(g_ea_state != STATE_STOPPED && InpCloseProfitOnly)
   {
      CheckAndCloseProfitablePositions();
   }

   // --- Kereskedés csak ACTIVE módban ---
   if(g_ea_state != STATE_ACTIVE) return;

   // --- Stealth Mode Időzítés ---
   if(InpStealthMode)
   {
      if(GetTickCount() < g_next_trade_time) return; // Még nem jött el az idő
      // Ha eljött, beállítjuk a következőt (random)
      int interval = InpMinIntervalMS + MathRand() % (InpMaxIntervalMS - InpMinIntervalMS + 1);
      g_next_trade_time = GetTickCount() + interval;
   }

   symbol_info.RefreshRates();
   double current_price = symbol_info.Bid();

   if(g_previous_tick_price == 0) { g_previous_tick_price = current_price; return; }

   bool price_changed = (current_price != g_previous_tick_price);
   // Stealth módban nem feltétlenül kell árváltozás, mert időre megy, de azért jobb ha van mozgás.
   // Ha nem stealth, akkor CSAK árváltozásra lépünk (régi logika).
   if(!InpStealthMode && !price_changed) return;

   // --- Irány ---
   ENUM_ORDER_TYPE desired_direction;
   switch(InpTradingMode) {
      case MODE_ALWAYS_BUY:   desired_direction = ORDER_TYPE_BUY; break;
      case MODE_ALWAYS_SELL:  desired_direction = ORDER_TYPE_SELL; break;
      case MODE_COUNTER_TICK: desired_direction = (current_price > g_previous_tick_price) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; break;
      case MODE_SAME_TICK:    desired_direction = (current_price > g_previous_tick_price) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; break;
      default: desired_direction = ORDER_TYPE_BUY; break;
   }

   // --- Lot Variálás (Stealth) ---
   double trade_lot = g_current_lot_size;
   if(InpStealthMode && InpLotVariationPercent > 0)
   {
      double variation = (MathRand() % (int)(InpLotVariationPercent * 20)) / 10.0 - InpLotVariationPercent; // +/- %
      trade_lot = trade_lot * (1.0 + variation / 100.0);
      // Újra validálni kell
      double step = symbol_info.LotsStep();
      if(step > 0) trade_lot = floor(trade_lot / step) * step;
      if(trade_lot < symbol_info.LotsMin()) trade_lot = symbol_info.LotsMin();
   }

   // --- Max Pozíció ---
   int current_positions = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      if(position_info.SelectByIndex(i) && position_info.Magic() == InpMagicNumber && position_info.Symbol() == _Symbol)
         current_positions++;
   }

   if(current_positions >= InpMaxPositions) {
      if(!InpCloseProfitOnly) { // Ha nem csak profitost zárunk, akkor FIFO
         ulong oldest = FindOldestPositionTicket();
         if(oldest > 0) trade.PositionClose(oldest);
      }
      g_previous_tick_price = current_price;
      return;
   }

   // --- Nyitás ---
   if(trade.PositionOpen(_Symbol, desired_direction, trade_lot, current_price, 0, 0, InpEaComment))
   {
      // Siker log
      WriteLog("OPEN", 0, current_price, trade_lot, 0);
   }

   g_previous_tick_price = current_price;
  }
//+------------------------------------------------------------------+
