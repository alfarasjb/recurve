
#property copyright "Copyright 2023, Jay Benedict Alfaras"
#property version   "1.00"
#property strict

#include "profiles.mqh"
#include <B63/ui/CInterface.mqh>
#include <B63/Generic.mqh>


struct Charts {
   string         chart_symbol; 
   long           chart_id; 
   ENUM_TIMEFRAMES chart_period;
} CHARTS;

Charts   EXTERNAL_CHARTS[]; 

const string   CONFIG_DIRECTORY     = "recurve\\csv\\config.csv";

CInterface ui;

input string      InpTemplate = "DEF.tpl";

string SYMBOLS[];


int OnInit()
  {
   DrawButton();
   LoadSymbols();
   
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
  {
//---
   ObjectsDeleteAll(0, -1, -1); 
  }
  
  
void OnTick()
  {
//---
   
  }
  
void OnChartEvent(const int id, const long &lparam, const double &daram, const string &sparam){
   Print("SPARAM: ", sparam); 
   if (CHARTEVENT_OBJECT_CLICK){
      if (sparam == "runbt") {
         Print("RUN PRESSED");
         InitializeExternalCharts(); 
         LoadCharts(); 
         ExternalCharts();
         resetObject(sparam);
      }
      if (sparam == "clearbt") {
         ClearCharts();
         resetObject(sparam);
      }
      if (sparam == "reloadbt"){
         Print("RELOAD PRESSED"); 
         ClearCharts();
         InitializeExternalCharts();
         LoadCharts();
         ExternalCharts();
         resetObject(sparam);
         
      }
   }
}


void     DrawButton() {
   ui.CButton("reloadbt", 10, 40, 75, 25, 10, "Calibri", "RELOAD");
   ui.CButton("runbt", 10, 70, 75, 25, 10, "Calibri", "RUN");
   ui.CButton("clearbt", 10, 100, 75, 25, 10, "Calibri", "CLEAR");
}


void     LoadSymbols() {

   CProfiles *profiles  = new CProfiles(CONFIG_DIRECTORY);
   TradeProfile   cfg   = profiles.BuildProfile();
   
   int num_symbols = ArraySize(profiles.SYMBOLS);
   ArrayResize(SYMBOLS, num_symbols);
   ArrayCopy(SYMBOLS, profiles.SYMBOLS);
   delete profiles; 
   
}
  



void     InitializeExternalCharts() {
   ArrayFree(EXTERNAL_CHARTS);
   ArrayResize(EXTERNAL_CHARTS, 0);
}


void     ExternalCharts() {

   int size = ArraySize(EXTERNAL_CHARTS);
   PrintFormat("%i Charts Open", size);
   
   for (int i = 0; i < size; i++) {
      Charts   chart = EXTERNAL_CHARTS[i];
      PrintFormat("ID: %s, Symbol: %s, Period: %s", (string)chart.chart_id, chart.chart_symbol, EnumToString(chart.chart_period));
   }
}

void     AddToExternalCharts(Charts &chart) {
   int size = ArraySize(EXTERNAL_CHARTS);
   ArrayResize(EXTERNAL_CHARTS,size+1);
   EXTERNAL_CHARTS[size] = chart;
}

void     ClearCharts() {
   long first = ChartFirst();
   BuildExternalCharts(first);
   int num_charts = ArraySize(EXTERNAL_CHARTS);
   for (int i = 0; i < num_charts;i++) {
      long id = EXTERNAL_CHARTS[i].chart_id;
      bool closed = ChartClose(id);
      switch(closed){ 
         case true:     PrintFormat("ID: %s Closed.", (string)id); break;
         case false:    PrintFormat("ID: %s failed to close.", id);break; 
      }
   }
   InitializeExternalCharts();
}

void     BuildExternalCharts(long chart_id) {
   if (chart_id < 0) return; 
   long  next = ChartNext(chart_id); 
   long  current = ChartID();
   //PrintFormat("Curr Symbol: %s, Next Symbol: %s", ChartSymbol(chart_id), ChartSymbol(next));
   string message = StringFormat("%s %s", (string)chart_id, (string)next);
   
   if (chart_id != current) {
      Charts   chart; 
      chart.chart_id       = chart_id;
      chart.chart_period   = ChartPeriod(chart_id);
      chart.chart_symbol   = ChartSymbol(chart_id); 
      AddToExternalCharts(chart);
   }
   BuildExternalCharts(next);
   //PrintFormat("Current: %l, Next: %l", chart_id, next); 
   
}

void     ViewChart() {
   int current_id = ChartID(); 
   //string symbol = ChartSymbol(current);
   Print(current_id);
}
void     LoadCharts() {
   //string symbols[] = {"USDCAD","AUDUSD"};
   int num_symbols = ArraySize(SYMBOLS);
   for(int i = 0; i < num_symbols; i++) {
      string symbol = SYMBOLS[i];
   
      PrintFormat("Initializing: %s", symbol);
      long id = ChartOpen(symbol, PERIOD_M15);
      PrintFormat("ID: %s", (string)id); 
      string template_path = "\\"+InpTemplate;
      long chart_id = ChartApplyTemplate(id, template_path);
      if (!chart_id) {
         PrintFormat("Failed to apply template on %s, ID: %s", symbol, (string)id); 
         ChartClose(id);
         
      }
      else {
         PrintFormat("%s: Template Applied", symbol);
         Charts chart;
         chart.chart_id       = id; 
         chart.chart_period   = ChartPeriod(chart.chart_id);
         chart.chart_symbol   = ChartSymbol(chart.chart_id);
         AddToExternalCharts(chart);
      }
   }
}

/*

//--- search for a template in terminal_data_directory\MQL4\
ChartApplyTemplate(0,"\\first_template.tpl"))
 
//--- search for a template in directory_of_EX4_file\, then in folder terminal_data_directory\Profiles\Templates\
ChartApplyTemplate(0,"second_template.tpl"))
 
//--- search for a template in directory_of_EX4_file\My_templates\, then in folder terminal_directory\Profiles\Templates\My_templates\
ChartApplyTemplate(0,"My_templates\\third_template.tpl"))

*/