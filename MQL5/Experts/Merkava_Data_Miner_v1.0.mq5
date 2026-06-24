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
input datetime      InpStartDate         = D'2026.01.01 00:00:00'; // Start Date for Mining
input datetime      InpEndDate           = D'2026.03.12 23:59:59'; // End Date for Mining
input string        InpIndPath           = "Jules\\";              // Indicators Path
input string        InpContextPath       = "Jules\\HybridContextIndicator_v3.28";

//--- Subsystems
CSymbolInfo         m_symbol;
CNavSystem          m_nav_system;
CBlackBox           m_black_box;

//--- Global State
bool g_mining_done = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 Merkava Data Miner v1.0 Initializing...");

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

   m_black_box.Initialize(_Symbol, "MINER_v1.0");

   Print("✅ Miner Ready. Starting Data Extraction in OnTick...");

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
//| Expert tick function (Active Market Extraction)                  |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_mining_done) return;

   Print("⛏️ Commencing Tick Data Mining from ", TimeToString(InpStartDate), " to ", TimeToString(InpEndDate));

   MqlTick ticks[];
   int count = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, (ulong)InpStartDate * 1000, (ulong)InpEndDate * 1000);

   if(count <= 0) {
       PrintFormat("❌ Failed to download ticks (Count: %d). Error: %d. Check Date Range or Symbol History!", count, GetLastError());
       g_mining_done = true;
       ExpertRemove();
       return;
   }

   PrintFormat("📥 Downloaded %d ticks. Processing...", count);

   int last_processed_pct = -1;

   for(int i = 0; i < count; i++) {
       datetime tick_time = (datetime)(ticks[i].time_msc / 1000);

       // Optimization: Print progress every 10%
       int pct = (int)(((double)i / count) * 100);
       if(pct != last_processed_pct && pct % 10 == 0) {
           PrintFormat("⏳ Processing: %d%%", pct);
           last_processed_pct = pct;
       }

       // We pass the historical tick to Refresh, simulating live feed for indicators
       m_nav_system.Refresh(_Symbol, ticks[i]);

       double bid = ticks[i].bid;
       double ask = ticks[i].ask;
       double spread = (ask - bid) / _Point;
       long bid_vol = 0; // Not available in all tick data
       long ask_vol = 0;

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

       // Write to CSV - passing dummy data for trading metrics
       m_black_box.RecordTick(
           ticks[i].time_msc, "MINER", 0, "NONE",
           bid, ask, spread, bid_vol, ask_vol,
           0, 0, 0, 0, // OHLC (handled internally or zeroed)
           rsi, 0, 0, // RSI, Vel, Acc
           macd, pulse,
           mfi, roc, delta,
           mp, mr, ms,
           sp, sr, ss,
           tp, tr, ts,
           ema25, ema50, ema150, ema300,
           wpr, stoch,
           0, // Ping
           0, 0, 0, // Acc Stats (Balance, Margin, Pct)
           0, 0, 0, // PL Stats
           0, "NONE", 0, // Position info
           "NONE", "MINER", "EXTRACTED"
       );
   }

   PrintFormat("✅ Mining Complete. All %d ticks logged. CSV saved directly in the terminal's Files/ directory.", count);
   g_mining_done = true;
   ExpertRemove(); // Auto detach from chart
}
//+------------------------------------------------------------------+
