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
