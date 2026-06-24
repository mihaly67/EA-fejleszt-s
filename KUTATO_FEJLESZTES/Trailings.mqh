//+------------------------------------------------------------------+
//|                                                    Trailings.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.10"

//+------------------------------------------------------------------+
//| Изменения                                                        |
//+------------------------------------------------------------------+
/*
   1.10 - Добавлены типы тралов
          (virtual int Type(void) const { return(trail_type); } )
*/

//+------------------------------------------------------------------+
//| Включаемые файлы                                                 |
//+------------------------------------------------------------------+
#include <Object.mqh>

//+------------------------------------------------------------------+
//| Макроподстановки                                                 |
//+------------------------------------------------------------------+
#define  TRAILING_SIMPLE   0x8000                     // Простой трал
#define  TRAILING_IND      0x8001                     // Базовый трал по индикаторам
#define  TRAILING_PSAR     0x8002                     // Трал по Parabolic SAR
#define  TRAILING_AMA      0x8003                     // Трал по Adaptive Moving Average
#define  TRAILING_DEMA     0x8004                     // Трал по Double Exponential Moving Average
#define  TRAILING_FRAMA    0x8005                     // Трал по Fractal Adaptive Moving Average
#define  TRAILING_MA       0x8006                     // Трал по Moving Average
#define  TRAILING_TEMA     0x8007                     // Трал по Triple Exponential Moving Average
#define  TRAILING_VIDYA    0x8008                     // Трал по Variable Index Dynamic Average
#define  TRAILING_VALUE    0x8009                     // Трал по указанным уровням для длинных и коротких позиций

//+------------------------------------------------------------------+
//| Класс простого трала StopLoss позиций                            |
//+------------------------------------------------------------------+
class CSimpleTrailing : public CObject
  {
private:
//--- проверяет критерии модификации StopLoss позициии и возвращает флаг
   bool              CheckCriterion(ENUM_POSITION_TYPE pos_type, double pos_open, double pos_sl, double value_sl, MqlTick &tick);

//--- модифицирует StopLoss позиции по её тикету
   bool              ModifySL(const ulong ticket, const double stop_loss);

//--- возвращает размер StopLevel в пунктах
   int               StopLevel(void);

protected:
   string            m_symbol;                        // торговый символ
   long              m_magic;                         // идентификатор эксперта
   double            m_point;                         // Point символа
   int               m_digits;                        // Digits символа
   int               m_offset;                        // дистанция стопа от цены
   int               m_trail_start;                   // прибыль в пунктах для запуска трала
   uint              m_trail_step;                    // шаг трала
   uint              m_spread_mlt;                    // множитель спреда для возврата значения StopLevel
   bool              m_active;                        // флаг активности трала

//--- рассчитывает и возвращает уровень StopLoss выбранной позиции
   virtual double    GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick);

public:
//--- Тип трала
   virtual int       Type(void)                       const { return(TRAILING_SIMPLE);    }
//--- установка параметров трала
   void              SetSymbol(const string symbol)
                       {
                        this.m_symbol = (symbol==NULL || symbol=="" ? ::Symbol() : symbol);
                        this.m_point  =::SymbolInfoDouble(this.m_symbol, SYMBOL_POINT);
                        this.m_digits = (int)::SymbolInfoInteger(this.m_symbol, SYMBOL_DIGITS);
                       }
   void              SetMagicNumber(const long magic)       { this.m_magic = magic;       }
   void              SetStopLossOffset(const int offset)    { this.m_offset = offset;     }
   void              SetTrailingStart(const int start)      { this.m_trail_start = start; }
   void              SetTrailingStep(const uint step)       { this.m_trail_step = step;   }
   void              SetSpreadMultiplier(const uint value)  { this.m_spread_mlt = value;  }
   void              SetActive(const bool flag)             { this.m_active = flag;       }

//--- возврат параметров трала
   string            Symbol(void)                     const { return this.m_symbol;       }
   long              MagicNumber(void)                const { return this.m_magic;        }
   int               StopLossOffset(void)             const { return this.m_offset;       }
   int               TrailingStart(void)              const { return this.m_trail_start;  }
   uint              TrailingStep(void)               const { return this.m_trail_step;   }
   uint              SpreadMultiplier(void)           const { return this.m_spread_mlt;   }
   bool              IsActive(void)                   const { return this.m_active;       }

