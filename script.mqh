
#ifdef __MQL4__ 
#include <B63/CExport.mqh>
#endif

#include <B63/Generic.mqh>
#include <RECURVE/Loader.mqh> 
#include "lib/forex_factory.mqh"
#include "dependencies/features.mqh"
#include "lib/trade_app.mqh"
#include "lib/trade_mt4_h.mqh"
CRecurveTrade              recurve_trade;
CCalendarHistoryLoader     calendar_loader;
CNewsEvents                news_events;
CRecurveApp                AppDialog; 
int OnInit() {
   
   
   ObjectsDeleteAll(0, -1, -1);
   
   recurve_trade.Init(); 
   latest_values_panel.Update(); 
   accounts_panel.Update(); 
   AppDialog.Init(); 
   bool testing; 
   #ifdef __MQL4__ 
   testing = IsTesting(); 
   #endif
     
   #ifdef __MQL5__ 
   testing = MQLInfoInteger(MQL_TESTER); 
   #endif 
   
   if (testing) Print("Holidays INIT: ", calendar_loader.LoadCSV(NEUTRAL)); 
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {
   #ifdef __MQL4__
   if (IsTesting()) {
      CExport  *export_hist   = new CExport("recurve_backtest"); 
      export_hist.ExportAccountHistory();
      delete export_hist;
   }
   
   #endif
   ObjectsDeleteAll(0, -1, -1); 
   AppDialog.Destroy(reason); 
   feature_panel.Destroy(reason); 
   entry_panel.Destroy(reason); 
   risk_panel.Destroy(reason); 
   symbol_panel.Destroy(reason); 
   var_panel.Destroy(reason);
   latest_values_panel.Destroy(reason); 
}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      //if (TimeHour(TimeCurrent()) >= 5) return;
      int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      //if (holidays > 0) PrintFormat("Num Holidays: %i", holidays);
      if (holidays == 0) recurve_trade.Stage(); 
      //int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      //PrintFormat("Num Holidays: %i", holidays_r4f); 
      
      
      if (recurve_trade.EndOfDay()) {
         recurve_trade.CloseOrder();
         recurve_trade.OnEndOfDay(); 
      }
      //ShowComments();
      //FeatureDialog.Update(); 
      latest_values_panel.Update(); 
      accounts_panel.Update(); 
      if (calendar_loader.IsNewYear()) calendar_loader.LoadCSV(HIGH); 
   }
   //recurve_trade.TrackAccounts(); 
}

void OnChartEvent(const int id,         // event ID  
                  const long& lparam,   // event parameter of the long type
                  const double& dparam, // event parameter of the double type
                  const string& sparam) // event parameter of the string type
  {
   AppDialog.ChartEvent(id, lparam, dparam, sparam);
  }