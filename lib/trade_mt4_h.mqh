#include "trade_mt4.mqh"


void           CRecurveTrade::Init() {
   InitializeConfigurationPaths();
   InitializeAccounts(); 
   InitializeOpenPositions(); 
   SYMBOL(Symbol()); 
   MAGIC(InpMagic);
   InitializeFeatureParameters();
   InitializeSymbolProperties();
   InitializeIntervals();
   InitializeConfiguration(); 
   SetLatestFeatureValues(); 
   Stage();
}

void           CRecurveTrade::InitializeAccounts() {
   /*
   if (Accounts_ == NULL) Accounts_ = new CAccounts(); 
   Accounts_.Init(); 
   ACCOUNT_HIST.deposit             = Accounts_.AccountDeposit();
   ACCOUNT_HIST.pl_today            = Accounts_.AccountClosedPLToday(); 
   ACCOUNT_HIST.start_bal_today     = Accounts_.AccountStartBalToday();  
   ACCOUNT_HIST.gain_today          = Accounts_.AccountPctGainToday(); */
}

void           CRecurveTrade::OnEndOfDay() {
   /**
      Executes functions on end of day. 
      
      Resets Account data for the next trading day 
   **/
   //--- Clear Today
   //Accounts_.ClearToday(); 
   symbol_trades_today_    = 0; 
   Log.LogInformation(StringFormat("Reset. Symbol Trades Today: %i", symbol_trades_today_), __FUNCTION__);    
}


//void           CRecurveTrade::TrackAccounts() {   Accounts_.Track(); }

string         CRecurveTrade::PresetKey() {
   string preset_as_string = EnumToString(InpPreset); 
   string result[];
   
   int split   = StringSplit(preset_as_string, '_', result); 
   string target_string = "";
   for (int i = 1; i < split; i++) {
      string result_string = result[i];
      StringToLower(result_string); 
      if (target_string == "") target_string = result_string; 
      else target_string = StringConcatenate(target_string, "_", result_string); 
   }
   
   return target_string; 
   
}


void           CRecurveTrade::InitializeConfigurationPaths() {
   /**
      Sets local path to directory of configuration files in the MetaQuotes 
      common folder, selected based on preset configuration. 
      
      UPDATE: 
      SYMBOLS_PATH: recurve\\profiles\\<PRESET NAME>\\symbols\\
      SETTINGS_PATH: recurve\\profiles\\<PRESET NAME>\\settings.ini 
   **/
   string   key   = PresetKey(); 
   SYMBOLS_PATH_  = StringFormat("%s\\%s\\symbols\\", CONFIG_DIRECTORY, key); 
   SETTINGS_PATH_ = StringFormat("%s\\%s\\", CONFIG_DIRECTORY, key); 
   Log.LogInformation(StringFormat("Selected Preset: %s Symbols Path: %s, Settings Path: %s",
      EnumToString(InpPreset), 
      SYMBOLS_PATH_,
      SETTINGS_PATH_), __FUNCTION__); 
}

void           CRecurveTrade::InitializeSymbolProperties() {
   /**
      Sets symbol properties for trade parameter calculations. 
   **/
   tick_value_    = UTIL_TICK_VAL(); 
   trade_points_  = UTIL_TRADE_PTS(); 
   digits_        = UTIL_SYMBOL_DIGITS();
   contract_size_ = UTIL_SYMBOL_CONTRACT_SIZE();

}

void           CRecurveTrade::InitializeOpenPositions() {
   /**
      Initializes current open positions into an array. 
   **/
   int num_open_positions  = ALGO_POSITIONS_.Init(); 
   Log.LogInformation(StringFormat("Num Open Positions: %i", num_open_positions), __FUNCTION__); 
}
//+------------------------------------------------------------------+
//| ARRAY OPS                                                        |
//+------------------------------------------------------------------+


template <typename T> 
void           CRecurveTrade::ClearArray(T &data[]) {
   /**
      Generic function for clearing an array. 
   **/
   ArrayFree(data);
   ArrayResize(data, 0); 
}

template <typename T> 
void           CRecurveTrade::Append(T &data[], T item) {
   /**
      Generic function for appending to an array. 
   **/
   int size =     ArraySize(data);
   ArrayResize(data, size + 1);
   data[size] = item; 
}

template <typename T> 
bool           CRecurveTrade::ElementInArray(T element,T &src[]) {
   /**
      Generic function for checking if array contains element. 
   **/
   int size = ArraySize(src);
   for (int i = 0; i < size; i++) {
      T item   = src[i];
      if (element == item) return true; 
   }
   return false; 
}

template <typename T> 
string         CRecurveTrade::ArrayAsString(T &data[]) {
   /**
      Returns array as a string 
   **/
   int size = ArraySize(data);
   string array_string = "";
   for (int i = 0; i < size; i++) {
      if (i == 0) array_string = (string)data[i];
      else array_string = StringConcatenate(array_string, ",", (string)data[i]); 
   }
   return array_string; 
}

string         CRecurveTrade::IntervalsAsString()       { return INTERVALS_.ArrayAsString(); }
string         CRecurveTrade::DaysAsString()            { return CONFIG.TRADING_DAYS.ArrayAsString(); }


//+------------------------------------------------------------------+
//| INITIALIZATION AND CONFIG                                        |
//+------------------------------------------------------------------+

void           CRecurveTrade::LoadSymbolConfigFromFile() {
   
   /**
      Loads symbol configuration from MetaQuotes common folder. 
   **/   
   
   
   CFeatureLoader *feature    = new CFeatureLoader(SYMBOLS_PATH_, Symbol());
   bool loaded = feature.LoadFile(ParseSymbolConfig);
   int num_trading_days = ArraySize(SYMBOL_CONFIG.trade_days);
   
   //-- Returns Input configuration if config file is not found for attached symbol. 
   if (num_trading_days == 0) {
      Log.LogError(StringFormat("No Config found for %s. Using inputs.", Symbol()), __FUNCTION__); 
      LoadSymbolConfigFromInput();
      delete feature;
      return;
   }
   
   CONFIG.TRADING_DAYS.Create(SYMBOL_CONFIG.trade_days);
   CONFIG.low_volatility_thresh  = SYMBOL_CONFIG.low_volatility_threshold; 
   CONFIG.use_pd                 = (bool)SYMBOL_CONFIG.trade_use_pd; 
   CONFIG.sl                     = SYMBOL_CONFIG.sl; 
   CONFIG.secure                 = (bool)SYMBOL_CONFIG.trade_secure; 
   
   delete feature; 
}

void           CRecurveTrade::LoadSymbolConfigFromInput() {
   /**
      Loads symbol configuration from EA Inputs. 
   **/
   
   InitializeDays();
   CONFIG.low_volatility_thresh  = InpLowVolThresh;
   CONFIG.use_pd                 = InpUsePrevDay;
   CONFIG.sl                     = InpSL; 
}

