#include "definition.mqh"
#include <MAIN/TradeOps.mqh>

// FIX THIS LATER



class CRecurveTrade : public CTradeOps {

   protected:
      int            DAILY_VOLATILITY_WINDOW, DAILY_VOLATILITY_PEAK_LOOKBACK, NORMALIZED_SPREAD_LOOKBACK, NORMALIZED_SPREAD_MA_LOOKBACK, SKEW_LOOKBACK, BBANDS_LOOKBACK, BBANDS_NUM_SDEV; 
      
      // SYMBOL PROPERTIES 
      double         tick_value, trade_points, contract_size;
      int            digits; 
      
      // INTERVALS
      int            TRADE_INTERVALS[];
      
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
  
      void           InitializeFeatureParameters();
      void           InitializeSymbolProperties();
      void           InitializeIntervals();
  
      void           GenerateInterval(int &intervals[]);
  
      // FEATURES 
      string         indicator_path(string indicator_name); 
      
      
      double         DAILY_VOLATILITY(int volatility_mode, int shift = 1); 
      double         STANDARD_SCORE(int shift = 1);
      double         SKEW(int shift = 1);
      double         BBANDS(int mode, int shift = 1);
      
      // FEATURE WRAPPER 
      double         DAY_VOL();
      double         DAY_PEAK_VOL();
      double         UPPER_BANDS();
      double         LOWER_BANDS();
      
      
      // LOGIC
      bool           ValidTradeWindow(); 
      bool           ValidDayVolatility(); 
      bool           ValidDayOfWeek();
      int            Signal();
      bool           EndOfDay();
      bool           ValidInterval();
      
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

      // UTILITIES 
      int            logger(string message, string function, bool notify=false, bool debug=true);
      bool           notification(string message);
}; 


CRecurveTrade::CRecurveTrade(void) {
   SYMBOL(Symbol());
   MAGIC(InpMagic);
   InitializeFeatureParameters();
   InitializeSymbolProperties();

}

CRecurveTrade::~CRecurveTrade(void) {}

void           CRecurveTrade::InitializeSymbolProperties(void) {

   tick_value     = UTIL_TICK_VAL(); 
   trade_points   = UTIL_TRADE_PTS(); 
   digits         = UTIL_SYMBOL_DIGITS();
   contract_size  = UTIL_SYMBOL_CONTRACT_SIZE();

}


void           CRecurveTrade::InitializeIntervals(void) {

   ENUM_TIMEFRAMES   current_timeframe = Period();
   if (current_timeframe != InpRPTimeframe) {
      logger("Invalid Timeframe", __FUNCTION__);
      return;
   }
   
   int   intervals_quarter[4]    = {0, 15, 30, 45};
   int   intervals_half[2]       = {0, 30};
   int   intervals_full[1]       = {0}; 
   switch(current_timeframe) {
      case PERIOD_M15:     GenerateInterval(intervals_quarter);
      case PERIOD_M30:     GenerateInterval(intervals_half);
      case PERIOD_H1:      GenerateInterval(intervals_full);
   }
}

