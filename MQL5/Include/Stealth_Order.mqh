//+------------------------------------------------------------------+
//|                                                Stealth_Order.mqh |
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
   // GetSystemMetrics for screen resolution scaling checks if needed
   int GetSystemMetrics(int nIndex);
#import

// Constants
#define WM_LBUTTONDOWN 0x0201
#define WM_LBUTTONUP   0x0202
#define MK_LBUTTON     0x0001

// Coordinates for One Click Trading Panel (Approximation)
// These might need calibration based on DPI/Resolution
// Standard MT5 One Click Panel is usually top-left.
// SELL Button ~ (40, 40)
// BUY Button ~ (120, 40)
// Panel Size ~ 150x60
// Offsets relative to chart area

class CStealthOrder {
private:
   bool m_verbose;
   int  m_buy_x;
   int  m_buy_y;
   int  m_sell_x;
   int  m_sell_y;

   // Helper to pack coordinates into lParam (low word x, high word y)
   int MakeLParam(int x, int y) {
      return (y << 16) | (x & 0xFFFF);
   }

   void Log(string msg) {
      if(m_verbose) Print("[StealthOrder] ", msg);
   }

public:
   CStealthOrder(bool verbose=true) {
      m_verbose = verbose;
      // Default coordinates for Standard DPI
      // Needs manual calibration or image recognition for robustness
      // SELL is Left, BUY is Right
      m_sell_x = 40;
      m_sell_y = 40;
      m_buy_x = 120;
      m_buy_y = 40;
   }

   // Set Custom Coordinates if auto-detection fails
   void Calibrate(int sellX, int sellY, int buyX, int buyY) {
      m_sell_x = sellX; m_sell_y = sellY;
      m_buy_x = buyX; m_buy_y = buyY;
   }

   // Enable the Panel
   void EnablePanel() {
      if(!ChartGetInteger(0, CHART_SHOW_ONE_CLICK)) {
         ChartSetInteger(0, CHART_SHOW_ONE_CLICK, true);
         ChartRedraw();
         Sleep(100); // Wait for repaint
      }
   }

   // Trigger BUY
   bool ClickBuy() {
      EnablePanel();
      long hwnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if(hwnd == 0) {
         Log("Error: Could not get Chart HWND");
         return false;
      }

      int lParam = MakeLParam(m_buy_x, m_buy_y);

      // Simulate Click
      PostMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
      Sleep(10); // Hold
      PostMessageW(hwnd, WM_LBUTTONUP, 0, lParam);

      Log("Clicked BUY at " + IntegerToString(m_buy_x) + "," + IntegerToString(m_buy_y));
      return true;
   }

   // Trigger SELL
   bool ClickSell() {
      EnablePanel();
      long hwnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if(hwnd == 0) return false;

      int lParam = MakeLParam(m_sell_x, m_sell_y);

      PostMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
      Sleep(10);
      PostMessageW(hwnd, WM_LBUTTONUP, 0, lParam);

      Log("Clicked SELL at " + IntegerToString(m_sell_x) + "," + IntegerToString(m_sell_y));
      return true;
   }

   // Disclaimer: This method relies on the UI layout.
   // It does NOT confirm execution. The EA must monitor OnTradeTransaction.
};
