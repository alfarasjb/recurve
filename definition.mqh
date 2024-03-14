
#include <MAIN/CalendarDownloader.mqh> 
#include <MAIN/utilities.mqh>
#include <Controls/Defines.mqh> 
#include <Controls/Dialog.mqh>
#include <Controls/Button.mqh>
#include <Controls/Label.mqh>
// ========== DEFINES ========== // 
#undef   CONTROLS_FONT_SIZE 

#define  CONTROLS_FONT_SIZE      8 



// ========== ENUM ========== // 

enum ENUM_DIRECTION {
   LONG, SHORT, INVALID
};

enum ENUM_CONFIG_SOURCE {
   FILE, INPUT
};

enum ENUM_FREQUENCY {
   QUARTER, // QUARTER - 0, 15, 30, 45
   HALF, // HALF - 0, 30
   FULL // FULL - 0
};

enum ENUM_SIGNAL {
   TRADE_LONG, TRADE_SHORT, CUT_LONG, CUT_SHORT, SIGNAL_NONE
};

enum ENUM_TRADE_MANAGEMENT {
   MODE_BREAKEVEN, MODE_TRAILING, MODE_NONE
};

enum ENUM_POSITION_SIZING {
   MODE_DYNAMIC, MODE_STATIC
};

enum ENUM_ORDER_SEND_METHOD {
   MODE_MARKET, MODE_PENDING
};

enum ENUM_POSITIONS {
   MODE_SINGLE, MODE_LAYER
};

enum ENUM_LAYER {
   LAYER_PRIMARY, LAYER_SECONDARY
};

enum ENUM_LAYER_ORDERS {
   // UNIFORM -> same order types (market or pending), SPLIT -> market and pending (market - secondary, pending - primary)
   MODE_UNIFORM, MODE_SPLIT 
};

enum ENUM_LAYER_MANAGEMENT {
   MODE_SECURE, MODE_RUNNER
};

enum ENUM_DAILY_VOLATILITY_MODE {
   MODE_STD_DEV, MODE_ROLLING_MAX_STD_DEV 
};

// =========== STRUCT ========== // 

struct RiskProfile {
   double                  RP_amount, RP_lot, RP_market_split, RP_min_risk_reward;
   int                     RP_half_life, RP_spread, RP_trade_limit; 
   ENUM_TIMEFRAMES         RP_timeframe; 
   ENUM_ORDER_SEND_METHOD  RP_order_send_method;
   ENUM_POSITIONS          RP_positions;
   ENUM_LAYER_ORDERS       RP_layer_orders;
} RISK_PROFILE;

struct TradeLayer {
   ENUM_LAYER  layer;
   double      allocation;
};

struct ActivePosition {

   datetime    pos_open_datetime, pos_deadline; 
   int         pos_ticket;
   TradeLayer  layer;

};

struct TradeQueue {
   datetime next_trade_open, next_trade_window_end, next_trade_close, curr_trade_open, curr_trade_window_end, curr_trade_close;
} TRADE_QUEUE;

struct TradeParams {
   double entry_price, sl_price, tp_price, volume;
   int order_type;
   TradeLayer  layer; 
};

struct TradesActive {
   int      orders_today;
   datetime trade_open_datetime, trade_close_datetime;
   
   ActivePosition active_positions[]; // STORES ALL EA POSITIONS
   ActivePosition primary_layers[]; // STORES PRIMARY POSITION
   ActivePosition secondary_layers[]; // STORES SECONDARY POSITIONS
} TRADES_ACTIVE;

struct FeatureValues {

   double standard_score_value, skew_value, last_candle_high, last_candle_low, last_candle_close;
   
   double upper_bands, lower_bands, extreme_upper, extreme_lower, slow_upper, slow_lower; 

} FEATURE;


struct Configuration {
   int      trading_days[]; 
   double   low_volatility_thresh;
   bool     use_pd;
   
   string   days_string, intervals_string; 
} CONFIG;