void           CRecurveTrade::LoadSettingsFromFile() {
   /**
      Loads global settings and feature parameters from MetaQuotes common folder. 
   **/
   
   CFeatureLoader *feature    = new CFeatureLoader(SETTINGS_PATH_, "settings");
   bool load      = feature.LoadFile(Parse); 
   if (!load) {
      Log.LogInformation("Failed to load settings.", __FUNCTION__); 
      return; 
   }
   
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
   FEATURE_CONFIG.CATLOSS                            = SETTINGS.catloss * 100;         // PERCENT
   FEATURE_CONFIG.RPT                                = SETTINGS.rpt * 100;             // PERCENT
   FEATURE_CONFIG.MIN_SL_DISTANCE                    = SETTINGS.min_sl_distance; 
   FEATURE_CONFIG.INDICATOR_PATH                     = SETTINGS.indicator_path;
   FEATURE_CONFIG.SKEW_FILENAME                      = SETTINGS.skew_filename;
   FEATURE_CONFIG.SPREAD_FILENAME                    = SETTINGS.spread_filename;
   FEATURE_CONFIG.SDEV_FILENAME                      = SETTINGS.sdev_filename; 
   delete feature;
   
}

void           CRecurveTrade::InitializeFeatureParameters()         { LoadSettingsFromFile(); } 



void           CRecurveTrade::InitializeConfiguration() {
   /**
      Initializes global and symbol configuration based on input. 
      
      FILE:
         loads from common folder
      
      INPUT:
         loads from input
   **/
   
   CONFIG.TRADING_DAYS.Clear(); 
   
   //-- Loads config based on source: Input or File (Located in common folder)
   switch(InpConfig) {
      case FILE:
         Log.LogInformation("Loading Config from Settings.", __FUNCTION__);
         LoadSymbolConfigFromFile();
         break;
      case INPUT:  
         Log.LogInformation("Loading Config from inputs.", __FUNCTION__);
         InitializeDays();
         CONFIG.low_volatility_thresh  = InpLowVolThresh;
         CONFIG.use_pd = InpUsePrevDay;
         break; 
      
   }
   CONFIG.days_string      = DaysAsString();
   CONFIG.intervals_string = IntervalsAsString(); 
   
   Log.LogInformation(StringFormat("Num Trading Days: %i, Days: %s, Volatility: %f", 
      CONFIG.TRADING_DAYS.Size(), 
      DaysAsString(), 
      CONFIG.low_volatility_thresh), __FUNCTION__);
}

void           CRecurveTrade::InitializeDays() {
   
   /**
      Creates trading days array based on input days string. 
   **/
   string result[];
   int split = StringSplit(InpDaysString, ',', result);
   for (int i = 0; i < split; i++) {
      int day = (int)result[i]; 
      CONFIG.TRADING_DAYS.Append(day); 
   }
   int size = CONFIG.TRADING_DAYS.Size(); 
   Log.LogInformation(StringFormat("%i Trading Days Valid.", size), __FUNCTION__);
}

