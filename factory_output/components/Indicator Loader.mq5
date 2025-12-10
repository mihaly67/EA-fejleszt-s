//|                                             Indicator Loader.mq5 |
//|                       Copyright 2025, phade, MetaQuotes Ltd.      |
//|                                             https://www.mql5.com |
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "A system to load up to 4 separate-window indicators for tests in the visual strategy tester"
#property description "Designed for Strategy Tester visualization"
// Input parameters for indicator paths
input string Indicator1_Path = "Examples\\MACD"; // Path to indicator 1
input string Indicator2_Path = "Examples\\ADX";  // Path to indicator 2
input string Indicator3_Path = "Examples\\ATR";  // Path to indicator 3
input string Indicator4_Path = "Examples\\CCI";  // Path to indicator 4
int indicator_handles[4];
int indicator_windows[];
string paths[] = {Indicator1_Path, Indicator2_Path, Indicator3_Path, Indicator4_Path};