struct FeatureConfiguration {
   int            DAILY_VOLATILITY_WINDOW, DAILY_VOLATILITY_PEAK_LOOKBACK, NORMALIZED_SPREAD_LOOKBACK, NORMALIZED_SPREAD_MA_LOOKBACK, SKEW_LOOKBACK, BBANDS_LOOKBACK, BBANDS_NUM_SDEV, BBANDS_SLOW_LOOKBACK; 
   double         SPREAD_THRESHOLD, SKEW_THRESHOLD;
   
   int            ENTRY_WINDOW_OPEN, ENTRY_WINDOW_CLOSE, TRADE_DEADLINE; 
   
   double         CATLOSS, RPT;
   
   int            MIN_SL_DISTANCE; 
      
} FEATURE_CONFIG;

/*
z score threshold = 2.1 
sl pips = 20 
entry window = 10-13 
close time = 20 
high volatility threshold = 0.012 
low volatility threshold = 0.001

daily sdev length = 10 
spread length = 20


DAILY_VOLATILITY_WINDOW            = 10;
DAILY_VOLATILITY_PEAK_LOOKBACK     = 90;
NORMALIZED_SPREAD_LOOKBACK         = 10; 
NORMALIZED_SPREAD_MA_LOOKBACK      = 50;
SKEW_LOOKBACK                      = 20;
BBANDS_LOOKBACK                    = 14;
BBANDS_NUM_SDEV                    = 2;
*/


input string                  InpPaths             = " ========== PATHS =========="; 
input string                  InpIndicatorPath     = "\\b63\\statistics\\"; // INDICATOR FOLDER
input string                  InpSkewFilename      = "skew"; // SKEW FILENAME
input string                  InpSpreadFilename    = "z_score"; // SPREAD FILENAME
input string                  InpSdevFilename      = "std_dev"; // VOLATILITY FILENAME

input string                  InpCFGSource         = " ========== CONFIG SOURCE ==========";
input ENUM_CONFIG_SOURCE      InpConfig            = FILE; // CONFIG SOURCE 

input string                  InpIndicator         = " ========== FEATURE VALUES ========== ";
input int                     InpDayVolWindow      = 10; // DAILY VOLATILITY WINDOW 
input int                     InpDayPeakVolWindow  = 90; // DAILY VOLATILITY PEAK LOOKBACK
input int                     InpNormSpreadWindow  = 10; // NORMALIZED SPREAD LOOKBACK 
input int                     InpNormMAWindow      = 50; // NORMALIZED SPREAD MA LOOKBACK
input int                     InpSkewWindow        = 20; // SKEW LOOKBACK
input int                     InpBBandsWindow      = 14; // BBANDS LOOKBACK
input int                     InpBBandsSlowWindow  = 100; // SLOW BBANDS LOOKBACK
input int                     InpBBandsNumSdev     = 2;  // BBANDS NUM SDEV
input double                  InpZThresh           = 2; // SPREAD THRESHOLD
input double                  InpSkewThresh        = 0.6; // SKEW THRESHOLD


input string                  InpEntry             = " ========== ENTRY WINDOW =========="; //
input int                     InpEntryWindowOpen   = 2; // ENTRY WINDOW OPEN
input int                     InpEntryWindowClose  = 21; // ENTRY WINDOW CLOSE 
input int                     InpTradeDeadline     = 22; // TRADE DEADLINE

input string                  InpRiskMgt           = " ========== RISK MANAGEMENT =========="; 
input double                  InpAcctMaxRiskPct    = 5; // ACCOUNT RISK PERCENT FOR CATASTROPHIC LOSS
input double                  InpAcctTradeRiskPct  = 0.5; // TRADE RISK PERCENT FOR LOT CALCULATION
input int                     InpMinimumSLDistance = 200; // MINIMUM SL DISTANCE (POINTS)


