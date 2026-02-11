//+------------------------------------------------------------------+
//|                                                Types_v2_15.mqh |
//|                                                      Jules Agent |
//|                                       Part of Merkava Tank Logic |
//|                                                    Version 2.15  |
//+------------------------------------------------------------------+
#ifndef TYPES_V2_15_MQH
#define TYPES_V2_15_MQH

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

enum ENUM_ATTACK_DIR
{
   ATTACK_BOTH = 0, // Legacy Trap (Buy + Sell)
   ATTACK_BUY  = 1, // Long Only (Buy)
   ATTACK_SELL = 2  // Short Only (Sell)
};

#endif