//--- запуск трала с отступом StopLoss от цены
   bool              Run(void);
   bool              Run(const ulong pos_ticket);

//--- конструкторы
                     CSimpleTrailing() : m_symbol(::Symbol()), m_point(::Point()), m_digits(::Digits()),
                                         m_magic(-1), m_trail_start(0), m_trail_step(0), m_offset(0), m_spread_mlt(2) {}
                     CSimpleTrailing(const string symbol, const long magic,
                                     const int trailing_start, const uint trailing_step, const int offset);
//--- деструктор
                    ~CSimpleTrailing() {}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CSimpleTrailing::CSimpleTrailing(const string symbol, const long magic,
                                 const int trail_start, const uint trail_step, const int offset) : m_spread_mlt(2)
  {
   this.SetSymbol(symbol);
   this.m_magic      = magic;
   this.m_trail_start= trail_start;
   this.m_trail_step = trail_step;
   this.m_offset     = offset;
  }
//+------------------------------------------------------------------+
//| Рассчитывает и возвращает уровень StopLoss выбранной позиции     |
//+------------------------------------------------------------------+
double CSimpleTrailing::GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick)
  {
//--- в зависимости от типа позиции рассчитываем и возвращаем уровень StopLoss
   switch(pos_type)
     {
      case POSITION_TYPE_BUY  :  return(tick.bid - this.m_offset * this.m_point);
      case POSITION_TYPE_SELL :  return(tick.ask + this.m_offset * this.m_point);
      default                 :  return 0;
     }
  }
//+------------------------------------------------------------------+
//|Проверяет критерии модификации StopLoss позициии и возвращает флаг|
//+------------------------------------------------------------------+
bool CSimpleTrailing::CheckCriterion(ENUM_POSITION_TYPE pos_type, double pos_open, double pos_sl, double value_sl, MqlTick &tick)
  {
//--- если стоп позиции и уровень стопа для модификации равны, или передан нулевой StopLoss - возвращаем false
   if(::NormalizeDouble(pos_sl - value_sl, this.m_digits) == 0 || value_sl==0)
      return false;

//--- переменные трала
   double trailing_step = this.m_trail_step * this.m_point;                      // переводим шаг трала в цену
   double stop_level    = this.StopLevel() * this.m_point;                       // переводим StopLevel символа в цену
   int    pos_profit_pt = 0;                                                     // прибыль позиции в пунктах

//--- в зависимости от типа позиции проверяем условия для модицикации StopLoss
   switch(pos_type)
     {
      //--- длинная позиция
      case POSITION_TYPE_BUY :
         pos_profit_pt = int((tick.bid - pos_open) / this.m_point);              // рассчитываем прибыль позиции в пунктах
         if(tick.bid - stop_level > value_sl                                     // если уровень StopLoss ниже цены с отложенным вниз от неё уровнем StopLevel (соблюдена дистанция по StopLevel)
            && pos_sl + trailing_step < value_sl                                 // если уровень StopLoss выше, чем шаг трала, отложенный вверх от текущего StopLoss позиции
            && (this.m_trail_start == 0 || pos_profit_pt > this.m_trail_start)   // если тралим при любой прибыли, или прибыль позиции в пунктах больше значения начала трейлинга - возвращаем true
           )
            return true;
         break;

      //--- короткая позиция
      case POSITION_TYPE_SELL :
         pos_profit_pt = int((pos_open - tick.ask) / this.m_point);              // рассчитываем прибыль позиции в пунктах
         if(tick.ask + stop_level < value_sl                                     // если уровень StopLoss выше цены с отложенным вверх от неё уровнем StopLevel (соблюдена дистанция по StopLevel)
            && (pos_sl - trailing_step > value_sl || pos_sl == 0)                // если уровень StopLoss ниже, чем шаг трала, отложенный вниз от текущего StopLoss позиции, или у позиции ещё не установлен StopLoss
            && (this.m_trail_start == 0 || pos_profit_pt > this.m_trail_start)   // если тралим при любой прибыли, или прибыль позиции в пунктах больше значения начала трейлинга - возвращаем true
           )
            return true;
         break;

      //--- по умолчанию вернём false
      default:
         break;
     }

//--- условия не подошли - возвращаем false
   return false;
  }