void           CRecurveTrade::InitializeIntervals() {
   
   /**
      Initializes interval based on input. 
   **/
   
   //-- Returns if selected timeframe does not match input timeframe. 
   ENUM_TIMEFRAMES   current_timeframe = Period();
   if (current_timeframe != InpRPTimeframe && InpRPTimeframe != PERIOD_CURRENT) {
      Log.LogInformation(StringFormat("Invalid Timeframe. Selected: %i, Target: %s", Period(), EnumToString(InpRPTimeframe)), __FUNCTION__);
      return;
   }
   
   //-- generating intervals if frequency is not used. 
   int   intervals_quarter[4]    = {0, 15, 30, 45};
   int   intervals_half[2]       = {0, 30};
   int   intervals_full[1]       = {0}; 
   
   //-- Generates interval if frequency is used. 
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


void           CRecurveTrade::GenerateInterval(int &intervals[]) {
   /**
      Copies specified interval into TRADE_INTERVALS array to be used later. 
   **/
   int itv=INTERVALS_.Create(intervals); 
}


CReports        *CRecurveTrade::GenerateReports() {
   CPool<int> *algo  = dynamic_cast<CPool<int>*>(&ALGO_POSITIONS_); 
   CReports *reports = new CReports(algo); 
   
   return reports; 
}



//+------------------------------------------------------------------+
//| TRADE OPS AND POSITION SIZING                                    |
//+------------------------------------------------------------------+


double         CRecurveTrade::CatastrophicLossVAR() {
   /**
      Calculates Catastrophic VAR in USD
   **/
   double balance    = InpUseFixedRisk ? InpFixedRisk : UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * FEATURE_CONFIG.CATLOSS / 100; 
   return var; 
}

double         CRecurveTrade::ValueAtRisk() {
   /**
      Calculates VAR in USD 
   **/
   double balance    = InpUseFixedRisk ? InpFixedRisk : UTIL_ACCOUNT_BALANCE(); 
   double var        = balance * FEATURE_CONFIG.RPT / 100; 
   return var;

}


double         CRecurveTrade::CalcLot(double sl_distance) {
   
   /**
      Calculates Lot Size
   **/
   
   
   double var           = ValueAtRisk();
   double lot_size      = (var * TRADE_POINTS()) / (sl_distance * TICK_VALUE()) * InpLotScaleFactor; 
   //-- Symbol max lot and min lot 
   double min_lot       = UTIL_SYMBOL_MINLOT();
   double max_lot       = UTIL_SYMBOL_MAXLOT(); 
   
   //PrintFormat("VAR: %f, Lot: %f, SL: %f, Scale: %f", var, lot_size, sl_distance, InpLotScaleFactor);
   //-- Returns min_lot if calculated lot is below instrument specification 
   if (lot_size < min_lot) return min_lot;
   
   //-- Returns max_lot if calculated lot is above instrument specification 
   if (lot_size > max_lot) return max_lot;
   
   //-- Returns input lot if calculated lot is above input lot
   if (lot_size > InpMaxLot) return InpMaxLot; 
   
   return lot_size; 

}

double         CRecurveTrade::SLFactor(double entry_price) {
   
   /**
      Calculates SL factor for calculating synthetic SL. 
   **/
   
   // -- Volatility Factor is used for calculating SL factor for virtual SL, and lot size. 
   double volatility_factor      = (DAY_VOL() * 0.5) / TRADE_POINTS(); 
   double minimum_sl             = FEATURE_CONFIG.MIN_SL_DISTANCE;
   double derived_sl             = CONFIG.sl;
   double calculated_sl          = volatility_factor * TRADE_POINTS();
   
   //-- Returns derived sl if calculated sl is below specified symbol minimum sl ticks. 
   double sl_factor              = volatility_factor < minimum_sl ? derived_sl : calculated_sl; 
   
   return sl_factor;
}

double         CRecurveTrade::CatastrophicSLFactor(double lot,double var) {
   
   /**
      Calculates SL factor for Catastrophic Loss. 
   **/
   
   // -- Returns ticks for catastrophic SL 
   double sl_ticks = (var * TRADE_POINTS()) / (lot * TICK_VALUE()); 
   return sl_ticks; 

}



TradeParams    CRecurveTrade::ParamsLong(ENUM_ORDER_SEND_METHOD method,TradeLayer &layer) {
   
   /**
      Sets Trade Parameters for Long Positions
   **/
   
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
   
   /**
      Sets Trade Params for Short Positions
   **/
   
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

   /**
      Send Market Order
   **/

   //-- Returns if trade window is closed. 
   if (!ValidTradeWindow()) { 
      Log.LogInformation("ORDER SEND FAILED. Trade window is closed.", __FUNCTION__);
      return 0;
   }
   
   //-- Returns if interval is invalid: selected timeframe does not match input timeframe. 
   if (!ValidInterval()) {
      string error_message = StringFormat("ORDER SEND FAILED. Invalid Interval. Current: %i", UTIL_TIME_MINUTE(TimeCurrent()));
      Log.LogInformation(error_message, __FUNCTION__); 
      //error(error_message);
      return 0;
   }
   
   int size = ALGO_POSITIONS_.Size(); 
   //-- Returns if current open positions is equal to max layers 
   if (size >= InpMaxLayers) {
      Log.LogInformation(StringFormat("Max Layers Reached. Current Open Positions for %s: %i. Max Layers: %i",
         Symbol(),
         size, 
         InpMaxLayers), __FUNCTION__, false, true); 
      return 0; 
   }

   //int num_trades_opened_today   = Accounts_.AccountSymbolTradesToday(); 
   if (symbol_trades_today_ >= InpMaxDayTrades) {
      Log.LogInformation(StringFormat("ORDER SEND FAILED. Daily Trade Limit Reached. Trades: %i", symbol_trades_today_), __FUNCTION__);
      return 0; 
   }
   
   string   layer_identifier  = PARAMS.layer.layer == LAYER_PRIMARY ? "PRIMARY" : "SECONDARY";
   string   comment           = StringFormat("%s_%s", EA_ID, layer_identifier);
   
   int ticket     = OP_OrderOpen(Symbol(), (ENUM_ORDER_TYPE)PARAMS.order_type, PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, comment);
   
   if (ticket == -1) {
      string error_message = StringFormat("ORDER SEND FAILED. ERROR: %i. Symbol: %s, Vol: %f, Entry: %f, SL: %f, TP: %f", 
         GetLastError(), 
         Symbol(), 
         PARAMS.volume, 
         PARAMS.entry_price, 
         PARAMS.sl_price, 
         PARAMS.tp_price);
         
      Log.LogError(error_message, __FUNCTION__); 
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
   
   Log.LogInformation(StringFormat("Updated active positions: %i, Ticket: %i", NumActivePositions(), pos.pos_ticket), __FUNCTION__);
   //AddOrderToday();
   */
   
   if (!ALGO_POSITIONS_.Search(ticket)) ALGO_POSITIONS_.Append(ticket); 
   //Accounts_.AddTradeToday(ticket); 
   //Accounts_.AddOpenedPositionToday(ticket); 
   symbol_trades_today_++; 
   Log.LogInformation(StringFormat("Order Placed. Symbol: %s, Ticket: %i, Order Type: %s, Volume: %f, Entry Price: %f, SL Price: %f, Symbol Trades Today: %i", 
      Symbol(),
      ticket,
      EnumToString((ENUM_ORDER_TYPE)PARAMS.order_type), 
      PARAMS.volume, 
      PARAMS.entry_price, 
      PARAMS.sl_price,
      symbol_trades_today_), __FUNCTION__);
   
   // match algo positions with current order pool 
   int update  = UpdatePositions(); 
   return ticket; 

}


int            CRecurveTrade::CloseOrder() {
   /**
      Close All Orders
   **/
   int num_positions    = PosTotal();
   
   for (int i = 0; i < num_positions; i ++) int c = OP_OrdersCloseAll(); 
   if (PosTotal() == 0) {
      CReports *reports = GenerateReports(); 
      reports.Reason("deadline"); 
      reports.Export(); 
      delete reports;
      Log.LogInformation("Close All. Reason: deadline.", __FUNCTION__, false, true); 
   }
   
   UpdatePositions(); 
   return 1;

}

double         CRecurveTrade::FloatingPL() {
   /**
      Calculates Floating PL for EA positions for specific symbol
   **/
   int num_trades = PosTotal(); 
   
   double floating_pl   = 0;
   int    trades_found  = 0;
   
   for (int i = 0; i < num_trades; i++) {
      int t = OP_OrderSelectByIndex(i);
      //-- Skips if ticket does not match attached symbol 
      if (!OP_TradeMatch(i)) continue; 
      //-- Adds floating pL 
      floating_pl += PosProfit();
      //-- Adds trades found
      trades_found++;
   }
   if (trades_found > 0) Log.LogInformation(StringFormat("%i Open Positions Found for %s. Floating P/L: %f", 
      trades_found, 
      Symbol(), 
      floating_pl), __FUNCTION__);
   return floating_pl; 
}

bool        CRecurveTrade::InFloatingLoss() {
   /*
      Returns true if trades in symbol is in floating loss. 
   **/
   double   floating_pl    = FloatingPL(); 
   if (floating_pl >= 0) return false; 
   Log.LogInformation(StringFormat("%s is in floating loss.", Symbol()), __FUNCTION__);
   return true; 
}

bool           CRecurveTrade::ValidStack() {
   /**
      Determines if stacking is valid. 
      
      Returns:
         true - order will not be closed
         false - order will be closed 
         
      Closing Conditions (returns false)
         1. Secure and in floating profit
         2. Cut and in floating loss 
   **/
   
   //--- Determines if selected order is in profit 
   bool profit = PosProfit() > 0; 
   bool valid_gain   = ValidFloatingGain();
   bool valid_loss   = ValidFloatingLoss(); 
   switch(profit) {
      case true:
         //--- Valid Stack on floating gain
         //--- if true, ignore order
         //--- if false, close order
         return valid_gain; 
         break;
      case false:
         //--- Valid Cut on floating loss
         //--- if false, close order
         //--- if true, ignore order 
         return valid_loss; 
         break;
   }
   return true; 
}

bool            CRecurveTrade::ValidFloatingGain() {
    
    //--- TODO: IMPLEMENT CONFIG.SECURE
    
    switch(InpFloatingGain) {
        case STACK_ON_PROFIT:
            //--- Ignores existing position
            return true; 
            break;
        case SECURE_FLOATING_PROFIT:
            //--- Closes existing position 
            return false; 
            break;
        case IGNORE:
            return true; 
            break;  
    }
    return false;
}

bool           CRecurveTrade::ValidFloatingLoss() {
   
   switch(InpFloatingDD) {
      case CUT_FLOATING_LOSS:
         //--- Closes existing position 
         return false; 
         
      case MARTINGALE:
         //--- Ignores existing position 
         return true; 
      case IGNORE_LOSS:
         //--- Ignores existing position
         return true; 
   }
   
   return false; 
}

bool           CRecurveTrade::Breakeven(int ticket) {
   /**
      Sets Breakeven if position floating profit is greater than 
      or equal to required profit threshold. (Input)
   **/
   int s = OP_OrderSelectByTicket(ticket); 
   //--- Calculates minimum gain to set BE. 
   if (InpTradeMgt != MODE_BREAKEVEN) return false; 
   double balance = InpUseFixedRisk ? InpFixedRisk : UTIL_ACCOUNT_BALANCE(); 
   double gain    = balance * (InpBEThreshold / 100); 
   //--- Returns false if current profit is below required threshold. 
   if (PosProfit() < gain) return false; 
   
   //-- Returns false if already set as BE
   if (PosSL() == PosOpenPrice()) return false;
   //--- Modifies SL 
   bool m = OP_ModifySL(ticket, PosOpenPrice()); 
   return m;
}

bool           CRecurveTrade::ValidTradeToday() {
   /**
      Checks if number of trades opened today has exceeded day trade limit. 
      
      Prevents overtrading. 
      
      Ex. Limit: 3 trades per day
          If Num Trades Opened > Limit, returns false, and prevents opening any more trades. 
          
          Returns true if positions today is below maximum limit. 
   **/
   //int num_trades_today    = Accounts_.AccountSymbolTradesToday(); 
   int num_trades_today = symbol_trades_today_; 
   if (num_trades_today >= InpMaxDayTrades) {
      Log.LogInformation(StringFormat("Daily Trade Limit is reached. Trades Opened Today: %i Limit: %i", 
         num_trades_today, 
         InpMaxDayTrades), __FUNCTION__); 
      return false; 
   }   
   return true; 
}

int            CRecurveTrade::ClosePositions(ENUM_SIGNAL reason) {
   /**
      Close Positions baseed on reason 
      
      Close logic varies with signal 
   **/
   int num_trades = PosTotal(); 
   
   
   CPoolGeneric<int> *trades_to_close = new CPoolGeneric<int>(); 
   
   for (int i = 0; i < num_trades; i++) {
      int t = OP_OrderSelectByIndex(i); 
      if (!OP_TradeMatch(i)) continue; 
      
      ENUM_ORDER_TYPE current_position = CurrentOpenPosition(), order = PosOrderType(); 
      int ticket  = PosTicket(); 
      bool valid_interval  = ValidInterval(), profit = PosProfit() > 0;
      
      bool c=false; 
      
      /**
         Objective: Determine which tickets to close. 
         Break: Adds to close 
         Continue: Ignore 
         
         1. Compare signal and existing order 
            - If match, check stack. Else, check invert. 
         If Valid Stack: ignore 
         Else: continue 
      **/
      if (Breakeven(ticket)) Log.LogInformation(StringFormat("Breakeven set for: %s, Ticket: %i", Symbol(), ticket), __FUNCTION__, false, true); 
 
 
      switch(reason) {
         case TRADE_LONG:        if (!ValidCloseOnTradeLong(ticket))       continue; break; 
         case TRADE_SHORT:       if (!ValidCloseOnTradeShort(ticket))      continue; break;
         case CUT_LONG:          if (!ValidCloseOnCutLong(ticket))         continue; break;
         case CUT_SHORT:         if (!ValidCloseOnCutShort(ticket))        continue; break;
         case TAKE_PROFIT_LONG:  if (!ValidCloseOnTakeProfitLong(ticket))  continue; break;
         case TAKE_PROFIT_SHORT: if (!ValidCloseOnTakeProfitShort(ticket)) continue; break; 
         case SIGNAL_NONE:       delete trades_to_close; return 0;
         default:                continue; 
      }
      
      trades_to_close.Append(ticket); 
   }
   
   int extracted[]; 
   int num_extracted = trades_to_close.Extract(extracted); 
   
   int num_closed = OP_OrdersCloseBatch(extracted); 
   
   if (num_closed == 0 && num_extracted > 0) {
      Log.LogInformation(StringFormat("Num Closed: %i", num_closed), __FUNCTION__);
      CReports *reports = GenerateReports(); 
      reports.Export(reason); 
      delete reports; 
      
      Log.LogInformation(StringFormat("Batch Close. Reason: %s", EnumToString(reason)), __FUNCTION__, false, true); 
      //--- UPDATE ACCOUNTS LINKED LIST HERE
      //int updated = Accounts_.AddClosedPositions(extracted); 
      //PrintFormat("UPDATE: %i", updated); 
   }
   
   
   delete trades_to_close; 
   UpdatePositions(); 
   return num_closed; 
}


//--- SIGNAL MANAGEMENT ---//
//--- TEMPORARY ---// 


string         CRecurveTrade::TradeLogicErrorReason(ENUM_TRADE_LOGIC_ERROR_REASON reason) {
   //--- Used for logging.
   switch (reason) {
      case REASON_GAIN_MGT:            return StringFormat("Gain Mgt.: %s", EnumToString(InpFloatingGain)); 
      case REASON_DD_MGT:              return StringFormat("DD Mgt.: %s", EnumToString(InpFloatingDD)); 
      case REASON_INVERT:              return "Invert"; 
      case REASON_WRONG_ORDER_TYPE:    return "Wrong order type.";
      case REASON_ORDER_IN_PROFIT:     return "Position in profit.";
      case REASON_ORDER_IN_DD:         return "Position in drawdown.";
      case REASON_SECURE_CONFIG_FALSE: return "Secure profits set to false.";
   }
   return "";
}


bool           CRecurveTrade::ValidCloseOnTradeLong(int ticket) {
   //--- Test Case: USDSGD, USDCAD 3/26/2024
   int s = OP_OrderSelectByTicket(ticket);   
   bool profit = PosProfit() > 0; 
   
   /*
      Return: 
         true -> Close this ticket
         false -> Ignore this ticket
         
      
      definition:
         stack -> add to winning positions
         martingale -> add to losing positions
      
      Logic: 
         - true -> close on stack (secures floating profit and adds another position)
         - true -> close on opposite trade (closes position on opposite signal)
         - true -> close on martingale (essentially cut losses and enter again)
   */
   string log_message   = StringFormat("Valid close on long signal. Ticket: %i", ticket); 
   
   //--- Secure floating profit and in profit returns true -> selected ticket will be closed. 
   if (InpFloatingGain == SECURE_FLOATING_PROFIT && profit && PosOrderType() == ORDER_TYPE_BUY) {  
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_GAIN_MGT)), __FUNCTION__); 
      return true; // break 
   } 
   //--- Set as cut floating loss and in drawdown returns true -> selected ticket will be closed
   if (InpFloatingDD == CUT_FLOATING_LOSS && !profit && ValidInterval()) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_DD_MGT)), __FUNCTION__);
      return true; // break
   }
   //--- Current trade is a sell, incoming LONG signal. Returns true only on valid interval -> selected tic
   if (PosOrderType() == ORDER_TYPE_SELL && ValidInterval()) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_INVERT)), __FUNCTION__); 
      return true; // break
   }
   Log.LogInformation(StringFormat("Invalid close on long signal. Gain Mgt: %s, DD Mgt: %s", 
      EnumToString(InpFloatingGain), 
      EnumToString(InpFloatingDD)), __FUNCTION__); 
      
   return false; 
}


