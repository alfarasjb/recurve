#include "definition.mqh"
#include <MAIN/TradeOps.mqh>
// FIX THIS LATER
#include "profiles.mqh"
#include "features.mqh"


class CRecurveTrade : public CTradeOps {

   protected:
      
      // SYMBOL PROPERTIES 
      double         tick_value, trade_points, contract_size;
      int            digits; 
      
      // INTERVALS
      int            TRADE_INTERVALS[];//, TRADING_DAYS[];
      
   private:
   public: 
   
      // SYMBOL PROPERTIES WRAPPERS 
      double         TICK_VALUE()         { return tick_value; }
      double         TRADE_POINTS()       { return trade_points; }
      double         DIGITS()             { return digits; }
      double         CONTRACT()           { return contract_size; }
      
   
      // INITIALIZATION
      CRecurveTrade(); 
      ~CRecurveTrade(); 
  
      void           Init(); 
      void           InitializeFeatureParameters();
      void           InitializeSymbolProperties();
      void           InitializeIntervals();
      void           InitializeDays();
      void           InitializeConfiguration();
      
      void           LoadSettingsFromFile();
      void           LoadSettingsFromInput();
      void           LoadSymbolConfigFromFile();
      void           LoadSymbolConfigFromInput();
  
      void           GenerateInterval(int &intervals[]);
  
      // FEATURES 
      string         indicator_path(string indicator_name); 
      
      
      double         DAILY_VOLATILITY(int volatility_mode, int shift = 1); 
      double         STANDARD_SCORE(int shift = 1);
      double         SKEW(int shift = 1);
      double         BBANDS(int mode, int num_sd = 2, int shift = 1);
      double         BBANDS_SLOW(int mode, int num_sd = 2, int shift = 1);
      
      // FEATURE WRAPPER 
      double         DAY_VOL();
      double         DAY_PEAK_VOL();
      double         UPPER_BANDS();
      double         LOWER_BANDS();
      double         EXTREME_UPPER();
      double         EXTREME_LOWER();
      double         SLOW_UPPER();
      double         SLOW_LOWER();
      
      
      // LOGIC
      bool           ValidTradeWindow(); 
      bool           ValidDayVolatility(); 
      bool           ValidDayOfWeek();
      ENUM_SIGNAL    Signal(FeatureValues &features);
      bool           EndOfDay();
      bool           ValidInterval();
      bool           DayOfWeekInTradingDays();
      
