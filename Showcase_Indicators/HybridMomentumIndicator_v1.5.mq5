//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v1.5.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|              Verzió: 1.5 (Decoupled Scaling)                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.5"

#property indicator_separate_window
#property indicator_buffers 8  // JAVÍTVA: 8 buffer kell
#property indicator_plots   3

//--- Plot 1: Hisztogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
// Palette: 0-4 (Green), 5-9 (Red), 10 (Gray)
#property indicator_color1  C'60,80,60', C'40,120,40', C'20,160,20', C'10,200,10', clrLimeGreen, C'80,60,60', C'120,40,40', C'160,20,20', C'200,10,10', clrRed, clrGray

//--- Plot 2: MACD Fővonal
#property indicator_label2  "MACD Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Jelzővonal
#property indicator_label3  "Signal Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input Parameters
input group              "=== DEMA MACD Settings ==="
input int                InpFastDEMAPeriod     = 12;     // Gyors DEMA periódus
input int                InpSlowDEMAPeriod     = 26;     // Lassú DEMA periódus
input int                InpSignalPeriod       = 9;      // Jelzővonal EMA periódusa
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_CLOSE; // Alkalmazott ár

input group              "=== Conviction Filter Settings ==="
input bool               InpUseConviction      = true;   // Meggyőződési súlyozás használata
input double             InpConvictionThreshold = 0.4;  // Conviction küszöbérték (0.0-1.0)
input double             InpConvictionMultiplier = 1.0; // Conviction szorzó

input group              "=== ATR Settings ==="
input bool               InpUseATRFilter       = true;   // ATR szűrő használata
input int                InpAtrPeriod          = 14;     // ATR periódus
input double             InpATRMultiplier      = 1.5;    // ATR szorzó

input group              "=== Volume Settings ==="
input bool               InpUseVolumeFilter    = true;   // Volumen szűrő használata
input int                InpVolumeMAPeriod     = 20;     // Volumen mozgóátlag periódusa
input double             InpVolumeStrengthFactor = 1.5;  // Volumen erősség szorzó
input double             InpVolumeMinThreshold = 0.5;    // Minimum volumen küszöb

input group              "=== Stochastic Settings ==="
input bool               InpUseStochastic      = true;   // Stochastic szűrő használata
input int                InpStochKPeriod       = 5;      // Stochastic %K
input int                InpStochDPeriod       = 3;      // Stochastic %D
input int                InpStochSlowing       = 3;      // Stochastic lassítás
input ENUM_MA_METHOD     InpStochMethod        = MODE_SMA; // Stochastic MA módszer
input ENUM_STO_PRICE     InpStochPrice         = STO_LOWHIGH; // Stochastic ár típus
input double             InpStochOverbought    = 80.0;   // Túlvett szint
input double             InpStochOversold      = 20.0;   // Túladott szint

input group              "=== Williams %R Settings ==="
input bool               InpUseWPR             = true;   // WPR szűrő használata
input int                InpWprPeriod          = 14;     // WPR periódus
input double             InpWPROverbought      = -20.0;  // WPR túlvett
input double             InpWPROversold        = -80.0;  // WPR túladott

input group              "=== Visual Settings ==="
input int                InpGradientLookback   = 100;   // Visszatekintés a gradienshez
input bool               InpShowZeroLine       = true;   // Nulla vonal megjelenítése
input color              InpZeroLineColor      = clrGray; // Nulla vonal színe
input ENUM_LINE_STYLE    InpZeroLineStyle     = STYLE_DOT; // Nulla vonal stílusa
input int                InpZeroLineWidth      = 1;      // Nulla vonal szélesség
input double             InpHistScale          = 1.0;    // Hisztogram skálázás (Magasság szorzó)
input double             InpSignalGain         = 1.0;    // Görbe szétválasztás (Jel erősítés)

input group              "=== Debug Settings ==="
input bool               InpEnableDebug        = false;  // Debug üzenetek
input bool               InpShowAllValues      = false;  // Minden érték megjelenítése (conviction mellőzése)

//--- Indicator Buffers
double      HistogramBuffer[];
double      ColorBuffer[];
double      MacdLineBuffer[];
double      SignalLineBuffer[];

//--- Calculation Buffers
double      fast_dema_buffer[];
double      slow_dema_buffer[];
double      conviction_buffer[];
double      temp_buffer[];

//--- Indicator Handles
int         wpr_handle = INVALID_HANDLE;
int         stoch_handle = INVALID_HANDLE;
int         atr_handle = INVALID_HANDLE;