bool           CRecurveTrade::ValidCloseOnTradeShort(int ticket) {
   int s = OP_OrderSelectByTicket(ticket); 
   bool profit = PosProfit() > 0; 
   string log_message   = StringFormat("Valid close on short signal. Ticket: %i", ticket); 
   
   if (InpFloatingGain == SECURE_FLOATING_PROFIT && profit && PosOrderType() == ORDER_TYPE_SELL) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_GAIN_MGT)), __FUNCTION__); 
      return true; 
   }
   if (InpFloatingDD == CUT_FLOATING_LOSS && !profit && ValidInterval()) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_DD_MGT)), __FUNCTION__); 
      return true; 
   }
   if (PosOrderType() == ORDER_TYPE_BUY && ValidInterval()) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_INVERT)), __FUNCTION__); 
      return true; 
   }
   Log.LogInformation(StringFormat("Invalid close on short signal. Gain Mgt: %s, DD Mgt: %s", 
      EnumToString(InpFloatingGain),
      EnumToString(InpFloatingDD)), __FUNCTION__); 
   
   return false; 
}

/*
NOTE:
- Signal already considers symbol net p/l 
- Closing needs to consider individual p/l 

Methods below are only triggered by closing signals
*/


bool           CRecurveTrade::ValidCloseOnCutLong(int ticket) {
   int s = OP_OrderSelectByTicket(ticket); 
   bool profit = PosProfit() < 0; 
   /*
      Valid Conditions:
         - Order = Long 
         - In drawdown
         - Drawdown Mgt -> Cut floating loss 
   */
   string log_message   = StringFormat("Invalid cut long for ticket: %i", ticket); 
   
   if (PosOrderType() != ORDER_TYPE_BUY) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_WRONG_ORDER_TYPE)), __FUNCTION__); 
      return false;
   }
   if (profit) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_ORDER_IN_PROFIT)), __FUNCTION__); 
      return false;
   }
   if (InpFloatingDD != CUT_FLOATING_LOSS) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_DD_MGT)), __FUNCTION__); 
      return false;
   }
   return true; 
    
}


