
/**
   WORK IN PROGRESS 
**/

#include "definition.mqh"
#include "trade_ops.mqh" 


class CHistoryObject {
   //--- History Object: Holds historical trade information
   //--- DATA STRUCTURE: Linked List
   protected:
      CHistoryObject *m_next, *m_prev; 
   
   public:
      
      CHistoryObject    *Next()   const               { return m_next; }
      CHistoryObject    *Prev()   const               { return m_prev; }
   
      //--- Sets Next and Previous
      void     Next(CHistoryObject *node)    { m_next = node; }
      void     Prev(CHistoryObject *node)    { m_prev = node; }
      
      //--- Trade Ticket
      int      m_ticket;
      
      //--- Sets Trade Attributes from ticket  
      void     SetAttrib(); 

      //--- Holds Trade Information 
      TradeObj trade; 
      
      //--- Constructor
      CHistoryObject(int ticket);
      ~CHistoryObject() {}; 
      
}; 

CHistoryObject::CHistoryObject(int ticket) {
   m_ticket = ticket; 
   SetAttrib(); 
}

void     CHistoryObject::SetAttrib(void) {
   
   CTradeOps *ops = new CTradeOps(); 
   ops.SYMBOL(Symbol());
   
   int s = ops.OP_HistorySelectByTicket(m_ticket); 
   if (!s) {
      Print("Failed to select");
      delete ops;
      return; 
   }
   
   trade.ticket         = m_ticket;     
   trade.magic          = ops.PosMagic();
   trade.symbol         = ops.PosSymbol(); 
   trade.open_price     = ops.PosOpenPrice(); 
   trade.close_price    = ops.PosClosePrice(); 
   trade.stop_loss      = ops.PosSL();
   trade.take_profit    = ops.PosTP(); 
   trade.volume         = ops.PosLots(); 
   trade.profit         = ops.PosProfit(); 
   trade.comment        = ops.PosComment();
   trade.open_time      = ops.PosOpenTime();
   trade.close_time     = ops.PosCloseTime(); 
   trade.order_type     = ops.PosOrderType();
   
   delete ops; 
}



class CAccounts : public CTradeOps {
   //--- Accounts: Manages trade history data 
   private:
   
   protected:
      CHistoryObject       *contents[], *m_first, *m_last, *today[]; 
      CPoolGeneric<int>    tickets, trades_today;
      
      //--- Tracks Global Positions
      CPoolGeneric<int>    tickets_active, tickets_closed;
      
      //--- Tracks instrument specific positions
      //--- Tracks currently open positions in order pool (not history)
      //--- Append to this everytime send market order is successful
      CPoolGeneric<int>    opened_positions;
      
      
      //--- Static All Time
      double               m_deposit; 
      //--- Static Intraday
      double               m_start_bal_today; 
      
      //--- Dynamic Intraday
      double               m_pl_today, m_gain_today; 
      int                  m_symbol_trades_today; 
      
   public:
      void        First(CHistoryObject *node)   { m_first = node; }
      void        Last(CHistoryObject *node)    { m_last = node; }
      
      CHistoryObject *First(void)   const { return m_first; }
      CHistoryObject *Last(void)    const { return m_last; } 
      
      //--- Wrappers
      int         AccountSymbolTradesToday(void) const { return m_symbol_trades_today; } // TRADES OPENED TODAY
      double      AccountPLToday(void)           const { return m_pl_today; }
      double      AccountDeposit(void)           const { return m_deposit; }
      double      AccountStartBalToday(void)     const { return m_start_bal_today; }
      
      //--- Constructor
      CAccounts();
      ~CAccounts(); 
      
      //--- Initialize
      void        Init(); 
      void        InitializeAccounts(); 
      
      //--- Linked List Methods
      void        Traverse(); 
      void        Reverse(); 
      
      //--- Main Operations
      void        ClearContents(); 
      void        ClearToday(); 
      void        ClearHistoryNodes(CHistoryObject *&objects[]);  
      int         Today(); 
      double      PLToday();
      double      StartBalToday(); 
      double      GainToday(); 
      double      Deposit();  
      bool        AddTradeToday(int ticket); 
      
      //--- TRADES TODAY
      bool        AddOpenedPositionToday(int ticket); 
      int         SymbolsHistoryToday(); 
      
