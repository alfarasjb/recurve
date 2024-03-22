#ifdef __MQL4__ 
#include "trade_mt4.mqh"
#endif

#include <B63/Generic.mqh>
#include <B63/CExport.mqh>
#include <MAIN/Loader.mqh> 
#include "forex_factory.mqh"
#include "features.mqh"
#include "trade_app.mqh"
#include "accounts.mqh"
CRecurveTrade              recurve_trade;
CCalendarHistoryLoader     calendar_loader;
CNewsEvents                news_events;
CRecurveApp                AppDialog; 
int OnInit() {
   ObjectsDeleteAll(0, -1, -1);
   
   recurve_trade.Init(); 
   latest_values_panel.Update(); 
   AppDialog.Init(); 
   
   if (IsTesting()) Print("Holidays INIT: ", calendar_loader.LoadCSV(NEUTRAL)); 
   //ShowComments();
   //accts.InitializeAccounts();
   //accts.PLToday(); 
   //Print(accts.Deposit()); 
   //accts.Reverse();
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {

   CExport  *export_hist   = new CExport("recurve_backtest"); 
   if (IsTesting()) export_hist.ExportAccountHistory();
   delete export_hist;
   
   ObjectsDeleteAll(0, -1, -1); 
   //ExtDialog.Destroy(reason); 
   //TradeDialog.Destroy(reason); 
   //FeatureDialog.Destroy(reason); 
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
      int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      //if (holidays > 0) PrintFormat("Num Holidays: %i", holidays);
      if (holidays == 0) recurve_trade.Stage(); 
      //int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      //PrintFormat("Num Holidays: %i", holidays_r4f); 
      
      
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
      //ShowComments();
      //FeatureDialog.Update(); 
      latest_values_panel.Update(); 
      if (calendar_loader.IsNewYear()) calendar_loader.LoadCSV(HIGH); 
   }
}

void OnChartEvent(const int id,         // event ID  
                  const long& lparam,   // event parameter of the long type
                  const double& dparam, // event parameter of the double type
                  const string& sparam) // event parameter of the string type
  {
   AppDialog.ChartEvent(id, lparam, dparam, sparam);
  }