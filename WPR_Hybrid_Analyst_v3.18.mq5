//+------------------------------------------------------------------+
//|                          WPR_Hybrid_Analyst_v3.18.mq5 |
//|                        Copyright 2024, Gemini & User Collaboration |
//|        Verzió: Statisztikai modul eltávolítva, stabil alap         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.18"

//+------------------------------------------------------------------+
//| Tartalmazza (Includes)                                           |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include "Trailings.mqh"
#include <Math\Stat\Stat.mqh>
#include <Object.mqh>

//+------------------------------------------------------------------+
//| Enum definíciók                                                  |
//+------------------------------------------------------------------+
enum ENUM_EXIT_LOGIC { MODE_POINT_BASED, MODE_SIGNAL_BASED };
enum ENUM_TRADE_MODE { MODE_AUTOMATIC, MODE_SEMI_AUTOMATIC };
enum ENUM_PROFIT_MODE { MODE_POINTS, MODE_PSAR, MODE_VIDYA, MODE_SPIKE_PROTECTOR };

enum ENUM_SMOOTH_METHOD
  {
   SMOOTH_SMA   = 0, // Simple Moving Average
   SMOOTH_EMA   = 1, // Exponential Moving Average
   SMOOTH_SMMA  = 2, // Smoothed Moving Average
   SMOOTH_LWMA  = 3, // Linear Weighted Moving Average
   SMOOTH_DEMA  = 10 // Double Exponential Moving Average (Ajánlott)
  };
// ---

//+------------------------------------------------------------------+
//| Bemeneti Paraméterek                                             |
//+------------------------------------------------------------------+
input group "EA Settings"
input ulong         InpMagicNumber            = 202433;
input string        InpEaComment              = "WPR_Hybrid_Analyst_v3.18";
input ENUM_TRADE_MODE InpTradeMode            = MODE_SEMI_AUTOMATIC;
input ENUM_EXIT_LOGIC InpExitLogic            = MODE_POINT_BASED;
input int           InpUjraProbaIdotullepesSec= 10;
input group "Panel Settings"
input bool          InpUsePanelOverrides      = true;
input int           InpPanelInitialX          = 10;
input int           InpPanelInitialY          = 80;
input int           InpPanelWidth             = 700;
input int           InpPanelHeight            = 280;
input group "Point Input Scaling"
input double        InpInputPointScaler       = 1.0;
input group "Entry Signal & Filters (WPR)"
input bool          InpUseAdaptiveWPR         = true;
input int           InpWprBasePeriod          = 14;
input int           InpAdaptiveAtrPeriod      = 21;
input double        InpAdaptiveSensitivity    = 1.5;
input int           InpWprPeriodMin           = 5;
input int           InpWprPeriodMax           = 100;
input ENUM_SMOOTH_METHOD InpWprSmoothingMethod = SMOOTH_DEMA;
input int            InpWprSmoothingPeriod    = 3;
input double        InpDemaVolumeFactor       = 0.7;    // Generalized DEMA "volume" faktora
input double        InpWPRLevelUp             = -20.0;
input double        InpWPRLevelDown           = -80.0;
input group "Signal Strength Filter"
input bool          InpUseSignalStrengthFilter= true;
input int           InpMinSignalStrength      = 5;      // Minimum score (1-10) for auto trade
input int           InpConfirmationPoints     = 0;
input bool          InpUseEmaFilter           = false;
input int           InpEmaPeriod              = 200;
input group "Capital Management"
input double        InpMaxMarginPercent       = 70;
input long          InpMaxSpreadPoints        = 50000;
input int           InpStopsLevelBufferPoints = 5;
input group "Profit Management Settings"
input ENUM_PROFIT_MODE InpProfitMode = MODE_SPIKE_PROTECTOR;
input group "PSAR Trailing Settings"
input double InpPsarStep = 0.02;
input double InpPsarMax  = 0.2;
input group "VIDYA Trailing Settings"
input int    InpVidyaCmoPeriod = 9;
input int    InpVidyaEmaPeriod = 30;
input int    InpVidyaShiftPts  = 10;
input group "Spike Protector Settings"
input int    InpSpikeProfitPoints   = 50;
input int    InpSpikeTimeSeconds    = 5;
input int    InpSpikeBreakevenPts   = 5;
input int    InpSpikeConfirmSeconds = 10;
input double InpSpikePullbackTol    = 50.0;
input int    InpSpikeTrailTemaPeriod = 9;
input int    InpSpikeTrailTemaShift  = 10;
input group "Position Management (Points Based)"
input int           InpInitialStopLossPoints    = 200;
input int           InpTakeProfitPoints         = 500;
input int           InpBreakevenTriggerPoints   = 100;
input int           InpBreakevenLockInPoints    = 2;
input int           InpTrailingStopTriggerPoints= 120;
input int           InpTrailingStopDistancePoints= 80;