//+------------------------------------------------------------------+
//| Модифицирует StopLoss позиции по тикету                          |
//+------------------------------------------------------------------+
bool CSimpleTrailing::ModifySL(const ulong ticket, const double stop_loss)
  {
//--- если взведён флаг остановки эксперта - сообщаем об этом в журнал и возвращаем false
   if(::IsStopped())
     {
      Print("The Expert Advisor is stopped, trading is disabled");
      return false;
     }
//--- если позицию не удалось выбрать по тикету - сообщаем об этом в журнал и возвращаем false
   ::ResetLastError();
   if(!::PositionSelectByTicket(ticket))
     {
      ::PrintFormat("%s: Failed to select position by ticket number %I64u. Error %d", __FUNCTION__, ticket, ::GetLastError());
      return false;
     }

//--- объявляем структуры торгового запроса и результата запроса
   MqlTradeRequest   request= {};
   MqlTradeResult    result = {};

//--- заполняем структуру запроса
   request.action    = TRADE_ACTION_SLTP;
   request.symbol    = ::PositionGetString(POSITION_SYMBOL);
   request.magic     = ::PositionGetInteger(POSITION_MAGIC);
   request.tp        = ::PositionGetDouble(POSITION_TP);
   request.position  = ticket;
   request.sl        = ::NormalizeDouble(stop_loss, this.m_digits);

//--- если торговую операцию отправить не удалось - сообщаем об этом в журнал и возвращаем false
   if(!::OrderSend(request, result))
     {
      PrintFormat("%s: OrderSend() failed to modify position #%I64u. Error %d",__FUNCTION__, ticket, ::GetLastError());
      return false;
     }

//--- успешно отправлен запрос на изменение StopLoss позиции
   return true;
  }
//+------------------------------------------------------------------+
//| Возвращает размер StopLevel в пунктах                            |
//+------------------------------------------------------------------+
int CSimpleTrailing::StopLevel(void)
  {
   int spread     = (int)::SymbolInfoInteger(this.m_symbol, SYMBOL_SPREAD);
   int stop_level = (int)::SymbolInfoInteger(this.m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return int(stop_level == 0 ? spread * this.m_spread_mlt : stop_level);
  }
//+------------------------------------------------------------------+
//| Запускает простой трейлинг с отступом StopLoss от цены           |
//+------------------------------------------------------------------+
bool CSimpleTrailing::Run(void)
  {
//--- если отключен - уходим
   if(!this.m_active)
      return false;
//--- переменные трала
   bool res  = true; // результат модификации всех позиций

//--- проверка корректности данных по символу
   if(this.m_point==0)
     {
      //--- попробуем ещё раз получить данные
      ::ResetLastError();
      this.SetSymbol(this.m_symbol);
      if(this.m_point==0)
        {
         ::PrintFormat("%s: Correct data was not received for the %s symbol. Error %d",__FUNCTION__, this.m_symbol, ::GetLastError());
         return false;
        }
     }

//--- в цикле по общему количеству открытых позиций
   int total =::PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      //--- получаем тикет очередной позиции
      ulong  pos_ticket =::PositionGetTicket(i);
      if(pos_ticket == 0)
         continue;

      //--- получаем символ и магик позиции
      string pos_symbol = ::PositionGetString(POSITION_SYMBOL);
      long   pos_magic  = ::PositionGetInteger(POSITION_MAGIC);

      //--- если позиция не соответствует фильтру по символу и магику - уходим
      if((this.m_magic != -1 && pos_magic != this.m_magic) || (pos_symbol != this.m_symbol))
         continue;

      res &=this.Run(pos_ticket);
     }
//--- по окончании цикла возвращаем результат модификации каждой подходящей по фильтру "символ/магик" позиции
   return res;
  }
//+------------------------------------------------------------------+
//| Запускает простой трейлинг с отступом StopLoss от цены           |
//| с указанием тикета модифицируемой позиции                        |
//+------------------------------------------------------------------+
bool CSimpleTrailing::Run(const ulong pos_ticket)
  {
//--- если трейлинг отключен, или невалидный тикет - уходим
   if(!this.m_active || pos_ticket==0)
      return false;

//--- переменные трала
   MqlTick tick = {};   // структура цен

//--- проверка корректности данных по символу
   ::ResetLastError();
   if(this.m_point==0)
     {
      //--- попробуем ещё раз получить данные
      this.SetSymbol(this.m_symbol);
      if(this.m_point==0)
        {
         ::PrintFormat("%s: Correct data was not received for the %s symbol. Error %d",__FUNCTION__, this.m_symbol, ::GetLastError());
         return false;
        }
     }
//--- выбираем позицию по тикету
   if(!::PositionSelectByTicket(pos_ticket))
     {
      ::PrintFormat("%s: PositionSelectByTicket(%I64u) failed. Error %d",__FUNCTION__, pos_ticket, ::GetLastError());
      return false;
     }

//--- если цены получить не удалось - возвращаем false
   if(!::SymbolInfoTick(this.m_symbol, tick))
      return false;

//--- получаем тип позиции, цену её открытия и уровень StopLoss
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)::PositionGetInteger(POSITION_TYPE);
   double             pos_open =::PositionGetDouble(POSITION_PRICE_OPEN);
   double             pos_sl   =::PositionGetDouble(POSITION_SL);

