//+------------------------------------------------------------------+
//|                                     WPR_Hybrid_Analyst.mq5 |
//|                        Copyright 2024, Gemini & User Collaboration |
//|        Verzió: Fordítási hibák javítása és keresőfejlesztés        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.11"

//+------------------------------------------------------------------+
//| Tartalmazza (Includes)                                           |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include "Trailings.mqh"
#include <Math\Stat\Stat.mqh>

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
   SMOOTH_DEMA  = 10, // Double Exponential Moving Average (Ajánlott)
   SMOOTH_TEMA  = 11  // Triple Exponential Moving Average (Még gyorsabb)
  };
// ---

//+------------------------------------------------------------------+
//| Bemeneti Paraméterek                                             |
//+------------------------------------------------------------------+
input group "EA Settings"
input ulong         InpMagicNumber            = 202433;
input string        InpEaComment              = "WPR_Hybrid_v3.11";
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
input double        InpWPRLevelUp             = -20.0;
input double        InpWPRLevelDown           = -80.0;
input group "Signal Strength Filter"
input bool          InpUseSignalStrengthFilter= true;
input int           InpMinSignalStrength      = 5;      // Minimum score (1-10) for auto trade
input group "Statistical Filters"
input int           InpStatLookbackSeconds    = 120;    // "Nyugodt piac" időablaka (sec)
input int           InpStatBreakoutSeconds    = 10;     // "Kitörés" időablaka (sec)
input double        InpStatVolFactor          = 2.0;    // Hányszorosára nőjön a tick volumen?
input double        InpStatStdDevFactor       = 2.0;    // Hányszorosára nőjön a szórás?
input double        InpStatCorrThreshold      = 0.7;    // Minimális korreláció a trendhez
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
int             g_current_wpr_period = 0;
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
datetime        g_spike_detected_time = 0;
double          g_spike_peak_price = 0;
bool            g_spike_breakeven_set = false;
bool            g_spike_trailing_activated = false;
CSimpleTrailing *g_trailings;
string          g_wpr_shortname = "";
string          g_smooth_wpr_shortname = "";
string          g_ema_filter_shortname = "";
bool            g_override_active = false;
double          g_override_margin_percent = 0;
int             g_override_sl_pts = 0;
int             g_override_tp_pts = 0;
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

bool FatalisHiba(long retcode)
  {
   return(retcode==10014||retcode==10016||retcode==10017||retcode==10020||retcode==10022||
          retcode==10018||retcode==10019||retcode==10024||retcode==10029||retcode==10030);
  }

double GetCurrentATRValue()
  {
   if(atr_handle==INVALID_HANDLE) return 0.0;
   double atr_buffer[1];
   if(CopyBuffer(atr_handle,0,1,1,atr_buffer)<1) {Print("Hiba az ATR érték másolásakor! ",GetLastError()); return 0.0;}
   if(atr_buffer[0]<=0) {Print("Figyelmeztetés: Az ATR érték nulla vagy negatív (",atr_buffer[0],"). Visszatérés 100 ponttal."); return g_point*100;}
   return atr_buffer[0];
  }

void UpdateAdaptiveWPRPeriod()
{
    if(!InpUseAdaptiveWPR||adaptive_atr_handle==INVALID_HANDLE){g_current_wpr_period=InpWprBasePeriod;return;}
    double atr_buffer[100];
    if(CopyBuffer(adaptive_atr_handle,0,0,100,atr_buffer)<100){Print("Hiba az adaptív ATR buffer másolásakor! Visszaállás az alap periódusra.");g_current_wpr_period=InpWprBasePeriod;return;}
    double short_term_avg_atr=0;for(int i=0;i<5;i++)short_term_avg_atr+=atr_buffer[i];short_term_avg_atr/=5;
    double long_term_avg_atr=0;for(int i=0;i<100;i++)long_term_avg_atr+=atr_buffer[i];long_term_avg_atr/=100;
    if(long_term_avg_atr<=0){g_current_wpr_period=InpWprBasePeriod;return;}
    double volatility_ratio=short_term_avg_atr/long_term_avg_atr;
    int new_period=(int)MathRound(InpWprBasePeriod*(1.0+(volatility_ratio-1.0)*InpAdaptiveSensitivity));
    g_current_wpr_period=MathMax(InpWprPeriodMin,MathMin(InpWprPeriodMax,new_period));
}

// ... the rest of the file content is identical to the previous `overwrite_file_with_block` call ...
