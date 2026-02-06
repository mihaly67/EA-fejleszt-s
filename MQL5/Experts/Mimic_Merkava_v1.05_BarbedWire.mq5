//+------------------------------------------------------------------+
//|                               Mimic_Merkava_v1.05_BarbedWire.mq5 |
//|                                                      Jules Agent |
//|                       Focused Strategy: Barbed Wire (Szögesdrót) |
//|                       Mode: MANUAL BURST FIRE (Grid Trap)        |
//|                       Modular Architecture (Merkava Tank)        |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "1.05"
#property strict

// --- Modular Includes ---
#include "../Indicators/Camouflage.mqh"
#include "../Indicators/BlackBox.mqh"
#include "../Indicators/NavSystem.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/FireControl.mqh"
#include "../Indicators/Stealth/StealthEngine.mqh"

//--- Inputs
// [Strategy Settings]
input double        InpSpreadMultStart   = 1.5;       // [Grid] Start Spread Multiplier
input double        InpSpreadMultStep    = 1.0;       // [Grid] Step Spread Multiplier per Layer
input int           InpLayers            = 3;         // [Grid] Number of Layers (Burst Size)
input double        InpSafeZonePts       = 50.0;      // [Safety] Minimum Distance (Points)
input string        InpIndPath           = "Jules\\"; // [Strategy] Indicator Path

// [Position Size]
input double        InpLotSize           = 0.01;      // [Position] Lot Size (Editable on Panel)

// [Risk Management]
input int           InpSlippage          = 10;     // [Risk] Slippage
input ulong         InpMagicNumber       = 999004; // [Risk] Magic Number
input string        InpComment           = "MerkavaWire"; // [Risk] Comment

// [Stealth Systems (Advanced Chaos)]
input group         "Stealth Systems";
input bool          InpUseStealth        = true;   // [Stealth] Enable Chaos Engine
input double        InpChaosLevel        = 1.0;    // [Stealth] Jitter Intensity (0.1 - 2.0)
input int           InpLatencyMin        = 50;     // [Stealth] Latency Min (ms)
input int           InpLatencyMax        = 300;    // [Stealth] Latency Max (ms)
input int           InpMagicVariance     = 500;    // [Stealth] Magic Number Rotation Range

// [Jules Hybrid Momentum Pulse v1.04 Settings]
input uint           Hybrid_InpPeriodFastEMA     =  3;
input uint           Hybrid_InpPeriodSlowEMA     =  6;
input uint           Hybrid_InpPeriodBB          =  20;
input double         Hybrid_InpDeviationBB       =  2.0;
input ENUM_MA_METHOD Hybrid_InpMethodBB          =  MODE_EMA;
input uint           Hybrid_InpPeriodKeltner     =  20;
input double         Hybrid_InpDeviationKeltner  =  1.5;
input uint           Hybrid_InpPeriodATRKeltner  =  10;
input ENUM_MA_METHOD Hybrid_InpMethodKeltner     =  MODE_EMA;
input double         Hybrid_InpMACDScale         =  4.0;
input int            Hybrid_InpDFShift           = 0;
input double         Hybrid_InpDFScale           = 1.0;
input bool           Hybrid_InpUseAutoScaling    = true;
input int            Hybrid_InpAutoScaleLookback = 100;

// [Flow Settings]
input bool               Flow_InpUseFixedScale       = false;
input double             Flow_InpScaleMin            = -100.0;
input double             Flow_InpScaleMax            = 200.0;
input int                Flow_InpMFIPeriod           = 5;
input bool               Flow_InpShowVROC            = true;
input int                Flow_InpVROCPeriod          = 5;
input double             Flow_InpVROCThreshold       = 20.0;
input bool               Flow_InpUseApproxDelta      = true;
input int                Flow_InpDeltaSmooth         = 3;
input int                Flow_InpNormalizationLen    = 100;
input double             Flow_InpDeltaScaleFactor    = 50.0;
input double             Flow_InpHistogramVisualGain = 3.0;

