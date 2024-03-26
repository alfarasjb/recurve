
#include <RECURVE/CalendarDownloader.mqh> 
#include <RECURVE/utilities.mqh>
#include <Controls/Defines.mqh> 
#include <Controls/Dialog.mqh>
#include <Controls/Button.mqh>
#include <Controls/Label.mqh>
//#include <MAIN/TradeOps.mqh>
#include "profiles.mqh"
#include "features.mqh"
#include "trade_ops.mqh"
#include "logging.mqh"

#include "pool.mqh"
// ========== DEFINES ========== // 
#undef   CONTROLS_FONT_SIZE 

#define  CONTROLS_FONT_SIZE      8 

#define     INDENT_X       10 
#define     GAP_Y          7

#define     COLUMN_1       10 
#define     COLUMN_2       120 
#define     COLUMN_3       230 

#define     ROW_1          10 
#define     ROW_2          40 
#define     ROW_3          70 

#define     BUTTON_WIDTH   100 
#define     BUTTON_HEIGHT  20 

#define     MAIN_PANEL_X1  10 
#define     MAIN_PANEL_Y1  20
#define     MAIN_PANEL_X2  360 
#define     MAIN_PANEL_Y2  150 

#define     SUBPANEL_X        370 
#define     SUBPANEL_Y        10
#define     SUBPANEL_HEIGHT   210
#define     SUBPANEL_WIDTH    180


// ========== ENUM ========== // 
enum ENUM_CLOSE_REASON {
   STACK, INVERT, TAKE_PROFIT, DEADLINE, CUT
};

enum ENUM_TRADE_LOGIC_ERROR_REASON {
   REASON_GAIN_MGT,
   REASON_DD_MGT,
   REASON_INVERT,
   REASON_WRONG_ORDER_TYPE,
   REASON_ORDER_IN_PROFIT,
   REASON_ORDER_IN_DD,
   REASON_SECURE_CONFIG_FALSE
};

enum ENUM_DIRECTION {
   LONG, SHORT, INVALID
};


enum ENUM_SIGNAL {
   TRADE_LONG, TRADE_SHORT, CUT_LONG, CUT_SHORT, TAKE_PROFIT_LONG, TAKE_PROFIT_SHORT, SIGNAL_NONE
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

enum ENUM_PRESET {
   MODE_AGGRESSIVE, // Aggressive
   MODE_AGGRESSIVE_SECONDARY, // Aggressive Secondary
   MODE_PROP, // Prop 
   MODE_STANDARD // Standard
};

enum ENUM_TRADE_MANAGEMENT {
   MODE_BREAKEVEN, // Breakeven
   MODE_NONE // None
};


enum ENUM_FLOATING_DD_MGT {
   CUT_FLOATING_LOSS, // Cut Losses
   MARTINGALE, // Martingale 
   IGNORE_LOSS // Ignore
};

enum ENUM_FLOATING_GAIN_MGT {
   SECURE_FLOATING_PROFIT, // Secure
   STACK_ON_PROFIT, // Stack
   IGNORE // Ignore
};

enum ENUM_CONFIG_SOURCE {
   FILE, // File
   INPUT // Input
};

enum ENUM_FREQUENCY {
   QUARTER, // QUARTER - 0, 15, 30, 45
   HALF, // HALF - 0, 30
   FULL // FULL - 0
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
   datetime    pos_open_datetime; 
   int         pos_ticket;
   double      pos_open_price, pos_volume, pos_stop_loss, pos_take_profit;
   long        pos_magic; 
   
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
   
   double day_vol, peak_day_vol; 

} FEATURE;


struct Configuration {
   CPoolGeneric<int>TRADING_DAYS; 
   //int      trading_days[]; 
   double   low_volatility_thresh;
   bool     use_pd, secure;
   double   sl; 
   string   days_string, intervals_string; 
} CONFIG;

struct FeatureConfiguration {
   int            DAILY_VOLATILITY_WINDOW, DAILY_VOLATILITY_PEAK_LOOKBACK, NORMALIZED_SPREAD_LOOKBACK, NORMALIZED_SPREAD_MA_LOOKBACK, SKEW_LOOKBACK, BBANDS_LOOKBACK, BBANDS_NUM_SDEV, BBANDS_SLOW_LOOKBACK; 
   double         SPREAD_THRESHOLD, SKEW_THRESHOLD;
   
   int            ENTRY_WINDOW_OPEN, ENTRY_WINDOW_CLOSE, TRADE_DEADLINE; 
   
   double         CATLOSS, RPT;
   
   int            MIN_SL_DISTANCE; 
      
      
   string         INDICATOR_PATH, SKEW_FILENAME, SPREAD_FILENAME, SDEV_FILENAME;
} FEATURE_CONFIG;

struct Risk {
   double   var, cat_var; 
   bool     valid_day_vol, valid_day_of_week, valid_long, valid_short; 
} RISK;


struct TradeObj {