bool           CRecurveTrade::ValidCloseOnCutShort(int ticket) {
   int s = OP_OrderSelectByTicket(ticket); 
   bool profit = PosProfit() < 0; 
   string log_message   = StringFormat("Invalid cut short for ticket: %i", ticket); 
   
   if (PosOrderType() != ORDER_TYPE_SELL) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_WRONG_ORDER_TYPE)), __FUNCTION__); 
      return false;
   }
   if (profit) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,  
         TradeLogicErrorReason(REASON_ORDER_IN_PROFIT)), __FUNCTION__); 
      return false; 
   }
   if (InpFloatingDD != CUT_FLOATING_LOSS) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_DD_MGT)), __FUNCTION__); 
      return false;
   }
   return true; 

}

bool           CRecurveTrade::ValidCloseOnTakeProfitLong(int ticket) {
   int s = OP_OrderSelectByTicket(ticket); 
   bool profit = PosProfit() < 0; 
   string log_message   = StringFormat("Invalid take profit long for ticket: %i", ticket); 
   
   if (PosOrderType() != ORDER_TYPE_BUY) {
      Log.LogInformation(StringFormat("%s. Reason - %s",
         log_message, 
         TradeLogicErrorReason(REASON_WRONG_ORDER_TYPE)), __FUNCTION__); 
      return false;
   }
   if (!profit) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message, 
         TradeLogicErrorReason(REASON_ORDER_IN_DD)), __FUNCTION__); 
      return false;
   }
   if (InpFloatingGain != SECURE_FLOATING_PROFIT && !CONFIG.secure) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_SECURE_CONFIG_FALSE)), __FUNCTION__); 
      return false; 
   }
   return true; 
   
}
bool           CRecurveTrade::ValidCloseOnTakeProfitShort(int ticket) {
   int s = OP_OrderSelectByTicket(ticket); 
   bool profit = PosProfit() < 0; 
   string log_message   = StringFormat("Invalid take profit short for ticket: %i", ticket); 
   
   if (PosOrderType() != ORDER_TYPE_SELL) {  
      Log.LogInformation(StringFormat("%s. Reason - %s",
         log_message,
         TradeLogicErrorReason(REASON_WRONG_ORDER_TYPE)), __FUNCTION__); 
      return false; 
   }
   if (!profit) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_ORDER_IN_DD)), __FUNCTION__); 
      return false; 
   }
   if (InpFloatingGain != SECURE_FLOATING_PROFIT && !CONFIG.secure) {
      Log.LogInformation(StringFormat("%s. Reason - %s", 
         log_message,
         TradeLogicErrorReason(REASON_SECURE_CONFIG_FALSE)), __FUNCTION__); 
      return false;
   }
   return true; 
}



bool           CRecurveTrade::ValidTradeOpen() {
   /*
      Opening trades is prohibited when action is ignored
   */
   
   bool floating_loss   = InFloatingLoss(); 
   
   switch(floating_loss) {
      case true:
         if (InpFloatingDD == IGNORE_LOSS) return false;
         return true; 
      case false:
         if (InpFloatingGain == IGNORE) return false;
         return true; 
   }
    
   return false;
}

//--- SIGNAL MANAGEMENT ---//
//--- TEMPORARY ---// 

int            CRecurveTrade::SendOrder(ENUM_SIGNAL signal) {
   
   if (!ValidTradeOpen()) {
      return 0; 
   }

   //-- Currently not used. Primarily for layering
   TradeLayer     LAYER;
   LAYER.layer          = LAYER_PRIMARY;
   LAYER.allocation     = 1.0;  
   
   switch(signal) {
      case TRADE_LONG:
         Log.LogInformation("Send Order: Long", __FUNCTION__);    
         return SendMarketOrder(ParamsLong(MODE_MARKET, LAYER));
      case TRADE_SHORT:
         Log.LogInformation("Send Order: Short", __FUNCTION__);    
         return SendMarketOrder(ParamsShort(MODE_MARKET, LAYER));
      default: break; 
   }
   
   return 0; 

}

double         CRecurveTrade::CalcBuffer() {
   /**
      Buffer Gain is calculated as a percentage of daily start balance. 
      Returns USD value. 
   **/
   
   //--- Day Start Balance 
   double day_start_balance = UTIL_ACCOUNT_BALANCE(); 
   
   double buffer = day_start_balance * (InpBufferPercent / 100); 
   return buffer; 
}

int            CRecurveTrade::SecureBuffer() { 
   /**
      Closes all positions if current p/l exceeds minimum buffer threshold.
      
      Only works on live testing.
   **/
   if (PosTotal() == 0) return 0; 
   
   int current_hour = UTIL_TIME_HOUR(TimeCurrent()); 
   if (current_hour > InpBufferDeadline) {
      //Log.LogInformation(StringFormat("Reached Buffer Deadline. Current: %i, Deadline: %i", current_hour, InpBufferDeadline), __FUNCTION__); 
      return 0; 
   }
   
   
   double buffer     = CalcBuffer();
   double running_pl = PortfolioRunningPL();
   
   if (running_pl < buffer) {
      //Log.LogInformation(StringFormat("Secure Invalid. Running PL is below minimum threshold. Buffer: %f, Running PL: %f", 
      //   buffer, 
      //   running_pl), __FUNCTION__); 
      return 0;
   }
   
   Log.LogInformation(StringFormat("Securing Open PL. Buffer: %f, Running PL: %f", 
      buffer, 
      running_pl), __FUNCTION__); 
   int extracted[]; 
   int num_extracted = ALGO_POSITIONS_.Extract(extracted);
   
   int c = OP_OrdersCloseBatch(extracted); 
   if (c == 0 && num_extracted > 0) {
      Log.LogInformation(StringFormat("Positions Closed: %i", 
         num_extracted), __FUNCTION__);
      CReports *reports = GenerateReports(); 
      reports.Reason("buffer"); 
      reports.Export(); 
      delete reports; 
   }   
   
   
   
   ALGO_POSITIONS_.Clear(); 
   UpdatePositions(); 
   return num_extracted; 
   
}

