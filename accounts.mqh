


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
      double               m_pl_today, m_deposit, m_start_bal_today; 
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
      void        InitializeAccounts(); 
      
      //--- Linked List Methods
      void        Traverse(); 
      void        Reverse(); 
      
      //--- Main Operations
      void        ClearContents(); 
      int         Today(); 
      double      PLToday();
      double      StartBalToday(); 
      double      Deposit();  
      int         TradesToday(); 
      bool        AddTradeToday(int ticket); 
      
      //--- Generic
      template <typename T>   int   Store(T &data, T &dst[]);
      
      //--- Utility
      int         Diff(datetime target); 
      datetime    GetDate(datetime target); 
      
};


CAccounts::CAccounts(void) {
   m_deposit               = Deposit(); 
   InitializeAccounts(); 
   m_pl_today              = PLToday();
   m_start_bal_today       = StartBalToday(); 
   m_symbol_trades_today   = TradesToday();
   
      
}

CAccounts::~CAccounts() { ClearContents(); }

void     CAccounts::ClearContents(void) {
   //--- Clears Array contents and deletes objects 
   
   for (int i = 0; i < ArraySize(contents); i++) delete contents[i]; 
   ArrayFree(contents);
   ArrayResize(contents, 0); 
}

double   CAccounts::Deposit(void) {
   /**
      Gets account deposit. 
   **/
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
      if (i == size - 1) {
         m_last = hist; 
         hist.Next(NULL);
         hist.Prev(contents[i-1]); 
      }
      
   }
   
   
   int num_contents  = ArraySize(contents);
   PrintFormat("%s: Contents Created. Num History: %i, Num Stored: %i", __FUNCTION__, num_hist, num_contents); 
}


int      CAccounts::TradesToday(void) {
   //--- Calculate number of trades in history and active positions in order pool 
   
   //--- Scan Trades in order pool 
   int num_pos             = PosTotal();
   
   //--- Reset to prevent miscalculation 
   m_symbol_trades_today   = 0; 
   trades_today.Clear();
   
   //--- Date Today
   datetime date_today  = GetDate(TimeCurrent()); 
   for (int i = 0; i < num_pos; i++) {
      int s = OP_OrderSelectByIndex(i); 
      
      //--- Ignore different symbol
      if (PosSymbol() != Symbol())     continue;
      
      //--- Ignore trades from different dates
      if (PosOpenTime() != date_today) continue; 
      
      int ticket = PosTicket(); 
      trades_today.Append(ticket); 
   }
   
   //--- Return if no trades today; 
   if (ArraySize(today) == 0) return m_symbol_trades_today;
    
   //--- Scan History
   //--- First entry, use Next() to traverse linked list
   CHistoryObject *head    = today[0]; 
   datetime reference      = GetDate(head.trade.open_time); 
   
   while(date_today == reference) {
      if (head.trade.symbol == Symbol()) trades_today.Append(head.trade.ticket); 
      head        = head.Next(); 
      reference   = GetDate(head.trade.open_time); 
   }
   
   m_symbol_trades_today   = trades_today.Size();
   return m_symbol_trades_today;
   
}

bool     CAccounts::AddTradeToday(int ticket) {
   //--- Appends ticket to trades_today. Used for updating trades_today if order is sent from main class. 
   
   if (trades_today.Search(ticket)) {
      PrintFormat("%s: Ticket: %i already exists.", __FUNCTION__, ticket); 
      return false; 
   }
   trades_today.Append(ticket); 
   return true; 
}

int      CAccounts::Today(void) {
   //--- Builds trades executed today
   //--- Determine starting pointed of linked list traversal 
   
   
   if (m_first == NULL || m_last == NULL) {
      PrintFormat("%s: Contents are empty.", __FUNCTION__);
      return 0; 
   }
   
   
   int diff_first = Diff(m_first.trade.open_time);
   int diff_last  = Diff(m_last.trade.open_time); 
   CHistoryObject *head; 
   if (diff_first > diff_last) Reverse(); 
   head = m_first; 
   
   
   datetime target      = GetDate(TimeCurrent()); 
   datetime reference   = GetDate(head.trade.open_time); 
   
   while (target == reference) {
      Store(head, today); 
      
      head        = head.Next(); 
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
   
   double pl_today   = 0; 
   int num_today     = ArraySize(today);
   if (num_today == 0) {
      PrintFormat("%s: Uninitialized Array.", __FUNCTION__);
      if (Today() == 0) {
         PrintFormat("%s: No Trades Today.", __FUNCTION__);
         return 0;
      } 
   }
   
   
   CHistoryObject *head = today[0]; 
   datetime date_today  = GetDate(TimeCurrent()); 
   datetime reference   = GetDate(head.trade.open_time);
   
   while(date_today == reference) {
      double profit = head.trade.profit; 
      pl_today+=profit; 
      head = head.Next(); 
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