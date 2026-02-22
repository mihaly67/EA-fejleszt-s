//+------------------------------------------------------------------+
//|                                       Probe_DLL_Sensitivity.mq5 |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property version   "1.00"
#property script_show_inputs

// Minimal WinAPI Import for Probing
#import "kernel32.dll"
   uint GetTickCount();
#import

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== STARTING DLL SENSITIVITY PROBE ===");

   if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) {
      Print("CRITICAL: 'Allow DLL imports' is DISABLED in Terminal Options!");
      Print("Please enable it in Tools -> Options -> Expert Advisors.");
      return;
   }

   Print("DLL Permission: GRANTED (Local Config OK)");
   Print("Attempting benign WinAPI call (GetTickCount)...");

   ResetLastError();
   uint tick = 0;

   // TRY-CATCH logic isn't native in MQL5 for external exceptions,
   // but if this call is blocked by the broker's custom build, the script will crash or log an error.
   tick = GetTickCount();

   if(tick > 0) {
      Print("SUCCESS: WinAPI Call Executed. Result: ", tick);
      Print("Environment appears PERMISSIVE to basic DLL calls.");
   } else {
      Print("FAILURE: WinAPI Call returned 0 or failed. Error: ", GetLastError());
   }

   Print("=== PROBE COMPLETE ===");
  }
