//+------------------------------------------------------------------+
//|                                 HybridMomentumIndicator_v1.9.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.9 (Optimized: Incremental DEMA & PrevCalculated)   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.9"

#property indicator_separate_window
#property indicator_buffers 15
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
input group              "=== DEMA Settings ==="
input int                InpFastDEMAPeriod     = 12;     // Gyors DEMA periódus
input int                InpSlowDEMAPeriod     = 26;     // Lassú DEMA periódus
input int                InpSignalPeriod       = 9;      // Jelzővonal EMA periódusa
input double             InpDemaGain           = 2.0;    // DEMA Erősítés (2.0=Standard, <2.0=Stabilabb)
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

//--- Calculation Buffers (Intermediates)
double      fast_dema_buffer[];
double      slow_dema_buffer[];
double      raw_macd_buffer[];
double      raw_signal_buffer[];
double      conviction_buffer[];

//--- Hidden State Buffers for Optimized DEMA (New in v1.9)
double      fast_ema1_buf[];
double      fast_ema2_buf[];
double      slow_ema1_buf[];
double      slow_ema2_buf[];
double      sig_ema1_buf[];
double      sig_ema2_buf[];

//--- Indicator Handles
int         wpr_handle = INVALID_HANDLE;
int         stoch_handle = INVALID_HANDLE;
int         atr_handle = INVALID_HANDLE;

//--- Global variables
int         min_bars_required;

