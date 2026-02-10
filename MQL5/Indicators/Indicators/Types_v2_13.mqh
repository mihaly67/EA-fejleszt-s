//+------------------------------------------------------------------+
//|                                                Types_v2_13.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.13  |
//+------------------------------------------------------------------+
#ifndef TYPES_V2_13_MQH
#define TYPES_V2_13_MQH

enum ENUM_FIRE_MODE
{
   FIRE_MODE_LIMIT = 0, // Reversion (Buy Low, Sell High)
   FIRE_MODE_STOP  = 1  // Breakout (Buy High, Sell Low)
};

enum ENUM_ENTRY_MODE
{
   ENTRY_PENDING = 0, // Default: All orders are pending (Stop/Limit)
   ENTRY_MARKET  = 1  // Burst: Level 1 is Market (Hedge), others are pending
};

#endif