//--- получаем рассчитанный уровень StopLoss
   double value_sl = this.GetStopLossValue(pos_type, tick);

   //--- если условия для модификации StopLoss подходят - возвращаем результат модифицикации стопа позиции
   if(this.CheckCriterion(pos_type, pos_open, pos_sl, value_sl, tick))
      return(this.ModifySL(pos_ticket, value_sl));
//--- условия для модификации не подходят
   return false;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Базовый класс тралов по индикаторам                              |
//+------------------------------------------------------------------+
class CTrailingByInd : public CSimpleTrailing
  {
protected:
   ENUM_TIMEFRAMES   m_timeframe;            // таймфрейм индикатора
   int               m_handle;               // хэндл индикатора
   uint              m_data_index;           // бар данных индикатора
   string            m_timeframe_descr;      // описание таймфрейма

//--- возвращает данные индикатора
   double            GetDataInd(void)              const { return this.GetDataInd(this.m_data_index); }

//--- рассчитывает и возвращает уровень StopLoss выбранной позиции
   virtual double    GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick);

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_IND);          }
//--- установка параметров
   void              SetTimeframe(const ENUM_TIMEFRAMES timeframe)
                       {
                        this.m_timeframe=(timeframe==PERIOD_CURRENT ? ::Period() : timeframe);
                        this.m_timeframe_descr=::StringSubstr(::EnumToString(this.m_timeframe), 7);
                       }
   void              SetDataIndex(const uint index)                  { this.m_data_index=index;       }

//--- возврат параметров
   ENUM_TIMEFRAMES   Timeframe(void)                           const { return this.m_timeframe;       }
   uint              DataIndex(void)                           const { return this.m_data_index;      }
   string            TimeframeDescription(void)                const { return this.m_timeframe_descr; }

//--- возвращает данные индикатора с указанного индекса таймсерии
   double            GetDataInd(const int index) const;

//--- конструкторы
                     CTrailingByInd(void) : CSimpleTrailing(::Symbol(), -1, 0, 0, 0), m_timeframe(::Period()),
                                            m_handle(INVALID_HANDLE), m_data_index(1), m_timeframe_descr(::StringSubstr(::EnumToString(::Period()), 7)) {}

                     CTrailingByInd(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic, const int trail_start, const uint trail_step, const int trail_offset) :
                                    CSimpleTrailing(symbol, magic, trail_start, trail_step, trail_offset), m_data_index(1), m_handle(INVALID_HANDLE)
                       {
                        this.SetTimeframe(timeframe);
                       }
//--- деструктор
                    ~CTrailingByInd(void)
                       {
                        if(this.m_handle!=INVALID_HANDLE)
                          {
                           ::IndicatorRelease(this.m_handle);
                           this.m_handle=INVALID_HANDLE;
                          }
                       }
  };
//+------------------------------------------------------------------+
//| Возвращает данные индикатора с указанного индекса таймсерии      |
//+------------------------------------------------------------------+
double CTrailingByInd::GetDataInd(const int index) const
  {
//--- если хендл невалидный - сообщаем об этом и возвращаем "пустое значение"
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("%s: Error. Invalid handle",__FUNCTION__);
      return EMPTY_VALUE;
     }
//--- получаем значение буфера индикатора по указанному индексу
   double array[1];
   ::ResetLastError();
   if(::CopyBuffer(this.m_handle, 0, index, 1, array)!=1)
     {
      ::PrintFormat("%s: CopyBuffer() failed. Error %d", __FUNCTION__, ::GetLastError());
      return EMPTY_VALUE;
     }
//--- возвращаем полученное значение
   return array[0];
  }