//+------------------------------------------------------------------+
//| Generalized DEMA Incremental Calculation                         |
//+------------------------------------------------------------------+
void CalculateIncrementalDEMA(const int rates_total, const int start_pos, const int period,
                              const double gain, const double &src[],
                              double &dema_buf[], double &ema1_buf[], double &ema2_buf[])
{
    if(period <= 0) return;

    double alpha = 2.0 / (period + 1.0);

    // Safety check for start position
    int begin = start_pos;
    if(begin < 1) begin = 1;
    if(begin == 1) // Initialization
    {
       ema1_buf[0] = src[0];
       ema2_buf[0] = src[0];
       dema_buf[0] = src[0];
    }

    for(int i = begin; i < rates_total; i++)
    {
       double prev_ema1 = ema1_buf[i-1];
       double prev_ema2 = ema2_buf[i-1];

       double ema1 = alpha * src[i] + (1.0 - alpha) * prev_ema1;
       double ema2 = alpha * ema1 + (1.0 - alpha) * prev_ema2;

       ema1_buf[i] = ema1;
       ema2_buf[i] = ema2;
       dema_buf[i] = gain * ema1 - (gain - 1.0) * ema2;
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
    double sensitivity = MathMax(0.1, InpNormSensitivity);
    return 100.0 * MathTanh(value / (std_dev * sensitivity));
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double GetStdDev(const double &buffer[], int index, int period)
{
    if(index < period) return 1.0;

    // Quick calculation loop - for optimization, could use running variance
    // but 100 bars is cheap enough.
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
    // Visible Buffers
    SetIndexBuffer(0, HistogramBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
    SetIndexBuffer(2, MacdLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, SignalLineBuffer, INDICATOR_DATA);

    // Internal Calculation Buffers
    SetIndexBuffer(4, fast_dema_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, slow_dema_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, raw_macd_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, raw_signal_buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, conviction_buffer, INDICATOR_CALCULATIONS);

    // DEMA State Buffers (New for v1.9)
    SetIndexBuffer(9, fast_ema1_buf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(10, fast_ema2_buf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(11, slow_ema1_buf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(12, slow_ema2_buf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(13, sig_ema1_buf, INDICATOR_CALCULATIONS);
    SetIndexBuffer(14, sig_ema2_buf, INDICATOR_CALCULATIONS);

    min_bars_required = MathMax(InpSlowDEMAPeriod, InpFastDEMAPeriod) + InpSignalPeriod + InpNormPeriod + 10;

    IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Momentum v1.9");

    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars_required);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars_required);

    if(InpShowZeroLine)
    {
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
        IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpZeroLineColor);
        IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, InpZeroLineStyle);
        IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, InpZeroLineWidth);
    }

    IndicatorSetDouble(INDICATOR_MINIMUM, -110.0);
    IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

    // Initialize External Indicators
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

    // Optimization: Only calculate new bars + 1 overlap for safety
    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

    // --- Data Preparation ---
    // Note: To optimize further, we could avoid copying ALL price data every tick.
    // However, for code clarity and simplicity, local array usage is kept,
    // but the loop range is restricted.

    // Instead of copying entire buffer, we'll just access 'close[]' (or other) directly if possible
    // or fill a small local array. But CalculateIncrementalDEMA needs the source array.
    // For MQL5 optimized, we can pass the 'close' array directly if InpAppliedPrice=CLOSE.
    // If not, we must construct the price array.

    // Optimized Price Array Construction
    // Since we need history for DEMA, we can't just resize to (rates_total-start).
    // We need the full array or at least aligned indices.
    double price_data[];
    ArrayResize(price_data, rates_total);

    // Only update the necessary part of price_data?
    // No, because DEMA calculation expects full array access by index.
    // But we only need to Fill price_data from 'start' onwards if we persist it?
    // Indicators re-initialize non-buffer arrays every tick.
    // So we must fill price_data entirely OR assume the cost is negligible (copying double array is fast).
    // Let's fill it all for safety to avoid garbage in history.

    // Performance Note: Copying 100k doubles is ~0.1ms. Negligible.
    // However, for strict incremental correctness, we only need to update the NEW part.
    // BUT since 'price_data' is a local dynamic array that is re-created (or resized) every tick,
    // it contains garbage or zeros if not filled completely.
    // Indicators do NOT persist local array content between calls unless declared static or global.
    // So we MUST copy everything or use a static array.

    // To be safe and simple, we copy all. Optimization: Use 'close' directly if possible?
    // We cannot pass 'close' (const double[]) to a function expecting (double[]).
    // So Copy is necessary.

    if(InpAppliedPrice == PRICE_CLOSE)
    {
       ArrayCopy(price_data, close, 0, 0, rates_total);
    }
    else
    {
       // Optimization: Only loop through 'start' to 'rates_total' IF we could trust history.
       // But we can't trust local array history. So we loop all.
       // Parallel execution (OpenCL) would be overkill here.
       for(int i = 0; i < rates_total; i++) {
           switch(InpAppliedPrice) {
               case PRICE_OPEN:     price_data[i] = open[i]; break;
               case PRICE_HIGH:     price_data[i] = high[i]; break;
               case PRICE_LOW:      price_data[i] = low[i]; break;
               case PRICE_MEDIAN:   price_data[i] = (high[i] + low[i]) / 2.0; break;
               case PRICE_TYPICAL:  price_data[i] = (high[i] + low[i] + close[i]) / 3.0; break;
               case PRICE_WEIGHTED: price_data[i] = (high[i] + low[i] + 2*close[i]) / 4.0; break;
               default:             price_data[i] = close[i]; break;
           }
       }
    }

    // --- 1. Incremental DEMA Calculation ---
    // Fast DEMA
    CalculateIncrementalDEMA(rates_total, start, InpFastDEMAPeriod, InpDemaGain, price_data,
                            fast_dema_buffer, fast_ema1_buf, fast_ema2_buf);

    // Slow DEMA
    CalculateIncrementalDEMA(rates_total, start, InpSlowDEMAPeriod, InpDemaGain, price_data,
                            slow_dema_buffer, slow_ema1_buf, slow_ema2_buf);

    // Calc MACD
    for(int i = start; i < rates_total; i++)
    {
        raw_macd_buffer[i] = fast_dema_buffer[i] - slow_dema_buffer[i];
    }

    // --- 2. Signal Line (DEMA of MACD) ---
    CalculateIncrementalDEMA(rates_total, start, InpSignalPeriod, InpDemaGain, raw_macd_buffer,
                            raw_signal_buffer, sig_ema1_buf, sig_ema2_buf);

    // --- 3. Aux Data Fetching ---
    // Efficient CopyBuffer: only fetch what's needed?
    // CopyBuffer handles internals well, but we need aligned history for normalization lookback.
    // We fetch full data for simplicity or at least enough lookback.
    int amount = rates_total - start;
    // Normalization needs history. If start is recent, we still need past data for GetStdDev.
    // But GetStdDev accesses the *calculated* buffers (raw_macd_buffer), which are already populated.

    // However, Conviction needs external indicators (ATR, WPR).
    // We should ensure their buffers are up to date.
    double wpr_val[], stoch_main[], stoch_signal[], atr_val[], vol_ma[];

    if(InpUseWPR) CopyBuffer(wpr_handle, 0, start, amount, wpr_val); // Note: CopyBuffer index 0 is NEWEST? No, in OnCalculate arrays 0 is OLDEST.
    // WAIT! CopyBuffer defaults to AsSeries=false (0=Oldest) usually?
    // Standard CopyBuffer usage: start_pos=0 means "from beginning" or "from current"?
    // "start_pos: The index of the first element to copy."
    // If we use dynamic arrays, we need to map them correctly to the 'i' index.
    // EASIEST WAY: Use full copy for external indicators to match 'rates_total' indexing.
    // Optimization: Partial copy requires tricky offset math (buffer[i] becomes buffer[i-start]).
    // Let's stick to full copy for reliability, optimize later if profiling shows lag.
    if(InpUseWPR) CopyBuffer(wpr_handle, 0, 0, rates_total, wpr_val);
    if(InpUseStochastic) { CopyBuffer(stoch_handle, 0, 0, rates_total, stoch_main); }
    if(InpUseATRFilter) CopyBuffer(atr_handle, 0, 0, rates_total, atr_val);
    if(InpUseVolumeFilter) {
        ArrayResize(vol_ma, rates_total);
        CalculateSMA(rates_total, start, InpVolumeMAPeriod, tick_volume, vol_ma);
    }

    // --- 4. Main Loop: Normalization & Output ---
    for(int i = start; i < rates_total; i++)
    {
        if(i < min_bars_required) continue;

        double std_dev = GetStdDev(raw_macd_buffer, i, InpNormPeriod);

        double velocity_macd = raw_macd_buffer[i] - raw_macd_buffer[i-1];
        double velocity_signal = raw_signal_buffer[i] - raw_signal_buffer[i-1];

        double boosted_macd = raw_macd_buffer[i] + (velocity_macd * InpPhaseAdvance);
        double boosted_signal = raw_signal_buffer[i] + (velocity_signal * InpPhaseAdvance);

        MacdLineBuffer[i]   = NormalizeTanh(boosted_macd, std_dev);
        SignalLineBuffer[i] = NormalizeTanh(boosted_signal, std_dev);

        double hist_raw = MacdLineBuffer[i] - SignalLineBuffer[i];

        conviction_buffer[i] = CalculateConviction(i, atr_val, wpr_val, stoch_main, vol_ma, tick_volume);

        if(InpShowAllValues || conviction_buffer[i] >= InpConvictionThreshold)
        {
            HistogramBuffer[i] = hist_raw * conviction_buffer[i];

            // Color Logic
            int lookback = MathMin(i + 1, InpGradientLookback);
            // ArrayMaximum needs specific parameters.
            // If i is current index, we want max in [i-lookback+1 ... i]
            // ArrayMaximum(array, start_index, count)
            // Start index in simple array is i - lookback + 1.
            int start_idx = MathMax(0, i - lookback + 1);
            int count = i - start_idx + 1;

            // Optimization: Don't scan 100 bars every tick?
            // We can just compare with previous max? No, it's a rolling window.
            // ArrayMaximum is native and fast.
            int max_idx = ArrayMaximum(HistogramBuffer, start_idx, count);
            double max_val = HistogramBuffer[max_idx];

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
            HistogramBuffer[i] = hist_raw * 0.2; // Dimmed ghost bar
            ColorBuffer[i] = 10; // Gray
        }
    }

    return rates_total;
}