      //--- Generic
      template <typename T>   int   Store(T &data, T &dst[]);
      template <typename T>   int   AddClosedPositions(T &data[]); 
      
      //--- Utility
      int         Diff(datetime target); 
      datetime    GetDate(datetime target); 
      bool        IsAscending(); 
      bool        IsNewDay(); 
      void        SetAsAscending(); 
      
      
      //--- New 
      int         Update(); 
      int         Track(); 
};


CAccounts::CAccounts(void) {
  m_deposit               = Deposit();
  m_start_bal_today       = StartBalToday();
  InitializeAccounts(); 
  Init(); 
}

CAccounts::~CAccounts() { 
   ClearContents();
   ClearHistoryNodes(today); 
}

void     CAccounts::ClearContents(void) {
   //--- Clears Array contents and deletes objects 
   ClearHistoryNodes(contents); 
}

void     CAccounts::ClearHistoryNodes(CHistoryObject *&objects[]) {
   
   for (int i = 0; i < ArraySize(objects); i++) {
      CHistoryObject *obj  = objects[i]; 
      delete obj; 
   }
   ArrayFree(objects);
   ArrayResize(objects, 0); 

}

void     CAccounts::ClearToday(void) {
   m_symbol_trades_today = 0;
   m_pl_today = 0; 
   m_start_bal_today = UTIL_ACCOUNT_BALANCE(); 
   ClearHistoryNodes(today);
   ClearHistoryNodes(contents);
   opened_positions.Clear(); 
   InitializeAccounts(); 
}

void     CAccounts::Init(void) {
   //--- TEMPORARY
    
   
   m_pl_today              = PLToday();
   m_gain_today            = GainToday();    
}

double   CAccounts::GainToday(void) {
   m_gain_today   = 0; 
   if (m_start_bal_today == NULL) m_start_bal_today = StartBalToday(); 
   if (m_pl_today == NULL) m_pl_today = PLToday(); 
   
   m_gain_today = (m_pl_today / m_start_bal_today) * 100; 
   return m_gain_today; 
}

double   CAccounts::Deposit(void) {
   /**
      Gets account deposit. 
   **/
   if (IsTesting()) return 100000; 
   int num_hist = PosHistTotal(); 
   
   int s = OP_HistorySelectByIndex(0); 
   if (PosOrderType() == 6) return PosProfit(); 
   
   s = OP_HistorySelectByIndex(num_hist - 1); 
   if (PosOrderType() == 6) { return PosProfit(); }
   
   
   else { 
      PrintFormat("%s: ERROR. Deposit Not Found.", __FUNCTION__); 
      return 0; 
   }
}


void     CAccounts::InitializeAccounts(void) {  
   //--- TEMPORARY SOLUTION 
   //--- Populates Tickets 
   //--- Assumes that Account History is sorted according to Time. 
   //--- Recalculate On End Of Day 
   
   int num_hist = PosHistTotal(); 
   double deposit = m_deposit == 0 ? Deposit() : m_deposit; 
   for (int j = 0; j < num_hist; j++) {
      int t = OP_HistorySelectByIndex(j);
      if (PosOrderType() == 6 || PosProfit() == deposit) continue; 
      int ticket = PosTicket();
      tickets.Append(ticket); 
   }
   
   int size = tickets.Size(); 
   //--- Generates Linked List 
   for (int i = 0; i < size; i++) {
      int ticket = tickets.Item(i); 
      int s = OP_HistorySelectByTicket(ticket); 
      CHistoryObject *hist = new CHistoryObject(ticket); 
      
      Store(hist, contents);
      //--- Identifies first element in the linked list and sets previous as NULL 
      if (i == 0) m_first = hist; hist.Prev(NULL); 
      if (i > 0 && i < size - 1) { 
         
         contents[i-1].Next(hist); 
         hist.Prev(contents[i-1]);  
      }
      //--- Identifies last element in linked list and sets next as NULL
      if (i == size - 1 && i != 0) {
         m_last = hist; 
         hist.Next(NULL);
         hist.Prev(contents[i-1]); 
      }
      
   }
   
   int num_contents  = ArraySize(contents);
   PrintFormat("%s: Contents Created. Num History: %i, Num Stored: %i", __FUNCTION__, num_hist, num_contents); 
}

