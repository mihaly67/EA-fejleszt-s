ad)-avd_QuoteStops,m_symbol.Digits())>0)
                  avi_Command=ORDER_TYPE_SELL;
           }
      //--- </7.7.5. Trading Strategy Interface Set for Sell 8 >
      //--- < 7.7.6. Trading Strategy Exit Point 1 >
     } // if 7.7.1
//--- </7.7.6. Trading Strategy Exit Point 1 >
//--- </7.7. Trading Strategy Logic 33 >
//--- < 7.8. Trading Module 59 >
//--- < 7.8.1. Trading Module Entry Point 3 >
   if(avi_Command>WRONG_VALUE)
      if(IsTradeAllowed())
        {
         //--- </7.8.1. Trading Module Entry Point 3 >