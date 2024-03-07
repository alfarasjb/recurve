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
   ShowComments();
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      //int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      //int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      //PrintFormat("Num Holidays: %i", holidays_r4f); 
      int stage_value = recurve_trade.Stage(); 
      recurve_trade.logger(StringFormat("Stage Value: %i", stage_value), __FUNCTION__);
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
      ShowComments();
   }
}

void     ShowComments() {
   
   Comment(
      StringFormat("Day Vol Window: %i", InpDayVolWindow),
      StringFormat("\nPeak Day Vol Window: %i", InpDayPeakVolWindow),
      StringFormat("\nSpread Window: %i", InpNormSpreadWindow),
      StringFormat("\nNorm MA Window: %i", InpNormMAWindow),
      StringFormat("\nSkew Window: %i", InpSkewWindow), 
      StringFormat("\nBBands Window: %i", InpBBandsWindow),
      StringFormat("\nBBands SDEV: %f", InpBBandsNumSdev),
      StringFormat("\nZ Thresh: %f", InpZThresh),
      StringFormat("\nSkew Thresh: %f", InpSkewThresh),
      StringFormat("\nLow Vol Thresh: %f", InpLowVolThresh),
      StringFormat("\n\nVAR: %f", recurve_trade.ValueAtRisk()),
      StringFormat("\nCatastrophic VAR: %f", recurve_trade.CatastrophicLossVAR()),
      StringFormat("\n\nSkew: %f", recurve_trade.SKEW()),
      StringFormat("\nSpread: %f", recurve_trade.STANDARD_SCORE())
   );

}