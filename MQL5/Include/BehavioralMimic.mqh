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

   // Trail memory
   struct TrailPoint {
      int x;
      int y;
   };
   TrailPoint m_trail[10];

   // Helper for Visual Debugging
   void DrawDebugMarker(int x, int y) {
      if(!m_visual_debug) return;

      // 1. Shift Trail
      for(int i=9; i>0; i--) {
         m_trail[i] = m_trail[i-1];
      }
      m_trail[0].x = x;
      m_trail[0].y = y;

      // 2. Draw Ghost Mouse (Main Cursor)
      string name = "MDAS_GhostMouse";
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
         // Wingdings 241 is an arrow
         ObjectSetString(0, name, OBJPROP_TEXT, CharToString((uchar)241));
         ObjectSetString(0, name, OBJPROP_FONT, "Wingdings");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 24);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); // Make Visible
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

      // 3. Draw Trail
      for(int i=1; i<10; i++) {
         if(m_trail[i].x == 0 && m_trail[i].y == 0) continue;

         string tName = "MDAS_Trail_" + IntegerToString(i);
         if(ObjectFind(0, tName) < 0) {
            ObjectCreate(0, tName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, tName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, tName, OBJPROP_COLOR, clrGreen);
            ObjectSetString(0, tName, OBJPROP_TEXT, "•");
            ObjectSetInteger(0, tName, OBJPROP_FONTSIZE, 10 - i); // Fade size
            ObjectSetInteger(0, tName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, tName, OBJPROP_ZORDER, 90);
         }
         ObjectSetInteger(0, tName, OBJPROP_XDISTANCE, m_trail[i].x);
         ObjectSetInteger(0, tName, OBJPROP_YDISTANCE, m_trail[i].y);
      }

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
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
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
      // Init trail
      for(int i=0; i<10; i++) { m_trail[i].x = 0; m_trail[i].y = 0; }
   }

   void SetDebugMode(bool enable) {
      m_visual_debug = enable;
      if(!m_visual_debug) {
         ObjectDelete(0, "MDAS_GhostMouse");
         ObjectDelete(0, "MDAS_Action");
         ObjectDelete(0, "MDAS_DEBUG_ACTIVE");
         for(int i=1; i<10; i++) ObjectDelete(0, "MDAS_Trail_" + IntegerToString(i));
      } else {
         // Show a static label to confirm debug mode is ON
         string name = "MDAS_DEBUG_ACTIVE";
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 100);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
         ObjectSetString(0, name, OBJPROP_TEXT, "[ DEBUG MODE: GHOST MOUSE & TRAIL ]");
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
   }

   // 2. Crosshair Exploration (New: Feb 2026)
   void CrosshairExploration() {
      if(!m_active) return;

      if(m_visual_debug) ShowActionDebug("Crosshair Exploration");

      // Enable Crosshair
      ChartSetInteger(0, CHART_CROSSHAIR_TOOL, true);

      // Get Chart dimensions
      int width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      // Simulate moving to a few random points (analyzing price levels)
      int steps = 5 + MathRand() % 5; // Increased steps for better viz
      for(int i=0; i<steps; i++) {
         int targetX = MathRand() % width;
         int targetY = MathRand() % height;

         // Interpolate movement for smoother trail (simple lerp)
         int startX = m_trail[0].x > 0 ? m_trail[0].x : targetX;
         int startY = m_trail[0].y > 0 ? m_trail[0].y : targetY;

         // Micro-steps
         int microSteps = 5;
         for(int j=1; j<=microSteps; j++) {
            int curX = startX + (targetX - startX) * j / microSteps;
            int curY = startY + (targetY - startY) * j / microSteps;
            MoveMouseToChartXY(curX, curY);
            Sleep(20);
         }

         Sleep(100 + MathRand() % 200); // Pause
      }

      // Disable Crosshair (optional)
      if(MathRand() % 2 == 0) {
         ChartSetInteger(0, CHART_CROSSHAIR_TOOL, false);
      }

      if(m_visual_debug) ShowActionDebug("Idle");
   }

   // 4. Random Noise Loop - INCREASED FREQUENCY FOR DEBUG
   void Update() {
      // 20% chance per tick (was 5%) to ensure visibility
      if(MathRand() % 100 < 20) {
         int action = MathRand() % 2; // 0, 1

         if(action == 0) ScrollFidget();
         if(action == 1) CrosshairExploration();
      }
   }
};