// [Panel UI]
input int           InpX                 = 10;               // [UI] X Coordinate
input int           InpY                 = 20;               // [UI] Y Coordinate
input color         InpBgColor           = clrDarkSlateGray; // [UI] BG Color
input color         InpTxtColor          = clrWhite;         // [UI] Text Color

//--- Globals (State)
bool              g_active = false;
bool              g_book_subscribed = false;
string            g_last_action = "IDLE";
double            g_last_realized_pl = 0.0;
double            g_session_realized_pl = 0.0;
string            g_tick_event_buffer = "";
string            g_decision_log = "";
string            g_transaction_buffer = "";
ulong             g_last_deal_ticket = 0;
long              g_last_deal_time_msc = 0;
double            g_user_lot_size = InpLotSize;
ulong             g_actual_magic = 0; // Rotated Magic

//--- Modules
CMimicCamouflage  *Camouflage;
StealthEngine     *Stealth;
CMimicBlackBox    *BlackBox;
CMimicNavSystem   *NavSystem;
PhysicsEngine     *Physics;
CFireControl      *FireControl;
CTrade            *Trade; // FireControl needs a pointer, but FireControl creates its own? No, it takes pointers.
CSymbolInfo       SymbolInfo; // Needed for FireControl

//--- GUI Objects
string Prefix = "MerkavaWire_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnFire = Prefix + "BtnFire";
string ObjBtnClear = Prefix + "BtnClear";
string ObjEditLot = Prefix + "EditLot";
string ObjLabelLot = Prefix + "LabelLot";
string ObjLabelPL = Prefix + "LabelPL";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void RemoveIndicators(); // Local cleanup of chart objects if any
double GetFloatingPL();
void CheckForNewDeals();
string GetNetLotDirection(double &total_lots);
string GetSLTPSnapshot();
string DetermineVerdict(double velocity, double pl);

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Cleanup Old Objects
   CleanupChart();
   // Note: We do NOT remove all indicators blindly to respect user setup,
   // but Barbed Wire code did: "RemoveIndicators()".
   // We will rely on NavSystem to manage its handles, but we might want to clean old instances.
   // Given the "Exact Copy" instruction, I should probably clean.
   // But modular systems usually behave nicer.
   // I will skip aggressive indicator deletion to be safe, relying on `ChartIndicatorAdd`.

   // 2. Initialize Modules
   Camouflage  = new CMimicCamouflage();
   Stealth     = new StealthEngine();
   BlackBox    = new CMimicBlackBox();
   NavSystem   = new CMimicNavSystem();
   Physics     = new PhysicsEngine(50);
   FireControl = new CFireControl();
   Trade       = new CTrade();

   // 2.1 Stealth Init (Identity Obfuscation)
   if(InpUseStealth)
   {
       Stealth->Initialize(InpChaosLevel, InpLatencyMin, InpLatencyMax);

       // Check Global Variable for existing identity
       string gvar_name = "Merkava_Identity_" + _Symbol;
       if(GlobalVariableCheck(gvar_name)) {
           g_actual_magic = (ulong)GlobalVariableGet(gvar_name);
           PrintFormat("🕵️ STEALTH ENGINE: Resuming Identity. Magic %I64d", g_actual_magic);
       } else {
           g_actual_magic = Stealth->GetRotatedMagic(InpMagicNumber, InpMagicVariance);
           GlobalVariableSet(gvar_name, (double)g_actual_magic);
           PrintFormat("🕵️ STEALTH ENGINE: New Identity Created. Magic %I64d -> %I64d", InpMagicNumber, g_actual_magic);
       }
   }
   else
   {
       g_actual_magic = InpMagicNumber;
       Print("🕵️ STEALTH ENGINE: DISABLED.");
   }

   // 3. Setup Trade & Symbol
   Trade->SetExpertMagicNumber(g_actual_magic);
   Trade->SetMarginMode();
   Trade->SetDeviationInPoints(InpSlippage);

   if(!SymbolInfo.Name(_Symbol)) return INIT_FAILED;
   SymbolInfo.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;
   g_user_lot_size = InpLotSize;

   // 4. Initialize FireControl
   FireControl->Init(Trade, &SymbolInfo, InpComment, g_actual_magic);
   if(InpUseStealth) FireControl->SetStealth(Stealth);

   // 5. Initialize NavSystem (Barbed Wire Mode)
   string path_hybrid = InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.04";
   string path_flow = InpIndPath + "HybridFlowIndicator_v1.125";

   if(!NavSystem->InitializeBarbedWire(
       _Symbol, _Period,
       path_hybrid,
       Hybrid_InpPeriodFastEMA, Hybrid_InpPeriodSlowEMA, Hybrid_InpPeriodBB, Hybrid_InpDeviationBB, Hybrid_InpMethodBB,
       Hybrid_InpPeriodKeltner, Hybrid_InpDeviationKeltner, Hybrid_InpPeriodATRKeltner, Hybrid_InpMethodKeltner,
       Hybrid_InpMACDScale, Hybrid_InpDFShift, Hybrid_InpDFScale, Hybrid_InpUseAutoScaling, Hybrid_InpAutoScaleLookback,
       path_flow,
       Flow_InpUseFixedScale, Flow_InpScaleMin, Flow_InpScaleMax, Flow_InpMFIPeriod, Flow_InpShowVROC, Flow_InpVROCPeriod,
       Flow_InpVROCThreshold, Flow_InpUseApproxDelta, Flow_InpDeltaSmooth, Flow_InpNormalizationLen, Flow_InpDeltaScaleFactor, Flow_InpHistogramVisualGain
   )) return INIT_FAILED;

   NavSystem->AttachIndicatorsToChart(0, 1, 2);

   // 6. Initialize BlackBox
   if(!BlackBox->Initialize(_Symbol, "v1.05_BW_DirectCalc")) return INIT_FAILED;

   // 7. Initialize Forensic Polling
   if (HistorySelect(0, TimeCurrent())) {
       int total = HistoryDealsTotal();
       if (total > 0) {
           ulong ticket = HistoryDealGetTicket(total - 1);
           g_last_deal_ticket = ticket;
           g_last_deal_time_msc = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);
       }
   }

   // 8. Create Panel
   CreatePanel();
   UpdateUI();

   Print("Merkava Wire v1.05 (Modular) Initialized.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DestroyPanel();
   // User Request: "teljesen tiszta csartot kérek" (Clean chart completely)
   CleanupChart(); // This now does ObjectsDeleteAll(0, -1, -1) and removes indicators

   if(g_book_subscribed) MarketBookRelease(_Symbol);

   if(BlackBox) delete BlackBox;
   if(NavSystem) delete NavSystem;
   if(Camouflage) delete Camouflage;
   if(Stealth) delete Stealth;
   if(Physics) delete Physics;
   if(FireControl) delete FireControl;
   if(Trade) delete Trade;
}

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == ObjBtnFire)
      {
         // FIRE BURST
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();

         SymbolInfo.RefreshRates();
         double center = (SymbolInfo.Ask() + SymbolInfo.Bid()) / 2.0;

         // Use Module
         FireControl->FireBurst(center, g_user_lot_size, InpLayers, InpSpreadMultStart, InpSpreadMultStep, InpSafeZonePts);

         g_last_action = "BURST_FIRED";
         g_decision_log += "Burst Fired L" + IntegerToString(InpLayers) + ";";

         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if (sparam == ObjBtnClear)
      {
         // CEASE FIRE
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);

         // Use Module
         FireControl->CeaseFire();

         g_last_action = "CEASE_FIRE";
         g_decision_log += "Cease Fire;";
         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      UpdateUI();
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == ObjEditLot) {
           string text = ObjectGetString(0, ObjEditLot, OBJPROP_TEXT);
           double val = StringToDouble(text);
           if(val > 0) g_user_lot_size = val;
           Print("Merkava: Lot Size Updated to: ", g_user_lot_size);
      }
   }
}

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   Physics->Update(tick);
   PhysicsState p = Physics->GetState();

   SymbolInfo.RefreshRates();
   NavSystem->Refresh(_Symbol);

   CheckForNewDeals(); // Polling for ActionDetails string

   // -- GATHER DATA FOR BLACKBOX --
   double mfi, dup, ddown;
   NavSystem->GetBarbedWireFlow(mfi, dup, ddown);

   // Reconstruct Net Delta from Split Logic (Center 50)
   double net_delta = dup + ddown - 50.0;
   double flow_roc = NavSystem->GetFlowROC();

   double rsi = NavSystem->GetRSI();
   // CCI removed as per user request
   double hybrid_macd = NavSystem->GetHybridMACD();
   double hybrid_dfcurve = NavSystem->GetPulse();

   double float_pl = GetFloatingPL();

   // Advanced Market Data (Book)
   long bid_vol = 0;
   long ask_vol = 0;
   if (g_book_subscribed) {
       MqlBookInfo book[];
       if (MarketBookGet(_Symbol, book)) {
           int size = ArraySize(book);
           for(int i=0; i<size; i++) {
               if((book[i].type == BOOK_TYPE_SELL) && (book[i].price == SymbolInfo.Ask())) ask_vol += book[i].volume;
               if((book[i].type == BOOK_TYPE_BUY) && (book[i].price == SymbolInfo.Bid())) bid_vol += book[i].volume;
           }
       }
   } else {
       bid_vol = (long)tick.volume; // Fallback
   }

   string verdict = DetermineVerdict(p.velocity, float_pl);
   string sltp = GetSLTPSnapshot();
   double total_lots = 0.0;
   string lot_dir = GetNetLotDirection(total_lots);

   // Handle ActionDetails string construction
   if (g_transaction_buffer == "") g_transaction_buffer = "NONE";
   if (g_decision_log != "") g_transaction_buffer += "|" + g_decision_log;

   // -- LOG --
   // Use 'tick' directly for Bid/Ask to avoid any SymbolInfo cache lag
   BlackBox->RecordTick(
      g_last_action, 0, verdict,
      tick.bid, tick.ask, p.spread_avg,
      bid_vol, ask_vol,
      iOpen(_Symbol, _Period, 0), iHigh(_Symbol, _Period, 0), iLow(_Symbol, _Period, 0), iClose(_Symbol, _Period, 0),
      rsi, p.velocity, p.acceleration,
      hybrid_macd, hybrid_dfcurve,
      mfi, flow_roc, net_delta, // Fixed Mapping: MFI, ROC, NetDelta
      AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
      float_pl, g_last_realized_pl, g_session_realized_pl,
      PositionsTotal(), lot_dir, total_lots,
      sltp, g_transaction_buffer, g_tick_event_buffer
   );

   // Reset Event Buffers
   // g_last_realized_pl = 0.0; // Wait, BlackBox accumulates? No, BlackBox takes "realized_pl" argument.
   // BarbedWire logic: g_last_realized_pl accumlates session profit?
   // BarbedWire v1.03 code:
   // "g_last_realized_pl += profit;" inside CheckForNewDeals loop.
   // "g_session_realized_pl += profit;" inside CheckForNewDeals loop.
   // "g_last_realized_pl = 0.0;" at end of OnTick.
   // So g_last_realized_pl is TICK SPECIFIC. g_session_realized_pl is TOTAL.

   g_last_realized_pl = 0.0;
   g_tick_event_buffer = "";
   g_decision_log = "";
   g_transaction_buffer = "";
   if (g_last_action != "IDLE") g_last_action = "IDLE";
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void CheckForNewDeals()
{
    datetime start = TimeCurrent() - 600;
    datetime end = TimeCurrent() + 10;

    if(!HistorySelect(start, end)) return;

    int total = HistoryDealsTotal();
    for(int i=0; i<total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        long deal_time = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);

        if (deal_time > g_last_deal_time_msc || (deal_time == g_last_deal_time_msc && ticket > g_last_deal_ticket))
        {
            g_last_deal_time_msc = deal_time;
            g_last_deal_ticket = ticket;

            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
            double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            string action_str = "";
            string type_str = (type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string ticket_info = "T#" + IntegerToString(ticket);

            if (entry == DEAL_ENTRY_IN) {
                action_str = ticket_info + ":OPEN:" + type_str + ":" + DoubleToString(vol, 2) + "@" + DoubleToString(price, _Digits);
            }
            else if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
                action_str = ticket_info + ":CLOSE:" + type_str + ":" + DoubleToString(vol, 2) + "@" + DoubleToString(price, _Digits) + ":PL=" + DoubleToString(profit, 2);
                g_last_realized_pl += profit;
                g_session_realized_pl += profit;
            }

            if (action_str != "") {
                if (g_transaction_buffer != "") g_transaction_buffer += "|";
                g_transaction_buffer += action_str;
            }
        }
    }
}

