

#include "dependencies/trade_ops.mqh"


class CAccountsLite : public CTradeOps {
protected:

private:


   CPoolGeneric<int>    tickets_active_; 
   CPoolGeneric<int>    tickets_closed_today_; 

   //--- Metrics
   double               deposit_, start_bal_today_, closed_pl_today_, pct_gain_today_;
   int                  symbol_trades_today_, total_trades_today_;
   
   //--- Daily Reset
   datetime             last_update_; 

public: 
   
            CAccountsLite();
            ~CAccountsLite(); 
   
      
            void        SetDeposit(double value)            { deposit_ = value; }
            void        SetStartBalToday(double value)      { start_bal_today_ = value; }
            void        SetClosedPLToday(double value)      { closed_pl_today_ = value; }
            void        SetPctGainToday(double value)       { pct_gain_today_ = value; }
            void        SetLastUpdate(datetime value)       { last_update_ = value; }
            
            void        AddClosedPLToday(double value)      { closed_pl_today_+=value; }
            
      const double      AccountDeposit()  const             { return deposit_; }
      const double      AccountStartBalToday()  const       { return start_bal_today_; }
      const double      AccountClosedPLToday()  const       { return closed_pl_today_; }
      const double      AccountPctGainToday()   const       { return pct_gain_today_; }
      
      const datetime    LastUpdate() const                  { return last_update_; }
      
            
            //--- Initialization
            int         Init();  
            int         InitializeActiveTickets(); 
            int         InitializeClosedToday();
            
            //--- Track Active Positions 
            void        Track(); 
            bool        PoolStateChanged(); 
            int         LastTicketInOrderPool();
            void        AppendClosedTrade(int ticket); 
            
            //--- Metrics
            double      Deposit(); 
            
            //--- Utility
            bool        IsNewDay(); 
            datetime    GetDate(datetime target); 
            datetime    Register(); 
            datetime    DateToday(); 
            bool        TradeDateToday(datetime target); 
            void        ResetAll(); 

};

CAccountsLite::CAccountsLite() : CTradeOps(Symbol(), 0) {}

CAccountsLite::~CAccountsLite() {
   tickets_active_.Clear();
   tickets_closed_today_.Clear(); 
}

int            CAccountsLite::Init() {
   ResetAll();
   InitializeActiveTickets(); 
   InitializeClosedToday(); 
   return 1;
}

void           CAccountsLite::ResetAll() {
   tickets_active_.Clear(); 
   tickets_closed_today_.Clear(); 
   SetClosedPLToday(0);
   SetStartBalToday(0); 
   SetPctGainToday(0); 
}


double         CAccountsLite::Deposit() {
   
   if (IsTesting())     return 100;
   
   int s;
   s = OP_HistorySelectByIndex(0); 
   if (PosOrderType() == 6)    return PosProfit(); 
   
   
   int hist_total  = PosHistTotal(); 
   s = OP_HistorySelectByIndex(hist_total - 1);
   if (PosOrderType() == 6)   return PosProfit(); 
   
   Log_.LogError("Deposit not found.", __FUNCTION__); 
   return 0; 
   
   
}

void           CAccountsLite::Track() {
   /*
      Tracks changes in order pool and executes functions accordingly. 
      
      Change in order pool would result in rechecking contents of tickets_active.
      
      Solution is currently temporary. 
   */
   if (IsNewDay()) {
      //--- Reinitalizes history and active positions if new day is detected. 
      Init(); 
      return; 
   }
   
   //--- Returns if pool state remains the same
   if (!PoolStateChanged()) return; 
   
   CPoolGeneric<int> *current = new CPoolGeneric<int>(); 
   
   //--- Populate current. Stores current active tickets in order pool.
   int s, curr_ticket;
   for (int i = 0; i < PosTotal(); i++) {
      s = OP_OrderSelectByIndex(i);
      curr_ticket =  PosTicket(); 
      current.Append(curr_ticket); 
   }
   
   current.Sort();
   tickets_active_.Sort(); 
   
   
   /*
      Compares contents of stored tickets with current order pool. 
      
      Stored tickets not found in current are considered closed trades, 
      and are adde to tickets_closed_ 
      
      Sequentially removes tickets from tickets_active
   */
   int first_ticket;
   while(tickets_active_.Size() > 0) {
      first_ticket   = tickets_active_.First(); 
      if (!current.Search(first_ticket)) AppendClosedTrade(first_ticket); 
      tickets_active_.Remove(first_ticket); 
   }
   
   //--- Extracts contents of current to be used for repopulating tickets_active
   int current_extracted[]; 
   int num_extracted = current.Extract(current_extracted); 
   
   tickets_active_.Create(current_extracted); 
   
}

void           CAccountsLite::AppendClosedTrade(int ticket) {
   /*
      Method for appending to tickets closed. 
      
      Triggered when order pool has changed. 
      
      Used to recalculate daily closed p/l and gain, and for risk management.
   */
   tickets_closed_today_.Append(ticket);
   int s = OP_HistorySelectByTicket(ticket);
   //--- Adds to closed PL and recalculates gain 
   AddClosedPLToday(PosProfit());
   double gain_today = AccountClosedPLToday() / AccountStartBalToday() * 100;
   SetPctGainToday(gain_today); 
      
   Log_.LogInformation(StringFormat("Updated Hist. Ticket: %i, Profit: %f, PL Today: %f, Gain Today: %f", 
      ticket,
      PosProfit(),
      AccountClosedPLToday(),
      AccountPctGainToday()), __FUNCTION__); 
   
}