//+------------------------------------------------------------------+
//| Рассчитывает и возвращает уровень StopLoss выбранной позиции     |
//+------------------------------------------------------------------+
double CTrailingByInd::GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick)
  {
//--- получаем значение индикатора как уровень для StopLoss
   double data=this.GetDataInd();
//--- в зависимости от типа позиции рассчитываем и возвращаем уровень StopLoss
   switch(pos_type)
     {
      case POSITION_TYPE_BUY  :  return(data!=EMPTY_VALUE ? data - this.m_offset * this.m_point : tick.bid);
      case POSITION_TYPE_SELL :  return(data!=EMPTY_VALUE ? data + this.m_offset * this.m_point : tick.ask);
      default                 :  return 0;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Parabolic SAR                    |
//+------------------------------------------------------------------+
class CTrailingBySAR : public CTrailingByInd
  {
private:
   double            m_sar_step;             // параметр Step Parabolic SAR
   double            m_sar_max;              // параметр Maximum Parabolic SAR

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_PSAR);                           }
//--- установка параметров Parabolic SAR
   void              SetSARStep(const double step)                   { this.m_sar_step=(step<0.0001 ? 0.0001 : step);   }
   void              SetSARMaximum(const double max)                 { this.m_sar_max =(max <0.0001 ? 0.0001 : max);    }

//--- возврат параметров Parabolic SAR
   double            SARStep(void)                             const { return this.m_sar_step;                          }
   double            SARMaximum(void)                          const { return this.m_sar_max;                           }

//--- создаёт индикатор Parabolic SAR, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const double sar_step, const double sar_maximum);

//--- конструкторы
                     CTrailingBySAR() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 0.02, 0.2);
                       }

                     CTrailingBySAR(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                    const double sar_step, const double sar_maximum,
                                    const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingBySAR(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingBySAR::CTrailingBySAR(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                               const double sar_step, const double sar_maximum,
                               const int trail_start, const uint trail_step, const int trail_offset) :
                               CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, sar_step, sar_maximum);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор Parabolic SAR, возвращает результат            |
//+------------------------------------------------------------------+
bool CTrailingBySAR::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const double sar_step, const double sar_maximum)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetSARStep(sar_step);
   this.SetSARMaximum(sar_maximum);
   ::ResetLastError();
   this.m_handle=::iSAR(this.m_symbol, this.m_timeframe, this.m_sar_step, this.m_sar_max);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iSAR(%s, %s, %.3f, %.2f) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_sar_step, this.m_sar_max, ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Adaptive Moving Average          |
//+------------------------------------------------------------------+
class CTrailingByAMA : public CTrailingByInd
  {
private:
   int               m_period;               // параметр Period AMA
   int               m_fast_ema;             // параметр Fast EMA Period
   int               m_slow_ema;             // параметр Slow EMA Period
   int               m_shift;                // параметр Shift AMA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price AMA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_AMA);                         }
//--- установка параметров AMA
   void              SetPeriod(const uint period)                    { this.m_period=int(period<1 ? 9 : period);     }
   void              SetFastEMAPeriod(const uint period)             { this.m_fast_ema=int(period<1 ? 2 : period);   }
   void              SetSlowEMAPeriod(const uint period)             { this.m_slow_ema=int(period<1 ? 30 : period);  }
   void              SetShift(const int shift)                       { this.m_shift = shift;                         }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                         }

//--- возврат параметров AMA
   int               Period(void)                              const { return this.m_period;                         }
   int               FastEMAPeriod(void)                       const { return this.m_fast_ema;                       }
   int               SlowEMAPeriod(void)                       const { return this.m_slow_ema;                       }
   int               Shift(void)                               const { return this.m_shift;                          }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                          }

//--- создаёт индикатор AMA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe,
                                const int period, const int fast_ema, const int slow_ema, const int shift, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByAMA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 9, 2, 30, 0, PRICE_CLOSE);
                       }

                     CTrailingByAMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                    const int period, const int fast_ema, const int slow_ema, const int shift, const ENUM_APPLIED_PRICE price,
                                    const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByAMA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByAMA::CTrailingByAMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                               const int period, const int fast_ema, const int slow_ema, const int shift, const ENUM_APPLIED_PRICE price,
                               const int trail_start, const uint trail_step, const int trail_offset) :
                               CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period, fast_ema, slow_ema, shift, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор AMA, возвращает результат                      |
