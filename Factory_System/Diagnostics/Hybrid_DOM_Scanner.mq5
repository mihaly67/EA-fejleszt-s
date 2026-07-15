//+------------------------------------------------------------------+
//|                                           Hybrid_DOM_Scanner.mq5 |
//|                                                      Jules Agent |
//|                             Diagnosztikai Eszköz: DOM Ellenőrzés |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property link      "https://mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

// --- Globális változók ---
bool is_subscribed = false;
long last_print_time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Megpróbálunk feliratkozni a MarketBook eseményekre
   if(MarketBookAdd(_Symbol))
     {
      Print("MarketBookAdd: SIKERES feliratkozás a ", _Symbol, " szimbólum DOM adataira.");
      is_subscribed = true;
     }
   else
     {
      Print("MarketBookAdd: HIBA! Nem sikerült feliratkozni. Hibakód: ", GetLastError());
      // Ha nem sikerül, akkor is futhatunk, hátha később sikerül, vagy manuális hívás működik?
      // Általában ha a MarketBookAdd false, akkor nincs DOM.
      return(INIT_SUCCEEDED); // Nem állítjuk le, hogy lássuk a logokat
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(is_subscribed)
     {
      MarketBookRelease(_Symbol);
      Print("MarketBookRelease: Feliratkozás törölve.");
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
   // Az OnBookEvent az elsődleges, de ha nincs esemény, ellenőrizzük itt is (ritkábban),
   // hogy egyáltalán visszaad-e valamit a MarketBookGet.

   // Csak 5 másodpercenként nézzük meg OnCalculate-ben, hogy ne terheljük a logot
   if(GetTickCount() - last_print_time > 5000)
     {
      CheckDOM("OnCalculate");
      last_print_time = GetTickCount();
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   if(symbol == _Symbol)
     {
      CheckDOM("OnBookEvent");
     }
  }

//+------------------------------------------------------------------+
//| Segédfüggvény a DOM ellenőrzésére                                |
//+------------------------------------------------------------------+
void CheckDOM(string source)
  {
   MqlBookInfo book[];

   // DOM lekérdezése
   if(MarketBookGet(_Symbol, book))
     {
      int size = ArraySize(book);

      if(size > 0)
        {
         // Van adat!
         PrintFormat("--- DOM ADAT (%s) --- Mélység: %d sor", source, size);

         // Statisztika számítása
         long total_bid_vol = 0;
         long total_ask_vol = 0;

         // Kiírjuk az első pár sort (Best Bid / Best Ask)
         // MQL5-ben a tömb általában ár szerint rendezett?
         // A dokumentáció szerint: "The array is sorted by price."
         // Általában:
         // Ask (Eladási ajánlatok) = Magasabb ár -> Tömb vége? Vagy eleje?
         // BOOK_TYPE_SELL és BOOK_TYPE_BUY

         int best_bid_idx = -1;
         int best_ask_idx = -1;

         for(int i=0; i<size; i++)
           {
            if(book[i].type == BOOK_TYPE_SELL)
               total_ask_vol += book[i].volume;
            if(book[i].type == BOOK_TYPE_BUY)
               total_bid_vol += book[i].volume;

            // Debug dump az első és utolsó elemekről
            if(i < 3 || i > size - 4)
              {
               PrintFormat("Index %d: Típus=%s Ár=%.5f Vol=%d",
                           i,
                           EnumToString(book[i].type),
                           book[i].price,
                           book[i].volume);
              }
           }

         PrintFormat("Összesített Bid Vol: %d | Összesített Ask Vol: %d", total_bid_vol, total_ask_vol);
        }
      else
        {
         // Üres tömb
         PrintFormat("--- DOM ÜRES (%s) --- MarketBookGet sikeres, de 0 elemet adott vissza.", source);
        }
     }
   else
     {
      // Hiba a lekérdezésnél
      // PrintFormat("--- DOM HIBA (%s) --- Nem sikerült az adatlekérés.", source);
     }
  }