void     CAccounts::SetAsAscending(void) {
   if (m_first == NULL || m_last == NULL) return; 
   
   //--- Checks if linked list is sorted from earliest to latest. 
   //--- Reverses if otherwise
   if (m_first.trade.open_time > m_last.trade.open_time) Reverse();
   
}

int      CAccounts::Update(void) {
   //--- Use tickets_closed to append to linked list
   //--- Set As Ascending First 
   
   SetAsAscending(); 
   
   CHistoryObject *reference = m_last; 
   int size = tickets_closed.Size(); 
   for (int i = 0; i < size; i++) {
      int ticket = tickets_closed.Item(i); 
      CHistoryObject *hist = new CHistoryObject(ticket); 
      
      Store(hist, contents); 
      
      
      if (i >= 0 && i < (size - 1)) {
          reference.Next(hist); 
          hist.Prev(reference); 
      }
      if (i == size - 1 && i != 0) {
         reference.Next(NULL);
         hist.Prev(reference); 
      }
      reference = hist; 
   }
   
   return 0; 
}

int      CAccounts::Track(void) {
   /**
      Objective: 
         Identify Tickets to add to linked list. 
         
         Needed in order to calculate PL today and other daily statistics
         
      Track: 
         Compare current interval and previous interval 
   **/
   //--- Clear Closed 
   tickets_closed.Clear(); 
   
   //--- Current positions in order pool; 
   int num_open = PosTotal(); 
   
   //--- Create pool
   CPoolGeneric<int> *current = new CPoolGeneric<int>(); 
   for (int i = 0; i < num_open; i++) {
      int s = OP_OrderSelectByIndex(i);
      int ticket = PosTicket();
      current.Append(ticket); 
   }
   
   //--- Check contents of tickets active.
   for (int j = 0; j < tickets_active.Size(); j++) {
      int active = tickets_active.Item(j); 
      if (!current.Search(active)) tickets_closed.Append(active); 
   }
   
   //--- If active is no longer in order pool, add to closed.
   //--- Update Linked List for closed positions. Check history first. 
   Update(); 
   
   //--- Update active tickets. 
   tickets_active.Clear();
   
   int extracted[];
   int num_extracted = current.Extract(extracted);
   
   tickets_active.Create(extracted); 
   
   int active_size   = tickets_active.Size();
   delete current; 
   return active_size; 
     
}


bool     CAccounts::IsAscending(void) {
   if (m_last == NULL || m_first == NULL) return true; 
   if (m_last.trade.open_time > m_first.trade.open_time) return true; 
   return false; 
}

bool     CAccounts::AddOpenedPositionToday(int ticket) {
   //--- Appends to opened positions today 
   //--- Called from main trade class everytime a new order is filled. 
   
   //--- Check Contents 
   datetime date_today  = GetDate(TimeCurrent()); 
   int last_index = opened_positions.Size() - 1; 
   
   
   if (opened_positions.Search(ticket)) {
      return false; 
   }
   
   opened_positions.Append(ticket); 
   m_symbol_trades_today++; 
   return true; 
}


bool     CAccounts::IsNewDay(void) {
   datetime date_today  = GetDate(TimeCurrent()); 
   
   int num_today  = ArraySize(today); 
   if (num_today == 0) return false; //--- Return false, safe to append to today, no need to clear
   
   CHistoryObject *last = today[num_today - 1]; 
   datetime last_stored = GetDate(last.trade.open_time); 
   if (date_today > last_stored) return true; 
   
   return false; 
}


