//+------------------------------------------------------------------+
//|                                     Hybrid_Signal_Aggregator.mqh |
//|                     Copyright 2024, Gemini & User Collaboration |
//|             "The Brain" - Consolidates all Hybrid Indicators      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property version   "1.0"

#include <Trade/Trade.mqh>

//--- Signal Status Structure
struct HybridSignalStatus
{
   double         MomentumScore;    // [-1.0 .. 1.0]
   double         FlowScore;        // [-1.0 .. 1.0]
   double         ContextScore;     // [-1.0 .. 1.0]
   double         WVFScore;         // [-1.0 .. 1.0] (Contrarian: High Fear = Buy)
   double         InstScore;        // [-1.0 .. 1.0] (VWAP/KAMA)

   double         TotalConviction;  // [-1.0 .. 1.0] Weighted Sum
   string         Recommendation;   // "STRONG BUY", "WAIT", "WEAK SELL"
   color          SignalColor;      // ForestGreen / FireBrick / Gray
};

//+------------------------------------------------------------------+
//| Class: Hybrid_Signal_Aggregator                                  |
//+------------------------------------------------------------------+
class HybridSignal_Aggregator
{
private:
   //--- Indicator Handles
   int            hMomentum;
   int            hFlow;
   int            hContext;
   int            hWVF;
   int            hInst;

   //--- Buffers (Temp storage for CopyBuffer)
   double         bufMomentumMACD[];   // Buf 2
   double         bufMomentumSignal[]; // Buf 3

   double         bufFlowMFI[];        // Buf 0
   double         bufFlowDelta[];      // Buf 2

   double         bufContextFast[];    // Buf 3
   double         bufContextSlow[];    // Buf 4

   double         bufWVF_Up[];         // Buf 0
   double         bufWVF_Down[];       // Buf 1

   double         bufInstVWAP[];       // Buf 0
   double         bufInstKAMA[];       // Buf 1

   //--- Weights (Total should be 1.0)
   double         wMomentum;
   double         wFlow;
   double         wContext;
   double         wWVF;
   double         wInst;

public:
   HybridSignal_Aggregator();
   ~HybridSignal_Aggregator();

   bool           Init(string symbol, ENUM_TIMEFRAMES period);
   void           Update();
   HybridSignalStatus GetStatus();