int            CRecurveTrade::Recover() {
   /**
      Closes all positions during recovery window if net PL reaches breakeven if current net PL is negative.
      
      Ignore this if current net PL is positive. 
      
      Not Implemented
   **/
   
   
   double running_pl = PortfolioRunningPL(); 
   if (!ValidRecoveryWindow()) return 0; 
   
   if (running_pl < 0) {
      Log.LogInformation(StringFormat("Recovery window valid. Running PL is negative. PL: %f", running_pl), __FUNCTION__); 
      return 0; 
   }
   int extracted[];
   int num_extracted = ALGO_POSITIONS_.Extract(extracted); 
   int c = OP_OrdersCloseBatch(extracted); 
   if (c == 0 && num_extracted > 0) {
      Log.LogInformation(StringFormat("PL Recovered. Positions Closed: %i", 
         num_extracted), __FUNCTION__); 
      CReports *reports = GenerateReports(); 
      reports.Reason("recovery");
      reports.Export();
      delete reports;
   }
   ALGO_POSITIONS_.Clear();
   UpdatePositions();
   
   return num_extracted;
}


double         CRecurveTrade::PortfolioRunningPL() {
   /**
      Running Open PL 
   **/
   
   return   UTIL_ACCOUNT_PROFIT();
   /*
   int num_pos = PosTotal();
   
   double running_pl = 0;
   for (int i = 0; i < num_pos; i++) {
      int s = OP_OrderSelectByIndex(i);
      running_pl+=PosProfit(); 
   }
   return running_pl; */
}

//+------------------------------------------------------------------+
//| DATA STRUCTURE                                                   |
//+------------------------------------------------------------------+


int            CRecurveTrade::UpdatePositions() {
   /**
      Objective: Contents of ALGO_POSITIONS must be in order pool and vice versa. 
      Count matching orders in order pool, 
      Count size of algopositions 
      
      if length mismatch, reset algo positions and repopulate 
      
      if same length, validate 
      
      if ticket mismatch, repopulate 
   **/
   
   
   int open_positions = PosTotal(); 
   if (open_positions == 0) {
      //Log.LogInformation("No Open Positions. Order pool is empty.", __FUNCTION__);
      ALGO_POSITIONS_.Clear(); 
      return open_positions; 
   }
   
   //-- Synthetic order pool for comparing contents of ALGO_POSITIONS
   CPoolGeneric<int> *synthetic   = new CPoolGeneric<int>(); 
   
   
   int updated_size = 0;
   //-- Iterate through order pool and find open positions with matching symbol and magic number
   for (int i = 0; i < open_positions; i++) {
      int s = OP_OrderSelectByIndex(i); 
      if (!OP_TradeMatch(i)) continue; //-- Skips if symbol and magic number do not match. 
      
      int ticket = PosTicket(); 
      synthetic.Append(ticket); 
   }
   
   int synth_size = synthetic.Size(), algo_size = ALGO_POSITIONS_.Size(); 
   
   if (synth_size == 0) {
      ALGO_POSITIONS_.Clear();
      //Log.LogInformation(StringFormat("No Open Positions. Algo: %i. Reset Size: %i", algo_size, ALGO_POSITIONS_.Size()), __FUNCTION__); 
      delete synthetic; 
      return algo_size; 
   }
   
   if (synth_size != algo_size) {
      Log.LogInformation(StringFormat("Order pool and Algo Positions length mismatch. Repopulating Algo Positions. Pool: %i, Algo: %i", 
         synth_size, 
         algo_size), __FUNCTION__); 
         
      updated_size   = RepopulateAlgoPositions(synthetic);       
      delete synthetic; 
      return ALGO_POSITIONS_.Size(); 
   } 
   
   else {
      //-- Match tickets 
      Log.LogInformation("Order pool and Algo Positions length matched. Verifying.", __FUNCTION__); 
      for (int j = 0; j < algo_size; j++) {
         if (synthetic.Item(j) != ALGO_POSITIONS_.Item(j)) {
            //-- If elements are mismatched, algo positions will be repopulated. 
            updated_size = RepopulateAlgoPositions(synthetic);
            delete synthetic;
            return ALGO_POSITIONS_.Size(); 
         }
      }
   }
   
   Log.LogInformation("Tickets stored in Algo Positions are valid.", __FUNCTION__, false, true); 
   delete synthetic; 
   return ALGO_POSITIONS_.Size(); 
   
}


int            CRecurveTrade::RepopulateAlgoPositions(CPoolGeneric<int> *&synth) {
   
   int extracted[]; 
   int num_extracted = synth.Extract(extracted); 
   
   ALGO_POSITIONS_.Clear();
   ALGO_POSITIONS_.Create(extracted); 
   
   return ALGO_POSITIONS_.Size(); 
}


ENUM_ORDER_TYPE   CRecurveTrade::CurrentOpenPosition() {
   int size = ALGO_POSITIONS_.Size(); 
   
   for (int i = 0; i < size; i++) {
      int ticket  = ALGO_POSITIONS_.Item(i); 
      int s       = OP_OrderSelectByTicket(ticket);
      return PosOrderType(); 
   }
   return -1; 
}

//+------------------------------------------------------------------+
//| LOGIC                                                            |
//+------------------------------------------------------------------+

bool           CRecurveTrade::ValidInterval() {
   
   //-- Intervals are automatically valid if config is overridden. 
   if (InpIgnoreIntervals) return true; 
   int minute  = UTIL_TIME_MINUTE(TimeCurrent());
   
   int size    = INTERVALS_.Size(); 
   
   //-- Returns true if no intervals are stored. 
   if (size == 0) {
      Log.LogInformation("Empty Interval. Returning True.", __FUNCTION__);
      return true;
   }
   
   //-- Returns true if current minute is in valid intervals.
   if (INTERVALS_.Search(minute)) return true; 
   return false;
}

bool           CRecurveTrade::EndOfDay() {
   //-- Determines end of trading window 
   int hour = UTIL_TIME_HOUR(TimeCurrent());
   if (hour >= FEATURE_CONFIG.TRADE_DEADLINE) return true;
   return false; 
   
}


