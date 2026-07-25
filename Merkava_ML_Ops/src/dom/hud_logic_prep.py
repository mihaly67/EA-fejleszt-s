def get_dynamic_features(df):
    ignore_cols = [
        'Start_Timestamp', 'End_Timestamp', 'Target_Label',
        'Open', 'High', 'Low', 'Close',
        'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value',
        '1m_Close', 'Dist_1m', '5m_Close', '15m_Close', '30m_Close',
        'Bar_Time_Seconds', 'OBI_Raw',
        'P_Short', 'P_Noise', 'P_Long', 'Signal'
    ]
    return [col for col in df.columns if col not in ignore_cols]
