//+------------------------------------------------------------------+
//|                                              accounts_tester.mq4 |
//|                             Copyright 2023, Jay Benedict Alfaras |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jay Benedict Alfaras"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


#include "accounts_secondary.mqh"
CAccounts accounts; 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   accounts.Init(); 
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   accounts.Track(); 
   
   
  }
//+------------------------------------------------------------------+
