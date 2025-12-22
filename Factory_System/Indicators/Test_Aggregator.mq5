//+------------------------------------------------------------------+
//|                                              Test_Aggregator.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             Script to verify Hybrid_Signal_Aggregator logic       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.0"
#property script_show_inputs

#include <Hybrid/Hybrid_Signal_Aggregator.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== Test_Aggregator Started ===");

   HybridSignal_Aggregator brain;

   // Initialize
   if(!brain.Init(_Symbol, _Period)) {
      Print("Failed to Init Aggregator");
      return;
   }

   Print("Aggregator Initialized. Weights:");
   // (Getter for weights wasn't added but defaults are known)

   // Update (Simulate Tick)
   brain.Update();

   // Get Status
   HybridSignalStatus status = brain.GetStatus();

   Print("--- Signal Report ---");
   Print("Momentum Score: ", DoubleToString(status.MomentumScore, 2));
   Print("Flow Score:     ", DoubleToString(status.FlowScore, 2));
   Print("Context Score:  ", DoubleToString(status.ContextScore, 2));
   Print("WVF Score:      ", DoubleToString(status.WVFScore, 2));
   Print("Inst Score:     ", DoubleToString(status.InstScore, 2));
   Print("---------------------");
   Print("TOTAL CONVICTION: ", DoubleToString(status.TotalConviction, 2));
   Print("RECOMMENDATION:   ", status.Recommendation);

   Print("=== Test Complete ===");
}