//+------------------------------------------------------------------+
bool CTrailingByAMA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe,
                                const int period, const int fast_ema, const int slow_ema, const int shift, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriod(period);
   this.SetFastEMAPeriod(fast_ema);
   this.SetSlowEMAPeriod(slow_ema);
   this.SetShift(shift);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iAMA(this.m_symbol, this.m_timeframe, this.m_period, this.m_fast_ema, this.m_slow_ema, this.m_shift, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iAMA(%s, %s, %d, %d, %d, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_period, this.m_fast_ema, this.m_slow_ema,
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Double Exponential Moving Average|
//+------------------------------------------------------------------+
class CTrailingByDEMA : public CTrailingByInd
  {
private:
   int               m_period;               // параметр Period DEMA
   int               m_shift;                // параметр Shift DEMA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price DEMA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_DEMA);                     }
//--- установка параметров DEMA
   void              SetPeriod(const uint period)                    { this.m_period=int(period<1 ? 14 : period); }
   void              SetShift(const int shift)                       { this.m_shift = shift;                      }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                      }

//--- возврат параметров DEMA
   int               Period(void)                              const { return this.m_period;                      }
   int               Shift(void)                               const { return this.m_shift;                       }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                       }

//--- создаёт индикатор DEMA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByDEMA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 14, 0, PRICE_CLOSE);
                       }

                     CTrailingByDEMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                     const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                     const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByDEMA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByDEMA::CTrailingByDEMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                 const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                 const int trail_start, const uint trail_step, const int trail_offset) :
                                 CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period, shift, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор DEMA, возвращает результат                     |
//+------------------------------------------------------------------+
bool CTrailingByDEMA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriod(period);
   this.SetShift(shift);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iDEMA(this.m_symbol, this.m_timeframe, this.m_period, this.m_shift, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iDEMA(%s, %s, %d, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_period,
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Fractal Adaptive Moving Average  |
//+------------------------------------------------------------------+
class CTrailingByFRAMA : public CTrailingByInd
  {
private:
   int               m_period;               // параметр Period FRAMA
   int               m_shift;                // параметр Shift DEMA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price FRAMA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_FRAMA);                    }
//--- установка параметров FRAMA
   void              SetPeriod(const uint period)                    { this.m_period=int(period<3 ? 14 : period); }
   void              SetShift(const int shift)                       { this.m_shift = shift;                      }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                      }

//--- возврат параметров FRAMA
   int               Period(void)                              const { return this.m_period;                      }
   int               Shift(void)                               const { return this.m_shift;                       }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                       }

//--- создаёт индикатор FRAMA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByFRAMA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 14, 0, PRICE_CLOSE);
                       }

                     CTrailingByFRAMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                      const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                      const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByFRAMA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByFRAMA::CTrailingByFRAMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                   const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                   const int trail_start, const uint trail_step, const int trail_offset) :
                                   CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period, shift, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор FRAMA, возвращает результат                    |
//+------------------------------------------------------------------+
bool CTrailingByFRAMA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriod(period);
   this.SetShift(shift);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iFrAMA(this.m_symbol, this.m_timeframe, this.m_period, this.m_shift, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iFrAMA(%s, %s, %d, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_period,
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Moving Average                   |
//+------------------------------------------------------------------+
class CTrailingByMA : public CTrailingByInd
  {
private:
   int               m_period;               // параметр Period MA
   int               m_shift;                // параметр Shift MA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price MA
   ENUM_MA_METHOD    m_method;               // параметр Method MA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_MA);                       }
//--- установка параметров MA
   void              SetPeriod(const uint period)                    { this.m_period=int(period<1 ? 10 : period); }
   void              SetShift(const int shift)                       { this.m_shift = shift;                      }
   void              SetMethod(const ENUM_MA_METHOD method)          { this.m_method=method;                      }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                      }

//--- возврат параметров MA
   int               Period(void)                              const { return this.m_period;                      }
   int               Shift(void)                               const { return this.m_shift;                       }
   ENUM_MA_METHOD    Method(void)                              const { return this.m_method;                      }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                       }

//--- создаёт индикатор MA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift,
                                const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByMA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 10, 0, MODE_SMA, PRICE_CLOSE);
                       }

                     CTrailingByMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                   const int period, const int shift, const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price,
                                   const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByMA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByMA::CTrailingByMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                             const int period, const int shift, const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price,
                             const int trail_start, const uint trail_step, const int trail_offset) :
                             CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period, shift, method, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор MA, возвращает результат                       |