bool           CRecurveTrade::ValidDayVolatility() {

   /**
      Returns true if daily volatility is valid based on model parameters. 
   **/

   double day_volatility      = DAY_VOL();
   double day_peak            = DAY_PEAK_VOL(); 
   
   double minimum_volatility  = CONFIG.low_volatility_thresh;  
   
   
   if (day_volatility > day_peak)            return false; 
   if (InpIgnoreLowVol)                      return true; 
   if (day_volatility < minimum_volatility)  return false;
   // ADD LOW VOLATILITY WINDOW 
   // ADD HOLIDAY
   return true;

}

bool           CRecurveTrade::DayOfWeekInTradingDays() {
   if (InpIgnoreDayOfWeek) return true; 
   int current_day_of_week    = UTIL_TIME_DAY_OF_WEEK(TimeCurrent()) - 1; 
   if (CONFIG.TRADING_DAYS.Search(current_day_of_week)) return true; 
   return false; 
}

bool           CRecurveTrade::ValidDayOfWeek() { return DayOfWeekInTradingDays(); }


int            CRecurveTrade::Stage() { 
   
   /**
      Staging algo logic 
   **/
   
   RISK.var                = ValueAtRisk();
   RISK.cat_var            = CatastrophicLossVAR(); 
   RISK.valid_day_of_week  = ValidDayOfWeek(); 
   RISK.valid_day_vol      = ValidDayVolatility();
   RISK.valid_long         = PreviousDayValid(LONG);
   RISK.valid_short        = PreviousDayValid(SHORT); 
   
   if (!RISK.valid_day_of_week) return 0;
   if (!RISK.valid_day_vol)   return 0; 
   
   //-- Locks in trades in profit early in the trading session. 
   int secured = SecureBuffer(); 
   
   if (secured > 0) Log.LogInformation(StringFormat("Secured %i positions.", secured), __FUNCTION__); 
   
   
   //-- Sets latest feature values 
   FeatureValues  LatestFeatureValues     = SetLatestFeatureValues(); 
   
   //-- Generates signal based on latest feature values 
   ENUM_SIGNAL signal   = Signal(LatestFeatureValues);
   Log.LogInformation(StringFormat("Signal: %s", EnumToString(signal)), __FUNCTION__); 
   //--- Handler for stacking etc 
   int c = ClosePositions(signal);
   
   //--- Handler for sending orders  
   int t = SendOrder(signal); 
   
   //--- Handler for recovery
   int r = Recover(); 
   
   //--- Handler for Account updates
   //Accounts_.Init();
   ACCOUNT_HIST.symbol_trades_today = symbol_trades_today_; 
   //--- Track Tickets in order pool 
   //if (IsTesting()) Accounts_.Track(); 
   
   //int num_trades_today = Accounts_.TradesToday();
   //Log.LogInformation(StringFormat("Updated Trades Today: %i", num_trades_today), __FUNCTION__); 
   return 0;
}

bool           CRecurveTrade::ValidTradeWindow() {

   /**
      Checks if entry window is open
   **/
   
   int hour             = UTIL_TIME_HOUR(TimeCurrent()); 
   int minute           = UTIL_TIME_MINUTE(TimeCurrent()); 
   int ENTRY_HOUR       = FEATURE_CONFIG.ENTRY_WINDOW_OPEN; // convert to input 
   int EXIT_HOUR        = FEATURE_CONFIG.ENTRY_WINDOW_CLOSE; // convert to input 
   
   if (hour < ENTRY_HOUR) return false ;
   if (hour > EXIT_HOUR) return false; 
   return true; 
   
}

bool           CRecurveTrade::ValidRecoveryWindow() {
   /**
      Checks if recovery window is open. 
   **/
   
   int hour             = UTIL_TIME_HOUR(TimeCurrent());
   int RECOVERY_ENTRY   = FEATURE_CONFIG.ENTRY_WINDOW_CLOSE;
   int RECOVERY_EXIT    = FEATURE_CONFIG.TRADE_DEADLINE; 
   
   if (hour < RECOVERY_ENTRY) return false; 
   if (hour > RECOVERY_EXIT)  return false;
   return true; 
}

bool           CRecurveTrade::PreviousDayValid(ENUM_DIRECTION direction) {
   
   /**
      Optional logic condition for specified pairs. 
      
   **/
   
   if (!CONFIG.use_pd) return true; 
   
   double   pd_upper_band  = PD_UPPER_BANDS();
   double   pd_lower_band  = PD_LOWER_BANDS(); 
   
   /*
      Secondary condition is temporarily silenced since algo requires updated config on trading days. 
   */
   
   switch(direction) {
      case LONG: 
         if (UTIL_CANDLE_LOW() > UTIL_PREVIOUS_DAY_LOW() && (UTIL_CANDLE_OPEN(1) > pd_lower_band)) return true; 
         return false; 
      case SHORT:   
         if (UTIL_CANDLE_HIGH() < UTIL_PREVIOUS_DAY_HIGH() && (UTIL_CANDLE_OPEN(1) < pd_upper_band)) return true;
         return false;
   }
   return false; 
   
}


ENUM_SIGNAL    CRecurveTrade::Signal(FeatureValues &features) {
   
   /**
      Main signal logic 
   **/
   
   double last_open           = UTIL_CANDLE_OPEN(1);
   double last_close          = UTIL_CANDLE_CLOSE(1); 
   
   //-- Short condition
   if ((features.skew_value > FEATURE_CONFIG.SKEW_THRESHOLD) 
      && (features.standard_score_value > FEATURE_CONFIG.SPREAD_THRESHOLD) 
      && (features.last_candle_high > features.upper_bands)
      //&& (last_close > last_open)
      && PreviousDayValid(SHORT)) return TRADE_SHORT;
   
   //-- Long Condition 
   if ((features.skew_value < -FEATURE_CONFIG.SKEW_THRESHOLD) 
      && (features.standard_score_value <- FEATURE_CONFIG.SPREAD_THRESHOLD)
      && (features.last_candle_low < features.lower_bands)
      //&& (last_close < last_open)
      && PreviousDayValid(LONG)) return TRADE_LONG;
   
   PrintFormat("Z: %f, ZThresh: %f, Skew: %f, Skew Thresh: %f, Last  Low: %f, Lower Band: %f, PD Long: %s", 
      features.standard_score_value,
      FEATURE_CONFIG.SPREAD_THRESHOLD,
      features.skew_value,
      FEATURE_CONFIG.SKEW_THRESHOLD,
      features.last_candle_low,
      features.lower_bands,
      (string)PreviousDayValid(LONG)); 
   bool floating_loss         = InFloatingLoss(); 
   //PrintFormat("Floating Loss?: %s", (string)floating_loss); 
   //-- Additional methods to take profit or cut losses 
   switch(floating_loss) {
      case true:        return CutLoss(features); 
      case false:       return TakeProfit(features); 
   }
   
   return SIGNAL_NONE;
   
}

ENUM_SIGNAL    CRecurveTrade::CutLoss(FeatureValues &features) {
   /**
      Main logic for cutting losses based on latest feature values. 
      
      UPDATE (3/23/24): Removed Skew from cutting condition
      
      Conditions satisfied at this point:
         1. Floating Loss
         2. No trade signals
   **/
   
   //-- Cut Short condition 
   if ((features.standard_score_value <= -FEATURE_CONFIG.SPREAD_THRESHOLD) 
      && (features.last_candle_close > features.slow_upper)) 
      return CUT_SHORT; 
      
   //-- Cut Long condition 
   if ((features.standard_score_value >= FEATURE_CONFIG.SPREAD_THRESHOLD) 
      && (features.last_candle_close < features.slow_lower)) 
      return CUT_LONG;
      
   return SIGNAL_NONE; 
}