//+------------------------------------------------------------------+
//| Globális Változók                                                |
//+------------------------------------------------------------------+
CTrade          trade;
CSymbolInfo     symbol_info;
CPositionInfo   position_info;
int             wpr_handle = INVALID_HANDLE;
int             ema_handle = INVALID_HANDLE;
int             atr_handle = INVALID_HANDLE;
int             g_wpr_smooth_handle = INVALID_HANDLE;
int             adaptive_atr_handle = INVALID_HANDLE;
int             g_current_wpr_period = 0; // Dinamikusan kalkulált WPR periódus
int             g_rsi_handle = INVALID_HANDLE;
int             g_bb_handle = INVALID_HANDLE;
int             g_ema_m15_handle = INVALID_HANDLE;
int             g_ema_m30_handle = INVALID_HANDLE;
int             g_ema_h1_handle = INVALID_HANDLE;
int             g_ema_h4_handle = INVALID_HANDLE;
int             g_ema_current_handle = INVALID_HANDLE;
int             g_digits = 0;
double          g_point = 0.0;
long            g_stops_level = 0;
double          g_min_lot = 0.0;
double          g_max_lot = 0.0;
double          g_lot_step = 0.0;
double          g_point_adjustment_factor = 1.0;
string          panel_bg_name    = "WPR_Panel_BG";
string          panel_title_name = "WPR_Panel_Title";
string          panel_status_name= "WPR_Panel_Status";
string          sell_button_name = "WPR_Manual_Sell_Button";
string          buy_button_name  = "WPR_Manual_Buy_Button";
string          close_button_name= "WPR_Manual_Close_Button";
string          balance_label_name = "WPR_Panel_Balance";
string          pl_label_name    = "WPR_Panel_PL";
string          broker_info_label_name = "WPR_Panel_Broker_Info";
string          market_info_label_name = "WPR_Panel_Market_Info";
string          multi_tf_trend_label_name = "WPR_Panel_MTF_Trend";
string          signal_strength_label_name = "WPR_Panel_Signal_Strength";
bool            is_panel_dragging= false;
int             panel_drag_offset_x = 0;
int             panel_drag_offset_y = 0;
double          confirmation_signal_price = 0;
bool            g_belepes_fuggoben = false;
ENUM_ORDER_TYPE g_fuggoben_irany;
datetime        g_fuggoben_idotullepes;
datetime        g_utolso_proba_ido;
int             g_last_signal_strength = 0;
//--- Spike Protector Globális Változók ---
datetime        g_spike_detected_time = 0;
double          g_spike_peak_price = 0;
bool            g_spike_breakeven_set = false;
bool            g_spike_trailing_activated = false;

//--- Trailings.mqh Objektum ---
CSimpleTrailing *g_trailings;

//--- Globális indikátornevek a tiszta törléshez ---
string          g_wpr_shortname = "";
string          g_smooth_wpr_shortname = "";
string          g_ema_filter_shortname = "";
//-----------------------------------------------------

//--- Panel Override Globális Változók ---
bool            g_override_active = false;
double          g_override_margin_percent = 0;
double          g_override_sl_atr = 0;
double          g_override_tp_atr = 0;
int             g_override_sl_pts = 0;
int             g_override_tp_pts = 0;

//--- Panel Override Objektumnevek ---
string          override_title_name = "WPR_Override_Title";
string          override_margin_label_name = "WPR_Override_Margin_Label";
string          override_margin_edit_name = "WPR_Override_Margin_Edit";
string          override_mode_button_atr_name = "WPR_Override_Mode_ATR";
string          override_mode_button_pts_name = "WPR_Override_Mode_PTS";
string          override_sl_label_name = "WPR_Override_SL_Label";
string          override_sl_edit_name = "WPR_Override_SL_Edit";
string          override_tp_label_name = "WPR_Override_TP_Label";
string          override_tp_edit_name = "WPR_Override_TP_Edit";
string          override_rr_label_name = "WPR_Override_RR_Label";


//+------------------------------------------------------------------+
//| SEGÉDFÜGGVÉNYEK (Változatlan)                                    |
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
   if(atr_handle == INVALID_HANDLE) { return 0.0; }
   double atr_buffer[1];
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1) { Print("Hiba az ATR érték másolásakor! ", GetLastError()); return 0.0; }
   if (atr_buffer[0] <= 0) { Print("Figyelmeztetés: Az ATR érték nulla vagy negatív (", atr_buffer[0], "). Visszatérés 100 ponttal."); return g_point * 100; }
   return atr_buffer[0];
  }
//+------------------------------------------------------------------+
//| ADAPTÍV LOGIKA                                                   |
//+------------------------------------------------------------------+
void UpdateAdaptiveWPRPeriod()
{
    if (!InpUseAdaptiveWPR || adaptive_atr_handle == INVALID_HANDLE)
    {
        g_current_wpr_period = InpWprBasePeriod;
        return;
    }

    // Volatilitás mérése az ATR segítségével
    double atr_buffer[100]; // Elég nagy buffer a hosszútávú átlaghoz
    if (CopyBuffer(adaptive_atr_handle, 0, 0, 100, atr_buffer) < 100)
    {
        Print("Hiba az adaptív ATR buffer másolásakor! Visszaállás az alap periódusra.");
        g_current_wpr_period = InpWprBasePeriod;
        return;
    }

    // Egyszerűsített volatilitási arány számítás: utolsó 5 gyertya átlaga a 100-as átlaghoz képest
    double short_term_avg_atr = 0;
    for (int i = 0; i < 5; i++) short_term_avg_atr += atr_buffer[i];
    short_term_avg_atr /= 5;

    double long_term_avg_atr = 0;
    for (int i = 0; i < 100; i++) long_term_avg_atr += atr_buffer[i];
    long_term_avg_atr /= 100;

    if (long_term_avg_atr <= 0) {
        g_current_wpr_period = InpWprBasePeriod;
        return;
    }

    double volatility_ratio = short_term_avg_atr / long_term_avg_atr;

    // A WPR periódus beállítása a volatilitási arány alapján
    int new_period = (int)MathRound(InpWprBasePeriod * (1.0 + (volatility_ratio - 1.0) * InpAdaptiveSensitivity));

    // A periódus korlátozása a megadott min/max értékek között
    g_current_wpr_period = MathMax(InpWprPeriodMin, MathMin(InpWprPeriodMax, new_period));
}


