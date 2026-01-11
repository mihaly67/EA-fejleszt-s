//|                                           ColorPsychological.mq5 |
//|                                                                  |
//|               Psychological Indicator (Ported from FXAccucharts) |
//|                                                      Version 1.0 |
//|                     Copyright © 2007, Bruce Hellstrom (brucehvn) |
//|                                              bhweb@speakeasy.net |
//|                                         http://www.metaquotes.ru |
//|  This indicator is ported from the FXAccuCharts platform to MT4. The formula   |
//|  used here has been tested on FXAccuCharts to insure it displays the same as   |
//|  their default psychological indicator.                                        |
//|                                                                                |
//| Input Parameters:                                                              || Input Parameters:                                                              |
//|  PsychPeriod - Lookback periods for the indicator (25 default)                 |
//|                                                                                |
//| Revision History                                                               |
//|    Version 1.0                                                                 |
//|    * Initial Revision                                                          |
#property link      "http: //www.metaquotes.net/"
//---- номер версии индикатора
#property version   "1.01"
//---- отрисовка индикатора в отдельном окне
#property indicator_separate_window
//---- количество индикаторных буферов
#property indicator_buffers 3
//---- использовано всего одно графическое построение
#property indicator_plots   1
//|  Параметры отрисовки индикатора              |
//---- отрисовка индикатора в виде многоцветной гистограммыator_plots   1
//|  Параметры отрисовки индикатора              |
//---- отрисовка индикатора в виде многоцветной гистограммы
#property indicator_type1   DRAW_COLOR_HISTOGRAM2
//---- в качестве цветов трехцветной гистограммы использованы
#property indicator_color1  clrLime,clrTeal,clrGray,clrPurple,clrMagenta
//---- гистограммы индикатора - непрерывная кривая
#property indicator_style1  STYLE_SOLID
//---- толщина линии индикатора равна 3
#property indicator_width1  3
//---- отображение метки сигнальной линии
#property indicator_label1  "Psychological"
//|  объявление констант                         |
#define RESET  0 // Константа для возврата терминалу команды на пересчёт индикатора
//|  объявление перечислений                     |
enum ENUM_APPLIED_PRICE_ //Тип константы
  {
   PRICE_CLOSE_ = 1,     //PRICE_CLOSE
   PRICE_OPEN_,          //PRICE_OPEN
   PRICE_HIGH_,          //PRICE_HIGH
   PRICE_LOW_,           //PRICE_LOWRICE_OPEN_,          //PRICE_OPEN
   PRICE_HIGH_,          //PRICE_HIGH
   PRICE_LOW_,           //PRICE_LOW
   PRICE_MEDIAN_,        //PRICE_MEDIAN
   PRICE_TYPICAL_,       //PRICE_TYPICAL
   PRICE_WEIGHTED_,      //PRICE_WEIGHTED
   PRICE_SIMPL_,         //PRICE_SIMPL_
   PRICE_QUARTER_,       //PRICE_QUARTER_
   PRICE_TRENDFOLLOW0_,  //PRICE_TRENDFOLLOW0_
   PRICE_TRENDFOLLOW1_,  // TrendFollow_2 Price
   PRICE_DEMARK_         // Demark Price
  };
//| Входные параметры индикатора                 |
input uint PsychPeriod=25;
input ENUM_APPLIED_PRICE_ IPC=PRICE_CLOSE_;       // ценовая константа
input int Shift=0;                                // сдвиг индикатора по горизонтали в барах
input uint HighLevel=60;                          // уровень перекупленности
input uint MidlleLevel=50;                        // уровень перекупленности
input uint LowLevel=40;                           // уровень перепроданностивень перекупленности
input uint LowLevel=40;                           // уровень перепроданности
input uint NumberofBar=1;//Номер бара для подачи сигнала
input bool SoundON=true; //Разрешение алерта
input uint NumberofAlerts=2;//Количество алертов
input bool EMailON=false; //Разрешение почтовой отправки сигнала
input bool PushON=false; //Разрешение отправки сигнала на мобильный
//---- объявление динамического массива, который будет в
// дальнейшем использован в качестве индикаторного буфера
double ExtUpLineBuffer[],ExtDnLineBuffer[],ColorExtLineBuffer[];
//---- Объявление целых переменных начала отсчёта данных
int min_rates_total;
//| Custom indicator initialization function                         |
void OnInit()
  {
//---- Инициализация переменных начала отсчёта данных
   min_rates_total=int(PsychPeriod)+1;
//---- превращение динамического массива в индикаторный буфер
   SetIndexBuffer(0,ExtUpLineBuffer,INDICATOR_DATA);вращение динамического массива в индикаторный буфер
   SetIndexBuffer(0,ExtUpLineBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtDnLineBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorExtLineBuffer,INDICATOR_COLOR_INDEX);
//---- инициализации переменной для короткого имени индикатора
   string shortname;
   StringConcatenate(shortname,"Psychological(",PsychPeriod," ",Shift,")");
//---- осуществление сдвига индикатора 1 по горизонтали на ATRShift
   PlotIndexSetInteger(0,PLOT_SHIFT,Shift);
//---- создание метки для отображения в Окне данных
   PlotIndexSetString(0,PLOT_LABEL,shortname);
//---- создание имени для отображения в отдельном подокне и во всплывающей подсказке
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//---- запрет на отрисовку индикатором пустых значений
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---- индексация элементов в буферах как в таймсериях
   ArraySetAsSeries(ExtUpLineBuffer,true);UE);