ENUM_SIGNAL    CRecurveTrade::TakeProfit(FeatureValues &features) {
   /**
      Main logic for securing profits based on latest feature values. 
      
      Used for selected pairs only. 
      
      Conditions Satisfied at this point:
         1. Floating Profit
         2. No trade signals 
   **/
   //Print("Secure: ", CONFIG.secure); 
   if (!CONFIG.secure) return SIGNAL_NONE; // THIS IS WRONG USE CONFIG.SECURE
   /*
   PrintFormat("Z: %f, ZThresh: %f, Last High: %f, Upper Band: %f", 
      features.standard_score_value,
      FEATURE_CONFIG.SPREAD_THRESHOLD,
      features.last_candle_high,
      features.upper_bands); 
   */
   //-- Take Profit Long Condition 
   if ((features.standard_score_value >= FEATURE_CONFIG.SPREAD_THRESHOLD) 
      && (features.last_candle_high > features.upper_bands)) 
      return TAKE_PROFIT_LONG; 
   
   //-- Take Profit Short Condition 
   if ((features.standard_score_value <= -FEATURE_CONFIG.SPREAD_THRESHOLD) 
      && (features.last_candle_low < features.lower_bands)) 
      return TAKE_PROFIT_SHORT; 

   return SIGNAL_NONE;
}


FeatureValues  CRecurveTrade::SetLatestFeatureValues() {
   
   /**
      Sets latest feature values and stores it in a struct. 
   **/
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
   FEATURE.day_vol                  = DAY_VOL();
   FEATURE.peak_day_vol             = DAY_PEAK_VOL(); 
  
   
   return FEATURE;

}





//+------------------------------------------------------------------+
//| FEATURES                                                         |
//+------------------------------------------------------------------+


double         CRecurveTrade::DAILY_VOLATILITY( int volatility_mode, int shift = 1)    { 
   /**
      Daily Volatility / Standard Deviation on the daily timeframe. 
   **/
   return iCustom(NULL, 
      PERIOD_D1, 
      indicator_path(FEATURE_CONFIG.SDEV_FILENAME),      // path 
      FEATURE_CONFIG.DAILY_VOLATILITY_WINDOW,            // sdev window
      FEATURE_CONFIG.DAILY_VOLATILITY_PEAK_LOOKBACK,     // max window
      0,                                                 // shift
      volatility_mode,                                   // buffer
      shift                                              // shift
      ); 
      
}


double         CRecurveTrade::STANDARD_SCORE(int shift=1) {
   /**
      Standard score based on spread of the last close to the mean. 
   **/
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
   /**
      Measures closing skew 
   **/
   return iCustom(NULL,
      InpRPTimeframe,
      indicator_path(FEATURE_CONFIG.SKEW_FILENAME),
      FEATURE_CONFIG.SKEW_LOOKBACK,   // window
      0,    // shift
      0,    // buffer
      shift     // shift
   );
   
}

#ifdef __MQL4__ 
double         CRecurveTrade::BBANDS(int mode, int num_sd = 2, int shift =1) {
   /**
      Bollinger Bands for measuring volatility, and filtering entries. 
   **/
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
   /**
      Slow Bands, for cutting losses 
   **/
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
#endif 

#ifdef __MQL5__ 
double         CRecurveTrade::BBANDS(ENUM_BBANDS_MODE mode, int num_sd = 2, int shift = 1) {
   int handle = iBands(
      NULL, 
      InpRPTimeframe, 
      FEATURE_CONFIG.BBANDS_LOOKBACK, 
      shift, 
      num_sd, 
      PRICE_CLOSE 
      );
   
   return BBANDS_VALUE(handle, mode); 
} 


double         CRecurveTrade::BBANDS_SLOW(ENUM_BBANDS_MODE mode, int num_sd=2,int shift=1) {
   int handle = iBands( 
      NULL,
      InpRPTimeframe, 
      FEATURE_CONFIG.BBANDS_SLOW_LOOKBACK, 
      shift, 
      num_sd, 
      PRICE_CLOSE); 
      
   return BBANDS_VALUE(handle, mode); 
}


double         CRecurveTrade::BBANDS_VALUE(int handle,ENUM_BBANDS_MODE mode) {
   double buffer[]; 
   switch(mode) {
      case MODE_UPPER:
         CopyBuffer(handle, 1, 0, 1, buffer);
         return buffer[0]; 
      case MODE_LOWER:
         CopyBuffer(handle, 2, 0, 1, buffer);
         return buffer[0]; 
   }
   return 0; 
}
#endif 

string         CRecurveTrade::indicator_path(string indicator_name)     { return StringFormat("%s%s", FEATURE_CONFIG.INDICATOR_PATH, indicator_name); }
double         CRecurveTrade::DAY_VOL()           { return DAILY_VOLATILITY(MODE_STD_DEV); }
double         CRecurveTrade::DAY_PEAK_VOL()      { return DAILY_VOLATILITY(MODE_ROLLING_MAX_STD_DEV); }


double         CRecurveTrade::UPPER_BANDS()       { return BBANDS(MODE_UPPER); }
double         CRecurveTrade::LOWER_BANDS()       { return BBANDS(MODE_LOWER); }
double         CRecurveTrade::EXTREME_UPPER()     { return BBANDS(MODE_UPPER, 3); }
double         CRecurveTrade::EXTREME_LOWER()     { return BBANDS(MODE_LOWER, 3); }
double         CRecurveTrade::SLOW_UPPER()        { return BBANDS_SLOW(MODE_UPPER, 3); }
double         CRecurveTrade::SLOW_LOWER()        { return BBANDS_SLOW(MODE_LOWER, 3); }
double         CRecurveTrade::PD_UPPER_BANDS()    { return BBANDS(MODE_UPPER, 2, 2); }
double         CRecurveTrade::PD_LOWER_BANDS()    { return BBANDS(MODE_LOWER, 2, 2); }


#ifdef __MQL5__ 
//--- TEMPORARY 
//--- Buffers: 0-Base, 1-Upper, 2-Lower
/*
double CopyBufferMQL4(int handle,int index,int shift)
  {
   double buf[];
   switch(index)
     {
      case 0: if(CopyBuffer(handle,0,shift,1,buf)>0)
         return(buf[0]); break;
      case 1: if(CopyBuffer(handle,1,shift,1,buf)>0)
         return(buf[0]); break;
      case 2: if(CopyBuffer(handle,2,shift,1,buf)>0)
         return(buf[0]); break;
      case 3: if(CopyBuffer(handle,3,shift,1,buf)>0)
         return(buf[0]); break;
      case 4: if(CopyBuffer(handle,4,shift,1,buf)>0)
         return(buf[0]); break;
      default: break;
     }
   return(EMPTY_VALUE);
  }
*/
#endif 
