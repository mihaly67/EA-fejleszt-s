//+------------------------------------------------------------------+
//|                                     Merkava_DOM_Miner_v1.1.mq5   |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                    Version 1.1 (OnBookEvent driven + Epoch Sync) |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      "https://github.com/MimicProject"
#property version   "1.10"

// Ez egy EXPERT ADVISOR (EA) kell hogy legyen, nem sima Script,
// mivel csak az EA-k tudják elkapni a valódi eseményeket (OnTick, OnBookEvent).

input string InpFileName = "DOM_Data"; // Filename base (will append _YYYYMMDD_HHMMSS)
input int InpDurationMinutes = 120; // Futási idő percekben (0 = végtelen)

int file_handle = INVALID_HANDLE;
long end_time = 0;
long last_written_time_msc = 0;

int OnInit() {
    string time_suffix = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
    StringReplace(time_suffix, ".", "");
    StringReplace(time_suffix, ":", "");
    StringReplace(time_suffix, " ", "_");

    string final_filename = InpFileName + "_" + time_suffix + ".csv";

    file_handle = FileOpen(final_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(file_handle == INVALID_HANDLE) {
        Print("❌ Nem sikerült megnyitni a fájlt: ", final_filename);
        return INIT_FAILED;
    }

    string header = "TimeMsc,Bid,Ask,Spread,Ask_Vol_1,Ask_Price_1,Ask_Vol_2,Ask_Price_2,Bid_Vol_1,Bid_Price_1,Bid_Vol_2,Bid_Price_2";
    FileWrite(file_handle, header);

    if(!MarketBookAdd(_Symbol)) {
        Print("❌ Nem sikerült feliratkozni a Depth of Market (DOM) adatokra!");
        FileClose(file_handle);
        return INIT_FAILED;
    }

    if(InpDurationMinutes > 0) {
        end_time = TimeLocal() + (InpDurationMinutes * 60);
        Print("✅ DOM adatgyűjtés indul ", InpDurationMinutes, " percig a következő fájlba: ", final_filename);
    } else {
        Print("✅ DOM adatgyűjtés indul VÉGTELEN ideig a következő fájlba: ", final_filename);
    }

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    MarketBookRelease(_Symbol);
    if(file_handle != INVALID_HANDLE) {
        FileFlush(file_handle);
        FileClose(file_handle);
    }
    Print("🛑 DOM adatgyűjtés leállt.");
}

void OnBookEvent(const string& symbol) {
    if(symbol != _Symbol) return;

    // Check expiration
    if(InpDurationMinutes > 0 && TimeLocal() >= end_time) {
        Print("⏳ Adatgyűjtési idő lejárt. EA leáll.");
        ExpertRemove();
        return;
    }

    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) return;

    // Szűrés: Csak akkor írjunk, ha a milliszekundum már lépett (nincs duplikált epoch azonos milliszekundumban)
    if(tick.time_msc <= last_written_time_msc) return;

    MqlBookInfo book[];
    if(MarketBookGet(_Symbol, book)) {
        long a_v1 = 0, a_v2 = 0;
        double a_p1 = 0.0, a_p2 = 0.0;
        long b_v1 = 0, b_v2 = 0;
        double b_p1 = 0.0, b_p2 = 0.0;

        int size = ArraySize(book);

        int buy_start_idx = -1;
        for(int i=0; i<size; i++) {
            if(book[i].type == BOOK_TYPE_BUY) {
                buy_start_idx = i;
                break;
            }
        }

        if(buy_start_idx > 0) {
            if(buy_start_idx - 1 >= 0) { a_p1 = book[buy_start_idx - 1].price; a_v1 = book[buy_start_idx - 1].volume; }
            if(buy_start_idx - 2 >= 0) { a_p2 = book[buy_start_idx - 2].price; a_v2 = book[buy_start_idx - 2].volume; }
        } else if (buy_start_idx == -1 && size >= 2) {
            a_p1 = book[size - 1].price; a_v1 = book[size - 1].volume;
            a_p2 = book[size - 2].price; a_v2 = book[size - 2].volume;
        }

        if(buy_start_idx != -1) {
            if(buy_start_idx < size) { b_p1 = book[buy_start_idx].price; b_v1 = book[buy_start_idx].volume; }
            if(buy_start_idx + 1 < size) { b_p2 = book[buy_start_idx + 1].price; b_v2 = book[buy_start_idx + 1].volume; }
        }

        double spread = tick.ask - tick.bid;

        string line = IntegerToString(tick.time_msc) + "," +
                      DoubleToString(tick.bid, _Digits) + "," +
                      DoubleToString(tick.ask, _Digits) + "," +
                      DoubleToString(spread, _Digits) + "," +
                      IntegerToString(a_v1) + "," + DoubleToString(a_p1, _Digits) + "," +
                      IntegerToString(a_v2) + "," + DoubleToString(a_p2, _Digits) + "," +
                      IntegerToString(b_v1) + "," + DoubleToString(b_p1, _Digits) + "," +
                      IntegerToString(b_v2) + "," + DoubleToString(b_p2, _Digits);

        FileWrite(file_handle, line);
        last_written_time_msc = tick.time_msc;

        static int flush_counter = 0;
        if(++flush_counter % 50 == 0) FileFlush(file_handle);
    }
}