//+------------------------------------------------------------------+
bool CTrailingByMA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift,
                               const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriod(period);
   this.SetShift(shift);
   this.SetMethod(method);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iMA(this.m_symbol, this.m_timeframe, this.m_period, this.m_shift, this.m_method, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iMA(%s, %s, %d, %s, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_period,
                    ::StringSubstr(::EnumToString(this.m_method),5),
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Triple Exponential Moving Average|
//+------------------------------------------------------------------+
class CTrailingByTEMA : public CTrailingByInd
  {
private:
   int               m_period;               // параметр Period TEMA
   int               m_shift;                // параметр Shift TEMA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price TEMA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_TEMA);                     }
//--- установка параметров TEMA
   void              SetPeriod(const uint period)                    { this.m_period=int(period<1 ? 14 : period); }
   void              SetShift(const int shift)                       { this.m_shift = shift;                      }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                      }

//--- возврат параметров TEMA
   int               Period(void)                              const { return this.m_period;                      }
   int               Shift(void)                               const { return this.m_shift;                       }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                       }

//--- создаёт индикатор TEMA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByTEMA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 14, 0, PRICE_CLOSE);
                       }

                     CTrailingByTEMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                     const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                     const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByTEMA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByTEMA::CTrailingByTEMA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                 const int period, const int shift, const ENUM_APPLIED_PRICE price,
                                 const int trail_start, const uint trail_step, const int trail_offset) :
                                 CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period, shift, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор TEMA, возвращает результат                     |
//+------------------------------------------------------------------+
bool CTrailingByTEMA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriod(period);
   this.SetShift(shift);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iTEMA(this.m_symbol, this.m_timeframe, this.m_period, this.m_shift, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iTEMA(%s, %s, %d, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_period,
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала StopLoss позиций по Variable Index Dynamyc Average   |
//+------------------------------------------------------------------+
class CTrailingByVIDYA : public CTrailingByInd
  {
private:
   int               m_cmo_period;           // параметр CMO Period VIDYA
   int               m_ema_period;           // параметр EMA Period VIDYA
   int               m_shift;                // параметр Shift VIDYA
   ENUM_APPLIED_PRICE m_price;               // параметр Applied Price VIDYA

public:
//--- Тип трала
   virtual int       Type(void)                                const { return(TRAILING_VIDYA);                       }
//--- установка параметров VIDYA
   void              SetPeriodCMO(const uint period)                 { this.m_cmo_period=int(period<1 ? 9 : period); }
   void              SetPeriodEMA(const uint period)                 { this.m_ema_period=int(period<1? 12 : period); }
   void              SetShift(const int shift)                       { this.m_shift = shift;                         }
   void              SetPrice(const ENUM_APPLIED_PRICE price)        { this.m_price = price;                         }

//--- возврат параметров VIDYA
   int               PeriodCMO(void)                           const { return this.m_cmo_period;                     }
   int               Shift(void)                               const { return this.m_shift;                          }
   ENUM_APPLIED_PRICE Price(void)                              const { return this.m_price;                          }

//--- создаёт индикатор VIDYA, возвращает результат
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe,
                                const int period_cmo, const int period_ema,
                                const int shift, const ENUM_APPLIED_PRICE price);

//--- конструкторы
                     CTrailingByVIDYA() : CTrailingByInd(::Symbol(), ::Period(), -1, 0, 0, 0)
                       {
                        this.Initialize(this.m_symbol, this.m_timeframe, 9, 12, 0, PRICE_CLOSE);
                       }

                     CTrailingByVIDYA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                      const int period_cmo, const int period_ema, const int shift, const ENUM_APPLIED_PRICE price,
                                      const int trail_start, const uint trail_step, const int trail_offset);
//--- деструктор
                    ~CTrailingByVIDYA(){}
  };
//+------------------------------------------------------------------+
//| Параметрический конструктор                                      |
//+------------------------------------------------------------------+
CTrailingByVIDYA::CTrailingByVIDYA(const string symbol, const ENUM_TIMEFRAMES timeframe, const long magic,
                                   const int period_cmo, const int period_ema, const int shift, const ENUM_APPLIED_PRICE price,
                                   const int trail_start, const uint trail_step, const int trail_offset) :
                                   CTrailingByInd(symbol, timeframe, magic, trail_start, trail_step, trail_offset)
  {
   this.Initialize(symbol, timeframe, period_cmo, period_ema, shift, price);
  }
