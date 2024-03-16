#ifdef __MQL4__ 
#include "trade_mt4.mqh"
#endif

#include <B63/Generic.mqh>
#include <B63/CExport.mqh>
#include <MAIN/Loader.mqh> 
#include "forex_factory.mqh"
#include "features.mqh"
#include "Panel.mqh"
CRecurveTrade              recurve_trade;
CCalendarHistoryLoader     calendar_loader;
CNewsEvents                news_events;
//-- PANELS ARE TEMPORARY
CInfoPanel                 ExtDialog; 
CTradePanel                TradeDialog; 
CFeaturePanel              FeatureDialog; 

int OnInit() {
   
   recurve_trade.Init(); 
   
   //--- TEMPORARY 
   FeatureDialog.Update(); 
   if (!ExtDialog.Create(0, "Info", 0,  5, 5, 150, 400))          return INIT_FAILED;
   if (!TradeDialog.Create(0, "Risk", 0, 160, 5, 350, 150))       return INIT_FAILED;
   if (!FeatureDialog.Create(0, "Feature", 0, 360, 5, 560, 150))  return INIT_FAILED;
   ExtDialog.Run(); 
   TradeDialog.Run(); 
   FeatureDialog.Run(); 
   if (IsTesting()) Print("Holidays INIT: ", calendar_loader.LoadCSV(NEUTRAL)); 
   //ShowComments();
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {

   CExport  *export_hist   = new CExport("recurve_backtest"); 
   if (IsTesting()) export_hist.ExportAccountHistory();
   delete export_hist;
   
   ObjectsDeleteAll(0, -1, -1); 
   ExtDialog.Destroy(reason); 
   TradeDialog.Destroy(reason); 
   FeatureDialog.Destroy(reason); 
}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      if (holidays > 0) PrintFormat("Num Holidays: %i", holidays);
      if (holidays == 0) recurve_trade.Stage(); 
      //int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      //PrintFormat("Num Holidays: %i", holidays_r4f); 
      
      
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
      //ShowComments();
      FeatureDialog.Update(); 
      if (calendar_loader.IsNewYear()) calendar_loader.LoadCSV(HIGH); 
   }
}

void OnChartEvent(const int id,         // event ID  
                  const long& lparam,   // event parameter of the long type
                  const double& dparam, // event parameter of the double type
                  const string& sparam) // event parameter of the string type
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
   TradeDialog.ChartEvent(id, lparam, dparam, sparam); 
   FeatureDialog.ChartEvent(id, lparam, dparam, sparam); 
  }