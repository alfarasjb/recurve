
#include "lib/dependencies/trade_ops.mqh"


/*
Objective: 
1. dynamically update linked list on interval
2. dynamically monitor active order pool and history, map active to history 


Initialize

Metrics:
1. deposit -> double
2. start bal today -> double
3. pl today -> double
4. pct gain today -> double
5. symbol trades today -> int
6. total trades today -> int
7. historical pl, historical gain 

*/

class CAccounts : public CTradeOps {
protected:

private:
   
   //--- Tickets in history
   //--- Needs to be updated dynamically 
   CPoolGeneric<int>    tickets_history_; 
   
   //--- Tickets active 
   //--- Monitor with tickets history 
   CPoolGeneric<int>    tickets_active_; 
   
   //--- Tickets closed today
   //--- Monitors tickets closed today
   CPoolGeneric<int>    tickets_closed_today_;
   
   
   //--- Metrics
   double               deposit_, start_bal_today_, closed_pl_today_, pct_gain_today_, historical_pl_, historical_gain_;
   int                  symbol_trades_today_, total_trades_today_;
   
   //--- Daily Reset
   datetime             last_update_; 
   
public:
   CAccounts();
   ~CAccounts();

         void        SetDeposit(double value)            { deposit_ = value; }
         void        SetStartBalToday(double value)      { start_bal_today_ = value; }
         void        SetClosedPLToday(double value)      { closed_pl_today_ = value; }
         void        SetPctGainToday(double value)       { pct_gain_today_ = value; }
         void        SetHistoricalPL(double value)       { historical_pl_ = value; }
         void        SetHistoricalGain(double value)     { historical_gain_ = value; }
         void        SetLastUpdate(datetime value)       { last_update_ = value; }
         
         void        AddClosedPLToday(double value)      { closed_pl_today_+=value; }
         void        AddHistoricalPL(double value)       { historical_pl_+=value; }

   const double      AccountDeposit(void) const          { return deposit_; }
   const double      AccountStartBalToday(void) const    { return start_bal_today_; }
   const double      AccountClosedPLToday(void) const    { return closed_pl_today_; }
   const double      AccountPctGainToday(void)  const    { return pct_gain_today_; }
   const double      AccountHistoricalPL(void)  const    { return historical_pl_; }
   const double      AccountHistoricalGain(void) const   { return historical_gain_; }
   
   const datetime    LastUpdate(void)  const             { return last_update_; }
   

   int         Init(); 
   int         InitializeTicketsHistory(); 
   int         InitializeActiveTickets(); 


   //--- Track Active Positions 
   void        Track(); 
   bool        PoolStateChanged(); 
   int         LastTicketInOrderPool(); 
   void        AppendClosedTrade(int ticket); 
   
   //--- Metrics 
   double      Deposit(); 
   void        UpdateToday(); 
   //--- Utility
   datetime    GetDate(datetime target); 
   bool        TradeDateToday(datetime target); 
   bool        IsNewDay();
   datetime    Register(); 
   void        ResetAll(); 
   
}; 

CAccounts::CAccounts(void) {
}

CAccounts::~CAccounts(void) {
   tickets_active_.Clear();
   tickets_history_.Clear();
   tickets_closed_today_.Clear();
}

int         CAccounts::Init(void) {
   Print(__FUNCTION__);
   ResetAll(); 
   InitializeTicketsHistory();
   InitializeActiveTickets(); 
   
   return 1;
}

void        CAccounts::ResetAll(void) {
   tickets_active_.Clear();
   tickets_history_.Clear();
   tickets_closed_today_.Clear(); 
   SetClosedPLToday(0);
   SetStartBalToday(0); 
   SetPctGainToday(0);
   SetHistoricalGain(0);
   SetHistoricalPL(0); 
}

double      CAccounts::Deposit(void) {
   //--- From start
   if (IsTesting()) return 100;
   
   int s, hist_total;
   
   
   s = OP_HistorySelectByIndex(0); 
   if (PosOrderType() == 6) return PosProfit(); 
   
   //-- From Last 
   hist_total = PosHistTotal(); 
   
   s = OP_HistorySelectByIndex(hist_total - 1); 
   if (PosOrderType() == 6) return PosProfit(); 
   
   PrintFormat("%s: Error. Deposit not found.", __FUNCTION__); 
   return 0;  
   
}


int         CAccounts::InitializeTicketsHistory(void) {

   PrintFormat("%s: Initializing History.", __FUNCTION__); 
   SetDeposit(Deposit()); 
   
   int i = PosHistTotal(), t, hist_ticket;
   
   while (i >= 0) {
      if (i <= 0) break;
   
      t     = OP_HistorySelectByIndex(i); 
      if (PosOrderType() == 6) { continue; }
      
      hist_ticket = PosTicket();
      if (!tickets_history_.Search(hist_ticket)) {
         tickets_history_.Append(hist_ticket);
         if (TradeDateToday(PosCloseTime())) tickets_closed_today_.Append(hist_ticket); 
         //if (TradeDateToday(PosOpenTime())) closed_pl_today+=PosProfit(); 
      } 
      i--; 
   }
   //--- Member 
   SetHistoricalPL(UTIL_ACCOUNT_BALANCE() - AccountDeposit());
   SetHistoricalGain(AccountHistoricalPL() / AccountDeposit() * 100); 
   
   int hist_size  = tickets_history_.Size();
   PrintFormat("%s: %i trades in history. Historical PL: %.2f, Historical Gain: %.2f", __FUNCTION__, hist_size, AccountHistoricalPL(), AccountHistoricalGain());
   UpdateToday(); 
   datetime upd = Register(); 
   return hist_size;  
}