      // OPERATIONS 
      int            Stage();
      int            SendOrder(TradeParams &PARAMS);
      TradeParams    ParamsLong(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer); 
      TradeParams    ParamsShort(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      TradeParams    SetTradeParameters(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      double         CalcLot(double sl_distance);
      double         SLFactor(double entry_price);
      int            SendMarketOrder(TradeParams &PARAMS);
      int            CloseOrder();
      double         CatastrophicSLFactor(double lot, double var);
      int            CloseOppositeTrade(ENUM_ORDER_TYPE order);
      int            CloseStackedTrade(ENUM_ORDER_TYPE order);
      double         CatastrophicLossVAR();
      double         ValueAtRisk();
      double         FloatingPL();
      bool           InFloatingLoss();
      FeatureValues  SetLatestFeatureValues();
      bool           PreviousDayValid(ENUM_DIRECTION direction);
      string         IntervalsAsString();
      string         DaysAsString();
      
      
      template <typename T>   string      ArrayAsString(T &data[]);
      template <typename T>   void        ClearArray(T &data[]);  
      template <typename T>   void        Append(T &data[], T item);
   
      // UTILITIES 
      int            logger(string message, string function, bool notify=false, bool debug=true);
      bool           notification(string message);
      int            error(string message);
}; 


CRecurveTrade::CRecurveTrade(void) {
/*
   SYMBOL(Symbol());
   MAGIC(InpMagic);
   InitializeFeatureParameters();
   InitializeSymbolProperties();
   InitializeIntervals();
   //InitializeDays();
   InitializeConfiguration();
*/
}

CRecurveTrade::~CRecurveTrade(void) {
   ClearArray(CONFIG.trading_days);
   ClearArray(TRADE_INTERVALS);
}

void           CRecurveTrade::Init(void) {
   SYMBOL(Symbol()); 
   MAGIC(InpMagic);
   InitializeFeatureParameters();
   InitializeSymbolProperties();
   InitializeIntervals();
   InitializeConfiguration(); 
}

void           CRecurveTrade::InitializeSymbolProperties(void) {

   tick_value     = UTIL_TICK_VAL(); 
   trade_points   = UTIL_TRADE_PTS(); 
   digits         = UTIL_SYMBOL_DIGITS();
   contract_size  = UTIL_SYMBOL_CONTRACT_SIZE();

}

template <typename T> 
void           CRecurveTrade::ClearArray(T &data[]) {
   ArrayFree(data);
   ArrayResize(data, 0); 
}

template <typename T> 
void           CRecurveTrade::Append(T &data[], T item) {
   int size =     ArraySize(data);
   ArrayResize(data, size + 1);
   data[size] = item; 
}


void           CRecurveTrade::LoadSymbolConfigFromFile(void) {
   CFeatureLoader *feature    = new CFeatureLoader(SYMBOLS_DIRECTORY, Symbol());
   bool loaded = feature.LoadFile(ParseSymbolConfig);
   int num_trading_days = ArraySize(SYMBOL_CONFIG.trade_days);
   
   if (num_trading_days == 0) {
      string message = StringFormat("No Config found for %s. Using inputs.", Symbol()); 
      error(message);
      logger(message, __FUNCTION__);
      LoadSymbolConfigFromInput();
      delete feature;
      return;
   }
   
   ArrayResize(CONFIG.trading_days, num_trading_days);
   ArrayCopy(CONFIG.trading_days, SYMBOL_CONFIG.trade_days); 
   
   CONFIG.low_volatility_thresh  = SYMBOL_CONFIG.low_volatility_threshold; 
   CONFIG.use_pd                 = (bool)SYMBOL_CONFIG.trade_use_pd; 
   
   delete feature; 
}

void           CRecurveTrade::LoadSymbolConfigFromInput(void) {
   InitializeDays();
   CONFIG.low_volatility_thresh  = InpLowVolThresh;
   CONFIG.use_pd                 = InpUsePrevDay;
}

void           CRecurveTrade::LoadSettingsFromFile(void) {

   CFeatureLoader *feature    = new CFeatureLoader(SETTINGS_DIRECTORY, "settings");
   bool load      = feature.LoadFile(Parse); 
   
   FEATURE_CONFIG.DAILY_VOLATILITY_WINDOW            = SETTINGS.day_vol_lookback;
   FEATURE_CONFIG.DAILY_VOLATILITY_PEAK_LOOKBACK     = SETTINGS.day_peak_lookback;
   FEATURE_CONFIG.NORMALIZED_SPREAD_LOOKBACK         = SETTINGS.norm_spread_lookback;
   FEATURE_CONFIG.NORMALIZED_SPREAD_MA_LOOKBACK      = SETTINGS.norm_spread_ma_lookback;
   FEATURE_CONFIG.SKEW_LOOKBACK                      = SETTINGS.skew_lookback;
   FEATURE_CONFIG.BBANDS_LOOKBACK                    = SETTINGS.bbands_lookback;
   FEATURE_CONFIG.BBANDS_NUM_SDEV                    = SETTINGS.bbands_num_sdev;
   FEATURE_CONFIG.BBANDS_SLOW_LOOKBACK               = SETTINGS.bbands_lookback;
   FEATURE_CONFIG.SPREAD_THRESHOLD                   = SETTINGS.spread_threshold;
   FEATURE_CONFIG.SKEW_THRESHOLD                     = SETTINGS.skew_threshold; 
   FEATURE_CONFIG.ENTRY_WINDOW_OPEN                  = SETTINGS.entry_window_open;
   FEATURE_CONFIG.ENTRY_WINDOW_CLOSE                 = SETTINGS.entry_window_close; 
   FEATURE_CONFIG.TRADE_DEADLINE                     = SETTINGS.trade_deadline;
   FEATURE_CONFIG.CATLOSS                            = SETTINGS.catloss;
   FEATURE_CONFIG.RPT                                = SETTINGS.rpt; 
   FEATURE_CONFIG.MIN_SL_DISTANCE                    = SETTINGS.min_sl_distance; 
   FEATURE_CONFIG.INDICATOR_PATH                     = SETTINGS.indicator_path;
   FEATURE_CONFIG.SKEW_FILENAME                      = SETTINGS.skew_filename;
   FEATURE_CONFIG.SPREAD_FILENAME                    = SETTINGS.spread_filename;
   FEATURE_CONFIG.SDEV_FILENAME                      = SETTINGS.sdev_filename; 
   delete feature;
}
/*
void           CRecurveTrade::LoadSettingsFromInput(void) {
   FEATURE_CONFIG.DAILY_VOLATILITY_WINDOW            = InpDayVolWindow;
   FEATURE_CONFIG.DAILY_VOLATILITY_PEAK_LOOKBACK     = InpDayPeakVolWindow;
   FEATURE_CONFIG.NORMALIZED_SPREAD_LOOKBACK         = InpNormSpreadWindow; 
   FEATURE_CONFIG.NORMALIZED_SPREAD_MA_LOOKBACK      = InpNormMAWindow;
   FEATURE_CONFIG.SKEW_LOOKBACK                      = InpSkewWindow;
   FEATURE_CONFIG.BBANDS_LOOKBACK                    = InpBBandsWindow;
   FEATURE_CONFIG.BBANDS_NUM_SDEV                    = InpBBandsNumSdev;
   FEATURE_CONFIG.BBANDS_SLOW_LOOKBACK               = InpBBandsSlowWindow;
   FEATURE_CONFIG.SPREAD_THRESHOLD                   = InpZThresh;
   FEATURE_CONFIG.SKEW_THRESHOLD                     = InpSkewThresh; 
   FEATURE_CONFIG.ENTRY_WINDOW_OPEN                  = InpEntryWindowOpen;
   FEATURE_CONFIG.ENTRY_WINDOW_CLOSE                 = InpEntryWindowClose; 
   FEATURE_CONFIG.TRADE_DEADLINE                     = InpTradeDeadline;
   FEATURE_CONFIG.CATLOSS                            = InpAcctMaxRiskPct;
   FEATURE_CONFIG.RPT                                = InpAcctTradeRiskPct;
   FEATURE_CONFIG.MIN_SL_DISTANCE                    = InpMinimumSLDistance; 
}
*/
void           CRecurveTrade::InitializeFeatureParameters(void) {
   LoadSettingsFromFile(); 
   /*
   switch (InpConfig) {
      case FILE:
         LoadSettingsFromFile();
         break;
      case INPUT:
         LoadSettingsFromInput();
         break;
   }*/
}




void           CRecurveTrade::InitializeConfiguration(void) {
   
   ClearArray(CONFIG.trading_days); 
   switch(InpConfig) {
      case FILE:
         logger("Loading Config from Settings.", __FUNCTION__);
         LoadSymbolConfigFromFile();
         break;
      case INPUT:  
         logger("Loading Config from inputs.", __FUNCTION__);
         InitializeDays();
         CONFIG.low_volatility_thresh  = InpLowVolThresh;
         CONFIG.use_pd = InpUsePrevDay;
         break; 
      
   }
   CONFIG.days_string      = DaysAsString();
   CONFIG.intervals_string = IntervalsAsString(); 
   
   logger(StringFormat("Num Trading Days: %i, Days: %s, Volatility: %f", ArraySize(CONFIG.trading_days), DaysAsString(), CONFIG.low_volatility_thresh), __FUNCTION__);
}

void           CRecurveTrade::InitializeDays(void) {
   
   string result[];
   int split = StringSplit(InpDaysString, ',', result);
   //for (int i = 0; i < split; i++) AddDay((int)result[i]);
   for (int i = 0; i < split; i++) Append(CONFIG.trading_days, (int)result[i]);
   int size = ArraySize(CONFIG.trading_days);
   logger(StringFormat("%i Trading Days Valid.", size), __FUNCTION__);
}

void           CRecurveTrade::InitializeIntervals(void) {
   
   ENUM_TIMEFRAMES   current_timeframe = Period();
   if (current_timeframe != InpRPTimeframe && InpRPTimeframe != PERIOD_CURRENT) {
      logger(StringFormat("Invalid Timeframe. Selected: %i, Target: %s", Period(), EnumToString(InpRPTimeframe)), __FUNCTION__);
      return;
   }
   
   int   intervals_quarter[4]    = {0, 15, 30, 45};
   int   intervals_half[2]       = {0, 30};
   int   intervals_full[1]       = {0}; 
   if (!InpUseFrequency)
      switch(current_timeframe) {
         case PERIOD_M15:     GenerateInterval(intervals_quarter); break;
         case PERIOD_M30:     GenerateInterval(intervals_half); break;
         case PERIOD_H1:      GenerateInterval(intervals_full); break;
      }
   else 
      switch(InpFrequency) {
         case FULL:           GenerateInterval(intervals_full); break;
         case HALF:           GenerateInterval(intervals_half); break;
         case QUARTER:        GenerateInterval(intervals_quarter); break;
      }
}

bool           CRecurveTrade::ValidInterval(void) {
   
   int minute  = TimeMinute(TimeCurrent());
   
   int size    = ArraySize(TRADE_INTERVALS);
   
   if (size == 0) {
      logger("Empty Interval. Returning True.", __FUNCTION__);
      return true;
   }
   
   for (int i = 0; i < size; i++) {
      int interval = TRADE_INTERVALS[i];
      if (minute == interval) return true;
   }
   return false;
}

void           CRecurveTrade::GenerateInterval(int &intervals[]) {
   int size    = ArraySize(intervals);
   ArrayResize(TRADE_INTERVALS, size);
   ArrayCopy(TRADE_INTERVALS, intervals);
}





template <typename T> 
string         CRecurveTrade::ArrayAsString(T &data[]) {
   
   int size = ArraySize(data);
   string array_string = "";
   for (int i = 0; i < size; i++) {
      if (i == 0) array_string = (string)data[i];
      else array_string = StringConcatenate(array_string, ",", (string)data[i]); 
   }
   return array_string; 
}

string         CRecurveTrade::IntervalsAsString(void) {
   return ArrayAsString(TRADE_INTERVALS);
}

string         CRecurveTrade::DaysAsString(void) {
   return ArrayAsString(CONFIG.trading_days);
}

double         CRecurveTrade::CatastrophicLossVAR(void) {

   double balance    = UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * FEATURE_CONFIG.CATLOSS / 100; 
   return var; 
}

double         CRecurveTrade::ValueAtRisk(void) {
   
   double balance    = UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * FEATURE_CONFIG.RPT / 100; 
   return var;

}

bool           CRecurveTrade::EndOfDay(void) {
   int hour = TimeHour(TimeCurrent());
   if (hour > FEATURE_CONFIG.ENTRY_WINDOW_CLOSE) return true;
   return false; 
   
}

double         CRecurveTrade::CalcLot(double sl_distance) {

   /*
   lot = (var * trade_point) / (sl_ticks * tick_value)
   */
   double var           = ValueAtRisk();
   double lot_size      = (var * TRADE_POINTS()) / (sl_distance * TICK_VALUE()); 
   
   double min_lot       = UTIL_SYMBOL_MINLOT();
   double max_lot       = UTIL_SYMBOL_MAXLOT(); 
   
   if (lot_size < min_lot) return min_lot;
   if (lot_size > max_lot) return max_lot;
   
   return lot_size; 

}

bool           CRecurveTrade::ValidDayVolatility(void) {

   double day_volatility      = DAY_VOL();
   double day_peak            = DAY_PEAK_VOL(); 
   //double minimum_volatility  = 0.00682; // NEED
   double minimum_volatility  = CONFIG.low_volatility_thresh;  
   
   if (day_volatility > day_peak) return false; 
   if (day_volatility < minimum_volatility) return false;
   // ADD LOW VOLATILITY WINDOW 
   // ADD HOLIDAY
   return true;

}

bool           CRecurveTrade::DayOfWeekInTradingDays(void) {
   int current_day_of_week    = DayOfWeek() - 1; 
   
   int size = ArraySize(CONFIG.trading_days);
   for (int i = 0; i < size; i++) {
      int day = CONFIG.trading_days[i];
      if (current_day_of_week == day) return true; 
   }
   return false; 
}

bool           CRecurveTrade::ValidDayOfWeek(void) { return DayOfWeekInTradingDays(); }

double         CRecurveTrade::SLFactor(double entry_price) {
   
   double volatility_factor      = (DAY_VOL() * 0.5) / TRADE_POINTS(); 
   double minimum_sl             = FEATURE_CONFIG.MIN_SL_DISTANCE;
   
   double sl_factor              = volatility_factor < minimum_sl ? volatility_factor * 4 * TRADE_POINTS() : volatility_factor * TRADE_POINTS(); 
   return sl_factor;
}

double         CRecurveTrade::CatastrophicSLFactor(double lot,double var) {

   // sl ticks = (var * trade_point) / (lot * tick value)
   
   double sl_ticks = (var * TRADE_POINTS()) / (lot * TICK_VALUE()); 
   return sl_ticks; 

}

TradeParams    CRecurveTrade::ParamsLong(ENUM_ORDER_SEND_METHOD method,TradeLayer &layer) {
   
   
   TradeParams    PARAMS;
   PARAMS.entry_price      = UTIL_PRICE_ASK();
   double virtual_sl       = PARAMS.entry_price - SLFactor(PARAMS.entry_price);
   PARAMS.volume           = CalcLot(MathAbs(PARAMS.entry_price - virtual_sl)) * layer.allocation; 
   
   PARAMS.sl_price         = PARAMS.entry_price - CatastrophicSLFactor(PARAMS.volume, CatastrophicLossVAR()); // CALCULATE VIRTUAL SL LATER
   PARAMS.tp_price         = 0; 
   
   PARAMS.order_type       = ORDER_TYPE_BUY; 
   PARAMS.layer            = layer; 
   
   return PARAMS; 

}

TradeParams    CRecurveTrade::ParamsShort(ENUM_ORDER_SEND_METHOD method,TradeLayer &layer) {
   
   TradeParams    PARAMS;
   PARAMS.entry_price      = UTIL_PRICE_BID();
   double virtual_sl       = PARAMS.entry_price + SLFactor(PARAMS.entry_price);
   PARAMS.volume           = CalcLot(MathAbs(PARAMS.entry_price - virtual_sl)) * layer.allocation; 
   
   PARAMS.sl_price         = PARAMS.entry_price + CatastrophicSLFactor(PARAMS.volume, CatastrophicLossVAR());
   PARAMS.tp_price         = 0;
   
   PARAMS.order_type       = ORDER_TYPE_SELL; 
   PARAMS.layer            = layer; 
   
   return PARAMS; 

}

int            CRecurveTrade::SendMarketOrder(TradeParams &PARAMS)  {

   if (!ValidTradeWindow()) { 
      logger("ORDER SEND FAILED. Trade window is closed.", __FUNCTION__);
      return 0;
   }
   
   if (!ValidInterval()) {
      string error_message = StringFormat("ORDER SEND FAILED. Invalid Interval. Current: %i", TimeMinute(TimeCurrent()));
      logger(error_message, __FUNCTION__); 
      error(error_message);
      return 0;
   }

   
   string   layer_identifier  = PARAMS.layer.layer == LAYER_PRIMARY ? "PRIMARY" : "SECONDARY";
   string   comment           = StringFormat("%s_%s", EA_ID, layer_identifier);
   
   int ticket     = OP_OrderOpen(Symbol(), (ENUM_ORDER_TYPE)PARAMS.order_type, PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, comment);
   
   if (ticket == -1) {
      string error_message = StringFormat("ORDER SEND FAILED. ERROR: %i. Vol: %f, Entry: %f, SL: %f, TP: %f", 
         GetLastError(), 
         PARAMS.volume, 
         PARAMS.entry_price, 
         PARAMS.sl_price, 
         PARAMS.tp_price);
         
      logger(error_message, __FUNCTION__, true);
      error(error_message);
      return -1; 
   }
   /*
   
   SetTradeWindow(TimeCurrent());
   
   ActivePosition    pos;
   pos.pos_open_datetime   =  TRADES_ACTIVE.trade_open_datetime;
   pos.pos_deadline        =  TRADES_ACTIVE.trade_close_datetime;
   pos.pos_ticket          =  ticket;
   pos.layer               =  PARAMS.layer;
   
   AppendActivePosition(pos, TRADES_ACTIVE.active_positions);
   
   switch(PARAMS.layer.layer) {
      case LAYER_PRIMARY:     AppendActivePosition(pos, TRADES_ACTIVE.primary_layers); break;
      case LAYER_SECONDARY:   AppendActivePosition(pos, TRADES_ACTIVE.secondary_layers); break;
      default: break;
   }
   
   logger(StringFormat("Updated active positions: %i, Ticket: %i", NumActivePositions(), pos.pos_ticket), __FUNCTION__);
   //AddOrderToday();
   */
   logger(StringFormat("Order Placed. Ticket: %i, Order Type: %s, Volume: %f, Entry Price: %f, SL Price: %f", 
      ticket,
      EnumToString((ENUM_ORDER_TYPE)PARAMS.order_type), 
      PARAMS.volume, 
      PARAMS.entry_price, 
      PARAMS.sl_price), __FUNCTION__);
      
   return ticket; 

}

int            CRecurveTrade::CloseOrder(void) {
   logger("Close All Orders.", __FUNCTION__);
   int num_positions    = PosTotal();
   
   for (int i = 0; i < num_positions; i ++) {
      int c = OP_OrdersCloseAll(); 
         
   }
   return 1;

}

double         CRecurveTrade::FloatingPL(void) {

   int num_trades = PosTotal(); 
   
   double floating_pl   = 0;
   int    trades_found  = 0;
   for (int i = 0; i < num_trades; i++) {
      int t = OP_OrderSelectByIndex(i);
      if (!OP_TradeMatch(i)) continue; 
      floating_pl += PosProfit();
      trades_found++;
   }
   if (trades_found > 0) logger(StringFormat("%i Open Positions Found for %s. Floating P/L: %f", 
      trades_found, 
      Symbol(), 
      floating_pl), __FUNCTION__);
   return floating_pl; 
}

bool        CRecurveTrade::InFloatingLoss(void) {
   double   floating_pl    = FloatingPL(); 
   if (floating_pl >= 0) return false; 
   logger(StringFormat("%s is in floating loss.", Symbol()), __FUNCTION__);
   return true; 
}

int            CRecurveTrade::CloseOppositeTrade(ENUM_ORDER_TYPE order) {
   
   int num_trades = PosTotal(); 
   
   int trades_to_close[];
   ClearArray(trades_to_close); 
   
   logger(StringFormat("Close Opposite Trade. Positions Open: %i, Orders to ignore: %s", 
      num_trades, 
      EnumToString(order)), __FUNCTION__);
      
   bool valid_interval  = ValidInterval();
   for (int i = 0; i < num_trades; i++) {
      int t = OP_OrderSelectByIndex(i);
      if (!OP_TradeMatch(i)) continue; 
      if (PosOrderType() == order) continue; 
      if (PosProfit() > 0 && !valid_interval) continue; // ignore orders in profit
      
      Append(trades_to_close, PosTicket());
             
   
   }
   
   int target_trades_to_close = ArraySize(trades_to_close);
   
   int closed_orders = OP_OrdersCloseBatch(trades_to_close);
   logger(StringFormat("Closed %i Opposite Trades.", closed_orders), __FUNCTION__);
   if (target_trades_to_close != closed_orders) {
      logger(StringFormat("Failed to close opposite trades. Target: %i, Closed: %i", target_trades_to_close, closed_orders), __FUNCTION__);
      Sleep(2500);
      CloseOppositeTrade(order); 
      
   }
   return closed_orders; 
}

int            CRecurveTrade::CloseStackedTrade(ENUM_ORDER_TYPE order) {

   int num_trades = PosTotal();
   
   int trades_to_close[];
   ClearArray(trades_to_close);
   logger(StringFormat("Close Stacked Trade. Positions Open: %i, Existing Position: %s", 
      num_trades, 
      EnumToString(order)), __FUNCTION__);
      
   bool valid_interval  = ValidInterval();
   for (int i = 0; i < num_trades; i++ ){ 
      int t = OP_OrderSelectByIndex(i);
      if (!OP_TradeMatch(i)) continue; 
      if (PosOrderType() != order) continue; 
      if (PosProfit() < 0 && !valid_interval) continue; // skip trades in profit 
      if (PosProfit() > 0 && valid_interval) continue;
      
      Append(trades_to_close, PosTicket());
      
   }
   int closed_orders = OP_OrdersCloseBatch(trades_to_close);
   logger(StringFormat("Closed %i Stacked Trades.", closed_orders), __FUNCTION__);
   return closed_orders;

}


int            CRecurveTrade::SendOrder(TradeParams &PARAMS) {
   // CLOSE ALL OPEN TRADES IF STACKING IS DISABLED
   // CLOSE OPPOSITE TRADES IF OPPOSITE SIGNAL    }
   logger(StringFormat("Sending Order. Order Type :%s", EnumToString((ENUM_ORDER_TYPE)PARAMS.order_type)), __FUNCTION__);
   if (TimeMinute(TimeCurrent()) != 0) {
      // Close Opposite Order
      //CloseOppositeTrade((ENUM_ORDER_TYPE)PARAMS.order_type);  
          
      //return 0; 
   }
   // Close Stack Order
   CloseOppositeTrade((ENUM_ORDER_TYPE)PARAMS.order_type);
   CloseStackedTrade((ENUM_ORDER_TYPE)PARAMS.order_type);
   //if (!InpRoundHourOnly)
   return SendMarketOrder(PARAMS);

}

int            CRecurveTrade::Stage() { 
   if (!ValidDayOfWeek()) return 0; 
   if (!ValidDayVolatility()) return 0; 
   
   
   
   FeatureValues  LatestFeatureValues     = SetLatestFeatureValues(); 
   
   ENUM_SIGNAL signal   = Signal(LatestFeatureValues);
   
   
   TradeLayer     LAYER;
   LAYER.layer          = LAYER_PRIMARY;
   LAYER.allocation     = 1.0;  
   
   if (signal != SIGNAL_NONE) {
      logger(StringFormat("Signal: %s", EnumToString(signal)), __FUNCTION__);
      PrintFormat("Skew: %f Spread: %f Daily Vol: %f Day Peak :%f", 
      FEATURE.skew_value, 
      FEATURE.standard_score_value,
      DAY_VOL(),
      DAY_PEAK_VOL()
      );
   
   }
   
   switch(signal) {
      //case 0:        return 0; 
      case TRADE_LONG: 
         logger("Send Order: Long", __FUNCTION__);       
         return SendOrder(ParamsLong(MODE_MARKET, LAYER)); // SEND LONG 
      case TRADE_SHORT:       
         logger("Send Order: Short", __FUNCTION__);
         return SendOrder(ParamsShort(MODE_MARKET, LAYER));  // SEND SHORT 
      case CUT_LONG:
         logger("Cut Long", __FUNCTION__);
         return CloseStackedTrade(ORDER_TYPE_BUY);
      case CUT_SHORT: 
         logger("Cut Short", __FUNCTION__);
         return CloseStackedTrade(ORDER_TYPE_SELL);
      default:       break;
      
   }
   return 0;
}

bool           CRecurveTrade::ValidTradeWindow(void) {

   int hour             = TimeHour(TimeCurrent()); 
   int minute           = TimeMinute(TimeCurrent()); 
   int ENTRY_HOUR       = FEATURE_CONFIG.ENTRY_WINDOW_OPEN; // convert to input 
   int EXIT_HOUR        = FEATURE_CONFIG.ENTRY_WINDOW_CLOSE; // convert to input 
   
   if ((minute != 0) && (InpRoundHourOnly)) return false; 
   if (hour < ENTRY_HOUR) return false ;
   if (hour > EXIT_HOUR) return false; 
   return true; 
   
}

bool           CRecurveTrade::PreviousDayValid(ENUM_DIRECTION direction) {
   
   if (!CONFIG.use_pd) return true; 
   
   switch(direction) {
      case LONG: 
         if (UTIL_CANDLE_LOW() > UTIL_PREVIOUS_DAY_LOW()) return true; 
         return false; 
      case SHORT:   
         if (UTIL_CANDLE_HIGH() < UTIL_PREVIOUS_DAY_HIGH()) return true;
         return false;
   }
   return false; 
   
}


ENUM_SIGNAL    CRecurveTrade::Signal(FeatureValues &features) {

   double spread_trigger      = FEATURE_CONFIG.SPREAD_THRESHOLD;
   double skew_trigger        = FEATURE_CONFIG.SKEW_THRESHOLD;
   
   
   if ((features.skew_value > skew_trigger) 
      && (features.standard_score_value > spread_trigger) 
      && (features.last_candle_high > features.upper_bands)
      && PreviousDayValid(SHORT)) return TRADE_SHORT;
   
   
   if ((features.skew_value < -skew_trigger) 
      && (features.standard_score_value <- spread_trigger)
      && (features.last_candle_low < features.lower_bands)
      && PreviousDayValid(LONG)) return TRADE_LONG;
   
   if (InFloatingLoss()) {
      if ((features.skew_value <= -skew_trigger || features.standard_score_value <= -spread_trigger) && (features.last_candle_close > features.slow_upper)) return CUT_SHORT; 
      if ((features.skew_value >= skew_trigger || features.standard_score_value >= spread_trigger) && (features.last_candle_close < features.slow_lower)) return CUT_LONG;
   }
   
   return SIGNAL_NONE;
   
}

FeatureValues  CRecurveTrade::SetLatestFeatureValues(void) {
   
   FEATURE.standard_score_value     = STANDARD_SCORE();
   FEATURE.skew_value               = SKEW();
   FEATURE.last_candle_high         = UTIL_CANDLE_HIGH(1);
   FEATURE.last_candle_low          = UTIL_CANDLE_LOW(1);
   FEATURE.last_candle_close        = UTIL_LAST_CANDLE_CLOSE();
   FEATURE.upper_bands              = UPPER_BANDS();
   FEATURE.lower_bands              = LOWER_BANDS();
   FEATURE.extreme_upper            = EXTREME_UPPER();
   FEATURE.extreme_lower            = EXTREME_LOWER();
   FEATURE.slow_upper               = SLOW_UPPER();
   FEATURE.slow_lower               = SLOW_LOWER(); 
   
   return FEATURE;

}

int            CRecurveTrade::logger(string message,string function,bool notify=false,bool debug=true) {
   if (!InpTerminalMsg && !debug) return -1;
   
   string mode    = debug ? "DEBUGGER" : "LOGGER";
   string func    = InpDebugLogging ? StringFormat(" - %s", function) : "";
   
   PrintFormat("%s %s: %s", mode, func, message);
   
   if (notify) notification(message);
   return 1;
}

bool           CRecurveTrade::notification(string message) {

   if (!InpPushNotifs) return false;
   if (IsTesting()) return false;
   
   bool n   = SendNotification(message);
   
   if (!n)  logger(StringFormat("Failed to send notification. Cose: %i", GetLastError()), __FUNCTION__);
   return n;

}

int            CRecurveTrade::error(string message) {
   
   Alert(message);
   return 1;
}



double         CRecurveTrade::DAILY_VOLATILITY( int volatility_mode, int shift = 1)    { 

   return iCustom(NULL, 
      PERIOD_D1, 
      indicator_path(FEATURE_CONFIG.SDEV_FILENAME), // path 
      FEATURE_CONFIG.DAILY_VOLATILITY_WINDOW,   // sdev window
      FEATURE_CONFIG.DAILY_VOLATILITY_PEAK_LOOKBACK,   // max window
      0,    // shift
      volatility_mode,    // buffer
      shift     // shift
      ); 
      
}


double         CRecurveTrade::STANDARD_SCORE(int shift=1) {
   return iCustom(NULL,
      InpRPTimeframe, 
      indicator_path(FEATURE_CONFIG.SPREAD_FILENAME),
      FEATURE_CONFIG.NORMALIZED_SPREAD_LOOKBACK,   // normalization window 
      FEATURE_CONFIG.NORMALIZED_SPREAD_MA_LOOKBACK,   // moving average window 
      0,    // shift
      0,    // buffer 
      shift     // shift
   );

}

double         CRecurveTrade::SKEW(int shift=1) {

   return iCustom(NULL,
      InpRPTimeframe,
      indicator_path(FEATURE_CONFIG.SKEW_FILENAME),
      FEATURE_CONFIG.SKEW_LOOKBACK,   // window
      0,    // shift
      0,    // buffer
      shift     // shift
   );
   
}

double         CRecurveTrade::BBANDS(int mode, int num_sd = 2, int shift =1) {
   return iBands(NULL,
      InpRPTimeframe,
      FEATURE_CONFIG.BBANDS_LOOKBACK,   // bbands period
      num_sd,    // num sdev 
      0,    // shift
      PRICE_CLOSE, // applied price 
      mode,
      shift    // shift
      );
}

double         CRecurveTrade::BBANDS_SLOW(int mode,int num_sd=2,int shift=1) {

   return iBands(NULL, 
      InpRPTimeframe,
      FEATURE_CONFIG.BBANDS_SLOW_LOOKBACK,
      num_sd,
      0,
      PRICE_CLOSE,
      mode,
      shift
      );

}

string         CRecurveTrade::indicator_path(string indicator_name)     { return StringFormat("%s%s", FEATURE_CONFIG.INDICATOR_PATH, indicator_name); }
double         CRecurveTrade::DAY_VOL(void)           { return DAILY_VOLATILITY(MODE_STD_DEV); }
double         CRecurveTrade::DAY_PEAK_VOL(void)      { return DAILY_VOLATILITY(MODE_ROLLING_MAX_STD_DEV); }
double         CRecurveTrade::UPPER_BANDS(void)       { return BBANDS(MODE_UPPER); }
double         CRecurveTrade::LOWER_BANDS(void)       { return BBANDS(MODE_LOWER); }
double         CRecurveTrade::EXTREME_UPPER(void)     { return BBANDS(MODE_UPPER, 3); }
double         CRecurveTrade::EXTREME_LOWER(void)     { return BBANDS(MODE_LOWER, 3); }
double         CRecurveTrade::SLOW_UPPER(void)        { return BBANDS_SLOW(MODE_UPPER, 3); }
double         CRecurveTrade::SLOW_LOWER(void)        { return BBANDS_SLOW(MODE_LOWER, 3); }


