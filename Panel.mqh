/*
TEMPORARY SETUP
*/

#include "definition.mqh"

#define     INDENT_X       10 
#define     GAP_Y          7



class CInfoPanel : public CAppDialog {
   public: 
                     CInfoPanel();
                     ~CInfoPanel();
               
               CLabel   day_vol_lbl, peak_vol_lbl, spread_lbl, spread_ma_lbl, skew_lbl, bbands_lbl, bbands_sdev_lbl, bbands_slow_lbl, spread_thresh_lbl, skew_thresh_lbl, window_open_lbl, window_close_lbl, deadline_lbl, catloss_lbl, rpt_lbl, min_sl_dist_lbl; 
               CLabel   days_lbl, intervals_lbl, low_vol_lbl, use_pd_lbl, sl_lbl; 
      
      //--- create
      virtual  bool  Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2); 
      virtual  void  Minimize(void); 
      
      //--- chart event handler 
      //virtual  bool  OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam); 
      
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
   if (!RowCreate(sl_lbl, "sl", CONFIG.sl, 22)) return false; 
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

void        CInfoPanel::Minimize(void) {
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long chart_width  = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); 
   int height  = MathAbs(m_min_rect.top - m_min_rect.bottom); 
   int lower_indent  = 5;
   m_min_rect.top = chart_height - (int)height - lower_indent; 
   m_min_rect.bottom = m_min_rect.top + height;
   CAppDialog::Minimize();
}


class CTradePanel : public CAppDialog {
   public:
      CTradePanel();
      ~CTradePanel();
      
      CLabel   var_lbl, cat_var_lbl, day_vol_lbl, day_of_week_lbl, long_lbl, short_lbl; 
      //--- create
      virtual  bool  Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2); 
      virtual  void  Minimize(void); 
      
      template <typename T>   bool  RowCreate(CLabel &lbl, string key, T value, int row_number); 
};

CTradePanel::CTradePanel(void) {}

CTradePanel::~CTradePanel(void) {} 

bool        CTradePanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2) {
   if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false;  
   if (!RowCreate(var_lbl, "var", RISK.var, 1)) return false; 
   if (!RowCreate(cat_var_lbl, "cat_var", RISK.cat_var, 2)) return false; 
   if (!RowCreate(day_vol_lbl, "valid_day_vol", RISK.valid_day_vol, 3)) return false; 
   if (!RowCreate(day_of_week_lbl, "valid_day_of_week", RISK.valid_day_of_week, 4)) return false;
   if (!RowCreate(long_lbl, "valid_long", RISK.valid_long, 5)) return false; 
   if (!RowCreate(short_lbl, "valid_short", RISK.valid_short, 6)) return false; 
   return true;
}



template <typename T> 
bool        CTradePanel::RowCreate(CLabel &lbl,string key,T value,int row_number) {
   string label_string     = StringFormat("%s: %s", key, (string)value); 
   int y1   = row_number * (CONTROLS_FONT_SIZE + GAP_Y); 
   if (!lbl.Create(0, key, 0, INDENT_X, y1, 50, 10)) return false; 
   if (!lbl.Text(label_string)) return false;
   if (!Add(lbl)) return false;
   return true; 
}

void        CTradePanel::Minimize(void) {
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long chart_width  = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); 
   int height  = MathAbs(m_min_rect.top - m_min_rect.bottom); 
   int width = MathAbs(m_min_rect.left - m_min_rect.right); 
   int lower_indent  = 5;
   int horiz_indent  = 10;
   m_min_rect.top = chart_height - (int)height - lower_indent; 
   m_min_rect.bottom = m_min_rect.top + height;
   m_min_rect.left   = horiz_indent + width; 
   m_min_rect.right  = m_min_rect.left + width; 
   CAppDialog::Minimize(); 
}


class CFeaturePanel : public CAppDialog {
   public:
      CFeaturePanel();
      ~CFeaturePanel();
      
      CLabel   ind_spread_lbl, ind_skew_lbl, ind_day_vol_lbl, ind_peak_lbl; 
      double   m_spread, m_skew, m_day_vol, m_peak_vol; 
      //--- create
      virtual  bool  Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2); 
      virtual  void  Minimize(void); 
      
      template <typename T>   bool  RowCreate(CLabel &lbl, string key, T value, int row_number); 
      void     Update(); 
};

CFeaturePanel::CFeaturePanel(void) {
   Update(); 
}

CFeaturePanel::~CFeaturePanel(void) {}

void        CFeaturePanel::Update(void) {
   m_spread    = FEATURE.standard_score_value;
   m_skew      = FEATURE.skew_value;
   m_day_vol   = FEATURE.day_vol;
   m_peak_vol  = FEATURE.peak_day_vol; 
}
bool        CFeaturePanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2) {
   if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false; 
   //Print(FEATURE.peak_day_vol); 
   if (!RowCreate(ind_spread_lbl, "read_spread", NormalizeDouble(m_spread, 5), 1)) return false;
   
   if (!RowCreate(ind_skew_lbl, "read_skew", NormalizeDouble(m_skew, 5), 2)) return false; 
   
   if (!RowCreate(ind_day_vol_lbl, "read_day_vol", NormalizeDouble(m_day_vol, 5), 3)) return false; 
   if (!RowCreate(ind_peak_lbl, "read_peak_vol", NormalizeDouble(m_peak_vol, 5), 4)) return false; 
   return true;
}



template <typename T> 
bool        CFeaturePanel::RowCreate(CLabel &lbl,string key,T value,int row_number) {
   string label_string     = StringFormat("%s: %s", key, (string)value); 
   int y1   = row_number * (CONTROLS_FONT_SIZE + GAP_Y); 
   if (!lbl.Create(0, key, 0, INDENT_X, y1, 50, 10)) return false; 
   
   if (!lbl.Text(label_string)) return false;
   
   if (!Add(lbl)) return false;
   return true; 
}

void        CFeaturePanel::Minimize(void) {
   long chart_height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   long chart_width  = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); 
   int height  = MathAbs(m_min_rect.top - m_min_rect.bottom); 
   int width = MathAbs(m_min_rect.left - m_min_rect.right); 
   int lower_indent  = 5;
   int horiz_indent  = 10;
   m_min_rect.top = chart_height - (int)height - lower_indent; 
   m_min_rect.bottom = m_min_rect.top + height;
   m_min_rect.left   = horiz_indent + (2*width); 
   m_min_rect.right  = m_min_rect.left + width; 
   CAppDialog::Minimize(); 
}