   //--- Helpers
   void           SetWeights(double m, double f, double c, double w, double i);
   double         Normalize(double val, double min, double max);
   double         GetConviction() { return GetStatus().TotalConviction; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
HybridSignal_Aggregator::HybridSignal_Aggregator()
{
   hMomentum = INVALID_HANDLE;
   hFlow     = INVALID_HANDLE;
   hContext  = INVALID_HANDLE;
   hWVF      = INVALID_HANDLE;
   hInst     = INVALID_HANDLE;

   // Default Weights
   wMomentum = 0.40;
   wFlow     = 0.20;
   wContext  = 0.20;
   wWVF      = 0.10;
   wInst     = 0.10;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
HybridSignal_Aggregator::~HybridSignal_Aggregator()
{
   IndicatorRelease(hMomentum);
   IndicatorRelease(hFlow);
   IndicatorRelease(hContext);
   IndicatorRelease(hWVF);
   IndicatorRelease(hInst);
}

//+------------------------------------------------------------------+
//| Init: Load Indicators                                            |
//+------------------------------------------------------------------+
bool HybridSignal_Aggregator::Init(string symbol, ENUM_TIMEFRAMES period)
{
   // 1. Momentum (v2.3)
   hMomentum = iCustom(symbol, period, "Showcase_Indicators\\HybridMomentumIndicator_v2.3",
                       5, 13, 6, PRICE_CLOSE, 1.0, 0.5); // Fast, Slow, Sig, Price, Gain, Phase

   // 2. Flow (v1.7)
   hFlow = iCustom(symbol, period, "Showcase_Indicators\\HybridFlowIndicator_v1.7",
                   14, true, 10, 20.0, true, 3, 100, 50.0);

   // 3. Context (v2.2)
   hContext = iCustom(symbol, period, "Showcase_Indicators\\HybridContextIndicator_v2.2",
                      true, true, PERIOD_H4); // Auto Mode

   // 4. WVF (v1.3)
   hWVF = iCustom(symbol, period, "Showcase_Indicators\\HybridWVFIndicator_v1.3",
                  22, 100.0); // Period, Multiplier (Scaled for visibility)

   // 5. Institutional (v1.0)
   hInst = iCustom(symbol, period, "Showcase_Indicators\\HybridInstitutionalIndicator_v1.0",
                   true, PERIOD_D1, true, 10, 2, 30, PRICE_CLOSE);

   if(hMomentum == INVALID_HANDLE || hFlow == INVALID_HANDLE ||
      hContext == INVALID_HANDLE || hWVF == INVALID_HANDLE || hInst == INVALID_HANDLE)
   {
      Print("CRITICAL: Failed to load one or more Hybrid Indicators!");
      return false;
   }

   // Set arrays as series (0 is newest)
   ArraySetAsSeries(bufMomentumMACD, true);
   ArraySetAsSeries(bufMomentumSignal, true);
   ArraySetAsSeries(bufFlowMFI, true);
   ArraySetAsSeries(bufFlowDelta, true);
   ArraySetAsSeries(bufContextFast, true);
   ArraySetAsSeries(bufContextSlow, true);
   ArraySetAsSeries(bufWVF_Up, true);
   ArraySetAsSeries(bufWVF_Down, true);
   ArraySetAsSeries(bufInstVWAP, true);
   ArraySetAsSeries(bufInstKAMA, true);

   return true;
}

//+------------------------------------------------------------------+
//| SetWeights                                                       |
//+------------------------------------------------------------------+
void HybridSignal_Aggregator::SetWeights(double m, double f, double c, double w, double i)
{
   double total = m + f + c + w + i;
   if(total == 0) return;
   wMomentum = m / total;
   wFlow     = f / total;
   wContext  = c / total;
   wWVF      = w / total;
   wInst     = i / total;
}

//+------------------------------------------------------------------+
//| Update: Fetch Data (Call in OnTick)                              |
//+------------------------------------------------------------------+
void HybridSignal_Aggregator::Update()
{
   // Copy latest 2 bars (0 and 1) to check crossovers if needed
   // Momentum: Buf 2 (MACD), Buf 3 (Signal)
   CopyBuffer(hMomentum, 2, 0, 2, bufMomentumMACD);
   CopyBuffer(hMomentum, 3, 0, 2, bufMomentumSignal);

   // Flow: Buf 0 (MFI), Buf 2 (Delta)
   CopyBuffer(hFlow, 0, 0, 2, bufFlowMFI);
   CopyBuffer(hFlow, 2, 0, 2, bufFlowDelta); // Delta Histogram

   // Context: Buf 3 (Fast EMA), Buf 4 (Slow EMA)
   CopyBuffer(hContext, 3, 0, 2, bufContextFast);
   CopyBuffer(hContext, 4, 0, 2, bufContextSlow);

   // WVF: Buf 0 (Up/Euphoria), Buf 1 (Down/Panic)
   CopyBuffer(hWVF, 0, 0, 2, bufWVF_Up);
   CopyBuffer(hWVF, 1, 0, 2, bufWVF_Down);

   // Inst: Buf 0 (VWAP), Buf 1 (KAMA)
   CopyBuffer(hInst, 0, 0, 2, bufInstVWAP);
   CopyBuffer(hInst, 1, 0, 2, bufInstKAMA);
}

//+------------------------------------------------------------------+
//| GetStatus: Calculate logic                                       |
//+------------------------------------------------------------------+
HybridSignalStatus HybridSignal_Aggregator::GetStatus()
{
   HybridSignalStatus status;

   // 1. Momentum Score
   // MACD > Signal = Bullish (+1), else Bearish (-1)
   // Refinement: Check Slope? No, simple cross for now.
   double macd = bufMomentumMACD[0];
   double sig  = bufMomentumSignal[0];
   status.MomentumScore = (macd > sig) ? 1.0 : -1.0;

   // 2. Flow Score
   // MFI > 50 = Bullish pressure
   // Delta > 50 = Buying Volume (Flow v1.7 center is 50)
   double mfi = bufFlowMFI[0];
   double delta = bufFlowDelta[0];
   double mfiScore = (mfi - 50.0) / 50.0; // [-1..1] approx
   double deltaScore = (delta - 50.0) / 50.0; // [-1..1]
   status.FlowScore = (mfiScore + deltaScore) / 2.0;
   // Clamp
   if(status.FlowScore > 1.0) status.FlowScore = 1.0;
   if(status.FlowScore < -1.0) status.FlowScore = -1.0;

   // 3. Context Score
   // Trend Alignment: FastEMA > SlowEMA
   double emaFast = bufContextFast[0];
   double emaSlow = bufContextSlow[0];
   status.ContextScore = (emaFast > emaSlow) ? 1.0 : -1.0;

   // 4. WVF Score (Contrarian)
   // Panic (DownBuffer > 0) -> Oversold -> Buy Signal
   // Euphoria (UpBuffer > 0) -> Overbought -> Sell Signal
   // Note: WVF values are positive.
   double panic = bufWVF_Down[0]; // Red bar length
   double euphoria = bufWVF_Up[0]; // Green bar length

   // If Panic is high, Score is Positive (Buy)
   // If Euphoria is high, Score is Negative (Sell)
   // Normalization: assume max spike around 50-100?
   // Let's use Tanh for soft limiting
   status.WVFScore = (MathTanh(panic/20.0) - MathTanh(euphoria/20.0));

   // 5. Institutional Score
   // Price > VWAP = Bullish
   // Price > KAMA = Bullish
   double price = iClose(_Symbol, _Period, 0); // Current Close
   double vwap = bufInstVWAP[0];
   double kama = bufInstKAMA[0];

   double vwapScore = (price > vwap) ? 1.0 : -1.0;
   double kamaScore = (price > kama) ? 1.0 : -1.0;
   status.InstScore = (vwapScore + kamaScore) / 2.0;

   // --- Total Conviction ---
   status.TotalConviction = (status.MomentumScore * wMomentum) +
                            (status.FlowScore * wFlow) +
                            (status.ContextScore * wContext) +
                            (status.WVFScore * wWVF) +
                            (status.InstScore * wInst);

   // --- Formatting ---
   if(status.TotalConviction > 0.5) {
      status.Recommendation = "STRONG BUY";
      status.SignalColor = clrForestGreen;
   } else if(status.TotalConviction > 0.1) {
      status.Recommendation = "WEAK BUY";
      status.SignalColor = clrMediumSeaGreen;
   } else if(status.TotalConviction < -0.5) {
      status.Recommendation = "STRONG SELL";
      status.SignalColor = clrFireBrick;
   } else if(status.TotalConviction < -0.1) {
      status.Recommendation = "WEAK SELL";
      status.SignalColor = clrIndianRed;
   } else {
      status.Recommendation = "WAIT";
      status.SignalColor = clrGray;
   }

   return status;
}
