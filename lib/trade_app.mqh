
#include "dependencies/definition.mqh"


class CDataPanel : public CAppDialog {
   private:
   public:
      CDataPanel();
      ~CDataPanel(); 
      
      template <typename T>   bool  RowCreate(CLabel &lbl, string key, T value, int row_number);
      
};


CDataPanel::CDataPanel(void) {}
CDataPanel::~CDataPanel(void) {}

template <typename T> 
bool        CDataPanel::RowCreate(CLabel &lbl,string key,T value,int row_number) {
   string label_string  = StringFormat("%s: %s", key, (string)value); 
   int y1   = row_number * (CONTROLS_FONT_SIZE + GAP_Y); 
   if (!lbl.Create(0, key, 0, INDENT_X, y1, 50, 10)) return false; 
   if (!lbl.Text(label_string)) return false; 
   if (!Add(lbl)) return false; 
   return true; 
}

class CFeaturePanel : public CDataPanel {
   private:
               string   name; 
               CLabel   day_vol_lbl, peak_vol_lbl, spread_lbl, spread_ma_lbl, skew_lbl, bbands_lbl, bbands_sdev_lbl, bbands_slow_lbl, spread_thresh_lbl, skew_thresh_lbl; 
                 
   public:
      CFeaturePanel() { name = "Features"; }
      ~CFeaturePanel() {}           
      
               string   NAME()      { return name; }
      virtual  bool     Create(); 
      virtual  void     Destroy();
      
}; 


bool        CFeaturePanel::Create(void) {
   
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
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
   
   return true; 
}


class CEntryPanel : public CDataPanel {
   private:
               string   name; 
               CLabel   window_open_lbl, window_close_lbl, deadline_lbl; 
   public:
      CEntryPanel() { name = "Entry"; }
      ~CEntryPanel() {}
               
               string   NAME()      { return name; }
      virtual  bool     Create(); 
}; 

bool        CEntryPanel::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(window_open_lbl, "window_open", FEATURE_CONFIG.ENTRY_WINDOW_OPEN, 1)) return false; 
   if (!RowCreate(window_close_lbl, "window_close", FEATURE_CONFIG.ENTRY_WINDOW_CLOSE, 2)) return false; 
   if (!RowCreate(deadline_lbl, "deadline", FEATURE_CONFIG.TRADE_DEADLINE, 3)) return false; 
   return true; 
}

class CRiskPanel : public CDataPanel {
   private:
               string   name; 
               CLabel   catloss_lbl, rpt_lbl, min_sl_dist_lbl; 
   
   public:
      CRiskPanel() { name = "Risk"; }
      ~CRiskPanel() {} 
      
               string   NAME()   { return name; }
      virtual  bool     Create(); 
}; 
bool        CRiskPanel::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(catloss_lbl, "catloss", FEATURE_CONFIG.CATLOSS, 1)) return false; 
   if (!RowCreate(rpt_lbl, "rpt", FEATURE_CONFIG.RPT, 2)) return false; 
   if (!RowCreate(min_sl_dist_lbl, "min_sl_dist", FEATURE_CONFIG.MIN_SL_DISTANCE, 3)) return false;
   return true; 
}

class CSymbolPanel : public CDataPanel {
   private:
               string   name;
               CLabel   days_lbl, intervals_lbl, low_vol_lbl, use_pd_lbl, sl_lbl; 
               
   public:
      CSymbolPanel() { name = "Symbol"; }
      ~CSymbolPanel() {}
      
               string   NAME()   { return name; }
      virtual  bool     Create(); 
};

bool        CSymbolPanel::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(days_lbl, "days", CONFIG.days_string, 1)) return false; 
   if (!RowCreate(intervals_lbl, "intervals", CONFIG.intervals_string, 2)) return false;
   if (!RowCreate(low_vol_lbl, "low_vol", CONFIG.low_volatility_thresh, 3)) return false; 
   if (!RowCreate(use_pd_lbl, "use_pd", CONFIG.use_pd, 4)) return false; 
   if (!RowCreate(sl_lbl, "sl", CONFIG.sl, 5)) return false; 
   return true; 
}
 