   int      ticket, magic;
   double   open_price, close_price, stop_loss, take_profit, volume, profit; 
   string   symbol, comment; 
   datetime open_time, close_time;  
   ENUM_ORDER_TYPE   order_type;
};

struct AccountHistory {
   int      symbol_trades_today; 
   double   pl_today, deposit, start_bal_today, gain_today;
   
} ACCOUNT_HIST; 
/**
//--- GLOBAL CONFIG ---// 

   InpUseFrequency: bool   
      - Determines how trading frequency / intervals are calculated.
      - Uses inputs if set to true. 
      - Options: See ENUM_FREQUENCY 
   
   InpFrequency: ENUM_FREQUENCY
      - Frequency Choice
      
      
//--- CONFIG SOURCE ---// 

   InpConfig: ENUM_CONFIG_SOURCE
      - Determines the source of configuration. 
      - Uses inputs if set as INPUT. 
      - Loads from file in common directory if set as FILE. 
      - Directories are currently hard coded in InitializeConfigurationPaths() 
   
   InpPreset: ENUM_PRESET
      - Options for risk level. 
      - Choices: Master/Aggressive
      
      
//--- CONSTRAINTS ---// 

   InpIgnoreLowVol: bool
      - Ignores low volatility restrictions. 
      
   InpIgnoreDayOfWeek: bool
      - Ignore day of week restrictions. 
      - Allows trading on all days. 
      
   InpIgnoreIntervals: bool
      - Ignore intervals/frequency restrictions. 
      - Allows trading on all intervals. 
      
   InpUseFixedRisk: bool
      - Uses fixed value for balance for calculating risk per trade. 


//--- SYMBOL CONFIG ---// 

   InpUsePrevDay: bool 
      - Uses previous day h/l as reference for trading.
      - Determined by model parameters. 

   InpLowVolThresh: double 
      - Low volatility threshold
      - Determined by model parameters
       
   InpSL: double 
      - Recommended Stop Loss in ticks. Used if calculated stop loss is too tight. 
      - Determined by model parameters
      
   InpDaysString: string 
      - Day of week to allow trading. 
      - Determined by model parameters 
      
   InpFixedRisk: double
      - Fixed reference balance for calculating lot size. 
      - Used if InpUseFixedRisk is set to true. 

//--- RISK PROFILE ---//

   InpRPTimeframe: ENUM_TIMEFRAMES
      - Specific timeframe to run algo. 
      - Used for validation in case wrong chart timeframe is set. 
   
   InpMagic: int
      - Magic Number 
   
   InpMaxLot: double
      - Maximum allowable lot.
      - Prevent accidental oversizing. 
   
   InpLotScaleFactor: double
      - Manual Scale Factor
   
   InpSecureBuffer: bool
      - Determines if algo will secure a target amount of gain early into the trading session 
      - Ideally, from 0000 to 0800 Server Time 
      
   InpBufferPercent: double
      - Target Required to secure buffer. 
    
      
//--- POSITION MANAGEMENT ---//

   InpFloatingGain: ENUM_FLOATING_GAIN_MGT
      - STACK: Adds to winning positions 
      - SECURE: Closes winning position, and enters on incoming signal 
      - IGNORE: Ignores incoming signal 
   
   InpFloatingDD: ENUM_FLOATING_DD_MGT
      - CUT_FLOATING_LOSS: Cuts floating loss, and enters on incoming signal 
      - MARTINGALE: Adds another layer to floating loss (Warning: Using martingale can lead to catastrophic loss)
   
   InpMaxLayers: int
      - Maximum simultaneous number of martingale layers or stacks. 
      - Prevents overlayering
      
   InpMaxDayTrades: int
      - Maximum trades per symbol, per day.
      - Prevents overtrading. 
      
   InpTradeMgt: ENUM_TRADE_MANGEMENT***
      - MODE_BREAKEVEN: Sets breakeven on threshold
      - MODE_NONE: Nothing 

***NOT YET IMPLEMENTED
**/
input string                  InpGlobal            = "Global Configs: Configs not found in .ini file. "; // ========== GLOBAL CONFIG ========== 
input bool                    InpUseFrequency      = true; // CALCULATE FREQUENCY FROM INPUT OR TIMEFRAME
input ENUM_FREQUENCY          InpFrequency         = HALF; // FREQUENCY
input string                  InpEmpty_1           = ""; //

input string                  InpCFGSource         = "Source for symbol config."; // ========== CONFIG SOURCE ========== 
input ENUM_CONFIG_SOURCE      InpConfig            = FILE; // CONFIG SOURCE 
input ENUM_PRESET             InpPreset            = MODE_AGGRESSIVE; // PRESET 
input string                  InpEmpty_2           = ""; //

input string                  InpConstraints       = "Override settings.ini"; // ========== CONSTRAINTS ========= 
input bool                    InpIgnoreLowVol      = true; // IGNORE LOW VOLATILITY CONSTRAINT
input bool                    InpIgnoreDayOfWeek   = false; // IGNORE DAY OF WEEK 
input bool                    InpIgnoreIntervals   = false; // IGNORE INTERVALS
input bool                    InpUseFixedRisk      = true; // USE FIXED RISK
input string                  InpEmpty_3           = ""; 

input string                  InpConfigMain        = "Main Symbol Config"; // ========== SYMBOL CONFIG ========== 
input bool                    InpUsePrevDay        = false; // USE PREVIOUS DAY H/L AS REFERENCE
input double                  InpLowVolThresh      = 0.001; // VOLATILITY LOWER LIMIT
input double                  InpSL                = 0.00500; // SL 
input string                  InpDaysString        = "0,1,2,3,4"; // DAYS
input double                  InpFixedRisk         = 100; // FIXED REFERENCE FOR CALCULATING LOT SIZE (DEPOSIT) 
input string                  InpEmpty_4           = ""; //


input string                  InpRiskProfile       = "Risk Profile and Trade Ops"; // ========== RISK PROFILE ==========
input ENUM_TIMEFRAMES         InpRPTimeframe       = PERIOD_M15; // RISK PROFILE: TIMEFRAME
input int                     InpMagic             = 232323; // MAGIC NUMBER
input double                  InpMaxLot            = 0.01; // MAX LOT
input double                  InpLotScaleFactor    = 1; // LOT SIZE SCALE FACTOR
input bool                    InpSecureBuffer      = true; // SECURE BUFFER
input double                  InpBufferPercent     = 5; // BUFFER (%)
input int                     InpBufferDeadline    = 8; // BUFFER DEADLINE (HOUR - Server Time)
input string                  InpEmpty_5           = ""; // 

input string                  InpPosMgt            = " Position Management "; // ========== POSITION MANAGEMENT ========== 
input ENUM_FLOATING_GAIN_MGT  InpFloatingGain      = STACK_ON_PROFIT; // FLOATING PROFIT MGT - Model Default - IGNORE
input ENUM_FLOATING_DD_MGT    InpFloatingDD        = IGNORE_LOSS; // FLOATING DD MGT - Model Default - CUT 
input int                     InpMaxLayers         = 2; // MAX STACKS/MARTINGALE LAYERS 
input int                     InpMaxDayTrades      = 3; // MAX TRADES ALLOWED PER DAY PER SYMBOL
input ENUM_TRADE_MANAGEMENT   InpTradeMgt          = MODE_BREAKEVEN; // TRADE MANAGEMENT
input double                  InpBEThreshold       = 1; // BREAKEVEN THRESHOLD (%)
input string                  InpEmpty_6           = ""; //

input string                  InpMisc              = "Misc Settings"; // ========== MISC ==========

input bool                    InpShowUI            = false; // SHOW UI
input bool                    InpTradeOnNews       = false; // TRADE ON NEWS
input Source                  InpNewsSource        = R4F_WEEKLY; // NEWS SOURCE

input bool                    InpTerminalMsg       = true; // TERMINAL LOGGING 
input bool                    InpPushNotifs        = false; // PUSH NOTIFICATIONS
input bool                    InpDebugLogging      = true; // DEBUG LOGGING


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

input float                   InpTrailInterval     = 100; // TRAILING STOP INTERVAL
input double                  InpCutoff            = 0.85; // EQUITY CUTOFF
input float                   InpMaxLot            = 1; // MAX LOT
input float                   InpDDScale           = 0.5; // DRAWDOWN SCALING
input float                   InpAbsDDThresh       = 10; // ABSOLUTE DRAWDOWN THRESHOLD
input double                  InpEquityDDThresh    = 5; // EQUITY DRAWDOWN THRESHOLD
*/





// Syntax: <Abbreviation>-<Date Deployed>-<Base Version>
// DO NOT CHANGE

const string   EA_ID                = "RCRV-030424-1";
const string   FXFACTORY_DIRECTORY  = "recurve\\ff_news";
const string   R4F_DIRECTORY        = "recurve\\r4f_news";
const string   INDICATOR_DIRECTORY  = "\\b63\\statistics\\";
//const string   CONFIG_DIRECTORY     = "recurve\\config.csv"; // DEPRECATED
const string   CONFIG_DIRECTORY     = "recurve\\profiles";
//const string   SETTINGS_DIRECTORY   = "recurve\\settings\\";
const string   REPORTS_DIRECTORY    = "recurve\\reports\\"; 
//const string   SYMBOLS_DIRECTORY    = "recurve\\symbols\\";

// DAY OF WEEK 0 - Sunday, 1, 2, 3, 4, 5, 6