int            CAccountsLite::InitializeActiveTickets() {

   /*
      Scans current order pool and stores all active tickets in `tickets_active`. 
      
      Returns size of `tickets_active`
   */

   int   t, active_ticket;
   
   for (int i = 0; i < PosTotal(); i++) {
      t  = OP_OrderSelectByIndex(i); 
      active_ticket  = PosTicket(); 
      //--- Skips tickets already stored in the order pool 
      
      if (tickets_active_.Search(active_ticket)) continue; 
      tickets_active_.Append(active_ticket); 
   }
   int active_size   = tickets_active_.Size(); 
   Log_.LogInformation(StringFormat("%i trades active.", active_size), __FUNCTION__); 
   
   //--- Registers date of initialization 
   datetime upd = Register();
   return active_size; 
}

int            CAccountsLite::InitializeClosedToday() {
   /*
      Initializes `tickets_closed_today` 
      
      Stores tickets closed today in account history. 
   */
   Log_.LogInformation("Initializing history.", __FUNCTION__); 
   SetDeposit(Deposit()); 
   
   //--- Identifies starting point of loop to save time. 
   //--- Looping sorted history is in descending order
   int s = OP_HistorySelectByIndex(PosHistTotal() - 1);
   int i = PosOrderType() == 6 ? 0 : PosHistTotal();
   int t, hist_ticket; 
   
   while (i >= 0) {
      if (i <= 0) break; 
      
      t = OP_HistorySelectByIndex(i); 
      if (PosOrderType() == 6) continue; 
      
      //--- If first detected ticket is before current date, break. 
      //--- No trades have been opened today. 
      if (GetDate(PosOpenTime()) < DateToday()) break; 
      hist_ticket = PosTicket(); 
      
      //--- Ignores trades that are not closed today. 
      if (!TradeDateToday(PosCloseTime())) continue; 
      
      //--- Ignores trades that are already in the data structure
      if (tickets_closed_today_.Search(hist_ticket)) continue; 
      
      //--- Adds to tickets_closed_today and adds to PL today. 
      tickets_closed_today_.Append(hist_ticket); 
      AddClosedPLToday(PosProfit()); 
   }
   int num_closed_today = tickets_closed_today_.Size(); 
   
   //--- Registers date of initialization. 
   datetime upd = Register();
   
   //--- Sets start balance today as closed PL today - current account balance
   SetStartBalToday(AccountClosedPLToday() - UTIL_ACCOUNT_BALANCE()); 
   SetPctGainToday(AccountClosedPLToday() / AccountStartBalToday() * 100); 
   
   Log_.LogInformation(StringFormat("%i trades closed today. Closed PL Today: %.2f, Closed Gain Today: %.2f", 
      AccountClosedPLToday(),
      AccountPctGainToday()), __FUNCTION__);
      
   return num_closed_today; 
}

bool           CAccountsLite::PoolStateChanged() {
   /*
      Monitors changes in order pool in comparison to the contents of tickets_active_.
      
      Returns true if order pool state has changed based on the ff conditions:
         1. Size: Order pool added or subtracted total number of positions 
         2. Change in latest ticket: A trade was simultaneously closed, and opened 
         3. Change in overall order pool contents. 
     
   */
   
   //--- 1. Size - monitors size of order pool 
   if (PosTotal() != tickets_active_.Size()) {
      Log_.LogInformation(StringFormat("Order Pool Changed: %i", PosTotal()), __FUNCTION__); 
      Log_.LogInformation(StringFormat("Order Pool Changed. Reason: Size. Pool: %i, Stored: %i", 
         PosTotal(), 
         tickets_active_.Size()), __FUNCTION__); 
      return true; 
   }
   
   //--- 2. Latest Ticket - monitors last ticket in order pool 
   bool b = tickets_active_.Sort(); 
   
   if (tickets_active_.Last() != LastTicketInOrderPool()) {
      Log_.LogInformation(StringFormat("Order Pool Changed. Reason: Last. Pool: %i, Stored: %i", 
         LastTicketInOrderPool(), 
         tickets_active_.Last()), __FUNCTION__); 
         return true; 
   }
   
   //--- 3. Contents: majority of the contents have changed. 
   int t;
   for (int i = 0; i < PosTotal(); i++) {
      t = OP_OrderSelectByIndex(i);
      if (PosTicket() != tickets_active_.Item(i)) {
         Log_.LogInformation(StringFormat("Order Pool Changed. Reason: Replace. Pool: %i, Stored: %i", 
            PosTicket(), 
            tickets_active_.Item(i)), __FUNCTION__); 
         return true; 
      }
   }
   return false; 
}

datetime       CAccountsLite::Register() {
   /*
      Registers datetime of latest updates to account information. 
   */
   SetLastUpdate(TimeCurrent());
   Log_.LogInformation(StringFormat("Last Update: %s", TimeToString(LastUpdate())), __FUNCTION__);
   return LastUpdate();
}

int            CAccountsLite::LastTicketInOrderPool() {
   //--- Returns last active ticket in order pool 
   if (PosTotal() == 0) return 0; 
   int s = OP_OrderSelectByIndex(PosTotal() - 1); 
   return PosTicket(); 
}

datetime       CAccountsLite::GetDate(datetime target)         { return StringToTime(TimeToString(target, TIME_DATE)); }
bool           CAccountsLite::IsNewDay()                       { return (GetDate(TimeCurrent()) != GetDate(LastUpdate())); }
datetime       CAccountsLite::DateToday()                      { return GetDate(TimeCurrent()); }
bool           CAccountsLite::TradeDateToday(datetime target)  { return GetDate(target) == GetDate(TimeCurrent()); }
