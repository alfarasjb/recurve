


#include "definition.mqh"
#include "trade_ops.mqh" 


class CHistoryObject {
   //--- History Object: Holds historical trade information
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
      CHistoryObject    *contents[], *m_first, *m_last, *today[]; 
      CPoolGeneric<int> tickets; 
      double      m_pl_today, m_deposit, m_start_bal_today; 
      
   public:
      void        First(CHistoryObject *node)   { m_first = node; }
      void        Last(CHistoryObject *node)    { m_last = node; }
      CHistoryObject *First(void)   const { return m_first; }
      CHistoryObject *Last(void)    const { return m_last; } 
   
      CAccounts();
      ~CAccounts(); 
      
      void        InitializeAccounts(); 
      
      void        Traverse(); 
      void        Reverse(); 
      void        ClearContents(); 
      int         Today(); 
      double      PLToday();
      double      StartBalToday(); 
      double      Deposit();  
      
      //--- Generic
      template <typename T>   int   Store(T &data, T &dst[]);
      
      //--- Utility
      int      Diff(datetime target); 
      datetime GetDate(datetime target); 
      
};


CAccounts::CAccounts(void) {
   m_deposit   = Deposit(); 
   InitializeAccounts(); 
   m_pl_today  = PLToday();
   m_start_bal_today  = StartBalToday(); 
}

CAccounts::~CAccounts() { ClearContents(); }

void     CAccounts::ClearContents(void) {
   //--- Clears Array contents and deletes objects 
   
   for (int i = 0; i < ArraySize(contents); i++) delete contents[i]; 
   ArrayFree(contents);
   ArrayResize(contents, 0); 
}

double   CAccounts::Deposit(void) {
   int num_hist = PosHistTotal(); 
   
   int s = OP_HistorySelectByIndex(0); 
   if (PosOrderType() == 6) return PosProfit(); 
   
   s = OP_HistorySelectByIndex(num_hist - 1); 
   if (PosOrderType() == 6) return PosProfit();
   
   else return 0;
}

void     CAccounts::InitializeAccounts(void) {  
   //--- TEMPORARY SOLUTION 
   //--- Populates Tickets 
   int num_hist = PosHistTotal(); 
   double deposit = Deposit(); 
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
      
      if (i == 0) m_first = hist; hist.Prev(NULL); 
      if (i > 0 && i < size - 1) { 
         
         contents[i-1].Next(hist); 
         hist.Prev(contents[i-1]);  
      }
      if (i == size - 1) {
         m_last = hist; 
         hist.Next(NULL);
         hist.Prev(contents[i-1]); 
      }
      
   }
   
   
   int num_contents  = ArraySize(contents);
   int num_today     = ArraySize(today); 
   PrintFormat("Contents Created. Num History: %i, Num Stored: %i Num Today: %i", num_hist, num_contents, num_today); 
}


int      CAccounts::Today(void) {
   //--- Builds trades executed today
   //--- Determine starting pointed of linked list traversal 
   
   if (m_first == NULL || m_last == NULL) {
      Print("Contents are empty.");
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
      head = head.Next(); 
      reference = GetDate(head.trade.open_time); 
   }
   PrintFormat("Trades Today: %i", ArraySize(today));
   
   
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

   CHistoryObject *head = m_last;
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
   
   double pl_today = 0; 
   int num_today = ArraySize(today);
   if (num_today == 0) {
      Print("Uninitialized Array.");
      if (Today() == 0) {
         Print("No Trades Today.");
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
   
   PrintFormat("Final PL Today: %f", pl_today); 
   return pl_today; 
}


double   CAccounts::StartBalToday(void) {
   return UTIL_ACCOUNT_BALANCE() - PLToday(); 
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