class CVARPanel : public CDataPanel {
   private:
               string   name;
               CLabel   var_lbl, cat_var_lbl, day_vol_lbl, day_of_week_lbl, long_lbl, short_lbl; 
   public:
      CVARPanel() { name = "VAR"; }
      ~CVARPanel() {}
      
               string   NAME()   { return name; }
      virtual  bool     Create();
};

bool        CVARPanel::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(var_lbl, "var", NormalizeDouble(RISK.var, 2), 1)) return false; 
   if (!RowCreate(cat_var_lbl, "cat_var", NormalizeDouble(RISK.cat_var, 2), 2)) return false; 
   if (!RowCreate(day_vol_lbl, "valid_day_vol", RISK.valid_day_vol, 3)) return false; 
   if (!RowCreate(day_of_week_lbl, "valid_day_of_week", RISK.valid_day_of_week, 4)) return false;
   if (!RowCreate(long_lbl, "valid_long", RISK.valid_long, 5)) return false; 
   if (!RowCreate(short_lbl, "valid_short", RISK.valid_short, 6)) return false; 
   return true; 
}

class CLatestValues : public CDataPanel {
   private:
                  string   name; 
                  double   m_spread, m_skew, m_day_vol, m_peak_vol; 
                  CLabel   ind_spread_lbl, ind_skew_lbl, ind_day_vol_lbl, ind_peak_lbl; 
   public:
      CLatestValues();
      ~CLatestValues() {}
               
               string   NAME()   { return name; }
      virtual  bool     Create();
         
               void     Update(); 
}; 

CLatestValues::CLatestValues(void) {
   name = "Latest";
   Update();
}

void        CLatestValues::Update(void) {
   m_spread    = FEATURE.standard_score_value;
   m_skew      = FEATURE.skew_value;
   m_day_vol   = FEATURE.day_vol;
   m_peak_vol  = FEATURE.peak_day_vol; 
}

bool        CLatestValues::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH;
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(ind_spread_lbl, "read_spread", DoubleToString(m_spread, 5), 1)) return false;
   if (!RowCreate(ind_skew_lbl, "read_skew", DoubleToString(m_skew, 5), 2)) return false; 
   if (!RowCreate(ind_day_vol_lbl, "read_day_vol", NormalizeDouble(m_day_vol, 5), 3)) return false; 
   if (!RowCreate(ind_peak_lbl, "read_peak_vol", NormalizeDouble(m_peak_vol, 5), 4)) return false;
   return true; 
}

class CAccountsPanel : public CDataPanel {
   private:
               string   name; 
               double   m_pl_today, m_deposit, m_start_bal_today, m_gain_today;
               int      m_symbol_trades_today; 
               CLabel   acc_pl_lbl, acc_deposit_lbl, acc_start_bal_lbl, acc_symbol_trades_lbl, acc_gain_lbl; 
   public:
      CAccountsPanel(); 
      ~CAccountsPanel() {}
               
               string   NAME()   const { return name; }
      virtual  bool     Create();
               void     Update(); 
};

CAccountsPanel::CAccountsPanel(void) {
   name = "Accounts"; 
   Update(); 
}


void     CAccountsPanel::Update(void) {
   m_pl_today              = ACCOUNT_HIST.pl_today;
   m_deposit               = ACCOUNT_HIST.deposit;
   m_start_bal_today       = ACCOUNT_HIST.start_bal_today;
   m_symbol_trades_today   = ACCOUNT_HIST.symbol_trades_today; 
   m_gain_today            = ACCOUNT_HIST.gain_today;
}

