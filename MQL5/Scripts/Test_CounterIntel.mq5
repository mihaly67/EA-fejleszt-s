//+------------------------------------------------------------------+
//|                                            Test_CounterIntel.mq5 |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property version   "1.00"
#property script_show_inputs

#include <Counter_Intel.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== STARTING COUNTER-INTEL DIAGNOSTIC ===");

   CCounterIntel sentinel(true);

   // 1. Test User Mode Debugger
   bool userDbg = sentinel.CheckDebugger_User();
   if(userDbg) Print("User Debugger Check: DETECTED (FAIL)");
   else Print("User Debugger Check: CLEAN (PASS)");

   // 2. Test Kernel Mode Debugger
   bool kernelDbg = sentinel.CheckDebugger_Kernel();
   if(kernelDbg) Print("Kernel Debugger Check: DETECTED (FAIL)");
   else Print("Kernel Debugger Check: CLEAN (PASS)");

   // 3. Test VM Specs
   bool vmSpecs = sentinel.CheckVM_Specs();
   if(vmSpecs) Print("VM Specs Check: DETECTED (FAIL)");
   else Print("VM Specs Check: CLEAN (PASS)");

   // 4. Test Mouse Sandbox (Short wait for test)
   Print("Testing Mouse (Waiting 2 seconds)...");
   bool mouseSandbox = sentinel.CheckSandbox_Mouse(2000);
   if(mouseSandbox) Print("Mouse Sandbox Check: STATIONARY (SUSPICIOUS)");
   else Print("Mouse Sandbox Check: MOVEMENT DETECTED (PASS)");

   Print("=== DIAGNOSTIC COMPLETE ===");
  }