//+------------------------------------------------------------------+
//| PANEL ÉS GOMB FUNKCIóK (Refaktorált)                             |
//+------------------------------------------------------------------+
void CreatePanelAndControls()
  {
   // --- Alap Panel ---
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

   // --- Címke ---
   ObjectCreate(0, panel_title_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_title_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_title_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, panel_title_name, OBJPROP_YDISTANCE, InpPanelInitialY + 10);
   ObjectSetString(0, panel_title_name, OBJPROP_TEXT, "WPR Control Trader v3.18");
   ObjectSetInteger(0, panel_title_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, panel_title_name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, panel_title_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_title_name, OBJPROP_ZORDER, 1);

   // --- Státusz Címke ---
   ObjectCreate(0, panel_status_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_status_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_status_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_YDISTANCE, InpPanelInitialY + 40);
   ObjectSetString(0, panel_status_name, OBJPROP_TEXT, "Initializing...");
   ObjectSetInteger(0, panel_status_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, panel_status_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, panel_status_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel_status_name, OBJPROP_ZORDER, 1);

   // --- Gombok ---
   int panel_x = InpPanelInitialX;
   int panel_y = InpPanelInitialY;
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
   ObjectSetInteger(0, sell_button_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
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
   ObjectSetInteger(0, buy_button_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
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
   ObjectSetInteger(0, close_button_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, close_button_name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, close_button_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, close_button_name, OBJPROP_STATE, false);

   // --- Számla Információk ---
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

   // --- Info Szekció ---
   int info_y_start = InpPanelInitialY + 165;
   ObjectCreate(0, broker_info_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_YDISTANCE, info_y_start);
   ObjectSetString(0, broker_info_label_name, OBJPROP_TEXT, "Broker: ...");
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, broker_info_label_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, market_info_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, market_info_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, market_info_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, market_info_label_name, OBJPROP_YDISTANCE, info_y_start + 20);
   ObjectSetString(0, market_info_label_name, OBJPROP_TEXT, "Market: ...");
   ObjectSetInteger(0, market_info_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, market_info_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, market_info_label_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, multi_tf_trend_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_YDISTANCE, info_y_start + 40);
   ObjectSetString(0, multi_tf_trend_label_name, OBJPROP_TEXT, "MTF Trend: ...");
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_ZORDER, 1);

   ObjectCreate(0, signal_strength_label_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_XDISTANCE, InpPanelInitialX + 10);
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_YDISTANCE, info_y_start + 60);
   ObjectSetString(0, signal_strength_label_name, OBJPROP_TEXT, "Signal Strength: ...");
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, signal_strength_label_name, OBJPROP_ZORDER, 1);

   // --- Position Management Override Szekció ---
   if(InpUsePanelOverrides)
   {
       int override_x_start = InpPanelInitialX + 430;
       int override_y_start = InpPanelInitialY + 10;

       ObjectCreate(0, override_title_name, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, override_title_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_title_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_title_name, OBJPROP_YDISTANCE, override_y_start);
       ObjectSetString(0, override_title_name, OBJPROP_TEXT, "--- Next Trade Overrides ---");
       ObjectSetInteger(0, override_title_name, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, override_title_name, OBJPROP_FONTSIZE, 10);
       ObjectSetInteger(0, override_title_name, OBJPROP_ZORDER, 1);

       // Margin
       ObjectCreate(0, override_margin_label_name, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_YDISTANCE, override_y_start + 30);
       ObjectSetString(0, override_margin_label_name, OBJPROP_TEXT, "Max Margin %:");
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_FONTSIZE, 10);
       ObjectSetInteger(0, override_margin_label_name, OBJPROP_ZORDER, 1);

       ObjectCreate(0, override_margin_edit_name, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_XDISTANCE, override_x_start + 100);
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_YDISTANCE, override_y_start + 25);
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_XSIZE, 50);
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_YSIZE, 20);
       ObjectSetString(0, override_margin_edit_name, OBJPROP_TEXT, DoubleToString(InpMaxMarginPercent, 1));
       ObjectSetInteger(0, override_margin_edit_name, OBJPROP_ZORDER, 2);


       // Mode Buttons
       ObjectCreate(0, override_mode_button_atr_name, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, override_mode_button_atr_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_mode_button_atr_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_mode_button_atr_name, OBJPROP_YDISTANCE, override_y_start + 60);
       ObjectSetInteger(0, override_mode_button_atr_name, OBJPROP_XSIZE, 80);
       ObjectSetInteger(0, override_mode_button_atr_name, OBJPROP_YSIZE, 25);
       // ATR/Ponts váltógombok eltávolítva

       // SL/TP Edits
       ObjectCreate(0, override_sl_label_name, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_YDISTANCE, override_y_start + 100);
       ObjectSetString(0, override_sl_label_name, OBJPROP_TEXT, "Stop Loss:");
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_FONTSIZE, 10);
       ObjectSetInteger(0, override_sl_label_name, OBJPROP_ZORDER, 1);

       ObjectCreate(0, override_sl_edit_name, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_XDISTANCE, override_x_start + 100);
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_YDISTANCE, override_y_start + 95);
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_XSIZE, 50);
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_YSIZE, 20);
       ObjectSetString(0, override_sl_edit_name, OBJPROP_TEXT, IntegerToString(InpInitialStopLossPoints));
       ObjectSetInteger(0, override_sl_edit_name, OBJPROP_ZORDER, 2);

       ObjectCreate(0, override_tp_label_name, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_YDISTANCE, override_y_start + 130);
       ObjectSetString(0, override_tp_label_name, OBJPROP_TEXT, "Take Profit:");
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_FONTSIZE, 10);
       ObjectSetInteger(0, override_tp_label_name, OBJPROP_ZORDER, 1);

       ObjectCreate(0, override_tp_edit_name, OBJ_EDIT, 0, 0, 0);
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_XDISTANCE, override_x_start + 100);
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_YDISTANCE, override_y_start + 125);
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_XSIZE, 50);
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_YSIZE, 20);
       ObjectSetString(0, override_tp_edit_name, OBJPROP_TEXT, IntegerToString(InpTakeProfitPoints));
       ObjectSetInteger(0, override_tp_edit_name, OBJPROP_ZORDER, 2);

       // R:R Label
       ObjectCreate(0, override_rr_label_name, OBJ_LABEL, 0, 0, 0);
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_XDISTANCE, override_x_start);
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_YDISTANCE, override_y_start + 160);
       ObjectSetString(0, override_rr_label_name, OBJPROP_TEXT, "R:R Ratio: N/A");
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_COLOR, clrWhite);
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_FONTSIZE, 10);
       ObjectSetInteger(0, override_rr_label_name, OBJPROP_ZORDER, 1);
   }
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
   ObjectDelete(0, broker_info_label_name);
   ObjectDelete(0, market_info_label_name);
   ObjectDelete(0, multi_tf_trend_label_name);
   ObjectDelete(0, signal_strength_label_name);

   if(InpUsePanelOverrides)
   {
       ObjectDelete(0, override_title_name);
       ObjectDelete(0, override_margin_label_name);
       ObjectDelete(0, override_margin_edit_name);
       ObjectDelete(0, override_sl_label_name);
       ObjectDelete(0, override_sl_edit_name);
       ObjectDelete(0, override_tp_label_name);
       ObjectDelete(0, override_tp_edit_name);
       ObjectDelete(0, override_rr_label_name);
   }
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
string TimeframeToString(ENUM_TIMEFRAMES period)
{
    string str = EnumToString(period);
    StringReplace(str, "PERIOD_", "");
    return str;
}
//+------------------------------------------------------------------+
string GetTrendDirection(ENUM_TIMEFRAMES timeframe)
{
    double ema_buffer[2];
    int handle_to_use = INVALID_HANDLE;

    switch(timeframe)
    {
        case PERIOD_CURRENT: handle_to_use = g_ema_current_handle; break;
        case PERIOD_M15:     handle_to_use = g_ema_m15_handle; break;
        case PERIOD_M30:     handle_to_use = g_ema_m30_handle; break;
        case PERIOD_H1:      handle_to_use = g_ema_h1_handle; break;
        case PERIOD_H4:      handle_to_use = g_ema_h4_handle; break;
        default:             handle_to_use = g_ema_current_handle; break;
    }

    if (handle_to_use == INVALID_HANDLE || CopyBuffer(handle_to_use, 0, 0, 2, ema_buffer) < 2)
    {
        return "?"; // Hiba
    }

    if (ema_buffer[0] > ema_buffer[1]) return "↑"; // Emelkedő
    if (ema_buffer[0] < ema_buffer[1]) return "↓"; // Csökkenő
    return "→"; // Oldalazó
}
//+------------------------------------------------------------------+
void UpdatePanelInfoLabels()
{
    // Bróker Infó
    symbol_info.Refresh();
    long spread = symbol_info.Spread();
    double swap_long = symbol_info.SwapLong();
    double swap_short = symbol_info.SwapShort();
    string broker_text = StringFormat("Spread: %d | Swap L: %.2f, S: %.2f", spread, swap_long, swap_short);
    ObjectSetString(0, broker_info_label_name, OBJPROP_TEXT, broker_text);

    // Piaci Infó (Volatilitás)
    double current_atr = GetCurrentATRValue();
    string market_text = StringFormat("Volatility (ATR): %.2f", NormalizeDouble(current_atr, g_digits));
    ObjectSetString(0, market_info_label_name, OBJPROP_TEXT, market_text);

    // MTF Trend
    string mtf_text = StringFormat("Trend | %s: %s M15: %s M30: %s H1: %s H4: %s",
                                   TimeframeToString(_Period), GetTrendDirection(_Period),
                                   GetTrendDirection(PERIOD_M15),
                                   GetTrendDirection(PERIOD_M30),
                                   GetTrendDirection(PERIOD_H1),
                                   GetTrendDirection(PERIOD_H4));
    ObjectSetString(0, multi_tf_trend_label_name, OBJPROP_TEXT, mtf_text);

    // Jel Erősség
    string strength_text;
    color strength_color;
    if (g_last_signal_strength > 0)
    {
        strength_text = StringFormat("Signal Strength: %d/10", g_last_signal_strength);
        if (g_last_signal_strength >= 8) strength_color = clrLimeGreen;
        else if (g_last_signal_strength >= 5) strength_color = clrOrange;
        else strength_color = clrRed;
    }
    else
    {
        strength_text = "Signal Strength: N/A";
        strength_color = clrWhite;
    }
    ObjectSetString(0, signal_strength_label_name, OBJPROP_TEXT, strength_text);
    ObjectSetInteger(0, signal_strength_label_name, OBJPROP_COLOR, strength_color);
}
//+------------------------------------------------------------------+
int CalculateSignalStrength(ENUM_ORDER_TYPE signal_type)
{
    int score = 0;
    int max_score = 0;

    // 1. Alap WPR jelzés (1 pont)
    score += 1;
    max_score += 1;

    // 2. Trend-egyezés (max 6 pont)
    max_score += 6;
    string trend_m15 = GetTrendDirection(PERIOD_M15);
    string trend_m30 = GetTrendDirection(PERIOD_M30);
    string trend_h1 = GetTrendDirection(PERIOD_H1);
    string trend_h4 = GetTrendDirection(PERIOD_H4);

    if(trend_m15 == "?") { max_score -= 1; Print("Signal Strength: M15 trend data not available."); }
    if(trend_m30 == "?") { max_score -= 1; Print("Signal Strength: M30 trend data not available."); }
    if(trend_h1 == "?")  { max_score -= 2; Print("Signal Strength: H1 trend data not available."); }
    if(trend_h4 == "?")  { max_score -= 2; Print("Signal Strength: H4 trend data not available."); }

    if (signal_type == ORDER_TYPE_BUY)
    {
        if (trend_m15 == "↑") score += 1;
        if (trend_m30 == "↑") score += 1;
        if (trend_h1 == "↑") score += 2;
        if (trend_h4 == "↑") score += 2;
    }
    else // SELL
    {
        if (trend_m15 == "↓") score += 1;
        if (trend_m30 == "↓") score += 1;
        if (trend_h1 == "↓") score += 2;
        if (trend_h4 == "↓") score += 2;
    }

    // 3. Momentum (RSI) (max 3 pont)
    max_score += 3;
    double rsi_buffer[2];
    if (g_rsi_handle != INVALID_HANDLE && CopyBuffer(g_rsi_handle, 0, 0, 2, rsi_buffer) >= 2)
    {
        if (signal_type == ORDER_TYPE_BUY && rsi_buffer[1] < 30 && rsi_buffer[0] >= 30) score += 3;
        if (signal_type == ORDER_TYPE_SELL && rsi_buffer[1] > 70 && rsi_buffer[0] <= 70) score += 3;
    }
    else
    {
        max_score -= 3;
        Print("Signal Strength: RSI data not available.");
    }

    // 4. Volatilitás (Bollinger Bands) (max 2 pont)
    max_score += 2;
    double bb_upper[1], bb_lower[1];
    if (g_bb_handle != INVALID_HANDLE && CopyBuffer(g_bb_handle, 1, 0, 1, bb_upper) >= 1 && CopyBuffer(g_bb_handle, 2, 0, 1, bb_lower) >= 1)
    {
        if (signal_type == ORDER_TYPE_BUY && symbol_info.Bid() > bb_upper[0]) score += 2;
        if (signal_type == ORDER_TYPE_SELL && symbol_info.Ask() < bb_lower[0]) score += 2;
    }
    else
    {
        max_score -= 2;
        Print("Signal Strength: Bollinger Bands data not available.");
    }

    // Arányosítás a 10-es skálára
    if (max_score <= 0) return 0;
    return (int)MathRound((double)score / max_score * 10.0);
}
//+------------------------------------------------------------------+
//| KERESKEDÉSI LOGIKA (Változatlan)                                 |
//+------------------------------------------------------------------+
void InitializeOverrides()
{
    if(!InpUsePanelOverrides) return;

    g_override_active = true;
    g_override_margin_percent = InpMaxMarginPercent;
    g_override_sl_pts = InpInitialStopLossPoints;
    g_override_tp_pts = InpTakeProfitPoints;
}
//+------------------------------------------------------------------+
void UpdateOverrideRRLabel()
{
    if(!InpUsePanelOverrides) return;

    double sl = (double)g_override_sl_pts;
    double tp = (double)g_override_tp_pts;

    string rr_text = "R:R Ratio: ";
    if (sl > 0)
    {
        if (tp > 0)
        {
            double ratio = tp / sl;
            rr_text += "1:" + DoubleToString(ratio, 2);
            Print("Calculating R:R. SL: ", sl, ", TP: ", tp, ". Ratio: 1:", DoubleToString(ratio, 2));
        }
        else
        {
            rr_text += "No TP";
        }
    }
    else
    {
        rr_text += "Invalid SL";
        Print("Calculating R:R. SL is zero or negative, cannot calculate ratio.");
    }
    ObjectSetString(0, override_rr_label_name, OBJPROP_TEXT, rr_text);
}
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
double CalculateLotSizeByMargin()
  {
   double margin_percent_to_use = (g_override_active) ? g_override_margin_percent : InpMaxMarginPercent;
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(account_equity <= 0) return 0.0;
   double max_margin_allowed = account_equity * (margin_percent_to_use / 100.0);
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

   double lot_size = CalculateLotSizeByMargin();
   if(lot_size <= 0)
     { Print("Could not calculate a valid lot size."); confirmation_signal_price = 0; return false; }

   double sl_price = 0;
   double tp_price = 0;
   double current_atr = 0;
   long min_stop_distance_points = g_stops_level + InpStopsLevelBufferPoints;
   double min_stop_distance_price = (double)min_stop_distance_points * g_point;
   if (min_stop_distance_price <= 0) min_stop_distance_price = g_point;

   // Felülírási logika
   int pts_sl = (g_override_active) ? g_override_sl_pts : InpInitialStopLossPoints;
   int pts_tp = (g_override_active) ? g_override_tp_pts : InpTakeProfitPoints;

   {
      double sl_input_scaled = pts_sl * InpInputPointScaler;
      double tp_input_scaled = (pts_tp > 0) ? pts_tp * InpInputPointScaler : 0;
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

   Print("OpenPosition (Pont mód): Price=", DoubleToString(current_price, g_digits),
         ", SL=", DoubleToString(sl_price, g_digits),
         ", TP=", (tp_price == 0 ? "0.0" : DoubleToString(tp_price, g_digits)),
         ", AdjF=", DoubleToString(g_point_adjustment_factor,1), ", Scaler=", DoubleToString(InpInputPointScaler,2),
         ", MinStopPrice=", DoubleToString(min_stop_distance_price, g_digits));

   if(trade.PositionOpen(_Symbol, type, lot_size, current_price, sl_price, tp_price, InpEaComment))
     {
      string mode_info = "(Pont, Adj: " + DoubleToString(g_point_adjustment_factor, 1) + ", Scaler: "+ DoubleToString(InpInputPointScaler, 2) + ")";
      Print("Position opened: ", EnumToString(type), " ", DoubleToString(lot_size,2), " lots. SL: ", DoubleToString(sl_price, g_digits), " TP: ", (tp_price==0?"N/A":DoubleToString(tp_price, g_digits)), " ", mode_info);
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
void CheckForNewSignal(const double previous_wpr_val, const double current_wpr_val)
  {
   if(position_info.SelectByMagic(_Symbol, InpMagicNumber)) return;

   if(current_wpr_val == EMPTY_VALUE || previous_wpr_val == EMPTY_VALUE) return;

   bool buy_cross = previous_wpr_val < InpWPRLevelDown && current_wpr_val >= InpWPRLevelDown;
   bool sell_cross = previous_wpr_val > InpWPRLevelUp && current_wpr_val <= InpWPRLevelUp;

   if(!buy_cross && !sell_cross)
     {
      g_last_signal_strength = 0;
      confirmation_signal_price = 0;
      return;
     }

   ENUM_ORDER_TYPE signal_type = (buy_cross) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   g_last_signal_strength = CalculateSignalStrength(signal_type);

   if(InpUseSignalStrengthFilter && g_last_signal_strength < InpMinSignalStrength)
     {
      PrintFormat("Signal ignored. Strength (%d) is below minimum (%d).", g_last_signal_strength, InpMinSignalStrength);
      return;
     }

   symbol_info.Refresh();
   if(symbol_info.Spread() > InpMaxSpreadPoints)
     { PrintFormat("Signal ignored due to high spread: %d > %d", symbol_info.Spread(), InpMaxSpreadPoints); confirmation_signal_price = 0; return; }


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

   if(OpenPosition(signal_type))
     {
      // Spike Protector állapot nullázása
      g_spike_breakeven_set = false;
      g_spike_trailing_activated = false;
     }
   else
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

   double open_price = position_info.PriceOpen();
   double current_sl = position_info.StopLoss();
   double current_tp = position_info.TakeProfit();
   symbol_info.RefreshRates();
   double current_close_price = (type == POSITION_TYPE_BUY) ? symbol_info.Bid() : symbol_info.Ask();
   bool trailing_stop_modified = false;

   switch(InpProfitMode)
   {
       case MODE_POINTS:
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
           break;

       case MODE_PSAR:
           if(CheckPointer(g_trailings) != POINTER_INVALID)
           {
               g_trailings.Run(position_info.Ticket());
           }
           break;
       case MODE_VIDYA:
           if(CheckPointer(g_trailings) != POINTER_INVALID)
           {
               g_trailings.Run(position_info.Ticket());
           }
           break;

       case MODE_SPIKE_PROTECTOR:
           {
               double profit_in_points = ((type == POSITION_TYPE_BUY) ? (current_close_price - open_price) : (open_price - current_close_price)) / g_point;

               // 1. FÁZIS: Spike detektálás és Breakeven+
               if (!g_spike_breakeven_set && profit_in_points >= InpSpikeProfitPoints)
               {
                   double be_price = (type == POSITION_TYPE_BUY) ? open_price + InpSpikeBreakevenPts * g_point : open_price - InpSpikeBreakevenPts * g_point;
                   if (trade.PositionModify(position_info.Ticket(), be_price, current_tp))
                   {
                       g_spike_breakeven_set = true;
                       g_spike_detected_time = TimeCurrent();
                       g_spike_peak_price = current_close_price;
                       Print("Spike detected! Position moved to Breakeven+.");
                   }
               }

               // Ha a breakeven be van állítva, de a trailing még nem aktív, figyeljük a megerősítést
               if (g_spike_breakeven_set && !g_spike_trailing_activated)
               {
                   // Mindig frissítjük a csúcsot, amíg a megerősítésre várunk
                   if(type == POSITION_TYPE_BUY && current_close_price > g_spike_peak_price) g_spike_peak_price = current_close_price;
                   if(type == POSITION_TYPE_SELL && current_close_price < g_spike_peak_price) g_spike_peak_price = current_close_price;

                   // Megerősítési feltételek ellenőrzése
                   bool time_passed = (TimeCurrent() - g_spike_detected_time) >= InpSpikeConfirmSeconds;
                   double pullback_limit = g_spike_peak_price - (g_spike_peak_price - position_info.PriceOpen()) * (InpSpikePullbackTol / 100.0);
                   bool price_stable = (type == POSITION_TYPE_BUY) ? current_close_price >= pullback_limit : current_close_price <= pullback_limit;

                   if (time_passed && price_stable)
                   {
                       g_spike_trailing_activated = true;
                       Print("Spike confirmed. Activating TEMA trailing stop.");
                   }
               }

               // 2. FÁZIS: Agresszív követés a megerősítés után
               if (g_spike_trailing_activated)
               {
                   if(CheckPointer(g_trailings) != POINTER_INVALID)
                   {
                       g_trailings.Run(position_info.Ticket());
                   }
               }
           }
           break;
   }
  }
//+------------------------------------------------------------------+
//| ESEMÉNYKEZELŐ FUNKCIÓK                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();

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

   // --- Inicializálás ---
   g_trailings = NULL; // Alapértelmezésben NULL

   switch(InpProfitMode)
   {
       case MODE_PSAR:
           // Paraméterek: symbol, timeframe, magic, sar_step, sar_maximum, trail_start, trail_step, trail_offset
           g_trailings = new CTrailingBySAR(_Symbol, _Period, InpMagicNumber, InpPsarStep, InpPsarMax, 0, 1, 0);
           break;
       case MODE_VIDYA:
           // Paraméterek: symbol, timeframe, magic, cmo_period, ema_period, shift(bar), price, trail_start, trail_step, trail_offset(points)
           g_trailings = new CTrailingByVIDYA(_Symbol, _Period, InpMagicNumber, InpVidyaCmoPeriod, InpVidyaEmaPeriod, 0, PRICE_CLOSE, 0, 1, InpVidyaShiftPts);
           break;
       case MODE_SPIKE_PROTECTOR:
           // A Spike Protector is TEMA trailinget használ a 2. fázisban
           // Paraméterek: symbol, timeframe, magic, period, shift(bar), price, trail_start, trail_step, trail_offset(points)
           g_trailings = new CTrailingByTEMA(_Symbol, _Period, InpMagicNumber, InpSpikeTrailTemaPeriod, 0, PRICE_CLOSE, 0, 1, InpSpikeTrailTemaShift);
           break;
   }

   if(CheckPointer(g_trailings) != POINTER_INVALID)
   {
       g_trailings.SetActive(true);
   }

   g_spike_breakeven_set = false;
   g_spike_trailing_activated = false;
   g_belepes_fuggoben = false;
   g_wpr_shortname = "";
   g_smooth_wpr_shortname = "";
   g_ema_filter_shortname = "";

   // --- Adaptív ATR Indikátor (ha szükséges) ---
   if(InpUseAdaptiveWPR)
     {
      adaptive_atr_handle = iATR(_Symbol, _Period, InpAdaptiveAtrPeriod);
      if(adaptive_atr_handle == INVALID_HANDLE) { Print("Error creating Adaptive ATR handle"); return(INIT_FAILED); }
     }

   // --- WPR Periódus Kezdeti Beállítása ---
   UpdateAdaptiveWPRPeriod();


   // --- Nyers WPR Indikátor Létrehozása ---
   wpr_handle = iWPR(_Symbol, _Period, g_current_wpr_period);
   if(wpr_handle == INVALID_HANDLE) { Print("Error creating WPR handle"); return(INIT_FAILED); }

   if(ChartIndicatorAdd(0, 1, wpr_handle))
     {
      g_wpr_shortname = ChartIndicatorName(0, 1, 0);
      Print("Added WPR indicator, shortname: ", g_wpr_shortname);
     }
   else { Print("Failed to add WPR indicator to chart!"); }


   // --- Simított WPR Indikátor Létrehozása (DEMA/TEMA logikával) ---
   if(InpWprSmoothingPeriod > 1)
     {
      ENUM_MA_METHOD classic_method = (ENUM_MA_METHOD)InpWprSmoothingMethod;

      switch(InpWprSmoothingMethod)
        {
         case SMOOTH_DEMA:
            {
               // A "Generalized DEMA" egyedi indikátort hívjuk meg a WPR handle-jével
               g_wpr_smooth_handle = iCustom(_Symbol, _Period, "Generalized DEMA", InpWprSmoothingPeriod, InpDemaVolumeFactor, wpr_handle);
               break;
            }
         default:
            {
               // Standard mozgóátlagok
               g_wpr_smooth_handle = iMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, classic_method, wpr_handle);
               break;
            }
        }

      if(g_wpr_smooth_handle != INVALID_HANDLE)
        {
         if(ChartIndicatorAdd(0, 1, g_wpr_smooth_handle))
           {
            g_smooth_wpr_shortname = ChartIndicatorName(0, 1, 1);
            Print("Added Smoothed WPR indicator (", EnumToString(InpWprSmoothingMethod), ",", InpWprSmoothingPeriod, "), shortname: ", g_smooth_wpr_shortname);
           }
         else { Print("Failed to add Smoothed WPR indicator to chart!"); }
        }
      else
        { Print("Hiba a simított WPR handle létrehozásakor!"); }
     }
   else
     {
      Print("WPR simítás kikcsapolva (Period <= 1). A nyers WPR jelet használjuk a belépéshez.");
      g_wpr_smooth_handle = wpr_handle;
     }

   // --- Trendszűrő EMA ---
   if(InpUseEmaFilter)
     {
      ema_handle = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE) { Print("Error creating EMA handle"); return(INIT_FAILED); }

      if(ChartIndicatorAdd(0, 0, ema_handle)) // EMA a fő ablakba (0)
        {
         g_ema_filter_shortname = ChartIndicatorName(0, 0, 0);
         Print("Added EMA Filter indicator, shortname: ", g_ema_filter_shortname);
        }
      else { Print("Failed to add EMA Filter to chart!"); }
     }

   // ATR
   atr_handle = iATR(_Symbol, _Period, 14);
   if(atr_handle == INVALID_HANDLE) { Print("Error creating ATR handle: ", GetLastError()); return(INIT_FAILED); }

   CreatePanelAndControls();
   UpdatePanelStatus();
   InitializeOverrides();
   UpdateOverrideRRLabel();

   // --- Segéd Indikátorok Inicializálása ---
   g_rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   if(g_rsi_handle == INVALID_HANDLE) { Print("Error creating RSI handle"); return(INIT_FAILED); }

   g_bb_handle = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);
   if(g_bb_handle == INVALID_HANDLE) { Print("Error creating Bollinger Bands handle"); return(INIT_FAILED); }

   g_ema_current_handle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_current_handle == INVALID_HANDLE) { Print("Error creating Current TF EMA handle"); return(INIT_FAILED); }

   g_ema_m15_handle = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_m15_handle == INVALID_HANDLE) { Print("Error creating M15 EMA handle"); return(INIT_FAILED); }

   g_ema_m30_handle = iMA(_Symbol, PERIOD_M30, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_m30_handle == INVALID_HANDLE) { Print("Error creating M30 EMA handle"); return(INIT_FAILED); }

   g_ema_h1_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_h1_handle == INVALID_HANDLE) { Print("Error creating H1 EMA handle"); return(INIT_FAILED); }

   g_ema_h4_handle = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_h4_handle == INVALID_HANDLE) { Print("Error creating H4 EMA handle"); return(INIT_FAILED); }


   Print("WPR Hybrid Analyst v3.18 Initialized.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Deinitializing EA. Reason code: ", reason);
   g_belepes_fuggoben = false;
   DeletePanelAndButtons();

   // --- Indikátorok törlése a chartról ---
   if(g_smooth_wpr_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 1, g_smooth_wpr_shortname))
        { Print("Failed to delete Smoothed WPR indicator: ", g_smooth_wpr_shortname); }
      else { Print("Deleted Smoothed WPR indicator: ", g_smooth_wpr_shortname); }
     }

   if(g_wpr_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 1, g_wpr_shortname))
        { Print("Failed to delete WPR indicator: ", g_wpr_shortname); }
      else { Print("Deleted WPR indicator: ", g_wpr_shortname); }
     }

   if(g_ema_filter_shortname != "")
     {
      if(!ChartIndicatorDelete(0, 0, g_ema_filter_shortname))
        { Print("Failed to delete EMA Filter indicator: ", g_ema_filter_shortname); }
      else { Print("Deleted EMA Filter indicator: ", g_ema_filter_shortname); }
     }

   // Handle-ök felszabadítása
   if(wpr_handle != INVALID_HANDLE) IndicatorRelease(wpr_handle);
   if(ema_handle != INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(adaptive_atr_handle != INVALID_HANDLE) IndicatorRelease(adaptive_atr_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_bb_handle != INVALID_HANDLE) IndicatorRelease(g_bb_handle);
   if(g_ema_current_handle != INVALID_HANDLE) IndicatorRelease(g_ema_current_handle);
   if(g_ema_m15_handle != INVALID_HANDLE) IndicatorRelease(g_ema_m15_handle);
   if(g_ema_m30_handle != INVALID_HANDLE) IndicatorRelease(g_ema_m30_handle);
   if(g_ema_h1_handle != INVALID_HANDLE) IndicatorRelease(g_ema_h1_handle);
   if(g_ema_h4_handle != INVALID_HANDLE) IndicatorRelease(g_ema_h4_handle);
   if(g_wpr_smooth_handle != INVALID_HANDLE && g_wpr_smooth_handle != wpr_handle)
     {
      IndicatorRelease(g_wpr_smooth_handle);
     }

   // Trailings objektum felszabadítása
   if(CheckPointer(g_trailings) != POINTER_INVALID) delete g_trailings;

   if(reason == REASON_REMOVE)
     {
      if(position_info.SelectByMagic(_Symbol, InpMagicNumber))
        {
         Print("Closing open position due to EA removal...");
         trade.PositionClose(position_info.Ticket());
        }
     }
   Print("WPR Hybrid Analyst deinitialized.");
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
         int info_y_start = new_y + 165;
         ObjectSetInteger(0, broker_info_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, broker_info_label_name, OBJPROP_YDISTANCE, info_y_start);
         ObjectSetInteger(0, market_info_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, market_info_label_name, OBJPROP_YDISTANCE, info_y_start + 20);
         ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, multi_tf_trend_label_name, OBJPROP_YDISTANCE, info_y_start + 40);
         ObjectSetInteger(0, signal_strength_label_name, OBJPROP_XDISTANCE, new_x + 10); ObjectSetInteger(0, signal_strength_label_name, OBJPROP_YDISTANCE, info_y_start + 60);
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

   //--- Felülírási logika eseménykezelése ---
   if(InpUsePanelOverrides && id == CHARTEVENT_OBJECT_ENDEDIT)
   {
       if(sparam == override_margin_edit_name)
       {
           double val = StringToDouble(ObjectGetString(0, sparam, OBJPROP_TEXT));
           if(val > 0) {
               g_override_margin_percent = val;
               Print("Override Margin % changed to: ", g_override_margin_percent);
           }
           else ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(g_override_margin_percent, 1));
       }
       else if(sparam == override_sl_edit_name)
       {
           int val = (int)StringToInteger(ObjectGetString(0, sparam, OBJPROP_TEXT));
           if(val > 0) {
               g_override_sl_pts = val;
               Print("Override SL (Points) changed to: ", g_override_sl_pts);
           }
           else ObjectSetString(0, sparam, OBJPROP_TEXT, IntegerToString(g_override_sl_pts));
       }
       else if(sparam == override_tp_edit_name)
       {
           int val = (int)StringToInteger(ObjectGetString(0, sparam, OBJPROP_TEXT));
           if(val >= 0) {
               g_override_tp_pts = val;
               Print("Override TP (Points) changed to: ", g_override_tp_pts);
           }
           else ObjectSetString(0, sparam, OBJPROP_TEXT, IntegerToString(g_override_tp_pts));
       }
       UpdateOverrideRRLabel();
       ChartRedraw();
       return;
   }
  }