bool     CAccountsPanel::Create(void) {
   int panel_y2 = SUBPANEL_Y + SUBPANEL_HEIGHT;
   int panel_x2 = SUBPANEL_X + SUBPANEL_WIDTH; 
   
   if (!CAppDialog::Create(0, name, 0, SUBPANEL_X, SUBPANEL_Y, panel_x2, panel_y2)) return false; 
   if (!RowCreate(acc_deposit_lbl, "deposit", DoubleToString(m_deposit, 2), 1)) return false; 
   if (!RowCreate(acc_start_bal_lbl, "start_bal", DoubleToString(m_start_bal_today, 2), 2)) return false; 
   if (!RowCreate(acc_symbol_trades_lbl, "trades", m_symbol_trades_today, 3)) return false; 
   if (!RowCreate(acc_pl_lbl, "pl", DoubleToString(m_pl_today, 2), 4)) return false;
   if (!RowCreate(acc_gain_lbl, "gain", DoubleToString(m_gain_today, 2)+"%", 5)) return false; 
   
   return true; 
}



CFeaturePanel        feature_panel; 
CEntryPanel          entry_panel; 
CRiskPanel           risk_panel; 
CSymbolPanel         symbol_panel;
CVARPanel            var_panel;
CLatestValues        latest_values_panel; 
CAccountsPanel       accounts_panel; 

class CRecurveApp : public CAppDialog {
   protected:
   private:
      CButton           m_feature_bt, m_entry_wnd_bt, m_risk_bt, m_symb_bt, m_var_bt, m_latest_vals_bt, m_accounts_bt; 
      CAppDialog        *ActiveDialog; 
      CLogging          *Log;
   public: 
                        CRecurveApp();
                        ~CRecurveApp(); 
                        
               void     Init();
               
      virtual  bool     Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2); 
      virtual  bool     ButtonCreate(CButton &bt, const string name, const int x1, const int y1); 
      
               void     OnClickFeature();
               void     OnClickEntryWindow();
               void     OnClickRisk();
               void     OnClickSymbolConfig();
               void     OnClickVAR();
               void     OnClickLatestValues(); 
               void     OnClickAccounts(); 
               
               string   ActiveName(); 
               void     CloseActiveWindow(); 
               bool     PageIsOpen(string panel_name); 
      
      template <typename T> bool OpenPage(T &Page); 
               
      EVENT_MAP_BEGIN(CRecurveApp)
      ON_EVENT(ON_CLICK, m_feature_bt, OnClickFeature);
      ON_EVENT(ON_CLICK, m_entry_wnd_bt, OnClickEntryWindow); 
      ON_EVENT(ON_CLICK, m_risk_bt, OnClickRisk); 
      ON_EVENT(ON_CLICK, m_symb_bt, OnClickSymbolConfig);
      ON_EVENT(ON_CLICK, m_var_bt, OnClickVAR); 
      ON_EVENT(ON_CLICK, m_latest_vals_bt, OnClickLatestValues); 
      ON_EVENT(ON_CLICK, m_accounts_bt, OnClickAccounts); 
      EVENT_MAP_END(CAppDialog) 
}; 

CRecurveApp::CRecurveApp(void) {
   Log   = new CLogging(InpTerminalMsg, InpPushNotifs, false); 
}

CRecurveApp::~CRecurveApp(void) {
   delete Log;
   Destroy();
}

void        CRecurveApp::Init(void) {
   Create(0, "Recurve App", 0, MAIN_PANEL_X1, MAIN_PANEL_Y1, MAIN_PANEL_X2, MAIN_PANEL_Y2); 
   Run(); 
}