//---- индексация элементов в буферах как в таймсериях
   ArraySetAsSeries(ExtUpLineBuffer,true);
   ArraySetAsSeries(ExtDnLineBuffer,true);
   ArraySetAsSeries(ColorExtLineBuffer,true);
//---- определение точности отображения значений индикатора
   IndicatorSetInteger(INDICATOR_DIGITS,0);
//---- количество  горизонтальных уровней индикатора 3
   IndicatorSetInteger(INDICATOR_LEVELS,3);
//---- значения горизонтальных уровней индикатора
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,HighLevel);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,1,MidlleLevel);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,2,LowLevel);
//---- в качестве цветов линий горизонтальных уровней использованы
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrMediumSeaGreen);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,1,clrGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,2,clrRed);
//---- в линии горизонтального уровня использован короткий штрих-пунктир  ger(INDICATOR_LEVELCOLOR,2,clrRed);
//---- в линии горизонтального уровня использован короткий штрих-пунктир
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DASHDOTDOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,1,STYLE_DASHDOTDOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,2,STYLE_DASHDOTDOT);
//----
  }
//| Custom indicator iteration function                              |
int OnCalculate(
                const int rates_total,    // количество истории в барах на текущем тике
                const int prev_calculated,// количество истории в барах на предыдущем тике
                const datetime &time[],
                const double &open[],
                const double& high[],     // ценовой массив максимумов цены для расчёта индикатора
                const double& low[],      // ценовой массив минимумов цены  для расчёта индикатора
                const double &close[],
                const long &tick_volume[],
                const long &volume[], для расчёта индикатора
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
//---- проверка количества баров на достаточность для расчёта
   if(rates_total<min_rates_total) return(RESET);
//---- объявления локальных переменных
   int limit,bar;
//---- расчёт стартового номера limit для цикла пересчёта баров
   if(prev_calculated>rates_total || prev_calculated<=0)// проверка на первый старт расчёта индикатора
     {
      limit=rates_total-min_rates_total-1; // стартовый номер для расчёта всех баров
     }
   else
     {
      limit=rates_total-prev_calculated; // стартовый номер для расчёта новых баров
     }
//--- индексация элементов в массивах как в таймсериях
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(close,true);
//---- основной цикл расчёта индикатораe);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(close,true);
//---- основной цикл расчёта индикатора
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      int Count=0;
      int endctr=bar+1+int(PsychPeriod);
      for(int jctr=bar+1; jctr<endctr; jctr++)
        {
         if(PriceSeries(IPC,jctr,open,low,high,close)>PriceSeries(IPC,jctr+1,open,low,high,close))
           {
            Count++;
           }
        }
      if(PriceSeries(IPC,bar,open,low,high,close)>PriceSeries(IPC,bar+1,open,low,high,close))
        {
         Count++;
        }
      if(PriceSeries(IPC,PsychPeriod,open,low,high,close)>PriceSeries(IPC,PsychPeriod+1,open,low,high,close))
        {
         Count--;
        }
      double dCount=Count;
      ExtUpLineBuffer[bar]=(dCount/PsychPeriod) *100.0;
      ExtDnLineBuffer[bar]=MidlleLevel;
     }
//---- Основной цикл раскраски индикатора
   for(bar=limit; bar>=0 && !IsStopped(); bar--)100.0;
      ExtDnLineBuffer[bar]=MidlleLevel;
     }
