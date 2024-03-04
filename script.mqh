#ifdef __MQL4__ 
#include "trade_mt4.mqh"
#endif

#include <B63/Generic.mqh>
#include <B63/CExport.mqh>
#include <MAIN/Loader.mqh> 
#include "forex_factory.mqh"

CRecurveTrade  recurve_trade;


int OnInit() {

   /*
   CHECK INDICATOR PATH (CALL VALUES ONCE)
   */
   
   
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      int stage = recurve_trade.Stage(); 
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
   }

}


/*
TODOS 

DAILY
Std Dev 10 
Rolling Max 90 

INTRADAY 
standard score (ma = 10, z = 50)
skew (10)
bbands (close, 14, sdev=2)

entry window 4-21
*/

bool     ValidDailyVolatility() {
   
   double daily_volatility = DAY_VOL();
   double daily_peak_vol   = DAY_PEAK_VOL();
   return true; 
}


bool     ValidTradeWindow() {
   int hour = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent()); 
   if (minute != 0) return false; 
   if (hour < 4) return false; 
   if (hour > 21) return false; 
   return true;    
}

int      Signal() {
   double spread_trigger = 2.1;
   double skew_trigger = 0.7;
   
   double normalized_spread = STANDARD_SCORE();
   double skew = SKEW(); 
   
   double last_high = iHigh(NULL, PERIOD_M15, 1);
   double last_low  = iLow(NULL, PERIOD_M15, 1);
   
   double upper_bands = UPPER_BANDS();
   double lower_bands = LOWER_BANDS();
   
   if ((skew > skew_trigger) && (normalized_spread > spread_trigger) && (last_high > upper_bands)) return -1;
   if ((skew < -skew_trigger) && (normalized_spread <- spread_trigger) && (last_low < lower_bands)) return 1; 
   return 0;
   
}

//const string INDICATOR_DIRECTORY = "\\b63\\statistics\\"; 

string indicator_path(string indicator_name) { 
   string path = StringFormat("%s\\%s", INDICATOR_DIRECTORY, indicator_name);
   return path;
}


//enum ENUM_DAILY_VOLATILITY_MODE {
//   MODE_STD_DEV, MODE_ROLLING_MAX_STD_DEV 
//};


const int DAILY_VOLATILITY_WINDOW            = 10;
const int DAILY_VOLATILITY_PEAK_LOOKBACK     = 90;
const int NORMALIZED_SPREAD_LOOKBACK         = 10; 
const int NORMALIZED_SPREAD_MA_LOOKBACK      = 50;
const int SKEW_LOOKBACK                      = 20;
const int BBANDS_LOOKBACK                    = 14;
const int BBANDS_NUM_SDEV                    = 2;

double   DAY_VOL() {
   return DAILY_VOLATILITY(MODE_STD_DEV);
}

double   DAY_PEAK_VOL() {
   return DAILY_VOLATILITY(MODE_ROLLING_MAX_STD_DEV);
}

double   DAILY_VOLATILITY( int volatility_mode, int i = 1)    { 
   return iCustom(NULL, 
      PERIOD_D1, 
      indicator_path("std_dev"), // path 
      DAILY_VOLATILITY_WINDOW,   // sdev window
      DAILY_VOLATILITY_PEAK_LOOKBACK,   // max window
      0,    // shift
      volatility_mode,    // buffer
      i     // shift
      ); 
}


double   STANDARD_SCORE(int i=1) {
   
   return iCustom(NULL,
      PERIOD_M15, 
      indicator_path("z_score"),
      NORMALIZED_SPREAD_LOOKBACK,   // normalization window 
      NORMALIZED_SPREAD_MA_LOOKBACK,   // moving average window 
      0,    // shift
      0,    // buffer 
      i     // shift
   );

}

double   SKEW(int i=1) {
   return iCustom(NULL,
      PERIOD_M15,
      indicator_path("skew"),
      SKEW_LOOKBACK,   // window
      0,    // shift
      0,    // buffer
      i     // shift
   );
}

double   UPPER_BANDS() { 
   return BBANDS(MODE_UPPER);
}

double   LOWER_BANDS() {
   return BBANDS(MODE_LOWER);
}

double   BBANDS(int mode, int i =1) {
   return iBands(NULL,
      PERIOD_M15,
      BBANDS_LOOKBACK,   // bbands period
      BBANDS_NUM_SDEV,    // num sdev 
      0,    // shift
      PRICE_CLOSE, // applied price 
      mode,
      i     // shift
      );
}
