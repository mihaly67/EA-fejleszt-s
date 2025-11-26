//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                            WPR_Analyst_v4.0.mq5 |
//|                      Copyright 2024, Gemini & User Collaboration |
//|                             Verzió: New Baseline & Cleanup Fix   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "4.3"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Globális Objektumok
CTrade         trade;
CSymbolInfo    symbol_info;
CPositionInfo  position_info;
int            wpr_handle;
int            smooth_wpr_handle;
int            ema_handle;
int            atr_handle = INVALID_HANDLE;
int            macd_handle = INVALID_HANDLE;

//--- Globális változók az instrumentum adatok tárolására ---
int                     g_digits = 0;
double                  g_point = 0.0;
long                    g_stops_level = 0;
double                  g_min_lot = 0.0;
double                  g_max_lot = 0.0;
double                  g_lot_step = 0.0;
double                  g_point_adjustment_factor = 1.0;
//--------------------------------------------------------------------

//--- Globális Változók a Panelhez és Gombokhoz ---
string         panel_bg_name    = "WPR_Panel_BG";
string         panel_title_name = "WPR_Panel_Title";
string         panel_status_name= "WPR_Panel_Status";
string         sell_button_name = "WPR_Manual_Sell_Button";
string         buy_button_name  = "WPR_Manual_Buy_Button";
string         close_button_name= "WPR_Manual_Close_Button";
string         balance_label_name = "WPR_Panel_Balance";
string         pl_label_name    = "WPR_Panel_PL";
bool           is_panel_dragging= false;
int            panel_drag_offset_x = 0;
int            panel_drag_offset_y = 0;

//--- Állapotkezelő Enum-ok ---
enum ENUM_EXIT_LOGIC { MODE_POINT_BASED, MODE_SIGNAL_BASED };
enum ENUM_TRADE_MODE { MODE_AUTOMATIC, MODE_SEMI_AUTOMATIC };

//--- Egyéni simítási mód Enum ---
enum ENUM_SMOOTH_METHOD
{
   SMOOTH_SMA,    // Simple moving average
   SMOOTH_EMA,    // Exponential moving average
   SMOOTH_SMMA,   // Smoothed moving average
   SMOOTH_TEMA    // Triple Exponential Moving Average
};

//--- Globális Kereskedési Változók ---
double         confirmation_signal_price = 0;

//--- Állapotgép Változók az Újrapróbálkozáshoz ---
bool           g_belepes_fuggoben = false;
ENUM_ORDER_TYPE g_fuggoben_irany;
datetime       g_fuggoben_idotullepes;
datetime       g_utolso_proba_ido;

//--- VÁLTOZÁS: Globális változók az indikátornevekhez ---
string         g_wpr_shortname = "";
string         g_smooth_ma_shortname = "";
string         g_macd_shortname = "";
//-----------------------------------------------------

//--- Bemeneti Paraméterek ---
input group "EA Settings"
input ulong         InpMagicNumber            = 202433;
input string        InpEaComment              = "WPR_Analyst_v4.0";
input ENUM_TRADE_MODE InpTradeMode            = MODE_SEMI_AUTOMATIC;
input ENUM_EXIT_LOGIC InpExitLogic            = MODE_POINT_BASED;
// VÁLTOZÁS: InpCleanupOnDeinit kapcsoló eltávolítva
// input bool          InpCleanupOnDeinit        = true;
input int           InpUjraProbaIdotullepesSec= 10;
input group "Panel Settings"
input int           InpPanelInitialX          = 10;
input int           InpPanelInitialY          = 80;
input int           InpPanelWidth             = 450;
input int           InpPanelHeight            = 165;
input group "Point Input Scaling"
input double        InpInputPointScaler       = 1.0;
input group "Entry Signal & Filters (WPR)"
input int           InpWPRPeriod              = 7;
input ENUM_SMOOTH_METHOD InpWprSmoothingMethod = SMOOTH_TEMA;
input int           InpWprSmoothingPeriod     = 3; // (0 = off)
input double        InpWPRLevelUp             = -20.0;
input double        InpWPRLevelDown           = -80.0;
input int           InpConfirmationPoints     = 0;
input bool          InpUseEmaFilter           = false;
input int           InpEmaPeriod              = 200;
input group "Capital Management"
input double        InpMaxMarginPercent       = 70;
input long          InpMaxSpreadPoints        = 50000;
input int           InpStopsLevelBufferPoints = 5;
input group "Position Management Mode"
input bool          InpUseATRManagement       = true;
input group "Position Management (ATR Based)"
input int           InpATRPeriod              = 14;
input double        InpATRMultiplierSL        = 1.5;
input double        InpATRMultiplierTP        = 3.0;
input double        InpATRMultiplierBETrigger = 0.5;
input double        InpATRMultiplierBELock    = 0.1;
input double        InpATRMultiplierTSTrigger = 0.8;
input double        InpATRMultiplierTSDistance= 0.6;
input group "Position Management (Points Based)"
input int           InpInitialStopLossPoints   = 200;
input int           InpTakeProfitPoints        = 500;
input int           InpBreakevenTriggerPoints  = 100;
input int           InpBreakevenLockInPoints   = 2;
input int           InpTrailingStopTriggerPoints= 120;
input int           InpTrailingStopDistancePoints= 80;
input group "MACD Overlay"
input bool          InpShowMacdOverlay         = true;
input int           InpMacdFastPeriod          = 12;
input int           InpMacdSlowPeriod          = 26;
input int           InpMacdSignalPeriod        = 9;
input ENUM_MA_METHOD InpMacdSignalMaMethod     = MODE_SMA;
input bool          InpMacdUseMultiColor       = true;
input ENUM_APPLIED_PRICE InpMacdAppliedPrice   = PRICE_CLOSE;

