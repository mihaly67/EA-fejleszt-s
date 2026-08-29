//+------------------------------------------------------------------+
//|                                             SimplePortTester.mq5 |
//|                                     To diagnose WINE TCP sockets |
//+------------------------------------------------------------------+
#property copyright "Jules"
#property link      "https://github.com/Jules"
#property version   "1.00"

input string InpHost = "127.0.0.1";
input int    InpPort = 5555;
input int    InpTimeout = 2000;

int g_socket = INVALID_HANDLE;

int OnInit()
{
    Print("--- Simple Port Tester Starting ---");

    g_socket = SocketCreate();
    if(g_socket == INVALID_HANDLE) {
        Print("❌ SocketCreate failed! Error: ", GetLastError());
        return INIT_FAILED;
    }

    Print("Attempting to connect to ", InpHost, ":", InpPort, " with timeout ", InpTimeout, "ms...");

    if(SocketConnect(g_socket, InpHost, InpPort, InpTimeout)) {
        Print("✅ SUCCESS! Connected to ", InpHost, ":", InpPort);

        // Let's send a ping!
        string msg = "HELLO_FROM_MT5\n";
        uchar buffer[];
        StringToCharArray(msg, buffer);
        if(SocketSend(g_socket, buffer, ArraySize(buffer)-1) >= 0) {
            Print("✅ Successfully sent data over socket.");
        } else {
            Print("❌ Failed to send data. Error: ", GetLastError());
        }

    } else {
        Print("❌ SocketConnect failed! Error: ", GetLastError());
    }

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(g_socket != INVALID_HANDLE) {
        SocketClose(g_socket);
        Print("Socket closed.");
    }
}
