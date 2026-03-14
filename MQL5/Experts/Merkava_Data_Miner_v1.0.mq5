//+------------------------------------------------------------------+
//|                                     Merkava_Data_Miner_v1.0.mq5 |
//|                                                      Jules Agent |
//|                                       Part of Operation Néma Sz. |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "1.00"
#property strict

#include <Trade\SymbolInfo.mqh>
#include "../Indicators/NavSystem_v2_22.mqh"
#include "../Indicators/BlackBox_v2_10.mqh"

//--- Inputs
input string        InpIndPath           = "Jules\\";              // Indicators Path
input string        InpContextPath       = "Jules\\HybridContextIndicator_v3.28";

//--- Subsystems
CSymbolInfo         m_symbol;
CNavSystem          m_nav_system;
CBlackBox           m_black_box;

//--- Global State
ulong g_tick_count = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 Merkava Data Miner v1.1 Initializing for Strategy Tester...");

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   // Prepare Context Params (v3.28 defaults, visual off since it's a miner)
   ContextParams ctx;
   ctx.path = InpContextPath;
   ctx.show_pivots = false; ctx.show_trends = false; ctx.max_hist = 5000;
   ctx.show_fibo = false; ctx.fibo_hist = 0;

   // Micro, Sec, Ter, Trends set to minimal usage for calculation only
   ctx.m_use = true; ctx.s_use = true; ctx.t_use = true; ctx.tr_method = 1;

   HybridMomentumParams mom;
   ZeroMemory(mom);
   mom.path = InpIndPath + "Hybrid_Momentum_WPR_Stoch_v1_04";
   mom.wpr_period = 5;
   mom.stoch_k = 3;
   mom.stoch_slow = 2;
   mom.stoch_d = 2;

   bool init_ok = m_nav_system.Initialize(
       _Symbol, _Period,
       InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05",
       14, 28, 20, 2.0, MODE_EMA,
       20, 1.5, 10, MODE_EMA,
       5.0, 0, 3.0, true, 100, 10.0,
       InpIndPath + "HybridFlowIndicator_v1.126",
       false, -100, 200, 14, true, 10, true,
       3, 20, 100.0, 3.0,
       ctx, mom
   );

   if(!init_ok) {
       Print("❌ Miner Initialization Failed at NavSystem");
       return INIT_FAILED;
   }

   m_black_box.Initialize(_Symbol, "MINER_TESTER_v1.1");

   Print("✅ Miner Ready. Please run this EA in the STRATEGY TESTER to extract accurate historical indicators.");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   m_nav_system.Release();
   m_black_box.CloseLog();
   Print("🛑 Miner Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function (Runs automatically in Strategy Tester)     |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   // The Strategy Tester seamlessly handles time progression
   m_nav_system.Refresh(_Symbol, tick);

   double bid = tick.bid;
   double ask = tick.ask;
   double spread = (ask - bid) / _Point;
   long bid_vol = (long)tick.volume; // Native tick volume
   long ask_vol = (long)tick.volume;

   // OHLC extraction from the currently simulated minute candle
   MqlRates rates[];
   double b_o=0, b_h=0, b_l=0, b_c=0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) > 0) {
       b_o = rates[0].open; b_h = rates[0].high; b_l = rates[0].low; b_c = rates[0].close;
   }

   double pulse = m_nav_system.GetPulse();
   double macd = m_nav_system.GetHybridMACD();
   double mfi = m_nav_system.GetFlowMFI();
   double delta = m_nav_system.GetFlowDelta();
   double roc = m_nav_system.GetFlowROC();

   double mp = m_nav_system.GetMicP(); double mr = m_nav_system.GetMicR(); double ms = m_nav_system.GetMicS();
   double sp = m_nav_system.GetSecP(); double sr = m_nav_system.GetSecR(); double ss = m_nav_system.GetSecS();
   double tp = m_nav_system.GetTerP(); double tr = m_nav_system.GetTerR(); double ts = m_nav_system.GetTerS();

   double ema25 = m_nav_system.GetTrendFast();
   double ema50 = m_nav_system.GetTrendMedium();
   double ema150 = m_nav_system.GetTrendSlow();
   double ema300 = m_nav_system.GetTrendSuper();

   double wpr = m_nav_system.GetWPR();
   double stoch = m_nav_system.GetStochK();
   double rsi = m_nav_system.GetRSI();

   // Write the synchronized data to CSV
   m_black_box.RecordTick(
       tick.time_msc, "MINER", 0, "NONE",
       bid, ask, spread, bid_vol, ask_vol,
       b_o, b_h, b_l, b_c,
       rsi, 0, 0, // Velocity/Acc disabled to avoid PhysicsEngine dependency in miner
       macd, pulse,
       mfi, roc, delta,
       mp, mr, ms,
       sp, sr, ss,
       tp, tr, ts,
       ema25, ema50, ema150, ema300,
       wpr, stoch,
       0, // Ping
       0, 0, 0, // Acc Stats
       0, 0, 0, // PL Stats
       0, "NONE", 0, // Position info
       "NONE", "MINER", "EXTRACTED"
   );

   g_tick_count++;

   // Progress indicator (Strategy Tester UI often hides Print, but it helps in logs)
   if(g_tick_count % 100000 == 0) {
       PrintFormat("⏳ Data Miner Progress: %llu ticks logged so far...", g_tick_count);
   }
}
//+------------------------------------------------------------------+
