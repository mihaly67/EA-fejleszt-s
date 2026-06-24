//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v1.7.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|          Verzió: 1.7 (Phase Advance & Tanh Normalization)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.7"

#property indicator_separate_window
#property indicator_buffers 9
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

input group              "=== Normalization & Phase Settings ==="
input int                InpNormPeriod         = 100;    // Normalizációs periódus (StdDev ablak)
input double             InpNormSensitivity    = 1.0;    // Érzékenység (1.0 = Normál, >1.0 = Élesebb)
input double             InpPhaseAdvance       = 0.5;    // Fázis siettetés (0.0 = Nincs, >0.0 = Siet)

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
double      raw_macd_buffer[];    // Stores un-normalized MACD
double      raw_signal_buffer[];  // Stores un-normalized Signal
double      conviction_buffer[];

//--- Indicator Handles
int         wpr_handle = INVALID_HANDLE;
int         stoch_handle = INVALID_HANDLE;
int         atr_handle = INVALID_HANDLE;

//--- Global variables
int         min_bars_required;

//+------------------------------------------------------------------+
//| DEMA calculation function (Optimized)                            |
//+------------------------------------------------------------------+
void CalculateDEMA(const int rates_total, const int start_pos, const int period,
                   const double &src[], double &dema_buffer[])
{
    if(period <= 0) return;

    double alpha = 2.0 / (period + 1.0);
    int begin = start_pos;

    // Handle initial calculation (0 to period)
    if (begin < period)
    {
       dema_buffer[0] = src[0];
    }

    // Safety check for lookback
    if(begin == 0) begin = 1;

    double ema1 = src[0];
    double ema2 = ema1;

    // Recalculate full history to maintain recursive stability
    for(int i = 0; i < rates_total; i++)
    {
       ema1 = alpha * src[i] + (1.0 - alpha) * ema1;
       ema2 = alpha * ema1 + (1.0 - alpha) * ema2;
       dema_buffer[i] = 2.0 * ema1 - ema2;
    }
}