//+------------------------------------------------------------------+
//| SEGÉDFÜGGVÉNYEK (HELPER FUNCTIONS)                               |
//+------------------------------------------------------------------+
bool FatalisHiba(long retcode)
  {
   switch((int)retcode)
     {
      case 10014: case 10016: case 10017: case 10020: case 10022:
      case 10018: case 10019: case 10024: case 10029: case 10030:
         return true;
      default:
         return false;
     }
   return false;
  }
//+------------------------------------------------------------------+
double GetCurrentATRValue()
  {
   if(!InpUseATRManagement || atr_handle == INVALID_HANDLE) { return 0.0; }
   double atr_buffer[1];
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1) { Print("Hiba az ATR érték másolásakor! ", GetLastError()); return 0.0; }
   if (atr_buffer[0] <= 0) { Print("Figyelmeztetés: Az ATR érték nulla vagy negatív (", atr_buffer[0], "). Visszatérés 100 ponttal."); return g_point * 100; }
   return atr_buffer[0];
   return 0.0;
  }
//+------------------------------------------------------------------+
//| PANEL ÉS GOMB FUNKCIÓK                                           |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   ObjectCreate(0, panel_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_XDISTANCE, InpPanelInitialX);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_YDISTANCE, InpPanelInitialY);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_XSIZE, InpPanelWidth);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_YSIZE, InpPanelHeight);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, panel_bg_name, OBJPROP_ZORDER, 0);

   ObjectCreate(0, panel_title_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_title_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_title_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, panel_title_name, OBJPROP_YDISTANCE, InpPanelInitialY + 10);
   ObjectSetString(0, panel_title_name, OBJPROP_TEXT, "WPR Analyst v4.3");
   ObjectSetInteger(0, panel_title_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, panel_title_name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, panel_title_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_title_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, panel_status_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_status_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_status_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_YDISTANCE, InpPanelInitialY + 40);
   ObjectSetString(0, panel_status_name, OBJPROP_TEXT, "Initializing...");
   ObjectSetInteger(0, panel_status_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, panel_status_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_status_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, balance_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, balance_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, balance_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, balance_label_name, OBJPROP_YDISTANCE, InpPanelInitialY + 120);
   ObjectSetString(0, balance_label_name, OBJPROP_TEXT, "Balance: ...");
   ObjectSetInteger(0, balance_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, balance_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, balance_label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, balance_label_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, pl_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, pl_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, pl_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, pl_label_name, OBJPROP_YDISTANCE, InpPanelInitialY + 140);
   ObjectSetString(0, pl_label_name, OBJPROP_TEXT, "P/L: N/A");
   ObjectSetInteger(0, pl_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, pl_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, pl_label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, pl_label_name, OBJPROP_ZORDER, 1);
  }
//+------------------------------------------------------------------+
void CreateButtons()
  {
   int panel_x = (int)ObjectGetInteger(0, panel_bg_name, OBJPROP_XDISTANCE);
   int panel_y = (int)ObjectGetInteger(0, panel_bg_name, OBJPROP_YDISTANCE);
   int button_y_pos = panel_y + 70;
   int button_width = 130;
   int button_height = 40;
   int padding = 20;
   int gap = 10;

   int sell_button_x = panel_x + padding;
   ObjectCreate(0, sell_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, sell_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, sell_button_name, OBJPROP_XDISTANCE, sell_button_x);
   ObjectSetInteger(0, sell_button_name, OBJPROP_YDISTANCE, button_y_pos);
   ObjectSetInteger(0, sell_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, sell_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, sell_button_name, OBJPROP_TEXT, "SELL");
   ObjectSetInteger(0, sell_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, sell_button_name, OBJPROP_BGCOLOR, 0xDC143C);
   ObjectSetInteger(0, sell_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, sell_button_name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, sell_button_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, sell_button_name, OBJPROP_STATE, false);

   int buy_button_x = sell_button_x + button_width + gap;
   ObjectCreate(0, buy_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buy_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, buy_button_name, OBJPROP_XDISTANCE, buy_button_x);
   ObjectSetInteger(0, buy_button_name, OBJPROP_YDISTANCE, button_y_pos);
   ObjectSetInteger(0, buy_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, buy_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, buy_button_name, OBJPROP_TEXT, "BUY");
   ObjectSetInteger(0, buy_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, buy_button_name, OBJPROP_BGCOLOR, 0x228B22);
   ObjectSetInteger(0, buy_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, buy_button_name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, buy_button_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, buy_button_name, OBJPROP_STATE, false);

   int close_button_x = buy_button_x + button_width + gap;
   ObjectCreate(0, close_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, close_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, close_button_name, OBJPROP_XDISTANCE, close_button_x);
   ObjectSetInteger(0, close_button_name, OBJPROP_YDISTANCE, button_y_pos);
   ObjectSetInteger(0, close_button_name, OBJPROP_XSIZE, button_width);
   ObjectSetInteger(0, close_button_name, OBJPROP_YSIZE, button_height);
   ObjectSetString(0, close_button_name, OBJPROP_TEXT, "CLOSE");
   ObjectSetInteger(0, close_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, close_button_name, OBJPROP_BGCOLOR, clrSlateGray);
   ObjectSetInteger(0, close_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, close_button_name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, close_button_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, close_button_name, OBJPROP_STATE, false);
  }
