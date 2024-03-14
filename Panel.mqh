
#include "definition.mqh"

#define     INDENT_X       10 
#define     GAP_Y          7



class CInfoPanel : public CAppDialog {
   public: 
                     CInfoPanel();
                     ~CInfoPanel();
               
               CLabel   day_vol_lbl, peak_vol_lbl, spread_lbl, spread_ma_lbl, skew_lbl, bbands_lbl, bbands_sdev_lbl, bbands_slow_lbl, spread_thresh_lbl, skew_thresh_lbl, window_open_lbl, window_close_lbl, deadline_lbl, catloss_lbl, rpt_lbl, min_sl_dist_lbl; 
               CLabel   days_lbl, intervals_lbl, low_vol_lbl, use_pd_lbl; 
      
      //--- create
      virtual  bool  Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2); 
      
      //--- chart event handler 
      //virtual  bool  OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam); 
               bool  Draw(); 
               bool  DrawFeatureConfiguration(); 
      
      template <typename T>   bool  LabelCreate(CLabel &lbl, string key, T value); 
      template <typename T>   bool  RowCreate(CLabel &lbl, string key, T value, int row_number); 
}; 


CInfoPanel::CInfoPanel(void) {}

CInfoPanel::~CInfoPanel(void) {}

bool        CInfoPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2) {
   if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false;
   if (!RowCreate(day_vol_lbl, "daily_vol", FEATURE_CONFIG.DAILY_VOLATILITY_WINDOW, 1)) return false; 
   if (!RowCreate(peak_vol_lbl, "peak_vol", FEATURE_CONFIG.DAILY_VOLATILITY_PEAK_LOOKBACK, 2)) return false; 
   if (!RowCreate(spread_lbl, "spread", FEATURE_CONFIG.NORMALIZED_SPREAD_LOOKBACK, 3)) return false; 
   if (!RowCreate(spread_ma_lbl, "spread_ma", FEATURE_CONFIG.NORMALIZED_SPREAD_MA_LOOKBACK, 4)) return false; 
   if (!RowCreate(skew_lbl, "skew", FEATURE_CONFIG.SKEW_LOOKBACK, 5)) return false; 
   if (!RowCreate(bbands_lbl, "bbands", FEATURE_CONFIG.BBANDS_LOOKBACK, 6)) return false; 
   if (!RowCreate(bbands_sdev_lbl, "bbands_sdev", FEATURE_CONFIG.BBANDS_NUM_SDEV, 7)) return false; 
   if (!RowCreate(bbands_slow_lbl, "bbands_slow", FEATURE_CONFIG.BBANDS_SLOW_LOOKBACK, 8)) return false; 
   if (!RowCreate(spread_thresh_lbl, "spread_thresh", FEATURE_CONFIG.SPREAD_THRESHOLD, 9)) return false; 
   if (!RowCreate(skew_thresh_lbl, "skew_thresh", FEATURE_CONFIG.SKEW_THRESHOLD, 10)) return false; 
   if (!RowCreate(window_open_lbl, "window_open", FEATURE_CONFIG.ENTRY_WINDOW_OPEN, 11)) return false; 
   if (!RowCreate(window_close_lbl, "window_close", FEATURE_CONFIG.ENTRY_WINDOW_CLOSE, 12)) return false; 
   if (!RowCreate(deadline_lbl, "deadline", FEATURE_CONFIG.TRADE_DEADLINE, 13)) return false; 
   if (!RowCreate(catloss_lbl, "catloss", FEATURE_CONFIG.CATLOSS, 14)) return false; 
   if (!RowCreate(rpt_lbl, "rpt", FEATURE_CONFIG.RPT, 15)) return false; 
   if (!RowCreate(min_sl_dist_lbl, "min_sl_dist", FEATURE_CONFIG.MIN_SL_DISTANCE, 16)) return false; 
   
   if (!RowCreate(days_lbl, "days", CONFIG.days_string, 18)) return false; 
   if (!RowCreate(intervals_lbl, "intervals", CONFIG.intervals_string, 19)) return false;
   if (!RowCreate(low_vol_lbl, "low_vol", CONFIG.low_volatility_thresh, 20)) return false; 
   if (!RowCreate(use_pd_lbl, "use_pd", CONFIG.use_pd, 21)) return false; 
   return true; 
}

/*
struct Configuration {
   int      trading_days[]; 
   double   low_volatility_thresh;
   bool     use_pd;
   
   string   days_string, intervals_string; 
} CONFIG;

*/
template <typename T>
bool        CInfoPanel::LabelCreate(CLabel &lbl,string key,T value) {
   string label_string     = StringFormat("%s: %s", key,  (string)value); 
   lbl.Create(0, key, 0, 10, 20, 30, 30); 
   lbl.Text(label_string);
   Add(lbl); 
   return true; 
}

template <typename T>   
bool        CInfoPanel::RowCreate(CLabel &lbl,string key,T value,int row_number) {
   string label_string     = StringFormat("%s: %s", key, (string)value); 
   int y1   = row_number * (CONTROLS_FONT_SIZE + GAP_Y); 
   if (!lbl.Create(0, key, 0, INDENT_X, y1, 50, 10)) return false; 
   if (!lbl.Text(label_string)) return false;
   if (!Add(lbl)) return false;
   return true; 
}

//bool        CInfoPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam) {}