input string                  InpConfigMain        = " ========== SYMBOL CONFIG ========== ";
//input bool                    InpUseConfigCsv      = true; // USE CONFIG CSV
input bool                    InpUsePrevDay        = false; // USE PREVIOUS DAY H/L AS REFERENCE
input double                  InpLowVolThresh      = 0.001; // VOLATILITY LOWER LIMIT
input bool                    InpRoundHourOnly     = false; // TRADE ON ROUND HOUR ONLY
input bool                    InpUseFrequency      = true; // CALCULATE FREQUENCY FROM INPUT OR TIMEFRAME
input ENUM_FREQUENCY          InpFrequency         = HALF; // FREQUENCY
input int                     InpMagic             = 232323; // MAGIC NUMBER
input string                  InpTradingDays       = " ========== TRADING DAYS ========== ";
input string                  InpDaysString        = "0,1,2,3,4";


input string                  InpRiskProfile       = " ========== RISK PROFILE =========="; // 
input ENUM_TIMEFRAMES         InpRPTimeframe       = PERIOD_M15; // RISK PROFILE: TIMEFRAME
/*
input ENUM_ORDER_SEND_METHOD  InpRPOrderSendMethod = MODE_PENDING; // RISK PROFILE: ORDER SEND METHOD
input ENUM_POSITIONS          InpRPPositions       = MODE_SINGLE; // RISK PROFILE: POSITIONS
input ENUM_LAYER_ORDERS       InpRPLayerOrders     = MODE_UNIFORM; // RISK PROFILE: LAYER ORDERS
input int                     InpRPSpreadLimit     = 10; // RISK PROFILE: SPREAD: Spread Required to use market order instead of pending order
input int                     InpRPTradeLimit      = 2; // MAX NUMBER OF POSITIONS PER DAY*/



/*
input string                  InpLayers            = " ========== LAYERS ========== ";
input int                     InpNumLayers         = 2; // NUMBER OF LAYERS
input double                  InpPrimaryAllocation = 0.6; // LOT ALLOCATION OF TOTAL VOLUME DESIGNATED FOR PRIMARY POSITION
input ENUM_LAYER_MANAGEMENT   InpLayerManagement   = MODE_SECURE; // LAYER MANAGEMENT

*/


/*
input float                   InpAllocation        = 1; // ALLOCATION
input ENUM_TRADE_MANAGEMENT   InpTradeMgt          = MODE_NONE; // TRADE MANAGEMENT
input float                   InpTrailInterval     = 100; // TRAILING STOP INTERVAL
input double                  InpCutoff            = 0.85; // EQUITY CUTOFF
input float                   InpMaxLot            = 1; // MAX LOT
input float                   InpDDScale           = 0.5; // DRAWDOWN SCALING
input float                   InpAbsDDThresh       = 10; // ABSOLUTE DRAWDOWN THRESHOLD
input double                  InpEquityDDThresh    = 5; // EQUITY DRAWDOWN THRESHOLD
*/
input string                  InpMisc              = " ========== MISC ==========";
input bool                    InpShowUI            = false; // SHOW UI
input bool                    InpTradeOnNews       = false; // TRADE ON NEWS
input Source                  InpNewsSource        = R4F_WEEKLY; // NEWS SOURCE

input string                  InpLogging           = " ========== LOGGING =========";
input bool                    InpTerminalMsg       = true; // TERMINAL LOGGING 
input bool                    InpPushNotifs        = false; // PUSH NOTIFICATIONS
input bool                    InpDebugLogging      = true; // DEBUG LOGGING





// Syntax: <Abbreviation>-<Date Deployed>-<Base Version>
// DO NOT CHANGE

const string   EA_ID                = "RCRV-030424-1";
const string   FXFACTORY_DIRECTORY  = "recurve\\ff_news";
const string   R4F_DIRECTORY        = "recurve\\r4f_news";
const string   INDICATOR_DIRECTORY  = "\\b63\\statistics\\";
const string   CONFIG_DIRECTORY     = "recurve\\config.csv";
const string   SETTINGS_DIRECTORY   = "recurve\\settings\\";
const string   SYMBOLS_DIRECTORY    = "recurve\\symbols\\";
// DAY OF WEEK 0 - Sunday, 1, 2, 3, 4, 5, 6

