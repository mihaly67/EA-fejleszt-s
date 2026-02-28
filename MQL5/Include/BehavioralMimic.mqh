//+------------------------------------------------------------------+
//|                                            BehavioralMimic.mqh   |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property strict

// WinAPI for Crosshair Mouse Movement
#import "user32.dll"
   int PostMessageW(long hWnd, int Msg, int wParam, int lParam);
   int GetSystemMetrics(int nIndex);
#import

#define WM_MOUSEMOVE   0x0200

//+------------------------------------------------------------------+
//| Class: CBehavioralMimic                                          |
//| Purpose: Generates "Human Noise" (Disinformation)                |
//+------------------------------------------------------------------+
class CBehavioralMimic {
private:
   bool m_active;
   bool m_visual_debug;

   // Helper for Visual Debugging
   void DrawDebugMarker(int x, int y) {
      if(!m_visual_debug) return;

      string name = "MDAS_GhostMouse";
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime); // Changed to Lime for contrast on black
         ObjectSetString(0, name, OBJPROP_TEXT, "●"); // Visual Marker
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 20); // Increased size
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); // Must be false for visibility
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 100); // Ensure on top
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ChartRedraw(0);
   }

   void ShowActionDebug(string text) {
      if(!m_visual_debug) return;

      string name = "MDAS_Action";
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 120);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow); // Yellow text
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12); // Larger text
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); // Must be false for visibility
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, "MIMIC: " + text);
      ChartRedraw(0);
   }

   // Helper for Mouse Move
   void MoveMouseToChartXY(int x, int y) {
      long hwnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if(hwnd == 0) return;

      if(m_visual_debug) DrawDebugMarker(x, y);

      int lParam = (y << 16) | (x & 0xFFFF);
      PostMessageW(hwnd, WM_MOUSEMOVE, 0, lParam);
   }

public:
   CBehavioralMimic() {
      m_active = true;
      m_visual_debug = false;
      MathSrand(GetTickCount());
   }

   void SetDebugMode(bool enable) {
      m_visual_debug = enable;
      if(!m_visual_debug) {
         ObjectDelete(0, "MDAS_GhostMouse");
         ObjectDelete(0, "MDAS_Action");
         ObjectDelete(0, "MDAS_DEBUG_ACTIVE");
      } else {
         // Show a static label to confirm debug mode is ON
         string name = "MDAS_DEBUG_ACTIVE";
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 100);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
         ObjectSetString(0, name, OBJPROP_TEXT, "[ DEBUG MODE: GHOST MOUSE ]");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
         ChartRedraw(0);
      }
   }

   // 1. Chart Scrolling (Fidgeting)
   void ScrollFidget() {
      if(!m_active) return;

      if(m_visual_debug) ShowActionDebug("Scrolling (Fidgeting)");

      int shift = MathRand() % 10 - 5; // -5 to +5 bars
      if(shift == 0) shift = 1;

      ChartNavigate(0, CHART_CURRENT_POS, shift);
      // Print("[BehavioralMimic] Scroll Fidget: ", shift); // Verbose
   }

   // 2. Timeframe Switching (Analysis Simulation)
   void TimeframeCheck() {
      if(!m_active) return;

      if(m_visual_debug) ShowActionDebug("Analyzing Timeframes");

      ENUM_TIMEFRAMES current = Period();
      ENUM_TIMEFRAMES target = current;

      int r = MathRand() % 3;
      if(r == 0) target = PERIOD_M1;
      if(r == 1) target = PERIOD_M5;
      if(r == 2) target = PERIOD_M15;

      if(target != current) {
         ChartSetSymbolPeriod(0, Symbol(), target);
         Sleep(2000); // Simulate "looking" at the chart
         ChartSetSymbolPeriod(0, Symbol(), current); // Switch back
      }
   }

   // 3. Crosshair Exploration (New: Feb 2026)
   void CrosshairExploration() {
      if(!m_active) return;

      if(m_visual_debug) ShowActionDebug("Crosshair Exploration");

      // Enable Crosshair
      ChartSetInteger(0, CHART_CROSSHAIR_TOOL, true);

      // Get Chart dimensions
      int width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      // Simulate moving to a few random points (analyzing price levels)
      int steps = 3 + MathRand() % 3;
      for(int i=0; i<steps; i++) {
         int targetX = MathRand() % width;
         int targetY = MathRand() % height;

         MoveMouseToChartXY(targetX, targetY);
         Sleep(300 + MathRand() % 500); // Random pause between movements
      }

      // Disable Crosshair (optional, or leave it on like a trader would)
      if(MathRand() % 2 == 0) {
         ChartSetInteger(0, CHART_CROSSHAIR_TOOL, false);
      }

      // Clear action text after activity
      if(m_visual_debug) ShowActionDebug("Idle");
   }

   // 4. Random Noise Loop
   void Update() {
      // 5% chance per tick to do something
      if(MathRand() % 100 < 5) {
         int action = MathRand() % 3; // 0, 1, 2

         if(action == 0) ScrollFidget();
         if(action == 1) CrosshairExploration();
         // Timeframe switch is disruptive, disabled by default for safety
         // if(action == 2) TimeframeCheck();
      }
   }
};
