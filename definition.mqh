
#include <MAIN/CalendarDownloader.mqh> 
#include <MAIN/utilities.mqh>



// ========== ENUM ========== // 

enum ENUM_DIRECTION {
   LONG, SHORT, INVALID
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
/*
   double normalized_spread   = STANDARD_SCORE();
   double skew                = SKEW(); 
   
   double last_high           = UTIL_CANDLE_HIGH(1); 
   double last_low            = UTIL_CANDLE_LOW(1);
   
   double upper_bands         = UPPER_BANDS();
   double lower_bands         = LOWER_BANDS();
   
   double extreme_upper       = EXTREME_UPPER();
   double extreme_lower       = EXTREME_LOWER();
*/

   double standard_score_value, skew_value, last_candle_high, last_candle_low, last_candle_close;
   
   double upper_bands, lower_bands, extreme_upper, extreme_lower, slow_upper, slow_lower; 

} FEATURE;

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

input string                  InpRiskProfile       = " ========== RISK PROFILE =========="; // 
input ENUM_TIMEFRAMES         InpRPTimeframe       = PERIOD_M15; // RISK PROFILE: TIMEFRAME
input ENUM_ORDER_SEND_METHOD  InpRPOrderSendMethod = MODE_PENDING; // RISK PROFILE: ORDER SEND METHOD
input ENUM_POSITIONS          InpRPPositions       = MODE_SINGLE; // RISK PROFILE: POSITIONS
input ENUM_LAYER_ORDERS       InpRPLayerOrders     = MODE_UNIFORM; // RISK PROFILE: LAYER ORDERS
input int                     InpRPSpreadLimit     = 10; // RISK PROFILE: SPREAD: Spread Required to use market order instead of pending order
input int                     InpRPTradeLimit      = 2; // MAX NUMBER OF POSITIONS PER DAY

input string                  InpIndicator         = " ========== INDICATOR VALUES ========== ";
input bool                    InpUsePrevDay        = false; // USE PREVIOUS DAY H/L AS REFERENCE
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
input double                  InpLowVolThresh      = 0.001; // VOLATILITY LOWER LIMIT
input string                  InpIndicatorPath     = "\\b63\\statistics\\"; // INDICATOR FOLDER
input string                  InpSkewFilename      = "skew"; // SKEW FILENAME
input string                  InpSpreadFilename    = "z_score"; // SPREAD FILENAME
input string                  InpSdevFilename      = "std_dev"; // VOLATILITY FILENAME


input string                  InpEntry             = " ========== ENTRY WINDOW =========="; //
input int                     InpEntryWindowOpen   = 2; // ENTRY WINDOW OPEN
input int                     InpEntryWindowClose  = 21; // ENTRY WINDOW CLOSE 
input int                     InpTradeDeadline     = 22; // TRADE DEADLINE
input bool                    InpRoundHourOnly     = true; // TRADE ON ROUND HOUR ONLY

input string                  InpLayers            = " ========== LAYERS ========== ";
input int                     InpNumLayers         = 2; // NUMBER OF LAYERS
input double                  InpPrimaryAllocation = 0.6; // LOT ALLOCATION OF TOTAL VOLUME DESIGNATED FOR PRIMARY POSITION
input ENUM_LAYER_MANAGEMENT   InpLayerManagement   = MODE_SECURE; // LAYER MANAGEMENT

input string                  InpTradingDays       = " ========== TRADING DAYS ========== ";
input bool                    InpMonday            = true; 
input bool                    InpTuesday           = true; 
input bool                    InpWednesday         = true; 
input bool                    InpThursday          = true; 
input bool                    InpFriday            = true; 

input string                  InpRiskMgt           = " ========== RISK MANAGEMENT =========="; 
input double                  InpAcctMaxRiskPct    = 1; // ACCOUNT RISK PERCENT FOR CATASTROPHIC LOSS
input double                  InpAcctTradeRiskPct  = 0.25; // TRADE RISK PERCENT FOR LOT CALCULATION
input int                     InpMinimumSLDistance = 200; // MINIMUM SL DISTANCE (POINTS)
input float                   InpAllocation        = 1; // ALLOCATION
input ENUM_TRADE_MANAGEMENT   InpTradeMgt          = MODE_NONE; // TRADE MANAGEMENT
input float                   InpTrailInterval     = 100; // TRAILING STOP INTERVAL
input double                  InpCutoff            = 0.85; // EQUITY CUTOFF
input float                   InpMaxLot            = 1; // MAX LOT
input float                   InpDDScale           = 0.5; // DRAWDOWN SCALING
input float                   InpAbsDDThresh       = 10; // ABSOLUTE DRAWDOWN THRESHOLD
input double                  InpEquityDDThresh    = 5; // EQUITY DRAWDOWN THRESHOLD

