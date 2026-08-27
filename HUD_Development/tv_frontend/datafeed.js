const socket = new WebSocket('ws://127.0.0.1:8765');
let realtimeUpdateCallback = null;
let currentBar = null;
let historicalData = []; // Will store our parsed historical data

socket.onmessage = function(event) {
    const message = JSON.parse(event.data);
    if (message.type === 'update' && realtimeUpdateCallback !== null) {
        const data = message.data;
        const raw_time = data.timestamp * 1000;
        const coeff = 60 * 1000;
        const rounded_time = Math.floor(raw_time / coeff) * coeff;
        const price = data.close;

        if (currentBar === null || currentBar.time !== rounded_time) {
            currentBar = {
                time: rounded_time,
                open: data.open || price,
                high: data.high || price,
                low: data.low || price,
                close: price,
            };
        } else {
            currentBar.high = Math.max(currentBar.high, price);
            currentBar.low = Math.min(currentBar.low, price);
            currentBar.close = price;
        }
        realtimeUpdateCallback(currentBar);
    }
};

const Datafeed = {
    onReady: (callback) => {
        setTimeout(() => callback({
            supports_marks: false,
            supports_timescale_marks: false,
            supports_time: true,
            supported_resolutions: ['1', '5', '15', '30', '60', 'D'],
        }));
    },
    searchSymbols: (userInput, exchange, symbolType, onResultReadyCallback) => {
        onResultReadyCallback([{
            symbol: 'Bitcoin', full_name: 'Bitcoin', description: 'BTC/USD', exchange: 'Merkava', type: 'crypto'
        }]);
    },
    resolveSymbol: (symbolName, onSymbolResolvedCallback, onResolveErrorCallback) => {
        onSymbolResolvedCallback({
            name: symbolName, full_name: symbolName, description: symbolName, type: 'crypto', session: '24x7',
            timezone: 'Etc/UTC', exchange: 'Merkava', minmov: 1, pricescale: 100000, has_intraday: true,
            has_no_volume: true, has_weekly_and_monthly: false, supported_resolutions: ['1', '5', '15', '30', '60', 'D'],
            volume_precision: 2, data_status: 'streaming',
        });
    },
    getBars: async (symbolInfo, resolution, periodParams, onHistoryCallback, onErrorCallback) => {
        try {
            // First time fetching history, we load the CSV via an API endpoint on our python server
            if (historicalData.length === 0) {
                 const response = await fetch('/api/history');
                 if (response.ok) {
                     historicalData = await response.json();
                 }
            }

            const { from, to, firstDataRequest } = periodParams;
            let bars = [];

            // Filter historicalData based on 'from' and 'to'
            for (let i = 0; i < historicalData.length; ++i) {
                if (historicalData[i].time >= from * 1000 && historicalData[i].time < to * 1000) {
                    bars.push(historicalData[i]);
                }
            }

            if (bars.length > 0) {
                // Initialize currentBar with the last historical bar if it's the first request
                if (firstDataRequest) {
                     currentBar = bars[bars.length - 1];
                }
                onHistoryCallback(bars, { noData: false });
            } else {
                onHistoryCallback([], { noData: true });
            }
        } catch (error) {
            console.error('[getBars]: Get error', error);
            onErrorCallback(error);
        }
    },
    subscribeBars: (symbolInfo, resolution, onRealtimeCallback, subscriberUID, onResetCacheNeededCallback) => {
        realtimeUpdateCallback = onRealtimeCallback;
    },
    unsubscribeBars: (subscriberUID) => {
        realtimeUpdateCallback = null;
    }
};