//+------------------------------------------------------------------+
//|                                             Hybrid_System_EA.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Master EA running the Hybrid System                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.0"

#include <Hybrid\Hybrid_Signal_Aggregator.mqh>
#include <Hybrid\Hybrid_Panel.mqh>

//--- Input Parameters
input group "=== System Settings ==="
input int InpMagicNumber = 123456; // Magic Number

//--- Global Objects
HybridSignal_Aggregator ExtBrain;
Hybrid_Panel            ExtPanel;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Initialize Brain (Aggregator)
   if(!ExtBrain.Init(_Symbol, _Period))
   {
      Print("Failed to initialize Hybrid Brain!");
      return INIT_FAILED;
   }

   // 2. Initialize Panel
   if(!ExtPanel.Init(&ExtBrain, InpMagicNumber))
   {
      Print("Failed to initialize Hybrid Panel Logic!");
      return INIT_FAILED;
   }

   // 3. Create Panel UI
   // Place it at top-left
   if(!ExtPanel.Create("HybridPanel", 10, 20, 310, 420))
   {
      Print("Failed to create Hybrid Panel UI!");
      return INIT_FAILED;
   }

   ExtPanel.Run(); // Needed for CAppDialog to start handling events? usually Create + explicit calls are enough but Run() sets up some flags.
   // Actually CAppDialog::Run() is not always standard, but let's check.
   // Usually we just create it.

   Print("Hybrid System Initialized.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ExtPanel.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update Logic
   ExtBrain.Update();

   // Update Visuals
   ExtPanel.Update();

   // Auto-Trading Logic (Optional - if we want the EA to trade automatically based on Brain)
   // For now, it's Manual via Panel.
   // if(ExtBrain.GetConviction() > 0.8) m_agent.OrderBuy(...)
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   ExtPanel.OnEvent(id, lparam, dparam, sparam);
}