//---- Основной цикл раскраски индикатора
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      int clr=2;
      if(ExtUpLineBuffer[bar]>MidlleLevel)
        {
         if(ExtUpLineBuffer[bar]>HighLevel) clr=0;
         else clr=1;
        }
      if(ExtUpLineBuffer[bar]<MidlleLevel)
        {
         if(ExtUpLineBuffer[bar]<LowLevel) clr=4;
         else clr=3;
        }
      ColorExtLineBuffer[bar]=clr;
     }
//---
   string text="ColorPsychological";
   if(ColorExtLineBuffer[NumberofBar]==0)
     {
      if(ColorExtLineBuffer[NumberofBar+1]!=0) text=text+" Пробой зоны перекупленности! ";
      else  text=text+" Тренд в зоне перекупленности! ";
     }
   if(ColorExtLineBuffer[NumberofBar]==1)
     {
      if(ColorExtLineBuffer[NumberofBar+1]!=1 && ColorExtLineBuffer[NumberofBar+1]!=0) text=text+" Пробой средней линии индикатора! Начало Buy тренда ";]!=1 && ColorExtLineBuffer[NumberofBar+1]!=0) text=text+" Пробой средней линии индикатора! Начало Buy тренда ";
      else  text=text+" Продолжение Buy тренда вне зоны перекупленности! ";
     }
   if(ColorExtLineBuffer[NumberofBar]==4)
     {
      if(ColorExtLineBuffer[NumberofBar+1]!=4) text=text+" Пробой зоны перепроданности! ";
      else  text=text+" Тренд в зоне перепроданности! ";
     }
   if(ColorExtLineBuffer[NumberofBar]==3)
     {
      if(ColorExtLineBuffer[NumberofBar+1]!=3 && ColorExtLineBuffer[NumberofBar+1]!=4) text=text+" Пробой средней линии индикатора! Начало Sell тренда ";
      else  text=text+" Продолжение Sell тренда вне зоны перепроданности! ";
     }
   BuySignal(text,ColorExtLineBuffer,rates_total,prev_calculated,close,spread);
   SellSignal(text,ColorExtLineBuffer,rates_total,prev_calculated,close,spread);
//---
   return(rates_total);
  }
//| Получение значения ценовой таймсерии                             |e,spread);
//---
   return(rates_total);
  }
//| Получение значения ценовой таймсерии                             |
double PriceSeries
(
 uint applied_price,// Ценовая константа
 uint   bar,// Индекс сдвига относительно текущего бара на указанное количество периодов назад или вперёд).
 const double &Open[],
 const double &Low[],
 const double &High[],
 const double &Close[]
 )
//PriceSeries(applied_price, bar, open, low, high, close)
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
  {
//----
   switch(applied_price)
     {
      //---- Ценовые константы из перечисления ENUM_APPLIED_PRICE
      case  PRICE_CLOSE: return(Close[bar]);
      case  PRICE_OPEN: return(Open [bar]);
      case  PRICE_HIGH: return(High [bar]);
      case  PRICE_LOW: return(Low[bar]);
      case  PRICE_MEDIAN: return((High[bar]+Low[bar])/2.0);
      case  PRICE_TYPICAL: return((Close[bar]+High[bar]+Low[bar])/3.0);IAN: return((High[bar]+Low[bar])/2.0);
      case  PRICE_TYPICAL: return((Close[bar]+High[bar]+Low[bar])/3.0);
      case  PRICE_WEIGHTED: return((2*Close[bar]+High[bar]+Low[bar])/4.0);
      //----
      case  8: return((Open[bar] + Close[bar])/2.0);
      case  9: return((Open[bar] + Close[bar] + High[bar] + Low[bar])/4.0);
      //----
      case 10:
        {
         if(Close[bar]>Open[bar])return(High[bar]);
         else
           {
            if(Close[bar]<Open[bar])
               return(Low[bar]);
            else return(Close[bar]);
           }
        }
      //----
      case 11:
        {
         if(Close[bar]>Open[bar])return((High[bar]+Close[bar])/2.0);
         else
           {
            if(Close[bar]<Open[bar])
               return((Low[bar]+Close[bar])/2.0);
            else return(Close[bar]);
           }
         break;
        }
      //----             return((Low[bar]+Close[bar])/2.0);
            else return(Close[bar]);
           }
         break;
        }
      //----
      case 12:
        {
         double res=High[bar]+Low[bar]+Close[bar];
         if(Close[bar]<Open[bar]) res=(res+Low[bar])/2;
         if(Close[bar]>Open[bar]) res=(res+High[bar])/2;
         if(Close[bar]==Open[bar]) res=(res+Close[bar])/2;
         return(((res-Low[bar])+(res-High[bar]))/2);
        }
      //----
      default: return(Close[bar]);
     }
