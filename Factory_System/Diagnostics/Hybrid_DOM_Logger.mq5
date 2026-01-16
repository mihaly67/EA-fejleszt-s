//+------------------------------------------------------------------+
//|                                           Hybrid_DOM_Logger.mq5 |
//|                                                      Jules Agent |
//|                                     Data Collection for DOM Analysis |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.02"
#property indicator_chart_window
#property indicator_plots 0

#include "../../Indicators/PhysicsEngine.mqh"

// --- Inputs ---
input string InpFileNamePrefix = "Hybrid_DOM_Log"; // File prefix

// --- Globals ---
int g_file_handle = INVALID_HANDLE;
bool g_subscribed = false;
PhysicsEngine g_physics(50);

// --- Struct to hold simplified level data ---
struct LevelData {
   double price;
   long volume;
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Subscribe to DOM
   if(MarketBookAdd(_Symbol))
     {
      g_subscribed = true;
      Print("Logger: MarketBook subscribed.");
     }
   else
     {
      Print("Logger: Failed to subscribe to MarketBook!");
      return(INIT_FAILED);
     }

   // 2. Open CSV File
   // Format: Prefix_Symbol_YYYYMMDD_HHMMSS.csv (Simplified to avoid OS issues)
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", "");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ".", ""); // Remove dots for cleanest filename
   string filename = InpFileNamePrefix + "_" + _Symbol + "_" + time_str + ".csv";

   ResetLastError();
   // Reverted to simple local FileOpen
   g_file_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(g_file_handle == INVALID_HANDLE)
     {
      Print("Logger: Failed to open file! Error: ", GetLastError());
      return(INIT_FAILED);
     }

   // 3. Write Header (Unified Schema with Trojan Horse EA)
   // Trade Cols: Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment
   // Market Cols: BestBid,BestAsk,Velocity,Acceleration,Spread,BidV1..5,AskV1..5
   string header = "Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,BestBid,BestAsk,Velocity,Acceleration,Spread,BidV1,BidV2,BidV3,BidV4,BidV5,AskV1,AskV2,AskV3,AskV4,AskV5\r\n";
   FileWriteString(g_file_handle, header);
   FileFlush(g_file_handle);

   Print("Logger: Recording started to ", filename);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_subscribed) MarketBookRelease(_Symbol);

   if(g_file_handle != INVALID_HANDLE)
     {
      FileClose(g_file_handle);
      Print("Logger: File closed.");
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      g_physics.Update(tick);
   }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol != _Symbol) return;
   if(g_file_handle == INVALID_HANDLE) return;

   MqlBookInfo book[];
   if(MarketBookGet(symbol, book))
     {
      WriteLog(book);
     }
  }

//+------------------------------------------------------------------+
//| Log Logic                                                        |
//+------------------------------------------------------------------+
void WriteLog(const MqlBookInfo &book[])
  {
   int size = ArraySize(book);
   if(size == 0) return;

   LevelData bids[];
   LevelData asks[];

   ArrayResize(bids, size);
   ArrayResize(asks, size);

   int bid_cnt = 0;
   int ask_cnt = 0;

   // 1. Collect
   for(int i=0; i<size; i++)
     {
      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
        {
         bids[bid_cnt].price = book[i].price;
         bids[bid_cnt].volume = book[i].volume;
         bid_cnt++;
        }
      else if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
        {
         asks[ask_cnt].price = book[i].price;
         asks[ask_cnt].volume = book[i].volume;
         ask_cnt++;
        }
     }

   // 2. Sort
   SortBids(bids, bid_cnt);
   SortAsks(asks, ask_cnt);

   // 3. Get Physics State
   PhysicsState phys = g_physics.GetState();

   // 4. Prepare Data Line

   // Time Columns
   string t = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount()%1000);
   string line = t + "," + ms + ",";

   // Trade Columns (Dummy for Logger)
   // Action,Ticket,TradePrice,TradeVol,Profit,Comment
   line += "LOG,0,0.0,0.0,0.0,Logger,";

   // Best Prices
   double best_bid = (bid_cnt > 0) ? bids[0].price : 0.0;
   double best_ask = (ask_cnt > 0) ? asks[0].price : 0.0;

   line += DoubleToString(best_bid, _Digits) + "," + DoubleToString(best_ask, _Digits) + ",";

   // Physics
   line += DoubleToString(phys.velocity, 5) + ",";
   line += DoubleToString(phys.acceleration, 5) + ",";
   line += DoubleToString(phys.spread_avg, 1) + ",";

   // 5. Volumes L1-L5
   // Bids
   for(int i=0; i<5; i++)
     {
      long v = (i < bid_cnt) ? bids[i].volume : 0;
      line += IntegerToString(v);
      line += ",";
     }

   // Asks
   for(int i=0; i<5; i++)
     {
      long v = (i < ask_cnt) ? asks[i].volume : 0;
      line += IntegerToString(v);
      if(i < 4) line += ",";
     }

   line += "\r\n";

   FileWriteString(g_file_handle, line);
   FileFlush(g_file_handle); // Forced flush for reliability
  }

// --- Sorting ---
void SortBids(LevelData &arr[], int count)
  {
   for(int i=0; i<count-1; i++)
     for(int j=0; j<count-i-1; j++)
       if(arr[j].price < arr[j+1].price)
         {
          LevelData temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }

void SortAsks(LevelData &arr[], int count)
  {
   for(int i=0; i<count-1; i++)
     for(int j=0; j<count-i-1; j++)
       if(arr[j].price > arr[j+1].price)
         {
          LevelData temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
         }
  }
