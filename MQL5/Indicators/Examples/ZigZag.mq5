//+------------------------------------------------------------------+
//|                                                       ZigZag.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
//--- plot ZigZag
#property indicator_label1  "ZigZag"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- input parameters
input int      InpDepth=12;     // Depth
input int      InpDeviation=5;  // Deviation
input int      InpBackstep=3;   // Backstep
//--- indicator buffers
double         ZigZagBuffer[];
double         HighBuffer[];
double         LowBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ZigZagBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,HighBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,LowBuffer,INDICATOR_CALCULATIONS);
//--- set empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
//---
   return(INIT_SUCCEEDED);
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
   int    i=0;
   int    limit=0,counter=0,i2=0;
   double extreme_search=0;
   double extreme_pr=0;
   int    extreme_pos=0;
   int    pos=rates_total-1;
   int    back=0;
   double last_high=0,last_low=0;
//---
   if(rates_total<InpDepth || InpBackstep>=InpDepth)
      return(0);
//---
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigZagBuffer,0.0);
      ArrayInitialize(HighBuffer,0.0);
      ArrayInitialize(LowBuffer,0.0);
      limit=InpDepth;
     }
   else
     {
      i=rates_total-prev_calculated-1;
      limit=rates_total-prev_calculated;
      if(prev_calculated>0)
        {
         limit+=InpDepth+InpBackstep;
         pos=rates_total-1;
         //--- search for the third extremum from the last uncompleted bar
         while(counter<3 && pos>=0)
           {
            if(pos<rates_total-1)
              {
               if(ZigZagBuffer[pos]!=0.0)
                  counter++;
               ZigZagBuffer[pos]=0.0;
              }
            pos--;
           }
         //---
         i=rates_total-pos-1;
         if(counter<3)
           {
            i=rates_total-InpDepth-1;
            ArrayInitialize(ZigZagBuffer,0.0);
            ArrayInitialize(HighBuffer,0.0);
            ArrayInitialize(LowBuffer,0.0);
            limit=InpDepth;
           }
        }
     }
//--- 1. searching for high and low
   if (rates_total-limit-1 < 0) limit = rates_total - 1; // Safety Check

   for(i=rates_total-limit-1; i<rates_total; i++)
     {
      if(i<InpDepth)
        {
         HighBuffer[i]=0.0;
         LowBuffer[i]=0.0;
         continue;
        }
      if(i >= rates_total) break; // Safety Check
      //---
      double max_val=high[ArrayMaximum(high,i-InpDepth+1,InpDepth)];
      double min_val=low[ArrayMinimum(low,i-InpDepth+1,InpDepth)];
      //---
      if(max_val==high[i])
         HighBuffer[i]=high[i];
      else
         HighBuffer[i]=0.0;
      //---
      if(min_val==low[i])
         LowBuffer[i]=low[i];
      else
         LowBuffer[i]=0.0;
     }
//--- 2. searching for main points
   if (rates_total-limit < 0) limit = rates_total; // Safety Check

   for(i=rates_total-limit; i<rates_total; i++)
     {
      if (i >= rates_total) break; // Safety Check
      //--- high
      if(HighBuffer[i]!=0.0)
        {
         if(last_low==0.0 && last_high==0.0)
           {
            last_high=HighBuffer[i];
            extreme_pos=i;
           }
         else
           {
            if(last_low!=0.0)
              {
               if(HighBuffer[i]-last_low>InpDeviation*_Point)
                 {
                  LowBuffer[extreme_pos]=last_low;
                  ZigZagBuffer[extreme_pos]=last_low;
                  extreme_pos=i;
                  last_low=0.0;
                  last_high=HighBuffer[i];
                 }
               else
                 {
                  if(last_low>LowBuffer[i] && LowBuffer[i]!=0.0)
                    {
                     LowBuffer[extreme_pos]=0.0;
                     ZigZagBuffer[extreme_pos]=0.0;
                     last_low=LowBuffer[i];
                     extreme_pos=i;
                    }
                 }
              }
            else
              {
               if(last_high<HighBuffer[i] && HighBuffer[i]!=0.0)
                 {
                  HighBuffer[extreme_pos]=0.0;
                  ZigZagBuffer[extreme_pos]=0.0;
                  last_high=HighBuffer[i];
                  extreme_pos=i;
                 }
              }
           }
        }
      //--- low
      if(LowBuffer[i]!=0.0)
        {
         if(last_low==0.0 && last_high==0.0)
           {
            last_low=LowBuffer[i];
            extreme_pos=i;
           }
         else
           {
            if(last_high!=0.0)
              {
               if(last_high-LowBuffer[i]>InpDeviation*_Point)
                 {
                  HighBuffer[extreme_pos]=last_high;
                  ZigZagBuffer[extreme_pos]=last_high;
                  extreme_pos=i;
                  last_high=0.0;
                  last_low=LowBuffer[i];
                 }
               else
                 {
                  if(last_high<HighBuffer[i] && HighBuffer[i]!=0.0)
                    {
                     HighBuffer[extreme_pos]=0.0;
                     ZigZagBuffer[extreme_pos]=0.0;
                     last_high=HighBuffer[i];
                     extreme_pos=i;
                    }
                 }
              }
            else
              {
               if(last_low>LowBuffer[i] && LowBuffer[i]!=0.0)
                 {
                  LowBuffer[extreme_pos]=0.0;
                  ZigZagBuffer[extreme_pos]=0.0;
                  last_low=LowBuffer[i];
                  extreme_pos=i;
                 }
              }
           }
        }
     }
//--- 3. final cutting
   if(limit<rates_total)
     {
      //--- search for the third extremum from the last uncompleted bar
      pos=rates_total-1;
      counter=0;
      while(counter<3 && pos>=0)
        {
         if(ZigZagBuffer[pos]!=0.0)
            counter++;
         pos--;
        }
      i2=pos;
      if(counter==3)
        {
         back=rates_total-i2-1;
         if(back>InpBackstep) // cutting
           {
            limit=rates_total-back+InpBackstep;
            for(i=rates_total-limit; i<rates_total; i++)
              {
               ZigZagBuffer[i]=0.0;
               HighBuffer[i]=0.0;
               LowBuffer[i]=0.0;
              }
           }
        }
     }
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