input string                  InpMisc              = " ========== MISC ==========";
input int                     InpMagic             = 232323; // MAGIC NUMBER
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

// DAY OF WEEK 0 - Sunday, 1, 2, 3, 4, 5, 6


/*
Symbol: AUDUSD WR: 0.56197 Days: [0, 1, 2, 3] Low Vol: 0.00442 Spread Thresh: 1.98719 Min: 0.00133
Symbol: EURUSD WR: 0.58654 Days: [0, 1, 3, 4] Low Vol: 0.00522 Spread Thresh: 1.98704 Min: 0.00160
Symbol: GBPUSD WR: 0.60247 Days: [2, 3, 4] Low Vol: 0.00719 Spread Thresh: 1.98556 Min: 0.00209
Symbol: USDCAD WR: 0.59815 Days: [1, 2, 3, 4] Low Vol: 0.00574 Spread Thresh: 1.99082 Min: 0.00111
Symbol: USDCHF WR: 0.59612 Days: [0, 1, 2, 3, 4] Low Vol: 0.00459 Spread Thresh: 1.99105 Min: 0.00115
Symbol: AUDCAD WR: 0.54098 Days: [0, 2, 3] Low Vol: 0.00414 Spread Thresh: 1.98321 Min: 0.00111
Symbol: AUDCHF WR: 0.56503 Days: [0, 1, 2, 4] Low Vol: 0.00408 Spread Thresh: 1.98752 Min: 0.00084
Symbol: AUDNZD WR: 0.55449 Days: [0, 3, 4] Low Vol: 0.00412 Spread Thresh: 1.98715 Min: 0.00071
Symbol: CADCHF WR: 0.58285 Days: [0, 1, 3, 4] Low Vol: 0.00383 Spread Thresh: 1.98489 Min: 0.00110
Symbol: EURAUD WR: 0.57489 Days: [0, 1, 2, 3, 4] Low Vol: 0.00800 Spread Thresh: 1.98840 Min: 0.00223
Symbol: EURCAD WR: 0.52645 Days: [0, 2, 4] Low Vol: 0.00680 Spread Thresh: 1.98739 Min: 0.00187
Symbol: EURCHF WR: 0.58486 Days: [0, 3, 4] Low Vol: 0.00318 Spread Thresh: 1.99209 Min: 0.00064
Symbol: EURGBP WR: 0.57477 Days: [0, 1, 2, 3, 4] Low Vol: 0.00376 Spread Thresh: 1.99097 Min: 0.00098
Symbol: EURNZD WR: 0.58630 Days: [1, 2, 3] Low Vol: 0.00858 Spread Thresh: 1.98485 Min: 0.00141
Symbol: GBPAUD WR: 0.56052 Days: [0, 1, 2, 3, 4] Low Vol: 0.01006 Spread Thresh: 1.98676 Min: 0.00286
Symbol: GBPCAD WR: 0.57455 Days: [0, 1, 3, 4] Low Vol: 0.00878 Spread Thresh: 1.98976 Min: 0.00244
Symbol: GBPCHF WR: 0.51812 Days: [1, 4] Low Vol: 0.00692 Spread Thresh: 1.98773 Min: 0.00139
Symbol: GBPNZD WR: 0.54211 Days: [1, 2, 3] Low Vol: 0.01088 Spread Thresh: 1.98620 Min: 0.00275
Symbol: NZDCAD WR: 0.56195 Days: [0, 1, 2, 3, 4] Low Vol: 0.00440 Spread Thresh: 1.98754 Min: 0.00131
Symbol: NZDCHF WR: 0.59877 Days: [2, 3, 4] Low Vol: 0.00376 Spread Thresh: 1.98717 Min: 0.00069
Symbol: NZDUSD WR: 0.56856 Days: [0, 1, 2, 3, 4] Low Vol: 0.00429 Spread Thresh: 1.98572 Min: 0.00107
Symbol: USDSGD WR: 0.54213 Days: [0, 1, 3] Low Vol: 0.00389 Spread Thresh: 1.98354 Min: 0.00079
*/