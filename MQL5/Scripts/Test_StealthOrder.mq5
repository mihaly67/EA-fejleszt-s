//+------------------------------------------------------------------+
//|                                            Test_StealthOrder.mq5 |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property version   "1.00"
#property script_show_inputs

#include <Stealth_Order.mqh>

input bool   Test_BUY  = true; // Test BUY Click?
input bool   Test_SELL = false; // Test SELL Click?

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== STARTING STEALTH ORDER TEST ===");
   Print("WARNING: This will open a REAL/DEMO trade immediately if successful!");

   CStealthOrder clicker(true);

   // Ensure panel is visible first
   clicker.EnablePanel();
   Sleep(1000); // Wait for user to see it

   if(Test_BUY) {
      Print("Attempting BUY Click...");
      clicker.ClickBuy();
   }

   if(Test_SELL) {
      Print("Attempting SELL Click...");
      clicker.ClickSell();
   }

   Print("=== CLICK COMMAND SENT. CHECK TERMINAL LOGS. ===");
   Print("Verify ORDER_REASON in 'Orders' tab.");
  }