//+------------------------------------------------------------------+
void DeletePanelAndButtons()
  {
   ObjectDelete(0, panel_bg_name);
   ObjectDelete(0, panel_title_name);
   ObjectDelete(0, panel_status_name);
   ObjectDelete(0, buy_button_name);
   ObjectDelete(0, sell_button_name);
   ObjectDelete(0, close_button_name);
   ObjectDelete(0, balance_label_name);
   ObjectDelete(0, pl_label_name);
  }
//+------------------------------------------------------------------+
void UpdatePanelStatus()
  {
   string mode_text = "Mode: " + EnumToString(InpTradeMode);
   string status_text = "Status: No Position";

   if(g_belepes_fuggoben)
     { status_text = "Status: Entry Pending..."; }
   else if(position_info.SelectByMagic(_Symbol, InpMagicNumber))
     {
      string type = (position_info.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      status_text = "Status: " + type + " Open";
      double profit = position_info.Profit();
      string pl_text = "P/L: " + DoubleToString(profit, 2);
      color pl_color = (profit >= 0) ? clrLimeGreen : clrRed;
      ObjectSetString(0, pl_label_name, OBJPROP_TEXT, pl_text);
      ObjectSetInteger(0, pl_label_name, OBJPROP_COLOR, pl_color);
     }
   else
     {
      ObjectSetString(0, pl_label_name, OBJPROP_TEXT, "P/L: N/A");
      ObjectSetInteger(0, pl_label_name, OBJPROP_COLOR, clrWhite);
     }

   if(InpTradeMode == MODE_AUTOMATIC) mode_text += " (Override ON)";

   string final_text = mode_text + "  |  " + status_text;
   ObjectSetString(0, panel_status_name, OBJPROP_TEXT, final_text);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   string balance_text = "Balance: " + DoubleToString(balance, 2);
   ObjectSetString(0, balance_label_name, OBJPROP_TEXT, balance_text);
  }
//+------------------------------------------------------------------+
//| KERESKEDÉSI LOGIKA                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   if(g_lot_step <= 0) return 0.0;
   double normalized_lot = floor(lot / g_lot_step) * g_lot_step;
   normalized_lot = MathMax(g_min_lot, normalized_lot);
   normalized_lot = MathMin(g_max_lot, normalized_lot);
   return(normalized_lot);
  }
//+------------------------------------------------------------------+
double CalculateLotSizeByMargin(double max_margin_percent)
  {
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(account_equity <= 0) return 0.0;
   double max_margin_allowed = account_equity * (max_margin_percent / 100.0);
   double margin_required_for_one_lot = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, symbol_info.Ask(), margin_required_for_one_lot) || margin_required_for_one_lot <= 0)
     { Print("Error calculating margin: ", GetLastError()); return 0.0; }
   return NormalizeLot(max_margin_allowed / margin_required_for_one_lot);
  }
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type)
  {
   ResetLastError();
   symbol_info.RefreshRates();
   double current_price = (type == ORDER_TYPE_BUY) ? symbol_info.Ask() : symbol_info.Bid();

   // Confirmation Logic (Nyers pontok)
   if(InpConfirmationPoints > 0)
     {
      if(confirmation_signal_price == 0)
        { confirmation_signal_price = current_price; Print("Signal detected. Waiting for confirmation..."); return false; }
      bool confirmed = (type == ORDER_TYPE_BUY) ?
                       (current_price >= confirmation_signal_price + (InpConfirmationPoints * g_point)) :
                       (current_price <= confirmation_signal_price - (InpConfirmationPoints * g_point));
      if(!confirmed) return false;
      Print("Signal confirmed.");
     }

   // Lot Size Logic
   double lot_size = CalculateLotSizeByMargin(InpMaxMarginPercent);
   if(lot_size <= 0)
     { Print("Could not calculate a valid lot size."); confirmation_signal_price = 0; return false; }

   // SL/TP számítás
   double sl_price = 0;
   double tp_price = 0;
   double current_atr = 0;

   // Minimum távolság (globális g_stops_level -> ár)
   long min_stop_distance_points = g_stops_level + InpStopsLevelBufferPoints;
   double min_stop_distance_price = (double)min_stop_distance_points * g_point;
   if (min_stop_distance_price <= 0) min_stop_distance_price = g_point;

   if(InpUseATRManagement) // ATR mód
     {
      current_atr = GetCurrentATRValue();
      if(current_atr <= 0) { Print("Hiba: Érvénytelen ATR érték (ATR mód)."); confirmation_signal_price = 0; return false; }
      double sl_distance_price = current_atr * InpATRMultiplierSL;
      double final_sl_distance_price = MathMax(sl_distance_price, min_stop_distance_price);
      sl_price = (type == ORDER_TYPE_BUY) ? current_price - final_sl_distance_price : current_price + final_sl_distance_price;
      if(InpATRMultiplierTP > 0)
        {
         double tp_distance_price = current_atr * InpATRMultiplierTP;
         tp_distance_price = MathMax(tp_distance_price, min_stop_distance_price);
         tp_price = (type == ORDER_TYPE_BUY) ? current_price + tp_distance_price : current_price - tp_distance_price;
        }
     }
   else // Pont Alapú mód (Auto FX Adjust 0.1 + Scaler)
     {
      double sl_input_scaled = InpInitialStopLossPoints * InpInputPointScaler;
      double tp_input_scaled = (InpTakeProfitPoints > 0) ? InpTakeProfitPoints * InpInputPointScaler : 0;

      double sl_actual_points = sl_input_scaled * g_point_adjustment_factor;
      double tp_actual_points = tp_input_scaled * g_point_adjustment_factor;

      double desired_sl_price = (type == ORDER_TYPE_BUY) ? current_price - sl_actual_points * g_point : current_price + sl_actual_points * g_point;
      double desired_tp_price = 0;
      if(tp_actual_points > 0)
        { desired_tp_price = (type == ORDER_TYPE_BUY) ? current_price + tp_actual_points * g_point : current_price - tp_actual_points * g_point; }

      if(type == ORDER_TYPE_BUY)
        {
         sl_price = MathMin(desired_sl_price, current_price - min_stop_distance_price);
         if(desired_tp_price > 0) tp_price = MathMax(desired_tp_price, current_price + min_stop_distance_price);
         else tp_price = 0;
        }
      else
        {
         sl_price = MathMax(desired_sl_price, current_price + min_stop_distance_price);
         if(desired_tp_price > 0) tp_price = MathMin(desired_tp_price, current_price - min_stop_distance_price);
         else tp_price = 0;
        }
     }

   sl_price = NormalizeDouble(sl_price, g_digits);
   if(tp_price != 0) tp_price = NormalizeDouble(tp_price, g_digits);

   Print("OpenPosition (", (InpUseATRManagement?"ATR":"Pont")," mód): Aktuális ár=", DoubleToString(current_price, g_digits),
         ", Számított SL=", DoubleToString(sl_price, g_digits),
         ", Számított TP=", (tp_price == 0 ? "0.0" : DoubleToString(tp_price, g_digits)),
         (!InpUseATRManagement? ", AdjFactor="+DoubleToString(g_point_adjustment_factor,1)+", Scaler="+DoubleToString(InpInputPointScaler,2) : ""),
         (InpUseATRManagement? ", ATR="+DoubleToString(current_atr, g_digits) : ""),
         ", MinStopPrice=", DoubleToString(min_stop_distance_price, g_digits));

   if(trade.PositionOpen(_Symbol, type, lot_size, current_price, sl_price, tp_price, InpEaComment))
     {
      string mode_info = InpUseATRManagement ? (" (ATR: " + DoubleToString(current_atr, g_digits) + ")") : (" (Pont, Adj: " + DoubleToString(g_point_adjustment_factor, 1) + ", Scaler: "+ DoubleToString(InpInputPointScaler, 2) + ")");
      Print("Position opened: ", EnumToString(type), " ", lot_size, " lots. SL: ", DoubleToString(sl_price, g_digits), " TP: ", (tp_price==0?"N/A":DoubleToString(tp_price, g_digits)), mode_info);
      confirmation_signal_price = 0;
      return true;
     }
   else
     {
      Print("PositionOpen Error: ", trade.ResultRetcode(), " - ", trade.ResultComment(), " Price: ", DoubleToString(current_price, g_digits), " SL: ", DoubleToString(sl_price, g_digits), " TP: ", DoubleToString(tp_price, g_digits));
      confirmation_signal_price = 0;
      return false;
     }
  }
