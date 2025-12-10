//|                                                   ASCTrendND.mq5 |
//|                                                   Alain Verleyen |
//|                                             http://www.alamga.be |
/*
    Trading strategy based on ASCTrend indicator as main signal,
    filtered by NRTR indicator (see    http://www.mql5.com/en/forum/10741)
    * Only for current symbol and timeframe
    * Stoploss based on ASCTrend signal,
    * No takeprofit, exit based on trailing stop
    * Money management NOT YET IMPLEMENTED (only fixed volume)
    * Very basic error management
   1.01 Correction of littles bugs.
   1.02 Add of TrendStrength as filter
   1.03 Cosmetic change for Codebase publication
*/
#property link          "http://www.mql5.com/en/forum/10741"
#property version       "1.03"
#property description   "Trading strategy based on ASCTrend indicator as main signal."