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

public:
   CUX_Controller(bool verbose=true) {
      m_verbose = verbose;
      // Default coordinates
      m_sell_x = 40;
      m_sell_y = 40;
      m_buy_x = 120;
      m_buy_y = 40;
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

      int lParam = MakeLParam(m_sell_x, m_sell_y);
      PostMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
      Sleep(10);
      PostMessageW(hwnd, WM_LBUTTONUP, 0, lParam);

      Log("Secondary Action Triggered (SELL)");
      return true;
   }
};
