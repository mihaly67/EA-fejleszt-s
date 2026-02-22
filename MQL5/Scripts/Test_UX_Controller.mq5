//+------------------------------------------------------------------+
//|                                            Test_UX_Controller.mq5|
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property version   "1.00"
#property script_show_inputs

#include <UX_Controller.mqh>

input bool   Test_Primary   = true;
input bool   Test_Secondary = false;

void OnStart()
  {
   Print("=== STARTING UX CONTROLLER TEST ===");

   CUX_Controller ux(true);

   ux.EnsurePanelVisible();
   Sleep(1000);

   if(Test_Primary) {
      ux.ExecuteAction_Primary();
   }

   if(Test_Secondary) {
      ux.ExecuteAction_Secondary();
   }

   Print("=== UX COMMAND SENT ===");
  }
