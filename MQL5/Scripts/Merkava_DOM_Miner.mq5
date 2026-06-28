//+------------------------------------------------------------------+
//|                                                Merkava_DOM_Miner |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                          Version 1.0 (Level 2)   |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      "https://github.com/MimicProject"
#property version   "1.00"
#property script_show_inputs

input string InpFileName = "DOM_Data.csv";
input int InpDurationMinutes = 120; // Futási idő percekben

int file_handle = INVALID_HANDLE;
long end_time = 0;

void OnStart()
{
    file_handle = FileOpen(InpFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(file_handle == INVALID_HANDLE) {
        Print("Nem sikerült megnyitni a fájlt!");
        return;
    }

    // Létező DOM szint paraméterek a brókeren
    int dom_depth = 5;

    string header = "TimeMsc,Bid,Ask,Spread,Ask_Vol_1,Ask_Price_1,Ask_Vol_2,Ask_Price_2,Bid_Vol_1,Bid_Price_1,Bid_Vol_2,Bid_Price_2";
    FileWrite(file_handle, header);

    if(!MarketBookAdd(_Symbol)) {
        Print("Nem sikerült feliratkozni a Depth of Market (DOM) adatokra!");
        FileClose(file_handle);
        return;
    }

    Print("DOM adatgyűjtés indul ", InpDurationMinutes, " percig...");
    end_time = TimeLocal() + (InpDurationMinutes * 60);

    MqlBookInfo book[];
    MqlTick tick;

    while(!IsStopped() && TimeLocal() < end_time) {
        if(SymbolInfoTick(_Symbol, tick) && MarketBookGet(_Symbol, book)) {
            long a_v1 = 0, a_v2 = 0;
            double a_p1 = 0.0, a_p2 = 0.0;
            long b_v1 = 0, b_v2 = 0;
            double b_p1 = 0.0, b_p2 = 0.0;

            int a_idx = 0;
            int b_idx = 0;

            int size = ArraySize(book);

            // MQL5 MarketBook array is sorted descending by price.
            // Best Ask (Level 1) is at the BOTTOM of the SELL block.
            // Best Bid (Level 1) is at the TOP of the BUY block.

            // Find where SELL ends and BUY starts
            int buy_start_idx = -1;
            for(int i=0; i<size; i++) {
                if(book[i].type == BOOK_TYPE_BUY) {
                    buy_start_idx = i;
                    break;
                }
            }

            // Extract Best Asks (from the bottom of the sell block upwards)
            if(buy_start_idx > 0) {
                if(buy_start_idx - 1 >= 0) { a_p1 = book[buy_start_idx - 1].price; a_v1 = book[buy_start_idx - 1].volume; }
                if(buy_start_idx - 2 >= 0) { a_p2 = book[buy_start_idx - 2].price; a_v2 = book[buy_start_idx - 2].volume; }
            } else if (buy_start_idx == -1 && size >= 2) {
                // Only SELL orders exist
                a_p1 = book[size - 1].price; a_v1 = book[size - 1].volume;
                a_p2 = book[size - 2].price; a_v2 = book[size - 2].volume;
            }

            // Extract Best Bids (from the top of the buy block downwards)
            if(buy_start_idx != -1) {
                if(buy_start_idx < size) { b_p1 = book[buy_start_idx].price; b_v1 = book[buy_start_idx].volume; }
                if(buy_start_idx + 1 < size) { b_p2 = book[buy_start_idx + 1].price; b_v2 = book[buy_start_idx + 1].volume; }
            }

            // Imbalance és Spoofing detektáláshoz elég a top 2 szint egyelőre
            string line = IntegerToString(tick.time_msc) + "," +
                          DoubleToString(tick.bid, _Digits) + "," +
                          DoubleToString(tick.ask, _Digits) + "," +
                          DoubleToString((tick.ask - tick.bid)/_Point, 1) + "," +
                          IntegerToString(a_v1) + "," + DoubleToString(a_p1, _Digits) + "," +
                          IntegerToString(a_v2) + "," + DoubleToString(a_p2, _Digits) + "," +
                          IntegerToString(b_v1) + "," + DoubleToString(b_p1, _Digits) + "," +
                          IntegerToString(b_v2) + "," + DoubleToString(b_p2, _Digits);

            FileWrite(file_handle, line);

            // Flush to disk safely so we don't lose data if the terminal crashes
            static int flush_counter = 0;
            if(++flush_counter % 100 == 0) FileFlush(file_handle);

            Sleep(10); // Ne terheljük túl a VPS-t, másodpercenként 100 minta
        } else {
            Sleep(1);
        }
    }

    MarketBookRelease(_Symbol);
    FileClose(file_handle);
    Print("DOM adatgyűjtés befejeződött.");
}