//--- Global variables
int         min_bars_required;

//+------------------------------------------------------------------+
//| DEMA calculation function (Javított verzió)                      |
//+------------------------------------------------------------------+
void CalculateDEMA(const int rates_total, const int begin, const int period, 
                   const double &src[], double &dema_buffer[])
{
    if(period <= 0) return;
    
    double alpha = 2.0 / (period + 1.0);
    double ema1 = src[begin];
    double ema2 = ema1;
    
    // Inicializálás
    for(int i = begin; i < begin + period && i < rates_total; i++)
    {
        ema1 = src[i];
        ema2 = ema1;
        dema_buffer[i] = ema1;
    }
    
    // DEMA számítás
    for(int i = begin + period; i < rates_total; i++)
    {
        ema1 = alpha * src[i] + (1.0 - alpha) * ema1;
        ema2 = alpha * ema1 + (1.0 - alpha) * ema2;
        dema_buffer[i] = 2.0 * ema1 - ema2;
    }
}

//+------------------------------------------------------------------+
//| EMA calculation function                                         |
//+------------------------------------------------------------------+
void CalculateEMA(const int rates_total, const int begin, const int period,
                  const double &src[], double &ema_buffer[])
{
    if(period <= 0) return;
    
    double alpha = 2.0 / (period + 1.0);
    
    // Inicializálás
    ema_buffer[begin] = src[begin];
    
    // EMA számítás
    for(int i = begin + 1; i < rates_total; i++)
    {
        ema_buffer[i] = alpha * src[i] + (1.0 - alpha) * ema_buffer[i-1];
    }
}

