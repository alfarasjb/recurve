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
//CInfoPanel                 ExtDialog; 

int OnInit() {
   /*
   CHECK INDICATOR PATH (CALL VALUES ONCE)
   */
   
   recurve_trade.Init(); 
   /*
   recurve_trade.InitializeFeatureParameters();
   recurve_trade.InitializeSymbolProperties();
   recurve_trade.InitializeIntervals();
   //recurve_trade.InitializeDays();
   recurve_trade.InitializeConfiguration();
   */
   //if (!ExtDialog.Create(0, "Info", 0,  40, 40, 250, 600)) return INIT_FAILED;
   //ExtDialog.Run(); 
   if (IsTesting()) Print("Holidays INIT: ", calendar_loader.LoadCSV(NEUTRAL)); 
   ShowComments();
   return INIT_SUCCEEDED;

}


void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, -1, -1); 
   //ExtDialog.Destroy(reason); 
}

void OnTick() {
/*
MAIN LOOP 
*/
   if (IsNewCandle()) {
      //int holidays = calendar_loader.LoadDatesToday(NEUTRAL); // FOR BACKTESTING 
      //int holidays_r4f = news_events.GetNewsSymbolToday(); // FOR LIVE 
      //PrintFormat("Num Holidays: %i", holidays_r4f); 
      int stage_value = recurve_trade.Stage(); 
      //recurve_trade.logger(StringFormat("Stage Value: %i", stage_value), __FUNCTION__);
      if (recurve_trade.EndOfDay()) recurve_trade.CloseOrder();
      ShowComments();
   }
}

void     ShowComments() {
   
   Comment(
      StringFormat("Day Vol Window: %i", SETTINGS.day_vol_lookback),
      //StringFormat("\nPeak Day Vol Window: %i", InpDayPeakVolWindow),
      //StringFormat("\nSpread Window: %i", InpNormSpreadWindow),
      //StringFormat("\nNorm MA Window: %i", InpNormMAWindow),
      //StringFormat("\nSkew Window: %i", InpSkewWindow), 
      //StringFormat("\nBBands Window: %i", InpBBandsWindow),
      //StringFormat("\nBBands SDEV: %f", InpBBandsNumSdev),
      //StringFormat("\nZ Thresh: %f", InpZThresh),
      //StringFormat("\nSkew Thresh: %f", InpSkewThresh),
      
      StringFormat("\n\nVAR: %f", recurve_trade.ValueAtRisk()),
      StringFormat("\nCatastrophic VAR: %f", recurve_trade.CatastrophicLossVAR()),
      StringFormat("\n\nSkew: %f", recurve_trade.SKEW()),
      StringFormat("\nSpread: %f", recurve_trade.STANDARD_SCORE()),
      StringFormat("\nIntervals: %s", recurve_trade.IntervalsAsString()),
      StringFormat("\nDays: %s", recurve_trade.DaysAsString()),
      StringFormat("\n\nDay Vol: %f", recurve_trade.DAY_VOL()),
      StringFormat("\nLow Vol Thresh: %f", CONFIG.low_volatility_thresh),
      StringFormat("\nDay Peak: %f", recurve_trade.DAY_PEAK_VOL()),
      StringFormat("\nValid Day Vol: %s", (string)recurve_trade.ValidDayVolatility()),
      StringFormat("\nValid Day of Week: %s", (string)recurve_trade.ValidDayOfWeek()),
      StringFormat("\n\nUse Prev Day: %s", (string)CONFIG.use_pd),
      StringFormat("\nPrev Day Valid Long: %s", (string)recurve_trade.PreviousDayValid(LONG)),
      StringFormat("\nPrev Day Valid Short: %s", (string)recurve_trade.PreviousDayValid(SHORT))
   );

}


void OnChartEvent(const int id,         // event ID  
                  const long& lparam,   // event parameter of the long type
                  const double& dparam, // event parameter of the double type
                  const string& sparam) // event parameter of the string type
  {
   //ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }