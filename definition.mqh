
#include <MAIN/CalendarDownloader.mqh> 
#include <MAIN/utilities.mqh>



// ========== ENUM ========== // 

enum ENUM_DIRECTION {
   LONG, SHORT, INVALID
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

/*
z score threshold = 2.1 
sl pips = 20 
entry window = 10-13 
close time = 20 
high volatility threshold = 0.012 
low volatility threshold = 0.001

daily sdev length = 10 
spread length = 20
*/

input string                  InpRiskProfile       = " ========== RISK PROFILE =========="; // 
input float                   InpRPDeposit         = 100000; // RISK PROFILE: DEPOSIT
input float                   InpRPRiskPercent     = 1; // RISK PROFILE: RISK PERCENT
input float                   InpRPLot             = 10; // RISK PROFILE: LOT
input ENUM_TIMEFRAMES         InpRPTimeframe       = PERIOD_M30; // RISK PROFILE: TIMEFRAME
input ENUM_ORDER_SEND_METHOD  InpRPOrderSendMethod = MODE_PENDING; // RISK PROFILE: ORDER SEND METHOD
input ENUM_POSITIONS          InpRPPositions       = MODE_SINGLE; // RISK PROFILE: POSITIONS
input ENUM_LAYER_ORDERS       InpRPLayerOrders     = MODE_UNIFORM; // RISK PROFILE: LAYER ORDERS
input int                     InpRPSpreadLimit     = 10; // RISK PROFILE: SPREAD: Spread Required to use market order instead of pending order
input int                     InpRPTradeLimit      = 2; // MAX NUMBER OF POSITIONS PER DAY
input double                  InpRPMinRiskReward   = 2; // MIN RISK REWARD RATIO


input string                  InpIndicator         = " ========== INDICATOR VALUES ========== ";
input double                  InpZThresh           = 2.1; // SPREAD THRESHOLD
input int                     InpZLookback         = 20; // SPREAD LOOKBACK PERIOD 
input double                  InpHighVolThresh     = 0.012; // VOLATILITY UPPER LIMIT
input double                  InpLowVolThresh      = 0.001; // VOLATILITY LOWER LIMIT
input int                     InpVolLookback       = 10; // VOLATILITY LOOKBACK PERIOD
input string                  InpIndicatorPath     = "\\b63\\statistics\\"; // INDICATOR FOLDER
input string                  InpSpreadFilename    = "day_spread"; // SPREAD FILENAME
input string                  InpSdevFilename      = "std_dev"; // VOLATILITY FILENAME


input string                  InpEntry             = " ========== ENTRY WINDOW =========="; //
input int                     InpEntryWindowOpen   = 10; // ENTRY WINDOW OPEN
input int                     InpEntryWindowClose  = 13; // ENTRY WINDOW CLOSE 
input int                     InpTradeDeadline     = 19; // TRADE DEADLINE

input string                  InpLayers            = " ========== LAYERS ========== ";
input int                     InpNumLayers         = 2; // NUMBER OF LAYERS
input double                  InpPrimaryAllocation = 0.6; // LOT ALLOCATION OF TOTAL VOLUME DESIGNATED FOR PRIMARY POSITION
input ENUM_LAYER_MANAGEMENT   InpLayerManagement   = MODE_SECURE; // LAYER MANAGEMENT

input string                  InpRiskMgt           = " ========== RISK MANAGEMENT =========="; 
input float                   InpAccountDeposit    = 100000; // ACCOUNT DEPOSIT
input float                   InpAccountRiskPct    = 1; // ACCOUNT RISK PERCENT 
input float                   InpAllocation        = 1; // ALLOCATION
input int                     InpSLPoints          = 200; // SL POINTS
input ENUM_TRADE_MANAGEMENT   InpTradeMgt          = MODE_NONE; // TRADE MANAGEMENT
input float                   InpTrailInterval     = 100; // TRAILING STOP INTERVAL
input double                  InpCutoff            = 0.85; // EQUITY CUTOFF
input float                   InpMaxLot            = 1; // MAX LOT
input ENUM_POSITION_SIZING    InpSizing            = MODE_DYNAMIC; // POSITION SIZING
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
input bool                    InpDebugLogging      = false; // DEBUG LOGGING





// Syntax: <Abbreviation>-<Date Deployed>-<Base Version>
// DO NOT CHANGE

const string   EA_ID                = "RCRV-030424-1";
const string   FXFACTORY_DIRECTORY  = "recurve\\ff_news";
const string   R4F_DIRECTORY        = "recurve\\r4f_news";
const string   INDICATOR_DIRECTORY  = "\\b63\\statistics\\";

// DAY OF WEEK 0 - Sunday, 1, 2, 3, 4, 5, 6