//+------------------------------------------------------------------+
void CheckForNewSignal(const double prev_wpr_value_unused, const double current_wpr_value_unused)
  {
   if(position_info.SelectByMagic(_Symbol, InpMagicNumber)) return;

   // --- Jel Értékek Beolvasása ---
   double signal_buffer[2];
   int handle_to_use = (InpWprSmoothingPeriod > 0 && smooth_wpr_handle != INVALID_HANDLE) ? smooth_wpr_handle : wpr_handle;

   if(CopyBuffer(handle_to_use, 0, 0, 2, signal_buffer) < 2)
     {
      // Nincs elég adat a jel bufferben, csendben kilépünk.
      return;
     }

   double current_wpr_val = signal_buffer[0];
   double previous_wpr_val = signal_buffer[1];

   if(current_wpr_val == EMPTY_VALUE || previous_wpr_val == EMPTY_VALUE) return;
   // --- Beolvasás Vége ---

   bool buy_cross = previous_wpr_val < InpWPRLevelDown && current_wpr_val >= InpWPRLevelDown;
   bool sell_cross = previous_wpr_val > InpWPRLevelUp && current_wpr_val <= InpWPRLevelUp;

   if(!buy_cross && !sell_cross)
     { confirmation_signal_price = 0; return; }

   symbol_info.Refresh();
   if(symbol_info.Spread() > InpMaxSpreadPoints)
     { PrintFormat("Signal ignored due to high spread: %d > %d", symbol_info.Spread(), InpMaxSpreadPoints); confirmation_signal_price = 0; return; }

   ENUM_ORDER_TYPE signal_type = (buy_cross) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(InpUseEmaFilter)
     {
      double ema_buffer[1];
      if(CopyBuffer(ema_handle, 0, 1, 1, ema_buffer) > 0)
        {
         symbol_info.RefreshRates();
         if(signal_type == ORDER_TYPE_BUY && symbol_info.Bid() < ema_buffer[0]) { confirmation_signal_price = 0; return; }
         if(signal_type == ORDER_TYPE_SELL && symbol_info.Ask() > ema_buffer[0]) { confirmation_signal_price = 0; return; }
        }
     }

   if(!OpenPosition(signal_type))
     {
      long retcode = trade.ResultRetcode();
      if(retcode == 0 || retcode == 10009) { return; }
      if(FatalisHiba(retcode))
        { Print("FATALIS hiba a belepeskor (", retcode, "). Jel torolve. Komment: ", trade.ResultComment()); }
      else
        {
         g_belepes_fuggoben = true; g_fuggoben_irany = signal_type;
         g_fuggoben_idotullepes = TimeCurrent() + InpUjraProbaIdotullepesSec; g_utolso_proba_ido = TimeCurrent();
         Print("Atmeneti hiba a belepeskor (", retcode, "). Ujraprobalkozas indul ", InpUjraProbaIdotullepesSec, " mp-ig.");
        }
     }
  }