bool           CRecurveTrade::ValidInterval(void) {
   
   int minute  = TimeMinute(TimeCurrent());
   
   int size    = ArraySize(TRADE_INTERVALS);
   
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

double         CRecurveTrade::CatastrophicLossVAR(void) {

   double balance    = UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * InpAcctMaxRiskPct / 100; 
   return var; 
}

double         CRecurveTrade::ValueAtRisk(void) {
   
   double balance    = UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * InpAcctTradeRiskPct / 100; 
   return var;

}

bool           CRecurveTrade::EndOfDay(void) {
   int hour = TimeHour(TimeCurrent());
   if (hour > InpEntryWindowClose) return true;
   return false; 
   
}

double         CRecurveTrade::CalcLot(double sl_distance) {

   /*
   lot = (var * trade_point) / (sl_ticks * tick_value)
   */
   double var = ValueAtRisk();
   double lot_size = (var * TRADE_POINTS()) / (sl_distance * TICK_VALUE()); 
   
   return NormalizeDouble(lot_size, 2); 

}

bool           CRecurveTrade::ValidDayVolatility(void) {

   double day_volatility      = DAY_VOL();
   double day_peak            = DAY_PEAK_VOL(); 
   //double minimum_volatility  = 0.00682; // NEED
   double minimum_volatility  = InpLowVolThresh;  
   
   if (day_volatility > day_peak) return false; 
   if (day_volatility < minimum_volatility) return false;
   // ADD LOW VOLATILITY WINDOW 
   // ADD HOLIDAY
   return true;

}

bool           CRecurveTrade::ValidDayOfWeek(void) {
      
   int current_day_of_week    = DayOfWeek();
   
   
   switch(current_day_of_week) {
      case 1:  return InpMonday;
      case 2:  return InpTuesday;
      case 3:  return InpWednesday;
      case 4:  return InpThursday;
      case 5:  return InpFriday;
   }
   return false; 
}

double         CRecurveTrade::SLFactor(double entry_price) {
   
   double volatility_factor      = (DAY_VOL() * 0.5) / TRADE_POINTS(); 
   double minimum_sl             = InpMinimumSLDistance;
   
   double sl_factor              = volatility_factor < minimum_sl ? volatility_factor * 4 * TRADE_POINTS() : volatility_factor * TRADE_POINTS(); 
   return sl_factor;
}

double         CRecurveTrade::CatastrophicSLFactor(double lot,double var) {
   // WRONG CALCULATION
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
      logger("ORDER SEND FAILED. Invalid Trade Window", __FUNCTION__);
      return 0;
   }
   
   if (!ValidInterval()) {
      logger(StringFormat("ORDER SEND FAILED. Invalid Interval. Current: %i", TimeMinute(TimeCurrent())), __FUNCTION__); 
      return 0;
   }

   
   string   layer_identifier  = PARAMS.layer.layer == LAYER_PRIMARY ? "PRIMARY" : "SECONDARY";
   string   comment           = StringFormat("%s_%s", EA_ID, layer_identifier);
   
   int ticket     = OP_OrderOpen(Symbol(), (ENUM_ORDER_TYPE)PARAMS.order_type, PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, comment);
   
   if (ticket == -1) {
      logger(StringFormat("ORDER SEND FAILED. ERROR: %i. Vol: %f, Entry: %f, SL: %f, TP: %f", GetLastError(), PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price), __FUNCTION__, true);
      Alert("ORDER SEND FAILED.");
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

int            CRecurveTrade::CloseOppositeTrade(ENUM_ORDER_TYPE order) {
   
   int num_trades = PosTotal(); 
   
   int trades_to_close[];
   
   logger(StringFormat("Close Opposite Trade. Positions Open: %i, Orders to ignore: %s", num_trades, EnumToString(order)), __FUNCTION__);
   for (int i = 0; i < num_trades; i++) {
      int t = OP_OrderSelectByIndex(i);
      if (!OP_TradeMatch(i)) continue; 
      if (PosOrderType() == order) continue; 
      
      int size = ArraySize(trades_to_close); 
      ArrayResize(trades_to_close, size + 1);
      trades_to_close[size] = PosTicket();            
   
   }
   
   int closed_orders = OP_OrdersCloseBatch(trades_to_close);
   logger(StringFormat("Closed %i Opposite Trades.", closed_orders), __FUNCTION__);
   return closed_orders; 
}

int            CRecurveTrade::CloseStackedTrade(ENUM_ORDER_TYPE order) {

   int num_trades = PosTotal();
   
   int trades_to_close[];
   
   logger(StringFormat("Close Stacked Trade. Positions Open: %i, Existing Position: %s", num_trades, EnumToString(order)), __FUNCTION__);
   for (int i = 0; i < num_trades; i++ ){ 
      int t = OP_OrderSelectByIndex(i);
      if (!OP_TradeMatch(i)) continue; 
      if (PosOrderType() != order) continue; 
      
      int size = ArraySize(trades_to_close);
      ArrayResize(trades_to_close, size + 1);
      trades_to_close[size] = PosTicket();
   }
   int closed_orders = OP_OrdersCloseBatch(trades_to_close);
   logger(StringFormat("Closed %i Opposite Trades.", closed_orders), __FUNCTION__);
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
   
   int signal     = Signal();
   
   logger(StringFormat("Signal: %i", signal), __FUNCTION__);
   TradeLayer     LAYER;
   LAYER.layer          = LAYER_PRIMARY;
   LAYER.allocation     = 1.0;  
   
   switch(signal) {
      case 0:        return 0; 
      case 1: 
         logger("Send Order: Long", __FUNCTION__);       
         return SendOrder(ParamsLong(MODE_MARKET, LAYER)); // SEND LONG 
      case -1:       
         logger("Send Order: Short", __FUNCTION__);
         return SendOrder(ParamsShort(MODE_MARKET, LAYER));  // SEND SHORT 
      default:       break;
      
   }
   return 0;
}

bool           CRecurveTrade::ValidTradeWindow(void) {

   int hour             = TimeHour(TimeCurrent()); 
   int minute           = TimeMinute(TimeCurrent()); 
   int ENTRY_HOUR       = InpEntryWindowOpen; // convert to input 
   int EXIT_HOUR        = InpEntryWindowClose; // convert to input 
   
   if ((minute != 0) && (InpRoundHourOnly)) return false; 
   if (hour < ENTRY_HOUR) return false ;
   if (hour > EXIT_HOUR) return false; 
   return true; 
   
}

int            CRecurveTrade::Signal() {
   double spread_trigger      = InpZThresh;
   double skew_trigger        = InpSkewThresh;
   
   double normalized_spread   = STANDARD_SCORE();
   double skew                = SKEW(); 
   
   double last_high           = UTIL_CANDLE_HIGH(1); 
   double last_low            = UTIL_CANDLE_LOW(1);
   
   double upper_bands         = UPPER_BANDS();
   double lower_bands         = LOWER_BANDS();
   PrintFormat("Skew: %f Spread: %f", skew, normalized_spread);
   if ((skew > skew_trigger) && (normalized_spread > spread_trigger) && (last_high > upper_bands)) return -1;
   if ((skew < -skew_trigger) && (normalized_spread <- spread_trigger) && (last_low < lower_bands)) return 1; 
   return 0;
   
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


void           CRecurveTrade::InitializeFeatureParameters(void) {
   DAILY_VOLATILITY_WINDOW            = InpDayVolWindow;
   DAILY_VOLATILITY_PEAK_LOOKBACK     = InpDayPeakVolWindow;
   NORMALIZED_SPREAD_LOOKBACK         = InpNormSpreadWindow; 
   NORMALIZED_SPREAD_MA_LOOKBACK      = InpNormMAWindow;
   SKEW_LOOKBACK                      = InpSkewWindow;
   BBANDS_LOOKBACK                    = InpBBandsWindow;
   BBANDS_NUM_SDEV                    = InpBBandsNumSdev;
}






double         CRecurveTrade::DAILY_VOLATILITY( int volatility_mode, int shift = 1)    { 

   return iCustom(NULL, 
      PERIOD_D1, 
      indicator_path(InpSdevFilename), // path 
      DAILY_VOLATILITY_WINDOW,   // sdev window
      DAILY_VOLATILITY_PEAK_LOOKBACK,   // max window
      0,    // shift
      volatility_mode,    // buffer
      shift     // shift
      ); 
      
}


double         CRecurveTrade::STANDARD_SCORE(int shift=1) {
   return iCustom(NULL,
      InpRPTimeframe, 
      indicator_path(InpSpreadFilename),
      NORMALIZED_SPREAD_LOOKBACK,   // normalization window 
      NORMALIZED_SPREAD_MA_LOOKBACK,   // moving average window 
      0,    // shift
      0,    // buffer 
      shift     // shift
   );

}

double         CRecurveTrade::SKEW(int shift=1) {

   return iCustom(NULL,
      InpRPTimeframe,
      indicator_path(InpSkewFilename),
      SKEW_LOOKBACK,   // window
      0,    // shift
      0,    // buffer
      shift     // shift
   );
   
}

double         CRecurveTrade::BBANDS(int mode, int shift =1) {
   return iBands(NULL,
      InpRPTimeframe,
      BBANDS_LOOKBACK,   // bbands period
      BBANDS_NUM_SDEV,    // num sdev 
      0,    // shift
      PRICE_CLOSE, // applied price 
      mode,
      shift    // shift
      );
}


string         CRecurveTrade::indicator_path(string indicator_name)     { return StringFormat("%s%s", InpIndicatorPath, indicator_name); }
double         CRecurveTrade::DAY_VOL(void)           { return DAILY_VOLATILITY(MODE_STD_DEV); }
double         CRecurveTrade::DAY_PEAK_VOL(void)      { return DAILY_VOLATILITY(MODE_ROLLING_MAX_STD_DEV); }
double         CRecurveTrade::UPPER_BANDS(void)       { return BBANDS(MODE_UPPER); }
double         CRecurveTrade::LOWER_BANDS(void)       { return BBANDS(MODE_LOWER); }