double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(PositionSelectByTicket(PositionGetTicket(i)))
       {
           if(PositionGetInteger(POSITION_MAGIC)==g_actual_magic)
               pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); // Commission removed (deprecated)
       }
    }
    return pl;
}

string GetNetLotDirection(double &total_lots)
{
    double net_lots = 0.0;
    total_lots = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(PositionSelectByTicket(PositionGetTicket(i))) {
           if(PositionGetInteger(POSITION_MAGIC)==g_actual_magic) {
               double vol = PositionGetDouble(POSITION_VOLUME);
               total_lots += vol;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) net_lots += vol;
               else net_lots -= vol;
           }
       }
    }
    if(net_lots > 0.001) return "BUY";
    if(net_lots < -0.001) return "SELL";
    if(PositionsTotal() > 0) return "NEUTRAL_HEDGE";
    return "NONE";
}

string GetSLTPSnapshot()
{
    string s = "";
    int count = 0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(PositionSelectByTicket(PositionGetTicket(i))) {
           if(PositionGetInteger(POSITION_MAGIC)==g_actual_magic) {
               if(count > 0) s += "|";
               string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "B" : "S";
               s += type + ":" + DoubleToString(PositionGetDouble(POSITION_SL), _Digits) + "/" + DoubleToString(PositionGetDouble(POSITION_TP), _Digits);
               count++;
               if(count >= 3) { s += "|..."; break; }
           }
       }
    }
    if(s == "") return "NONE";
    return s;
}