//+------------------------------------------------------------------+
void ManageOpenPosition(const double prev_wpr_value, const double current_wpr_value)
  {
   if(!position_info.SelectByMagic(_Symbol, InpMagicNumber)) return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)position_info.PositionType();

   // Jel alapú kilépés a NYERS WPR értékekkel
   if(InpExitLogic == MODE_SIGNAL_BASED && InpTradeMode == MODE_AUTOMATIC)
     {
      bool close_buy  = (type == POSITION_TYPE_BUY) && (prev_wpr_value > InpWPRLevelUp && current_wpr_value <= InpWPRLevelUp);
      bool close_sell = (type == POSITION_TYPE_SELL) && (prev_wpr_value < InpWPRLevelDown && current_wpr_value >= InpWPRLevelDown);
      if(close_buy || close_sell)
        {
         PrintFormat("Signal Exit triggered: PrevWPR=%.2f, CurrWPR=%.2f", prev_wpr_value, current_wpr_value);
         trade.PositionClose(position_info.Ticket());
         return;
        }
     }

   // --- A többi menedzsment logika (BE, TS) változatlan ---
   double open_price = position_info.PriceOpen();
   double current_sl = position_info.StopLoss();
   double current_tp = position_info.TakeProfit();
   symbol_info.RefreshRates();
   double current_close_price = (type == POSITION_TYPE_BUY) ? symbol_info.Bid() : symbol_info.Ask();
   bool trailing_stop_modified = false;

   if(InpUseATRManagement) // ATR mód
     {
      double current_atr = GetCurrentATRValue();
      if(current_atr <= 0) { Print("Hiba: Érvénytelen ATR érték (ATR mód)."); return; }
      double be_trigger_price_diff   = current_atr * InpATRMultiplierBETrigger;
      double be_lock_price_diff      = current_atr * InpATRMultiplierBELock;
      double ts_trigger_price_diff   = current_atr * InpATRMultiplierTSTrigger;
      double ts_distance_price_diff  = current_atr * InpATRMultiplierTSDistance;
      double current_profit_price = (type == POSITION_TYPE_BUY) ? (current_close_price - open_price) : (open_price - current_close_price);

      if(InpATRMultiplierTSTrigger > 0 && current_profit_price >= ts_trigger_price_diff)
        {
         double new_ts_sl_price = (type == POSITION_TYPE_BUY) ? current_close_price - ts_distance_price_diff : current_close_price + ts_distance_price_diff;
         new_ts_sl_price = NormalizeDouble(new_ts_sl_price, g_digits);
         if((type == POSITION_TYPE_BUY && new_ts_sl_price > current_sl) || (type == POSITION_TYPE_SELL && (new_ts_sl_price < current_sl || current_sl == 0)))
           { if(trade.PositionModify(position_info.Ticket(), new_ts_sl_price, current_tp)) trailing_stop_modified = true; else Print("Hiba a TS módosításakor (ATR): ", trade.ResultRetcode(), " - ", trade.ResultComment()); }
        }
      if(!trailing_stop_modified && InpATRMultiplierBETrigger > 0 && current_profit_price >= be_trigger_price_diff)
        {
         double be_price = (type == POSITION_TYPE_BUY) ? open_price + be_lock_price_diff : open_price - be_lock_price_diff;
         be_price = NormalizeDouble(be_price, g_digits);
         if((type == POSITION_TYPE_BUY && current_sl < be_price) || (type == POSITION_TYPE_SELL && (current_sl > be_price || current_sl == 0)))
           { if(!trade.PositionModify(position_info.Ticket(), be_price, current_tp)) Print("Hiba a BE módosításakor (ATR): ", trade.ResultRetcode(), " - ", trade.ResultComment()); }
        }
     }
   else // Pont Alapú mód
     {
      double profit_in_actual_points = ((type == POSITION_TYPE_BUY) ? (current_close_price - open_price) : (open_price - current_close_price)) / g_point;

      double ts_trigger_actual_points = InpTrailingStopTriggerPoints * InpInputPointScaler * g_point_adjustment_factor;
      if(InpTrailingStopTriggerPoints > 0 && profit_in_actual_points >= ts_trigger_actual_points)
        {
         double ts_distance_actual_points = InpTrailingStopDistancePoints * InpInputPointScaler * g_point_adjustment_factor;
         double new_ts_sl_price = (type == POSITION_TYPE_BUY) ? current_close_price - ts_distance_actual_points * g_point : current_close_price + ts_distance_actual_points * g_point;
         new_ts_sl_price = NormalizeDouble(new_ts_sl_price, g_digits);
         if((type == POSITION_TYPE_BUY && new_ts_sl_price > current_sl) || (type == POSITION_TYPE_SELL && (new_ts_sl_price < current_sl || current_sl == 0)))
           { if(trade.PositionModify(position_info.Ticket(), new_ts_sl_price, current_tp)) trailing_stop_modified = true; else Print("Hiba a TS módosításakor (Pont): ", trade.ResultRetcode(), " - ", trade.ResultComment()); }
        }

      double be_trigger_actual_points = InpBreakevenTriggerPoints * InpInputPointScaler * g_point_adjustment_factor;
      if(!trailing_stop_modified && InpBreakevenTriggerPoints > 0 && profit_in_actual_points >= be_trigger_actual_points)
        {
         double be_lock_actual_points = InpBreakevenLockInPoints * InpInputPointScaler * g_point_adjustment_factor;
         double be_price = (type == POSITION_TYPE_BUY) ? open_price + be_lock_actual_points * g_point : open_price - be_lock_actual_points * g_point;
         be_price = NormalizeDouble(be_price, g_digits);
         if((type == POSITION_TYPE_BUY && current_sl < be_price) || (type == POSITION_TYPE_SELL && (current_sl > be_price || current_sl == 0)))
           { if(!trade.PositionModify(position_info.Ticket(), be_price, current_tp)) Print("Hiba a BE módosításakor (Pont): ", trade.ResultRetcode(), " - ", trade.ResultComment()); }
        }
     }
  }
