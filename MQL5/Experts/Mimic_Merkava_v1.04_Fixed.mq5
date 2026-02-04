//+------------------------------------------------------------------+
//|                                     Mimic_Merkava_v1.04_Fixed.mq5|
//|                        Project Merkava (The Tank) - Phase 2      |
//|                                    Copyright 2026, Jules (Mimic) |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "1.04"
#property strict

// --- Modular Includes (Flat Structure in Indicators) ---
#include "../Indicators/Camouflage.mqh"
#include "../Indicators/BlackBox.mqh"
#include "../Indicators/NavSystem.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/FireControl.mqh"

// --- Inputs ---
input string   Inp_System_Name   = "Merkava v1.04 Fixed";  // System Name
input long     Inp_Magic_Seed    = 8888;                  // Magic Seed
input double   Inp_LotSize       = 0.01;                  // Base Lot Size

// --- Globals ---
CMimicCamouflage  *Camouflage;
CMimicBlackBox    *BlackBox;
CMimicNavSystem   *NavSystem;
PhysicsEngine     *Physics;  // CORRECTED CLASS NAME
CFireControl      *FireControl;

long     current_magic;
double   last_tick_price;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Initialize Modules
   Camouflage  = new CMimicCamouflage();
   BlackBox    = new CMimicBlackBox();
   NavSystem   = new CMimicNavSystem();
   Physics     = new PhysicsEngine(50); // CORRECTED CONSTRUCTOR
   FireControl = new CFireControl();

   // 2. Setup Stealth
   current_magic = Camouflage.GenerateMagic(Inp_Magic_Seed);
   Print("⚔️ Merkava Activated. Stealth Magic: ", current_magic);

   // 3. Initialize Sensors & Logs
   if(!NavSystem.Initialize(_Symbol, _Period)) return INIT_FAILED;
   if(!BlackBox.Initialize(_Symbol, "v1.04_FIXED")) return INIT_FAILED;

   // Physics.Init(_Symbol); // REMOVED: Method does not exist

   last_tick_price = 0.0;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(BlackBox) delete BlackBox;
   if(NavSystem) delete NavSystem;
   if(Camouflage) delete Camouflage;
   if(Physics) delete Physics;
   if(FireControl) delete FireControl;

   Print("🛡️ Merkava Deactivated.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Data Refresh
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return; // Safety check

   double bid = tick.bid;
   double ask = tick.ask;
   double spread = (ask - bid) * MathPow(10, _Digits);
   long bid_vol = tick.volume; // Standard tick volume

   Physics.Update(tick); // CORRECTED SIGNATURE
   PhysicsState p_state = Physics.GetState(); // Get state for logging

   NavSystem.Refresh(_Symbol);

   // 2. Flow Physics Update (Fix for Blindness)
   if(last_tick_price > 0)
      NavSystem.UpdateFlowPhysics(bid, last_tick_price, bid_vol);
   last_tick_price = bid;

   // 3. Financials (Fix for PL Bug)
   double float_pl = 0, real_pl = 0, sess_pl = 0;
   BlackBox.CalculateFinancials(current_magic, float_pl, real_pl, sess_pl);

   // 4. Mimic Logic (Placeholder for FireControl / Chaos)
   // For now, we just Log.

   // 5. Forensic Logging
   BlackBox.RecordTick(
      "ACTIVE", 1, "MONITOR",
      bid, ask, spread, bid_vol, 0,
      iOpen(_Symbol, _Period, 0), iHigh(_Symbol, _Period, 0), iLow(_Symbol, _Period, 0), iClose(_Symbol, _Period, 0),
      NavSystem.GetRSI(), NavSystem.GetCCI(), p_state.velocity, p_state.acceleration, // CORRECTED ACCESS
      0.0, NavSystem.GetPulse(), // Hybrid MACD/Pulse
      NavSystem.GetFlowMFI(), NavSystem.GetFlowROC(), NavSystem.GetFlowDelta(), // FIXED FLOW
      AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
      float_pl, real_pl, sess_pl, // FIXED PL
      PositionsTotal(), "NONE", 0.0, "NONE", "Scanning", "TICK"
   );
}
//+------------------------------------------------------------------+
