. Trading Strategy Entry Point 2 >
   if(avi_SystemFlag==1)
     {
      //--- </7.7.1. Trading Strategy Entry Point 2 >
      //--- < 7.7.2. Buy Rules 2 >
      if(NormalizeDouble(avd_Close_1-avd_Average_1,m_symbol.Digits())>0)
         if(NormalizeDouble(m_symbol.Ask() -(avd_High_1+avd_QuoteSpread),m_symbol.Digits())>0)
            //--- </7.7.2. Buy Rules 2 >
            //--- < 7.7.3. Trading Strategy Interface Set for Buy 8 >
           {
            avd_Price   = NormalizeDouble(m_symbol.Ask()                              ,m_symbol.Digits());