string DetermineVerdict(double velocity, double pl)
{
    if(pl < -50.0 && velocity > 20.0) return "CRASH_RISK";
    if(pl > 10.0) return "WINNING";
    if(pl < -10.0) return "UNDER_PRESSURE";
    return "STABLE";
}

void CleanupChart()
  {
   // Aggressive cleanup as requested
   ObjectsDeleteAll(0, -1, -1); // Delete ALL objects

   // Remove Indicators aggressively to avoid stacking
   int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for (int w = windows - 1; w >= 0; w--) {
       int total = ChartIndicatorsTotal(0, w);
       for (int i = total - 1; i >= 0; i--) {
           string name = ChartIndicatorName(0, w, i);
           // Delete if it looks like our indicators (Jules, Hybrid, Flow)
           // Or just delete everything if it's a subwindow > 0?
           // User said "ahányszor állitok annyi görbe van egymáson" -> Delete duplicates.
           // Ideally, we delete *specific* indicators we added.
           string nlow = name; StringToLower(nlow);
           if (StringFind(nlow, "hybrid") >= 0 || StringFind(nlow, "pulse") >= 0 || StringFind(nlow, "flow") >= 0)
               ChartIndicatorDelete(0, w, name);
       }
   }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpX, y = InpY, w = 140, h = 200;

   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   int cy = y + 10;

   // Status
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "MERKAVA v1.05");
   cy += 25;

   // Lot Input
   ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "Lot:");

   ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+40);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 50);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(g_user_lot_size, 2));
   ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);
   cy += 30;

   // FIRE Button
   ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, 40);
   ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE BURST");
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);
   cy += 50;

   // CLEAR Button
   ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);
   cy += 40;

   ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "PL: " + DoubleToString(GetFloatingPL(), 2));
   ChartRedraw();
  }

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnFire); ObjectDelete(0, ObjBtnClear);
   ObjectDelete(0, ObjEditLot); ObjectDelete(0, ObjLabelLot);
   ObjectDelete(0, ObjLabelPL);
  }