//+------------------------------------------------------------------+
//| Simple Moving Average calculation                                 |
//+------------------------------------------------------------------+
void CalculateSMA(const int rates_total, const int begin, const int period,
                  const long &volume[], double &sma_buffer[])
{
    if(period <= 0) return;
    
    for(int i = begin + period - 1; i < rates_total; i++)
    {
        double sum = 0.0;
        for(int j = 0; j < period; j++)
        {
            sum += (double)volume[i - j];
        }
        sma_buffer[i] = sum / period;
    }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Buffer setup
    SetIndexBuffer(0, HistogramBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
    SetIndexBuffer(2, MacdLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, SignalLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, fast_dema_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, slow_dema_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, conviction_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, temp_buffer, INDICATOR_CALCULATIONS);

    // Minimum required bars
    min_bars_required = MathMax(InpSlowDEMAPeriod, InpFastDEMAPeriod) + InpSignalPeriod + 10;
    
    // Plot settings
    IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v1.5");
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);
    
    // Zero line
    if(InpShowZeroLine)
    {
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
        IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpZeroLineColor);
        IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, InpZeroLineStyle);
        IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, InpZeroLineWidth);
    }
    
    // Initialize handles
    if(InpUseWPR)
    {
        wpr_handle = iWPR(_Symbol, _Period, InpWprPeriod);
        if(wpr_handle == INVALID_HANDLE)
        {
            Print("Hiba: WPR handle létrehozása sikertelen");
            return INIT_FAILED;
        }
    }
    
    if(InpUseStochastic)
    {
        stoch_handle = iStochastic(_Symbol, _Period, InpStochKPeriod, InpStochDPeriod, 
                                  InpStochSlowing, InpStochMethod, InpStochPrice);
        if(stoch_handle == INVALID_HANDLE)
        {
            Print("Hiba: Stochastic handle létrehozása sikertelen");
            return INIT_FAILED;
        }
    }
    
    if(InpUseATRFilter)
    {
        atr_handle = iATR(_Symbol, _Period, InpAtrPeriod);
        if(atr_handle == INVALID_HANDLE)
        {
            Print("Hiba: ATR handle létrehozása sikertelen");
            return INIT_FAILED;
        }
    }
    
    // Parameter validation
    if(InpFastDEMAPeriod <= 0 || InpSlowDEMAPeriod <= 0 || InpSignalPeriod <= 0)
    {
        Print("Hiba: Érvénytelen DEMA/Signal periódusok");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(InpFastDEMAPeriod >= InpSlowDEMAPeriod)
    {
        Print("Hiba: Gyors DEMA periódusnak kisebbnek kell lennie mint a lassú");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(InpEnableDebug)
        Print("Hybrid Momentum indikátor inicializálva - min_bars: ", min_bars_required);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(wpr_handle != INVALID_HANDLE) IndicatorRelease(wpr_handle);
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Calculate Conviction Score                                       |
//+------------------------------------------------------------------+
double CalculateConviction(int index, const double &atr_val[], const double &wpr_val[],
                          const double &stoch_main[], const double &vol_ma[],
                          const long &tick_volume[])
{
    if(!InpUseConviction) return 1.0;
    
    double conviction = 1.0;
    double factors = 0.0;
    
    // ATR faktor
    if(InpUseATRFilter && atr_val[index] > 0)
    {
        double atr_factor = MathMin(2.0, InpATRMultiplier);
        conviction *= atr_factor;
        factors += 1.0;
    }
    
    // Volumen faktor
    if(InpUseVolumeFilter && vol_ma[index] > 0)
    {
        double volume_ratio = (double)tick_volume[index] / vol_ma[index];
        double volume_strength = MathMin(2.0, MathMax(InpVolumeMinThreshold, 
                                volume_ratio * InpVolumeStrengthFactor));
        conviction *= volume_strength;
        factors += 1.0;
    }
    
    // WPR faktor
    if(InpUseWPR)
    {
        double wpr_norm = (-wpr_val[index]) / 100.0;
        double wpr_conviction = 1.0;
        if(wpr_norm <= (InpWPROversold + 100.0) / 100.0) 
            wpr_conviction = 1.5; // Túladott = erős
        else if(wpr_norm >= (InpWPROverbought + 100.0) / 100.0) 
            wpr_conviction = 1.5; // Túlvett = erős
        conviction *= wpr_conviction;
        factors += 1.0;
    }
    
    // Stochastic faktor
    if(InpUseStochastic)
    {
        double stoch_conviction = 1.0;
        if(stoch_main[index] <= InpStochOversold) 
            stoch_conviction = 1.5; // Túladott = erős
        else if(stoch_main[index] >= InpStochOverbought) 
            stoch_conviction = 1.5; // Túlvett = erős
        conviction *= stoch_conviction;
        factors += 1.0;
    }
    
    // Normalize
    if(factors > 0)
        conviction = MathPow(conviction, 1.0/factors) * InpConvictionMultiplier;
    
    return MathMin(2.0, MathMax(0.0, conviction));
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
    if(rates_total < min_bars_required)
    {
        if(InpEnableDebug)
            Print("Nem elég adat: ", rates_total, " < ", min_bars_required);
        return 0;
    }
    
    int start = 0;
    if(prev_calculated > 0)
        start = prev_calculated - 1;
    else
        start = min_bars_required;
    
    // Get price data based on applied price
    double price_data[];
    ArrayResize(price_data, rates_total);
    
    for(int i = 0; i < rates_total; i++)
    {
        switch(InpAppliedPrice)
        {
            case PRICE_OPEN:     price_data[i] = open[i]; break;
            case PRICE_HIGH:     price_data[i] = high[i]; break;
            case PRICE_LOW:      price_data[i] = low[i]; break;
            case PRICE_CLOSE:    price_data[i] = close[i]; break;
            case PRICE_MEDIAN:   price_data[i] = (high[i] + low[i]) / 2.0; break;
            case PRICE_TYPICAL:  price_data[i] = (high[i] + low[i] + close[i]) / 3.0; break;
            case PRICE_WEIGHTED: price_data[i] = (high[i] + low[i] + 2*close[i]) / 4.0; break;
            default:             price_data[i] = close[i]; break;
        }
    }
    
    // Calculate DEMA values
    CalculateDEMA(rates_total, 0, InpFastDEMAPeriod, price_data, fast_dema_buffer);
    CalculateDEMA(rates_total, 0, InpSlowDEMAPeriod, price_data, slow_dema_buffer);
    
    // Calculate MACD Line
    for(int i = start; i < rates_total; i++)
    {
        double raw_macd = fast_dema_buffer[i] - slow_dema_buffer[i];

        // Store RAW MACD in temp buffer for pure calculations
        temp_buffer[i] = raw_macd;

        // Apply Signal Gain ONLY for the visual MACD line buffer
        MacdLineBuffer[i] = raw_macd * InpSignalGain;
    }
    
    // Calculate Signal Line
    // 1. Calculate RAW Signal (on raw MACD) for Histogram consistency
    // We can't easily do this without another buffer.
    // Alternative: Calculate Scaled Signal Line on Scaled MACD (visual),
    // and derive Histogram from (Macd/Gain - Signal/Gain) * HistScale?
    // YES.

    // Calculate Visual Signal Line (DEMA of Visual MACD)
    CalculateDEMA(rates_total, InpSlowDEMAPeriod, InpSignalPeriod, MacdLineBuffer, SignalLineBuffer);
    
    // Get auxiliary data
    double wpr_val[], stoch_main[], stoch_signal[], atr_val[], vol_ma[];
    
    // Initialize arrays
    if(InpUseWPR)
    {
        ArrayResize(wpr_val, rates_total);
        if(CopyBuffer(wpr_handle, 0, 0, rates_total, wpr_val) <= 0)
        {
            if(InpEnableDebug) Print("WPR adat lekérése sikertelen");
            return prev_calculated;
        }
    }
    
    if(InpUseStochastic)
    {
        ArrayResize(stoch_main, rates_total);
        ArrayResize(stoch_signal, rates_total);
        if(CopyBuffer(stoch_handle, 0, 0, rates_total, stoch_main) <= 0 ||
           CopyBuffer(stoch_handle, 1, 0, rates_total, stoch_signal) <= 0)
        {
            if(InpEnableDebug) Print("Stochastic adat lekérése sikertelen");
            return prev_calculated;
        }
    }
    
    if(InpUseATRFilter)
    {
        ArrayResize(atr_val, rates_total);
        if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_val) <= 0)
        {
            if(InpEnableDebug) Print("ATR adat lekérése sikertelen");
            return prev_calculated;
        }
    }
    
    if(InpUseVolumeFilter)
    {
        ArrayResize(vol_ma, rates_total);
        CalculateSMA(rates_total, 0, InpVolumeMAPeriod, tick_volume, vol_ma);
    }
    
    // Calculate final values
    for(int i = start; i < rates_total; i++)
    {
        if(i < InpSlowDEMAPeriod + InpSignalPeriod) continue;
        
        // Calculate conviction
        conviction_buffer[i] = CalculateConviction(i, atr_val, wpr_val, stoch_main, vol_ma, tick_volume);
        
        // Calculate histogram
        // We must reverse the SignalGain to get the "True" difference, then apply HistScale.
        // Or simply: VisualDiff = (Macd - Signal). This contains Gain.
        // We want Hist = RawDiff * HistScale.
        // Since VisualDiff = RawDiff * Gain, then RawDiff = VisualDiff / Gain.
        // So Hist = (VisualDiff / Gain) * HistScale.

        double visual_diff = MacdLineBuffer[i] - SignalLineBuffer[i];
        double histogram_raw = 0.0;

        if(InpSignalGain > 0.0)
            histogram_raw = (visual_diff / InpSignalGain) * InpHistScale;
        else
            histogram_raw = visual_diff * InpHistScale; // Safety fallback
        
        if(InpShowAllValues || conviction_buffer[i] >= InpConvictionThreshold)
        {
            HistogramBuffer[i] = histogram_raw * conviction_buffer[i];

            // Calculate color (Standard Gradient)
            int lookback = MathMin(i + 1, InpGradientLookback);
            double max_val = HistogramBuffer[ArrayMaximum(HistogramBuffer, i - lookback + 1, lookback)];
            double min_val = HistogramBuffer[ArrayMinimum(HistogramBuffer, i - lookback + 1, lookback)];

            double value = HistogramBuffer[i];
            if(value > 0 && max_val > 0)
            {
                int color_index = (int)MathRound((value / max_val) * 4.0);
                ColorBuffer[i] = MathMin(4, color_index);
            }
            else if(value < 0 && min_val < 0)
            {
                int color_index = (int)MathRound((value / min_val) * 4.0);
                ColorBuffer[i] = MathMin(4, color_index) + 5;
            }
            else
            {
                ColorBuffer[i] = 0;
            }
        }
        else
        {
            // Soft Gate: Show weak signal as Gray (Ghost Mode)
            HistogramBuffer[i] = histogram_raw * 0.2; // 20% visual height for weak signals
            HistogramBuffer[i] = histogram_raw * conviction_buffer[i];

            // Fallback for visibility
            if (MathAbs(HistogramBuffer[i]) < 0.0000001) HistogramBuffer[i] = histogram_raw * 0.1;

            // Gray Color Mapping (v1.3)
            // Use the new explicit Gray color (Index 10)
            ColorBuffer[i] = 10;
        }
    }
    
    if(InpEnableDebug && prev_calculated == 0)
        Print("Hybrid Momentum számítás befejezve. Utolsó MACD: ", MacdLineBuffer[rates_total-1]);
    
    return rates_total;
}