//+------------------------------------------------------------------+
//| ESEMÉNYKEZELŐ FUNKCIÓK                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();

   // --- Instrumentum Adatok Lekérdezése és Tárolása ---
   if(!symbol_info.Name(_Symbol))
     { Print("Hiba a szimbólum nevének beállításakor: ", GetLastError()); return(INIT_FAILED); }
   symbol_info.Refresh();

   g_digits = (int)symbol_info.Digits();
   g_point = symbol_info.Point();
   g_stops_level = symbol_info.StopsLevel();
   g_min_lot = symbol_info.LotsMin();
   g_max_lot = symbol_info.LotsMax();
   g_lot_step = symbol_info.LotsStep();
   ENUM_SYMBOL_TRADE_MODE trade_mode = (ENUM_SYMBOL_TRADE_MODE)symbol_info.TradeMode();
   ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)symbol_info.TradeCalcMode();

   if(g_digits <= 0 || g_point <= 0)
     { Print("Hiba: Alapvető szimbólum adatok (Digits, Point) lekérdezése sikertelen!"); return(INIT_FAILED); }
   if(trade_mode != SYMBOL_TRADE_MODE_FULL)
     { Print("Figyelmeztetés: Kereskedés nem engedélyezett (TradeMode: ", EnumToString(trade_mode), ")"); }

   // --- Automatikus Forex Pont Faktor Beállítása (0.1 vagy 1.0) ---
   g_point_adjustment_factor = 1.0;
   bool is_forex_calc_mode = (calc_mode == SYMBOL_CALC_MODE_FOREX || calc_mode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);

   if (is_forex_calc_mode && (g_digits == 5 || g_digits == 3))
     {
      g_point_adjustment_factor = 0.1;
      PrintFormat("%s: Forex (5/3 Digits) detektálva. Pont alapú inputok tizedelve (belső x0.1 szorzó).", _Symbol);
     }
   else
     {
      g_point_adjustment_factor = 1.0;
      PrintFormat("%s: Nem-pip Forex vagy egyéb instrumentum detektálva. Pont alapú inputok változatlanul (belső x1.0 szorzó).", _Symbol);
     }
   PrintFormat("Automatikus Pont Faktor: %.1f", g_point_adjustment_factor);
   PrintFormat("Felhasználói Skálázó (InpInputPointScaler): %.2f", InpInputPointScaler);
   // --- Faktor Beállítása Vége ---

   // --- További Inicializálás ---
   g_belepes_fuggoben = false;
   // VÁLTOZÁS: Indikátornevek inicializálása
   g_wpr_shortname = "";
   g_smooth_ma_shortname = "";
   g_macd_shortname = "";

   wpr_handle = iWPR(_Symbol, _Period, InpWPRPeriod);
   if(wpr_handle == INVALID_HANDLE) { Print("Error creating WPR handle"); return(INIT_FAILED); }
   // VÁLTOZÁS: Indikátornév lekérdezése
   if(ChartIndicatorAdd(0, 1, wpr_handle))
     {
      g_wpr_shortname = ChartIndicatorName(0, 1, 0); // 0. indikátor a 1. ablakban
      Print("Added WPR indicator, shortname: ", g_wpr_shortname);
     }
   else { Print("Failed to add WPR indicator to chart!"); }


   // --- Simított WPR Indikátor Létrehozása és Hozzáadása ---
   smooth_wpr_handle = INVALID_HANDLE; // Alaphelyzetbe állítás
   if(InpWprSmoothingPeriod > 0)
     {
      // A felhasználói input alapján választjuk ki a megfelelő simítási függvényt
      switch(InpWprSmoothingMethod)
        {
         case SMOOTH_TEMA:
            // TEMA hívása, ha az van kiválasztva
            smooth_wpr_handle = iTEMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, wpr_handle);
            break;
         case SMOOTH_SMA:
            smooth_wpr_handle = iMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, MODE_SMA, wpr_handle);
            break;
         case SMOOTH_EMA:
            smooth_wpr_handle = iMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, MODE_EMA, wpr_handle);
            break;
         case SMOOTH_SMMA:
            smooth_wpr_handle = iMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, MODE_SMMA, wpr_handle);
            break;
        }

      if(smooth_wpr_handle != INVALID_HANDLE)
        {
         // Hozzáadjuk a simított indikátort ugyanahhoz az ablakhoz, mint a WPR-t
         if(ChartIndicatorAdd(0, 1, smooth_wpr_handle))
           {
            // A név lekérdezése a Deinit-hez szükséges
            g_smooth_ma_shortname = ChartIndicatorName(0, 1, 1); // Index 1, mert ez a második a subwindow-ban
            Print("Added Smoothed WPR indicator (", EnumToString(InpWprSmoothingMethod), "), shortname: ", g_smooth_ma_shortname);
           }
         else
           {
            Print("Failed to add Smoothed WPR indicator to chart! Error: ", GetLastError());
           }
        }
      else
        {
         Print("Error creating Smoothed WPR handle! Error: ", GetLastError());
        }
     }
   // --- Simítás Vége ---

   // --- MACD Overlay Létrehozása és Hozzáadása a WPR ablakba ---
   if(InpShowMacdOverlay)
     {
      macd_handle = iCustom(
         _Symbol,
         _Period,
         "MACD Histogram MC",
         InpMacdFastPeriod,
         InpMacdSlowPeriod,
         InpMacdSignalPeriod,
         InpMacdSignalMaMethod,
         (InpMacdUseMultiColor ? 0 : 1),
         InpMacdAppliedPrice
      );
      if(macd_handle == INVALID_HANDLE)
        {
         Print("Error creating MACD handle: ", GetLastError());
         return(INIT_FAILED);
        }

      // MACD indikátor hozzáadása a WPR külön ablakához (index: 1)
      if(ChartIndicatorAdd(0, 1, macd_handle))
        {
         // A MACD saját skálát használhat, így vizuálisan a WPR felett jelenik meg rétegként
         g_macd_shortname = ChartIndicatorName(0, 1, (smooth_wpr_handle != INVALID_HANDLE) ? 2 : 1);
         Print("Added MACD overlay indicator, shortname: ", g_macd_shortname);
        }
      else
        {
         Print("Failed to add MACD overlay indicator to WPR window! Error: ", GetLastError());
        }
     }

   if(InpUseEmaFilter)
     {
      ema_handle = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE) { Print("Error creating EMA handle"); return(INIT_FAILED); }
      ChartIndicatorAdd(0, 0, ema_handle); // EMA a fő ablakba (0)
     }

   if(InpUseATRManagement)
     {
      atr_handle = iATR(_Symbol, _Period, InpATRPeriod);
      if(atr_handle == INVALID_HANDLE) { Print("Error creating ATR handle: ", GetLastError()); return(INIT_FAILED); }
      // ATR-t nem rajzoljuk ki
     }

   CreatePanel();
   CreateButtons();
   UpdatePanelStatus();

   Print("WPR Analyst v4.3 Initialized.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason) // VÁLTOZÁS: Takarítás ChartIndicatorDelete-tel
  {
   Print("Deinitializing EA. Reason code: ", reason);
   g_belepes_fuggoben = false;
   DeletePanelAndButtons();

   // --- Indikátorok Törlése a Chartról (MINDEN OnDeinit Esetén) ---
   // Ez biztosítja, hogy paraméterváltoztatáskor a régi görbék eltűnjenek.

   // Először a simított MA-t töröljük, ha létezik (volt neve)
   if(g_smooth_ma_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 1, g_smooth_ma_shortname))
        { Print("Failed to delete Smooth MA indicator: ", g_smooth_ma_shortname); }
      else { Print("Deleted Smooth MA indicator: ", g_smooth_ma_shortname); }
     }
   // MACD overlay törlése, ha hozzá lett adva
   if(g_macd_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 1, g_macd_shortname))
        { Print("Failed to delete MACD overlay indicator: ", g_macd_shortname); }
      else { Print("Deleted MACD overlay indicator: ", g_macd_shortname); }
     }
   // Majd az eredeti WPR-t töröljük, ha létezik (volt neve)
   if(g_wpr_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 1, g_wpr_shortname))
        { Print("Failed to delete WPR indicator: ", g_wpr_shortname); }
      else { Print("Deleted WPR indicator: ", g_wpr_shortname); }
     }

   // Handle-ök felszabadítása továbbra is szükséges
   if(wpr_handle != INVALID_HANDLE) IndicatorRelease(wpr_handle);
   if(smooth_wpr_handle != INVALID_HANDLE) IndicatorRelease(smooth_wpr_handle);
   if(ema_handle != INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);

   // Pozíciók zárása, ha az EA-t eltávolítják (kapcsoló nélkül)
   if(reason == REASON_REMOVE)
     {
      if(position_info.SelectByMagic(_Symbol, InpMagicNumber))
        {
         Print("Closing open position due to EA removal...");
         trade.PositionClose(position_info.Ticket());
        }
     }
   Print("WPR Analyst deinitialized.");
  }
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
//--- Panel mozgatás ---
   if(id == CHARTEVENT_OBJECT_DRAG && sparam == panel_bg_name)
     { is_panel_dragging = true; panel_drag_offset_x = (int)lparam - (int)ObjectGetInteger(0, panel_bg_name, OBJPROP_XDISTANCE); panel_drag_offset_y = (int)dparam - (int)ObjectGetInteger(0, panel_bg_name, OBJPROP_YDISTANCE); return; }
   if(id == CHARTEVENT_MOUSE_MOVE && is_panel_dragging)
     {
      int key_status = (int)StringToInteger(sparam);
      if((key_status & 1) == 1)
        {
         int new_x = (int)lparam - panel_drag_offset_x; int new_y = (int)dparam - panel_drag_offset_y;
         ObjectSetInteger(0, panel_bg_name, OBJPROP_XDISTANCE, new_x); ObjectSetInteger(0, panel_bg_name, OBJPROP_YDISTANCE, new_y);
         ObjectSetInteger(0, panel_title_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, panel_title_name, OBJPROP_YDISTANCE, new_y + 10);
         ObjectSetInteger(0, panel_status_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, panel_status_name, OBJPROP_YDISTANCE, new_y + 40);
         int button_y_pos = new_y + 70; int padding = 20; int gap = 10;
         int sell_button_x = new_x + padding;
         ObjectSetInteger(0, sell_button_name, OBJPROP_XDISTANCE, sell_button_x); ObjectSetInteger(0, sell_button_name, OBJPROP_YDISTANCE, button_y_pos);
         int buy_button_x = sell_button_x + (int)ObjectGetInteger(0, sell_button_name, OBJPROP_XSIZE) + gap;
         ObjectSetInteger(0, buy_button_name, OBJPROP_XDISTANCE, buy_button_x); ObjectSetInteger(0, buy_button_name, OBJPROP_YDISTANCE, button_y_pos);
         int close_button_x = buy_button_x + (int)ObjectGetInteger(0, buy_button_name, OBJPROP_XSIZE) + gap;
         ObjectSetInteger(0, close_button_name, OBJPROP_XDISTANCE, close_button_x); ObjectSetInteger(0, close_button_name, OBJPROP_YDISTANCE, button_y_pos);
         ObjectSetInteger(0, balance_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, balance_label_name, OBJPROP_YDISTANCE, new_y + 120);
         ObjectSetInteger(0, pl_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, pl_label_name, OBJPROP_YDISTANCE, new_y + 140);
        } else { is_panel_dragging = false; } return;
     }

