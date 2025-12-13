//+------------------------------------------------------------------+
//|                                       Test_Amplitude_Booster.mq5 |
//|                                                   Jules Assistant|
//|                                      Test Script for AGC Library |
//|                                                                  |
//| INSTALLATION PATH: MQL5/Scripts/Test_Amplitude_Booster.mq5       |
//| DEPENDENCY: MQL5/Include/Amplitude_Booster.mqh                   |
//+------------------------------------------------------------------+
#property copyright "Jules Assistant"
#property version   "1.00"
#property script_show_inputs

// Include the library (Ensure Amplitude_Booster.mqh is in MQL5/Include/ or same folder)
#include "Amplitude_Booster.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting Amplitude Booster Test ===");

   CAmplitudeBooster booster;
   booster.Init(10, true, 1.5); // Period 10, Use IFT, Gain 1.5

   // Simulating a flattened sine wave (low amplitude)
   // Normally -1 to 1, here flattened to -0.1 to 0.1
   double input_signal[] = {0.0, 0.05, 0.08, 0.1, 0.08, 0.05, 0.0, -0.05, -0.08, -0.1, -0.08, -0.05};

   for(int i=0; i<ArraySize(input_signal); i++)
     {
      double raw = input_signal[i];
      double boosted = booster.Update(raw);

      // We expect the first few to be 0 (filling buffer)
      // Once full, we expect values closer to -1..1 despite raw being small
      PrintFormat("Step %d: Raw=%.2f -> Boosted=%.2f", i, raw, boosted);
     }

   Print("=== Test Complete. If this compiled and ran, the library is valid. ===");
  }
//+------------------------------------------------------------------+