//+------------------------------------------------------------------+
//| создаёт индикатор VIDYA, возвращает результат                    |
//+------------------------------------------------------------------+
bool CTrailingByVIDYA::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe,
                                  const int period_cmo, const int period_ema,
                                  const int shift, const ENUM_APPLIED_PRICE price)
  {
   this.SetSymbol(symbol);
   this.SetTimeframe(timeframe);
   this.SetPeriodCMO(period_cmo);
   this.SetPeriodEMA(period_ema);
   this.SetShift(shift);
   this.SetPrice(price);
   ::ResetLastError();
   this.m_handle=::iVIDyA(this.m_symbol, this.m_timeframe, this.m_cmo_period, this.m_ema_period, this.m_shift, this.m_price);
   if(this.m_handle==INVALID_HANDLE)
     {
      ::PrintFormat("Failed to create iVIDyA(%s, %s, %d, %d, %s) handle. Error %d",
                    this.m_symbol, this.TimeframeDescription(), this.m_cmo_period, this.m_ema_period,
                    ::StringSubstr(::EnumToString(this.m_price),6), ::GetLastError());
     }
   return(this.m_handle!=INVALID_HANDLE);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Класс трала по указанному значению                               |
//+------------------------------------------------------------------+
class CTrailingByValue : public CSimpleTrailing
  {
protected:
   double            m_value_sl_long;     // значение уровня StopLoss длинных позиций
   double            m_value_sl_short;    // значение уровня StopLoss коротких позиций

//--- рассчитывает и возвращает уровень StopLoss выбранной позиции
   virtual double    GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick);

public:
//--- Тип трала
   virtual int       Type(void)                 const { return(TRAILING_VALUE);        }
//--- возвращает уровень StopLoss (2) длинных, (2) коротких позиций
   double            StopLossValueLong(void)    const { return this.m_value_sl_long;   }
   double            StopLossValueShort(void)   const { return this.m_value_sl_short;  }

//--- запуск трала с указанным отступом StopLoss от цены
   bool              Run(const double value_sl_long, double value_sl_short);
   bool              Run(const ulong pos_ticket, const double value_sl_long, double value_sl_short);

//--- конструкторы
                     CTrailingByValue(void) : CSimpleTrailing(::Symbol(), -1, 0, 0, 0), m_value_sl_long(0), m_value_sl_short(0) {}

                     CTrailingByValue(const string symbol, const long magic, const int trail_start, const uint trail_step, const int trail_offset) :
                                      CSimpleTrailing(symbol, magic, trail_start, trail_step, trail_offset), m_value_sl_long(0), m_value_sl_short(0) {}
//--- деструктор
                    ~CTrailingByValue(void){}
  };
//+------------------------------------------------------------------+
//| Рассчитывает и возвращает уровень StopLoss выбранной позиции     |
//+------------------------------------------------------------------+
double CTrailingByValue::GetStopLossValue(ENUM_POSITION_TYPE pos_type, MqlTick &tick)
  {
//--- в зависимости от типа позиции рассчитываем и возвращаем уровень StopLoss
   switch(pos_type)
     {
      case POSITION_TYPE_BUY  :  return(this.m_value_sl_long  - this.m_offset * this.m_point);
      case POSITION_TYPE_SELL :  return(this.m_value_sl_short + this.m_offset * this.m_point);
      default                 :  return 0;
     }
  }
//+------------------------------------------------------------------+
//| Запуск трала с указанным отступом StopLoss от цены               |
//+------------------------------------------------------------------+
bool CTrailingByValue::Run(const double value_sl_long, double value_sl_short)
  {
   this.m_value_sl_long =value_sl_long;
   this.m_value_sl_short=value_sl_short;
   return CSimpleTrailing::Run();
  }
//+------------------------------------------------------------------+
//| Запуск трала с указанным отступом StopLoss от цены               |
//| с указанием тикета модифицируемой позиции                        |
//+------------------------------------------------------------------+
bool CTrailingByValue::Run(const ulong pos_ticket,const double value_sl_long,double value_sl_short)
  {
   this.m_value_sl_long =value_sl_long;
   this.m_value_sl_short=value_sl_short;
   return CSimpleTrailing::Run(pos_ticket);
  }
//+------------------------------------------------------------------+
