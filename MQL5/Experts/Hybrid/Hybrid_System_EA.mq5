//+------------------------------------------------------------------+
//|                                             Hybrid_System_EA.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Master EA running the Hybrid System                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.1"

#include <Hybrid\Hybrid_Signal_Aggregator.mqh>
#include <Hybrid\Hybrid_Panel.mqh>

//--- Input Parameters
input group "=== System Settings ==="
input int InpMagicNumber = 123456; // Magic Number

//--- Global Objects
HybridSignal_Aggregator ExtBrain;
Hybrid_Panel            ExtPanel;

//--- State
datetime LastDayTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   LastDayTime = iTime(_Symbol, PERIOD_D1, 0);

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
   if(!ExtPanel.Create("HybridPanel", 10, 20, 310, 420))
   {
      Print("Failed to create Hybrid Panel UI!");
      return INIT_FAILED;
   }

   ExtPanel.Run();

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
   // Check New Day
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay != LastDayTime)
   {
      LastDayTime = currentDay;
      ExtPanel.OnNewDay();
   }

   // Update Logic
   ExtBrain.Update();
   ExtPanel.OnTick(); // Agent Logic (Profit Management)

   // Update Visuals
   ExtPanel.Update();
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