//----
//return(0);
  }
//| Buy signal function                                              |
void BuySignal(string SignalSirname,      // текст имени индикатора для почтовых и пуш-сигналов
               double &BuyArrow[],        // индикаторный буфер с сигналами для покупки
               const int Rates_total,     // текущее количество баров
               const int Prev_calculated, // количество баров на предыдущем тикетекущее количество баров
               const int Prev_calculated, // количество баров на предыдущем тике
               const double &Close[],     // цена закрытия
               const int &Spread[])       // спред
  {
//---
   static uint counter=0;
   if(Rates_total!=Prev_calculated) counter=0;
   bool BuySignal=false;
   bool SeriesTest=ArrayGetAsSeries(BuyArrow);
   int index;
   if(SeriesTest) index=int(NumberofBar);
   else index=Rates_total-int(NumberofBar)-1;
   if(BuyArrow[index]==0 || BuyArrow[index]==1) BuySignal=true;
   if(BuySignal && counter<=NumberofAlerts)
     {
      counter++;
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(),tm);
      string text=TimeToString(TimeCurrent(),TIME_DATE)+" "+string(tm.hour)+":"+string(tm.min);
      SeriesTest=ArrayGetAsSeries(Close);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      double Ask=Close[index];
      double Bid=Close[index];=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      double Ask=Close[index];
      double Bid=Close[index];
      SeriesTest=ArrayGetAsSeries(Spread);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      Bid+=Spread[index]*_Point;
      string sAsk=DoubleToString(Ask,_Digits);
      string sBid=DoubleToString(Bid,_Digits);
      string sPeriod=GetStringTimeframe(ChartPeriod());
      if(SoundON) Alert("BUY signal \n Ask=",Ask,"\n Bid=",Bid,"\n currtime=",text,"\n Symbol=",Symbol()," Period=",sPeriod);
      if(EMailON) SendMail(SignalSirname+": BUY signal alert","BUY signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
      if(PushON) SendNotification(SignalSirname+": BUY signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
     }
//---
  }
//| Sell signal function                                             |t+" Symbol="+Symbol()+" Period="+sPeriod);
     }
//---
  }
//| Sell signal function                                             |
void SellSignal(string SignalSirname,      // текст имени индикатора для почтовых и пуш-сигналов
                double &SellArrow[],       // индикаторный буфер с сигналами для покупки
                const int Rates_total,     // текущее количество баров
                const int Prev_calculated, // количество баров на предыдущем тике
                const double &Close[],     // цена закрытия
                const int &Spread[])       // спред
  {
//---
   static uint counter=0;
   if(Rates_total!=Prev_calculated) counter=0;
   bool SellSignal=false;
   bool SeriesTest=ArrayGetAsSeries(SellArrow);
   int index;
   if(SeriesTest) index=int(NumberofBar);
   else index=Rates_total-int(NumberofBar)-1;
   if(SellArrow[index]==3 || SellArrow[index]==4) SellSignal=true;
   if(SellSignal && counter<=NumberofAlerts)
     {ofBar)-1;
   if(SellArrow[index]==3 || SellArrow[index]==4) SellSignal=true;
   if(SellSignal && counter<=NumberofAlerts)
     {
      counter++;
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(),tm);
      string text=TimeToString(TimeCurrent(),TIME_DATE)+" "+string(tm.hour)+":"+string(tm.min);
      SeriesTest=ArrayGetAsSeries(Close);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      double Ask=Close[index];
      double Bid=Close[index];
      SeriesTest=ArrayGetAsSeries(Spread);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      Bid+=Spread[index]*_Point;
      string sAsk=DoubleToString(Ask,_Digits);
      string sBid=DoubleToString(Bid,_Digits);
      string sPeriod=GetStringTimeframe(ChartPeriod());
      if(SoundON) Alert("SELL signal \n Ask=",Ask,"\n Bid=",Bid,"\n currtime=",text,"\n Symbol=",Symbol()," Period=",sPeriod);oundON) Alert("SELL signal \n Ask=",Ask,"\n Bid=",Bid,"\n currtime=",text,"\n Symbol=",Symbol()," Period=",sPeriod);
      if(EMailON) SendMail(SignalSirname+": SELL signal alert","SELL signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
      if(PushON) SendNotification(SignalSirname+": SELL signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
     }
//---
  }
//|  Получение таймфрейма в виде строки                              |
string GetStringTimeframe(ENUM_TIMEFRAMES timeframe)
  {
//----
   return(StringSubstr(EnumToString(timeframe),7,-1));
//----
  }
