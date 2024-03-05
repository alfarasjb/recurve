#ifdef __MQL4__ 
#include "trade_mt4.mqh"
#endif

#include <B63/Generic.mqh>
#include <B63/CExport.mqh>
#include <MAIN/Loader.mqh> 
#include "forex_factory.mqh"

CRecurveTrade              recurve_trade;
CCalendarHistoryLoader     calendar_loader;
CNewsEvents                news_events;

int OnInit() {

   /*
   CHECK INDICATOR PATH (CALL VALUES ONCE)
   */
   recurve_trade.InitializeFeatureParameters();
   recurve_trade.InitializeSymbolProperties();
   
   if (IsTesting()) Print("Holidays INIT: ", calendar_loader.LoadCSV(NEUTRAL)); 
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      if (holidays == 0) recurve_trade.Stage(); 
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
   }

}