//+------------------------------------------------------------------+
void OnTick()
  {

   // --- WPR Periódus Frissítése (ha adaptív mód aktív) ---
   if(InpUseAdaptiveWPR)
     {
      int old_wpr_period = g_current_wpr_period;
      UpdateAdaptiveWPRPeriod();

      if(g_current_wpr_period != old_wpr_period)
        {
         Print("WPR Period changed from ", old_wpr_period, " to ", g_current_wpr_period);

         // Régi handle-ök felszabadítása
         if(wpr_handle != INVALID_HANDLE) IndicatorRelease(wpr_handle);
         if(g_wpr_smooth_handle != INVALID_HANDLE && g_wpr_smooth_handle != wpr_handle) IndicatorRelease(g_wpr_smooth_handle);

         // Új WPR handle létrehozása az új periódussal
         wpr_handle = iWPR(_Symbol, _Period, g_current_wpr_period);
         if(wpr_handle == INVALID_HANDLE) { Print("Error re-creating WPR handle"); return; }

         // Új simított WPR handle létrehozása
         if(InpWprSmoothingPeriod > 1) {
             ENUM_MA_METHOD classic_method = (ENUM_MA_METHOD)InpWprSmoothingMethod;
             switch(InpWprSmoothingMethod) {
                 case SMOOTH_DEMA:
                     {
                         g_wpr_smooth_handle = iCustom(_Symbol, _Period, "Generalized DEMA", InpWprSmoothingPeriod, InpDemaVolumeFactor, wpr_handle);
                         break;
                     }
                 default:
                     {
                         g_wpr_smooth_handle = iMA(_Symbol, _Period, InpWprSmoothingPeriod, 0, classic_method, wpr_handle);
                         break;
                     }
             }
             if(g_wpr_smooth_handle == INVALID_HANDLE) { Print("Error re-creating Smoothed WPR handle"); }
         } else {
             g_wpr_smooth_handle = wpr_handle;
         }
        }
     }
   // --- Panel Frissítés ---
   UpdatePanelStatus();
   UpdatePanelInfoLabels();

   // --- WPR Adatok olvasása (Nyers ÉS Simított) ---
   double wpr_buffer_raw[2];
   double wpr_buffer_smoothed[2];

   if(CopyBuffer(wpr_handle, 0, 0, 2, wpr_buffer_raw) < 2)
     {
      return;
     }
   double raw_current_wpr    = wpr_buffer_raw[0];
   double raw_previous_wpr = wpr_buffer_raw[1];

   if(CopyBuffer(g_wpr_smooth_handle, 0, 0, 2, wpr_buffer_smoothed) < 2)
     {
      return;
     }
   double smoothed_current_wpr  = wpr_buffer_smoothed[0];
   double smoothed_previous_wpr = wpr_buffer_smoothed[1];

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
      ManageOpenPosition(raw_previous_wpr, raw_current_wpr);
     }
   else if(InpTradeMode == MODE_AUTOMATIC)
     {
      CheckForNewSignal(smoothed_previous_wpr, smoothed_current_wpr);
     }
  }
//+------------------------------------------------------------------+