template <typename T>
int      CAccounts::AddClosedPositions(T &data[]) {
   int size = ArraySize(data);
   
   //--- Check for new day 
   int num_today = ArraySize(today); 
   datetime date_today = GetDate(TimeCurrent()); 
   if (IsNewDay()) ClearHistoryNodes(today); 
   
   //--- Reference node is latest 
   bool ascending = IsAscending(); 
   CHistoryObject *reference_node = ascending ? m_last : m_first; 
   for (int i = 0; i < size; i++) {
      //--- Search if exists in trades today 
      //--- Trades today contains tickets of opened positions 
      
      int ticket = data[i];
      
      //--- Check latest node for similar tickets. 
      
      /*
         Conditions: 
            1. Date must be later than latest stored in LL. If true, append. If false, scan if already exists. 
            2. Add to next if ascending, add to prev if descending
      */
      
      int s = OP_HistorySelectByTicket(ticket);      
      
      //--- Build and set attrib then store as next if ascending, prev if descending 
      CHistoryObject *hist = new CHistoryObject(ticket); 
      
      if (reference_node == NULL) {
         reference_node = hist;
         First(hist); 
         Last(hist); 
         Store(hist, today); 
         continue; 
      }
      
      if (reference_node.trade.open_time > PosOpenTime()) continue; //--- Invalid since PosOpenTime has to be greater than latest stored node
      
      
      
      switch(ascending) {
         case true:
            reference_node.Next(hist); 
            hist.Next(NULL);
            hist.Prev(reference_node); 
            break;
         case false:
            reference_node.Prev(hist);
            hist.Prev(NULL);
            hist.Next(reference_node); 
            break;
      }
      Last(hist); 
      reference_node = hist; 
      Print("STORING: ", hist.trade.ticket);
      Store(hist, today); 
   }
   return ArraySize(today); 
}

int      CAccounts::Today(void) {
   //--- Builds trades executed today
   //--- Determine starting pointed of linked list traversal 
   
   
   if (m_first == NULL || m_last == NULL) {
      //InitializeAccounts(); 
      //PrintFormat("%s: Contents are empty.", __FUNCTION__);
      return 0; 
   }
   
   
   int diff_first = Diff(m_first.trade.open_time);
   int diff_last  = Diff(m_last.trade.open_time); 
   CHistoryObject *head; 
   if (diff_first > diff_last) Reverse(); 
   head = m_first; 
   
   
   datetime target      = GetDate(TimeCurrent()); 
   datetime reference   = GetDate(head.trade.open_time); 
   
   while (target == reference && head != NULL) {
      Store(head, today); 
      
      head        = head.Next(); 
      if (head == NULL) break; 
      reference   = GetDate(head.trade.open_time); 
   }
   PrintFormat("%s: Trades Today: %i Symbol Trades Today: %i", __FUNCTION__, ArraySize(today), m_symbol_trades_today);
   
   
   return ArraySize(today);
}


void CAccounts::Traverse(void) {

   CHistoryObject *head = m_first; 
   CHistoryObject *next = m_first.Next(); 
   
   while (head != NULL && next != NULL) {
      head = head.Next(); 
      next = head.Next(); 
   }
}

void     CAccounts::Reverse(void) {

   CHistoryObject *head    = m_last;
   Last(First());
   First(head); 
   
   while (head != NULL) {
      
      CHistoryObject *next = head.Next();
      CHistoryObject *prev = head.Prev(); 
   
      head.Prev(next);
      head.Next(prev); 
      head = head.Next(); 
   }
}

double   CAccounts::PLToday(void) {
   m_pl_today        = 0; 
   double pl_today   = 0; 
   int num_today     = ArraySize(today);
   if (num_today == 0) {
      //PrintFormat("%s: Uninitialized Array.", __FUNCTION__);
      if (Today() == 0) {
         //PrintFormat("%s: No Trades Today.", __FUNCTION__);
         return 0;
      } 
   }
   
   CHistoryObject *head = today[0]; 
   
   if (head == NULL) return 0; 
   
   datetime date_today  = GetDate(TimeCurrent()); 
   datetime reference   = GetDate(head.trade.open_time);
   
   while(date_today == reference && head != NULL) {
      double profit = head.trade.profit; 
      pl_today+=profit; 
      head = head.Next(); 
      if (head == NULL) break;
      reference = GetDate(head.trade.open_time); 
   }
   
   return pl_today; 
}


double   CAccounts::StartBalToday(void) {
   if (m_pl_today == NULL) m_pl_today = PLToday(); 
   return UTIL_ACCOUNT_BALANCE() - m_pl_today; 
}

int      CAccounts::Diff(datetime target) {
   datetime current = TimeCurrent(); 
   return current - target; 
}

datetime CAccounts::GetDate(datetime target) {
   return StringToTime(TimeToString(target, TIME_DATE)); 
}



template <typename T> 
int CAccounts::Store(T &data, T&dst[]) {
   int size = ArraySize(dst);
   ArrayResize(dst, size + 1);
   dst[size] = data; 
   
   return 0;
}