//+------------------------------------------------------------------+
//| Simple Moving Average calculation (for Volume)                   |
//+------------------------------------------------------------------+
void CalculateSMA(const int rates_total, const int begin, const int period,
                  const long &volume[], double &sma_buffer[])
{
    if(period <= 0) return;
    int limit = MathMax(period, begin);

    for(int i = limit; i < rates_total; i++)
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
//| Tanh Normalization Helper                                        |
//+------------------------------------------------------------------+
double NormalizeTanh(double value, double std_dev)
{
    if(std_dev == 0.0 || !MathIsValidNumber(value) || !MathIsValidNumber(std_dev)) return 0.0;

    double sensitivity = MathMax(0.1, InpNormSensitivity); // Prevent division by zero
    double normalized = 100.0 * MathTanh(value / (std_dev * sensitivity));

    return normalized;
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation of Buffer (Rolling Window)          |
//+------------------------------------------------------------------+
double GetStdDev(const double &buffer[], int index, int period)
{
    if(index < period) return 1.0;

    double sum = 0.0;
    double sum_sq = 0.0;
    int count = 0;

    for(int i = 0; i < period; i++)
    {
        double val = buffer[index - i];
        if(MathIsValidNumber(val))
        {
            sum += val;
            sum_sq += val * val;
            count++;
        }
    }

    if(count == 0) return 1.0;

    double mean = sum / count;
    double variance = (sum_sq / count) - (mean * mean);

    return (variance > 0) ? MathSqrt(variance) : 1.0;
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
    SetIndexBuffer(6, raw_macd_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, raw_signal_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, conviction_buffer, INDICATOR_CALCULATIONS);

    // Minimum required bars
    min_bars_required = MathMax(InpSlowDEMAPeriod, InpFastDEMAPeriod) + InpSignalPeriod + InpNormPeriod + 10;

    // Plot settings
    IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v1.7");
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);

    // Zero line & Fixed Levels
    if(InpShowZeroLine)
    {
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
        IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpZeroLineColor);
        IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, InpZeroLineStyle);
        IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, InpZeroLineWidth);
    }

    // Fixed Range for normalized view
    IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
    IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

    // Initialize handles
    if(InpUseWPR)
    {
        wpr_handle = iWPR(_Symbol, _Period, InpWprPeriod);
        if(wpr_handle == INVALID_HANDLE) return INIT_FAILED;
    }

    if(InpUseStochastic)
    {
        stoch_handle = iStochastic(_Symbol, _Period, InpStochKPeriod, InpStochDPeriod,
                                  InpStochSlowing, InpStochMethod, InpStochPrice);
        if(stoch_handle == INVALID_HANDLE) return INIT_FAILED;
    }

    if(InpUseATRFilter)
    {
        atr_handle = iATR(_Symbol, _Period, InpAtrPeriod);
        if(atr_handle == INVALID_HANDLE) return INIT_FAILED;
    }

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

    // ATR, Volume, WPR, Stoch Logic (Same as v1.6)
    if(InpUseATRFilter && atr_val[index] > 0)
    {
        double atr_factor = MathMin(2.0, InpATRMultiplier);
        conviction *= atr_factor;
        factors += 1.0;
    }

    if(InpUseVolumeFilter && vol_ma[index] > 0)
    {
        double volume_ratio = (double)tick_volume[index] / vol_ma[index];
        double volume_strength = MathMin(2.0, MathMax(InpVolumeMinThreshold,
                                volume_ratio * InpVolumeStrengthFactor));
        conviction *= volume_strength;
        factors += 1.0;
    }

    if(InpUseWPR)
    {
        double wpr_norm = (-wpr_val[index]) / 100.0;
        double wpr_conviction = 1.0;
        if(wpr_norm <= (InpWPROversold + 100.0) / 100.0) wpr_conviction = 1.5;
        else if(wpr_norm >= (InpWPROverbought + 100.0) / 100.0) wpr_conviction = 1.5;
        conviction *= wpr_conviction;
        factors += 1.0;
    }

    if(InpUseStochastic)
    {
        double stoch_conviction = 1.0;
        if(stoch_main[index] <= InpStochOversold) stoch_conviction = 1.5;
        else if(stoch_main[index] >= InpStochOverbought) stoch_conviction = 1.5;
        conviction *= stoch_conviction;
        factors += 1.0;
    }

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
    if(rates_total < min_bars_required) return 0;

    int start = (prev_calculated > 0) ? prev_calculated - 1 : min_bars_required;

    // Performance Optimization: Only resize/fill price data if needed
    double price_data[];
    if(start == min_bars_required) {
        ArrayResize(price_data, rates_total);
    } else {
        ArrayResize(price_data, rates_total);
    }

    // Fill Price Data
    for(int i = 0; i < rates_total; i++) {
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

    // 1. Calculate RAW MACD components (Points)
    CalculateDEMA(rates_total, 0, InpFastDEMAPeriod, price_data, fast_dema_buffer);
    CalculateDEMA(rates_total, 0, InpSlowDEMAPeriod, price_data, slow_dema_buffer);

    for(int i = start; i < rates_total; i++)
    {
        raw_macd_buffer[i] = fast_dema_buffer[i] - slow_dema_buffer[i];
    }

    // 2. Calculate RAW Signal Line (Points)
    CalculateDEMA(rates_total, InpSlowDEMAPeriod, InpSignalPeriod, raw_macd_buffer, raw_signal_buffer);

    // 3. Get Auxiliary Data
    double wpr_val[], stoch_main[], stoch_signal[], atr_val[], vol_ma[];
    if(InpUseWPR) CopyBuffer(wpr_handle, 0, 0, rates_total, wpr_val);
    if(InpUseStochastic) { CopyBuffer(stoch_handle, 0, 0, rates_total, stoch_main); CopyBuffer(stoch_handle, 1, 0, rates_total, stoch_signal); }
    if(InpUseATRFilter) CopyBuffer(atr_handle, 0, 0, rates_total, atr_val);
    if(InpUseVolumeFilter) { ArrayResize(vol_ma, rates_total); CalculateSMA(rates_total, start, InpVolumeMAPeriod, tick_volume, vol_ma); }

    // 4. Normalize and Visualize with PHASE ADVANCE
    for(int i = start; i < rates_total; i++)
    {
        if(i < min_bars_required) continue;

        // Calculate StdDev for Normalization
        double std_dev = GetStdDev(raw_macd_buffer, i, InpNormPeriod);

        // Phase Advance Logic:
        // Boosted = Value + (Velocity * PhaseAdvance)
        // Velocity = Value - PrevValue
        double velocity_macd = raw_macd_buffer[i] - raw_macd_buffer[i-1];
        double velocity_signal = raw_signal_buffer[i] - raw_signal_buffer[i-1];

        double boosted_macd = raw_macd_buffer[i] + (velocity_macd * InpPhaseAdvance);
        double boosted_signal = raw_signal_buffer[i] + (velocity_signal * InpPhaseAdvance);

        // Normalize the BOOSTED values
        MacdLineBuffer[i]   = NormalizeTanh(boosted_macd, std_dev);
        SignalLineBuffer[i] = NormalizeTanh(boosted_signal, std_dev);

        // Calculate Histogram
        double hist_raw = MacdLineBuffer[i] - SignalLineBuffer[i];

        // Apply Conviction
        conviction_buffer[i] = CalculateConviction(i, atr_val, wpr_val, stoch_main, vol_ma, tick_volume);

        if(InpShowAllValues || conviction_buffer[i] >= InpConvictionThreshold)
        {
            HistogramBuffer[i] = hist_raw * conviction_buffer[i];

            int lookback = MathMin(i + 1, InpGradientLookback);
            double max_val = HistogramBuffer[ArrayMaximum(HistogramBuffer, i - lookback + 1, lookback)];

            if(MathAbs(max_val) > 0)
            {
                double ratio = MathAbs(HistogramBuffer[i] / max_val);
                int color_idx = (int)MathRound(ratio * 4.0);
                ColorBuffer[i] = (HistogramBuffer[i] >= 0) ? MathMin(4, color_idx) : MathMin(4, color_idx) + 5;
            }
            else ColorBuffer[i] = 0;
        }
        else
        {
            // Ghost Mode
            HistogramBuffer[i] = hist_raw * 0.2;
            ColorBuffer[i] = 10;
        }
    }

    return rates_total;
}
