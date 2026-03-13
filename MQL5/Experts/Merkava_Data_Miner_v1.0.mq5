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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_mining_done) return;

   Print("⛏️ Commencing Tick Data Mining from ", TimeToString(InpStartDate), " to ", TimeToString(InpEndDate));

   MqlTick ticks[];
   int count = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, (ulong)InpStartDate * 1000, (ulong)InpEndDate * 1000);

   if(count == -1) {
       Print("❌ Failed to download ticks. Error: ", GetLastError());
       return;
   }

   PrintFormat("📥 Downloaded %d ticks. Processing...", count);

   // We need indicator data. Because indicators in MT5 are array series tied to bars,
   // aligning pure ticks perfectly with historical indicator buffers is complex without
   // running in Strategy Tester.
   // For a live script, we approximate by fetching the 1-minute bar corresponding to the tick's time.

   int last_processed_pct = -1;

   for(int i = 0; i < count; i++) {
       datetime tick_time = (datetime)(ticks[i].time_msc / 1000);

       // Optimization: Print progress every 10%
       int pct = (int)(((double)i / count) * 100);
       if(pct != last_processed_pct && pct % 10 == 0) {
           PrintFormat("⏳ Processing: %d%%", pct);
           last_processed_pct = pct;
       }

       // Find the bar index for this tick's time
       int bar_idx = iBarShift(_Symbol, _Period, tick_time, true);
       if(bar_idx < 0) continue; // Skip if no bar data matches

       // Fetch indicator data at this specific historical bar index
       m_nav_system.UpdateAtShift(bar_idx);

       double bid = ticks[i].bid;
       double ask = ticks[i].ask;
       double spread = (ask - bid) / _Point;
       double bid_vol = 0; // Not available in all tick data
       double ask_vol = 0;

       // Write to CSV - passing dummy data for trading metrics
       m_black_box.LogTick(
           tick_time, ticks[i].time_msc, "MINER", "OBSERVATION", "NONE",
           bid, ask, spread, bid_vol, ask_vol,
           0, 0, 0, 0, // OHLC (handled internally or zeroed)
           0, 0, 0, // RSI, Vel, Acc
           m_nav_system.GetMomentumPulse().MACD,
           m_nav_system.GetMomentumPulse().DFCurve,
           m_nav_system.GetHybridFlow().MFI,
           m_nav_system.GetHybridFlow().ROC,
           m_nav_system.GetHybridFlow().Delta,
           m_nav_system.GetContext().mic_p, m_nav_system.GetContext().mic_r, m_nav_system.GetContext().mic_s,
           m_nav_system.GetContext().sec_p, m_nav_system.GetContext().sec_r, m_nav_system.GetContext().sec_s,
           m_nav_system.GetContext().ter_p, m_nav_system.GetContext().ter_r, m_nav_system.GetContext().ter_s,
           m_nav_system.GetContext().ema_25, m_nav_system.GetContext().ema_50,
           m_nav_system.GetContext().ema_150, m_nav_system.GetContext().ema_300,
           m_nav_system.GetHybridMomentum().WPR, m_nav_system.GetHybridMomentum().Stoch_K,
           0, // Ping
           0, 0, 0, 0, 0, 0, // Acc Stats
           0, "NONE", 0, "NONE", "MINER", "EXTRACTED"
       );
   }

   Print("✅ Mining Complete. CSV saved in Files/BlackBox/ directory.");
   g_mining_done = true;
   ExpertRemove(); // Auto detach from chart
}
//+------------------------------------------------------------------+