//--- Gombnyomások ---
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(g_belepes_fuggoben) { Print("Manual entry blocked: Automatic entry pending."); ObjectSetInteger(0, sparam, OBJPROP_STATE, false); ChartRedraw(); return; }
      Print("Object Click Event Detected. Clicked Object: '", sparam, "'");

      if(sparam == buy_button_name)
        {
         if(!position_info.SelectByMagic(_Symbol, InpMagicNumber)) { Print("Kézi VEGYÉL parancs fogadva..."); OpenPosition(ORDER_TYPE_BUY); }
         else { Print("Kézi VEGYÉL figyelmen kívül: Már van pozíció."); }
        }
      else if(sparam == sell_button_name)
        {
         if(!position_info.SelectByMagic(_Symbol, InpMagicNumber)) { Print("Kézi ADJ EL parancs fogadva..."); OpenPosition(ORDER_TYPE_SELL); }
         else { Print("Kézi ADJ EL figyelmen kívül: Már van pozíció."); }
        }
      else if(sparam == close_button_name)
        {
         if(position_info.SelectByMagic(_Symbol, InpMagicNumber))
           {
            Print("Kézi ZÁRJ parancs fogadva...");
            if(trade.PositionClose(position_info.Ticket())) { Print("Pozíció sikeresen lezárva."); }
            else { Print("HIBA a záráskor: ", trade.ResultRetcode(), " - ", trade.ResultComment()); }
           }
         else { Print("Kézi ZÁRJ figyelmen kívül: Nincs mit zárni."); }
        }

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- WPR Adatok olvasása (a ManageOpenPosition Signal Exithez és a CheckForNewSignal-hoz kellenek, ha nincs simítás) ---
   double wpr_buffer_raw[2]; // Nyers WPR értékek tárolása
   if(CopyBuffer(wpr_handle, 0, 0, 2, wpr_buffer_raw) < 2) { Print("Hiba WPR adatok másolásakor OnTick-ben!"); return; }
   double raw_current_wpr     = wpr_buffer_raw[0];
   double raw_previous_wpr = wpr_buffer_raw[1];

   // --- Panel Frissítés ---
   UpdatePanelStatus();

   // --- ÁLLAPOTGÉP (RETRY LOGIC) ---
   if(g_belepes_fuggoben)
     {
      if(TimeCurrent() > g_fuggoben_idotullepes) { Print("Belepesi probalkozas idotullepes miatt torolve."); g_belepes_fuggoben = false; return; }
      if(TimeCurrent() < g_utolso_proba_ido + 1) { return; }

      Print("Ujraprobalkozas a belepessel: ", EnumToString(g_fuggoben_irany));
      g_utolso_proba_ido = TimeCurrent();

      if(OpenPosition(g_fuggoben_irany))
        { Print("Ujraprobalkozas sikeres."); g_belepes_fuggoben = false; }
      else
        {
         long retcode = trade.ResultRetcode();
         // Check for non-temporary errors (excluding REQUOTE, CONNECTION issues, Request Accepted)
         if(retcode != 0 && retcode != TRADE_RETCODE_REQUOTE && retcode != TRADE_RETCODE_CONNECTION && retcode != 10009)
           {
            Print("Nem átmeneti hiba ujraprobalkozas kozben (", retcode, "). Jel torolve.");
            g_belepes_fuggoben = false;
           }
        }
      return;
     }

   // --- NORMÁL MŰKÖDÉS ---
   if(position_info.SelectByMagic(_Symbol, InpMagicNumber))
     {
      // A ManageOpenPosition Signal Exit-hez átadjuk a nyers WPR értékeket
      ManageOpenPosition(raw_previous_wpr, raw_current_wpr);
     }
   else if(InpTradeMode == MODE_AUTOMATIC)
     {
      // A CheckForNewSignal most már belsőleg kezeli a simítást vagy a nyers értékeket.
      CheckForNewSignal(raw_previous_wpr, raw_current_wpr);
     }
  }
//+------------------------------------------------------------------+