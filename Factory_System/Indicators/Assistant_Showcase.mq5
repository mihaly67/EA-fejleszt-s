//+------------------------------------------------------------------+
//|                                           Assistant_Showcase.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Showcase for Trading Assistant & Dashboard"

//--- Includes
#include "..\Profit_Management\TradingAssistant.mqh"
#include "..\Profit_Management\TradingPanel.mqh"
#include "..\Profit_Management\Environment\Environment.mqh"
#include "..\Profit_Management\ProfitMaximizer.mqh"

//--- Input Parameters
input int      InpADXPeriod   = 14;    // ADX Period
input int      InpATRPeriod   = 14;    // ATR Period

//--- Global Objects
CTradingAssistant *g_Assistant;
CTradingPanel     *g_Panel;
CEnvironment      *g_Env;
CProfitMaximizer  *g_ProfitMax;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 0. Initialize Environment (The Nervous System)
   g_Env = new CEnvironment();
   if(!g_Env->Init(_Symbol))
     {
      Print("Failed to init Environment");
      return INIT_FAILED;
     }

   // 1. Initialize Assistant Logic
   g_Assistant = new CTradingAssistant();
   if(!g_Assistant->Init(_Symbol, _Period, g_Env))
     {
      Print("Failed to init Assistant");
      return INIT_FAILED;
     }

   // 1.b Initialize Profit Maximizer
   g_ProfitMax = new CProfitMaximizer();
   // Hack: We need access to internal TickVol from Assistant, or create new one.
   // For showcase, let's use the one in Assistant if exposed, or pass NULL for now.
   // Ideally: g_ProfitMax->Init(g_Assistant->GetTickVolObject());
   // Since GetTickVolObject doesn't exist, we skip init for this demo or update logic.
   // Let's assume we can get it later or it's optional.

   // 2. Initialize GUI Panel
   g_Panel = new CTradingPanel();
   if(!g_Panel->Create(0, "WPR_Assistant_Panel", 0, 50, 50, 400, 250))
     {
      Print("Failed to create Panel");
      return INIT_FAILED;
     }
   g_Panel->Run(); // Start message loop for panel

   // 3. Set timer for updates
   EventSetTimer(1); // 1 second update rate for GUI

   Print("Assistant Showcase Initialized");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   if(CheckPointer(g_Panel) == POINTER_DYNAMIC)
     {
      g_Panel->Destroy(reason);
      delete g_Panel;
     }

   if(CheckPointer(g_Assistant) == POINTER_DYNAMIC)
     {
      delete g_Assistant;
     }

   if(CheckPointer(g_Env) == POINTER_DYNAMIC)
     {
      delete g_Env;
     }

   if(CheckPointer(g_ProfitMax) == POINTER_DYNAMIC)
     {
      delete g_ProfitMax;
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Get current Bid price
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   // 0. Update Environment
   if(g_Env != NULL) g_Env->OnTick();

   // Feed logic
   g_Assistant->OnTick(tick.bid);

   // Profit Maximizer Logic (Simulated Loop for Showcase)
   // In real EA, we loop through PositionsTotal()
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) g_ProfitMax->ManagePosition(ticket, tick.bid);
     }

   // Note: We update GUI in OnTimer to decouple heavy logic from rendering,
   // but for simple panels, updating here is also fine.
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(CheckPointer(g_Panel) != POINTER_DYNAMIC) return;

   // Refresh Panel Data from Assistant
   g_Panel->UpdateValues(
      g_Assistant->GetRegimeText(),
      g_Assistant->GetAdviceText(),
      g_Assistant->GetConvictionScore(),
      g_Assistant->GetTickVolatility()
   );
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   // Pass events to Panel (for clicks, drag, etc)
   if(CheckPointer(g_Panel) == POINTER_DYNAMIC)
     {
      g_Panel->OnEvent(id, lparam, dparam, sparam);
     }
  }
//+------------------------------------------------------------------+