void        CAccounts::UpdateToday(void) {
   
   //--- Reset 
   SetClosedPLToday(0);
   SetStartBalToday(0); 
   int s;
   
   for (int i = 0; i < tickets_closed_today_.Size(); i++) {
      s = OP_HistorySelectByTicket(tickets_closed_today_.Item(i));
      AddClosedPLToday(PosProfit()); 
   }
   SetStartBalToday(UTIL_ACCOUNT_BALANCE() - AccountClosedPLToday()); 
   PrintFormat("PL Today: %f", AccountClosedPLToday()); 
}

datetime    CAccounts::GetDate(datetime target) {
   return StringToTime(TimeToString(target, TIME_DATE)); 
}

bool        CAccounts::TradeDateToday(datetime target) {
   return GetDate(target) == GetDate(TimeCurrent()); 
}

int         CAccounts::InitializeActiveTickets(void) {
   Print(__FUNCTION__); 
   int   t, active_ticket; 
   
   for (int i = 0; i < PosTotal(); i++) {
      t  = OP_OrderSelectByIndex(i);
      active_ticket  = PosTicket(); 
      if (!tickets_active_.Search(active_ticket))
         tickets_active_.Append(active_ticket); 
   }
   int active_size   = tickets_active_.Size(); 
   PrintFormat("%s: %i trades active.", __FUNCTION__, active_size);
   
   datetime upd = Register();  
   return active_size; 
}

void        CAccounts::AppendClosedTrade(int ticket) {
   tickets_history_.Append(ticket);
   tickets_closed_today_.Append(ticket); 
   int s = OP_HistorySelectByTicket(ticket);
   
   //--- Update Metrics
   AddClosedPLToday(PosProfit()); 
   double gain_today = AccountClosedPLToday() / AccountStartBalToday() * 100; 
   SetPctGainToday(gain_today); 
   
   
   AddHistoricalPL(PosProfit()); 
   double gain_hist = AccountHistoricalPL() / AccountDeposit() * 100; 
   SetHistoricalGain(gain_hist); 
   
   PrintFormat("%s: Updated Hist. Ticket: %i, Profit: %f, PL Today: %f Gain Today: %f, Hist PL: %f, Hist Gain: %f", 
      __FUNCTION__, 
      ticket, 
      PosProfit(), 
      AccountClosedPLToday(),
      AccountPctGainToday(), 
      AccountHistoricalPL(),
      AccountHistoricalGain());
}
void        CAccounts::Track(void) {
   if (IsNewDay()) {
      Init(); 
      return; 
   }
   if (!PoolStateChanged()) return; 
   //UpdateHistoryWithClosedPositions(); 
   //int added = UpdateActiveWithNewPositions(); //
   /*
      Method:
         1. Generate list of current positions in order pool
         2. Check tickets_active_ if each ticket exists in current open positions. 
            If no longer exists in current positions, set as close, and append to
            tickets_history_. 
         3. Clear tickets_active_ and repopulate with current. 
   */
   Print(__FUNCTION__); 
   CPoolGeneric<int> *current = new CPoolGeneric<int>(); 
   
   int s, curr_ticket;
   for(int i = 0; i < PosTotal(); i++) {
      s = OP_OrderSelectByIndex(i); 
      curr_ticket = PosTicket();
      current.Append(curr_ticket); 
   }
   
   current.Sort(); 
   tickets_active_.Sort();
   
    
   int first_ticket; 
   while (tickets_active_.Size() > 0) {
      first_ticket   = tickets_active_.First();
      if (!current.Search(first_ticket)) AppendClosedTrade(first_ticket); 
      tickets_active_.Remove(first_ticket); 
      
   }
   
   int current_extracted[];
   int num_current_extracted  = current.Extract(current_extracted); 
   
   tickets_active_.Clear();
   tickets_active_.Create(current_extracted);
   
   
   delete current; 
   
   
}

bool        CAccounts::PoolStateChanged(void) {
   /*
      State Change:
         1. Count
         2. Last stored ticket
   */
   
   //--- Count has changed
   if (PosTotal() != tickets_active_.Size()) {
      Print("Order Pool Changed: Size"); 
      return true; 
   }
   int extracted[], t; 
   bool b   = tickets_active_.Sort(); 
   int num_extracted = tickets_active_.Extract(extracted);
   
   
   //--- Latest tickets have changed
   //--- Order Pool has been modified 
   if (tickets_active_.Last() != LastTicketInOrderPool()) {
      Print("Order Pool Change: Last"); 
      return true;   
   }
   
   
   
   for (int i = 0; i < PosTotal(); i++) {
      t  = OP_OrderSelectByIndex(i); 
      if (PosTicket() != extracted[i]) {
         PrintFormat("%s: Order Pool has changed. Ticket: %i, Stored: %i", __FUNCTION__, PosTicket(), extracted[i]); 
         return true; 
      }
   }
   
   return false; 
}

int         CAccounts::LastTicketInOrderPool(void) {
   if (PosTotal() ==  0) return 0; 
   
   int s = OP_OrderSelectByIndex(PosTotal() - 1); 
   return PosTicket(); 
}

bool        CAccounts::IsNewDay(void) {

   datetime date_today = GetDate(TimeCurrent()); 
   datetime last_date = GetDate(LastUpdate()); 
   return (date_today != last_date); 
}

datetime    CAccounts::Register(void) {
 
   SetLastUpdate(TimeCurrent());
   PrintFormat("%s: Last Update: %s", __FUNCTION__, TimeToString(LastUpdate())); 
   return LastUpdate(); 
}