bool        CRecurveApp::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2) {
   if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false;  
   if (!ButtonCreate(m_feature_bt, "Feature", COLUMN_1, ROW_1)) return false; 
   if (!ButtonCreate(m_entry_wnd_bt, "Entry Window", COLUMN_1, ROW_2)) return false; 
   if (!ButtonCreate(m_risk_bt, "Risk", COLUMN_2, ROW_1)) return false; 
   if (!ButtonCreate(m_symb_bt, "Symbol Config", COLUMN_2, ROW_2)) return false; 
   if (!ButtonCreate(m_var_bt, "VAR", COLUMN_3, ROW_1)) return false; 
   if (!ButtonCreate(m_latest_vals_bt, "Latest Values", COLUMN_3, ROW_2)) return false; 
   if (!ButtonCreate(m_accounts_bt, "Accounts", COLUMN_1, ROW_3)) return false; 
   return true; 
}

bool        CRecurveApp::ButtonCreate(CButton &bt,const string name,const int x1,const int y1) {
   int x_1 = x1 + BUTTON_WIDTH;
   int y_1 = y1 + BUTTON_HEIGHT; 
   if (!bt.Create(0, name, 0, x1, y1, x_1, y_1))     return false; 
   if (!bt.Text(name))                             return false; 
   if (!Add(bt))                                   return false; 
   return true; 
}


void        CRecurveApp::CloseActiveWindow(void) {
   CAppDialog *pt = (CAppDialog*)GetPointer(ActiveDialog); 
   delete ActiveDialog; 
}

string      CRecurveApp::ActiveName(void) {  
   if (CheckPointer(ActiveDialog) == POINTER_INVALID) return ""; 
   //if (ActiveDialog == NULL) return ""; 
   CAppDialog *d  = (CAppDialog*)GetPointer(ActiveDialog); 
   return d.Caption(); 
}

// --- EVENTS 
void        CRecurveApp::OnClickFeature(void) {

   CFeaturePanel *feature  = (CFeaturePanel*)GetPointer(feature_panel); 
   string panel_name = feature.NAME();
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(feature)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 

}
void        CRecurveApp::OnClickEntryWindow(void) {

   CEntryPanel *entry   = (CEntryPanel*)GetPointer(entry_panel); 
   string panel_name = entry.NAME();
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(entry)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 
   
}
void        CRecurveApp::OnClickRisk(void) {
   
   CRiskPanel *risk     = (CRiskPanel*)GetPointer(risk_panel); 
   string panel_name    = risk.NAME(); 
   if (PageIsOpen(panel_name)) return;
   if (!OpenPage(risk)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 
   
}
void        CRecurveApp::OnClickSymbolConfig(void) {

   CSymbolPanel *symbol = (CSymbolPanel*)GetPointer(symbol_panel);
   string panel_name    = symbol.NAME(); 
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(symbol)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 
   
}
void        CRecurveApp::OnClickVAR(void) {
   
   CVARPanel *var       = (CVARPanel*)GetPointer(var_panel);
   string panel_name    = var.NAME(); 
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(var)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 

}
void        CRecurveApp::OnClickLatestValues(void) {
   
   CLatestValues *latest   = (CLatestValues*)GetPointer(latest_values_panel); 
   string panel_name       = latest.NAME(); 
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(latest)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 
   
}

void        CRecurveApp::OnClickAccounts(void) {
   
   CAccountsPanel *accounts = (CAccountsPanel*)GetPointer(accounts_panel); 
   string panel_name        =  accounts.NAME(); 
   if (PageIsOpen(panel_name)) return; 
   if (!OpenPage(accounts)) Log.LogError(StringFormat("Failed to open panel: %s", panel_name), __FUNCTION__); 
}

bool        CRecurveApp::PageIsOpen(string panel_name) {
   string name = ActiveName(); 
   if (CheckPointer(ActiveDialog) != POINTER_INVALID) ActiveDialog.Destroy(1); 
   if (name == panel_name) {
      CloseActiveWindow();
      return true; 
   }
   return false; 
}

template <typename T> 
bool        CRecurveApp::OpenPage(T &Page) {
   if (!Page.Create()) return false;
   Page.Run(); 
   ActiveDialog = Page; 
   return true; 
}