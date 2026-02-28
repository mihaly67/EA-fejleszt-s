//+------------------------------------------------------------------+
//|                                            Merkava_Defense.mqh   |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property strict

#include <SystemMonitor.mqh>
#include <UX_Controller.mqh>
#include <BehavioralMimic.mqh>

//+------------------------------------------------------------------+
//| Class: CMerkavaDefense                                           |
//| Purpose: Unified Controller for MDAS (Defense Autonomous System) |
//+------------------------------------------------------------------+
class CMerkavaDefense {
private:
   CSystemMonitor    *m_monitor;
   CUX_Controller    *m_ux;
   CBehavioralMimic  *m_mimic;
   bool              m_is_compromised;
   bool              m_visual_debug;

   // Co-Pilot Variables
   string            m_ai_signal_file;
   datetime          m_last_signal_time;

   void DrawCoPilotOverlay(string signal, double confidence) {
      // Visual Feedback for the Human Trader
      // Green = Safe/Recommended, Red = Risky/Trap
      color signalColor = (signal == "BUY") ? clrLime : (signal == "SELL" ? clrRed : clrGray);

      ObjectCreate(0, "MDAS_Signal", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "MDAS_Signal", OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, "MDAS_Signal", OBJPROP_YDISTANCE, 150);
      ObjectSetInteger(0, "MDAS_Signal", OBJPROP_COLOR, signalColor);
      ObjectSetString(0, "MDAS_Signal", OBJPROP_TEXT, "AI COPILOT: " + signal + " (" + DoubleToString(confidence*100, 1) + "%)");
   }

public:
   CMerkavaDefense(bool debug_mode = true) {
      m_monitor = new CSystemMonitor(false);
      m_ux      = new CUX_Controller(false);
      m_mimic   = new CBehavioralMimic();
      m_is_compromised = false;
      m_ai_signal_file = "Merkava_Signal.json";

      SetVisualMode(debug_mode);
   }

   void SetVisualMode(bool enable) {
      m_visual_debug = enable;
      if(CheckPointer(m_mimic) != POINTER_INVALID) {
         m_mimic.SetDebugMode(m_visual_debug);
      }
      if(CheckPointer(m_ux) != POINTER_INVALID) {
         m_ux.SetVisualMode(m_visual_debug);
      }
   }

   ~CMerkavaDefense() {
      if(CheckPointer(m_monitor) == POINTER_DYNAMIC) delete m_monitor;
      if(CheckPointer(m_ux) == POINTER_DYNAMIC) delete m_ux;
      if(CheckPointer(m_mimic) == POINTER_DYNAMIC) delete m_mimic;
   }

   bool SecureBoot() {
      if(!m_monitor.IsStable()) {
         Print("[MDAS] CRITICAL: Environment Unstable. AI Copilot Disabled.");
         m_is_compromised = true;
         return false;
      }
      return true;
   }

   // Main Loop
   void Defend() {
      if(m_is_compromised) return;

      // 1. Generate Noise
      m_mimic.Update();

      // 2. Check AI Signal (Co-Pilot Mode)
      // Implementation of JSON reading would go here
      // For now, we simulate the interface
   }

   // Human Triggered Action (Safe Execution)
   // Call this when YOU press a button on your custom panel
   bool HumanExecute(int type) {
      if(m_is_compromised) {
         Alert("MDAS BLOCKED: Environment Unsafe!");
         return false;
      }

      // 1. UX Controller executes the click (Spoofing)
      if(type == 0) return m_ux.ExecuteAction_Primary(); // BUY
      if(type == 1) return m_ux.ExecuteAction_Secondary(); // SELL

      return false;
   }
};
2. MQL5/Include/UX_Controller.mqh

//+------------------------------------------------------------------+
//|                                                UX_Controller.mqh |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property strict

// WinAPI Imports
#import "user32.dll"
   int PostMessageW(long hWnd, int Msg, int wParam, int lParam);
   int SendMessageW(long hWnd, int Msg, int wParam, int lParam);
   int GetWindowRect(long hWnd, int &rect[]);
   int GetSystemMetrics(int nIndex);
#import

// Constants
#define WM_LBUTTONDOWN 0x0201
#define WM_LBUTTONUP   0x0202
#define MK_LBUTTON     0x0001

//+------------------------------------------------------------------+
//| Class: CUX_Controller (formerly StealthOrder)                    |
//| Purpose: GUI Automation & User Experience Control                |
//+------------------------------------------------------------------+
class CUX_Controller {
private:
   bool m_verbose;
   bool m_visual_debug;
   int  m_buy_x;
   int  m_buy_y;
   int  m_sell_x;
   int  m_sell_y;

   int MakeLParam(int x, int y) {
      return (y << 16) | (x & 0xFFFF);
   }

   void Log(string msg) {
      if(m_verbose) Print("[UX_Controller] ", msg);
   }

   void VisualizeClick(int x, int y, bool is_buy) {
      if(!m_visual_debug) return;
      
      // Diagnostic Strategy (Visual Verification): Draw BEFORE the API call
      string name = "MDAS_ClickFlash_" + IntegerToString(GetTickCount());
      color col = is_buy ? clrDeepSkyBlue : clrCrimson;

      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetString(0, name, OBJPROP_TEXT, "◎"); // Circle Wingding
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 30); // Large circle
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); // Explicitly visible
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 101); // On top of Ghost Mouse
      ChartRedraw(0);

      // Simulate expanding circle and deletion via sleep
      Sleep(50);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 40);
      ChartRedraw(0);
      Sleep(50);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 50);
      ChartRedraw(0);
      Sleep(50);
      ObjectDelete(0, name);
      ChartRedraw(0);
   }

public:
   CUX_Controller(bool verbose=true) {
      m_verbose = verbose;
      m_visual_debug = false; // Off by default, turned on by MDAS
      // Default coordinates
      m_sell_x = 40;
      m_sell_y = 40;
      m_buy_x = 120;
      m_buy_y = 40;
   }
   
   void SetVisualMode(bool enable) {
      m_visual_debug = enable;
   }

   void Calibrate(int sellX, int sellY, int buyX, int buyY) {
      m_sell_x = sellX; m_sell_y = sellY;
      m_buy_x = buyX; m_buy_y = buyY;
   }

   void EnsurePanelVisible() {
      if(!ChartGetInteger(0, CHART_SHOW_ONE_CLICK)) {
         ChartSetInteger(0, CHART_SHOW_ONE_CLICK, true);
         ChartRedraw();
         Sleep(100);
      }
   }

   bool ExecuteAction_Primary() { // BUY
      EnsurePanelVisible();
      long hwnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if(hwnd == 0) return false;

      // Visual Verification BEFORE API call
      VisualizeClick(m_buy_x, m_buy_y, true);

      int lParam = MakeLParam(m_buy_x, m_buy_y);
      PostMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
      Sleep(10);
      PostMessageW(hwnd, WM_LBUTTONUP, 0, lParam);

      Log("Primary Action Triggered (BUY)");
      return true;
   }

   bool ExecuteAction_Secondary() { // SELL
      EnsurePanelVisible();
      long hwnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if(hwnd == 0) return false;

      // Visual Verification BEFORE API call
      VisualizeClick(m_sell_x, m_sell_y, false);

      int lParam = MakeLParam(m_sell_x, m_sell_y);
      PostMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
      Sleep(10);
      PostMessageW(hwnd, WM_LBUTTONUP, 0, lParam);

      Log("Secondary Action Triggered (SELL)");
      return true;
   }
};

