

#include "definition.mqh"
//--- TEMPORARY 

class CReports {
private:
   string   reason_, path_; 
   CPoolObject<TradeObj>      TradeObjects_; 
protected:
public:
   CReports(CPool<int> *&tickets);
   ~CReports(){};
   
   void     Reason(string reason)      { reason_ = reason; }
   string   Reason(void)   const       { return reason_; }
   
   void     Path(string path)          { path_ = path; }
   string   Path(void)     const       { return path_; }
   
   void     Generate(CPool<int> *&tickets); 
   string   CloseReason(ENUM_SIGNAL   signal); 
   int      Export(ENUM_SIGNAL signal = -1); 
   bool     FileValid(); 
   bool     Write(string row); 
   void     Clear(int handle); 
   string   Header(); 
   string   Message(TradeObj &obj); 
   bool     HeaderExist(); 
};

CReports::CReports(CPool<int> *&tickets) {
   const string trail = IsTesting() ? "backtest" : "live";
   path_ = StringConcatenate(REPORTS_DIRECTORY, Symbol(), "_report_", trail, ".csv"); 
   Generate(tickets); 
}


void        CReports::Generate(CPool<int> *&tickets) {
   /**
      Generates Trade Objects 
   **/
   int num_tickets = tickets.Size();
   
   CTradeOps   *ops  = new CTradeOps();
   ops.SYMBOL(Symbol()); 
   if (num_tickets > 0) Print("NUM TICKETS: ", num_tickets); 
   for (int i = 0; i < num_tickets; i++) {
      int ticket  = tickets.Item(i); 
      int s       = ops.OP_HistorySelectByTicket(ticket); 
      
      TradeObj    trade; 
      trade.ticket         = ticket;     
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
      
      TradeObjects_.Append(trade); 
   }
   delete ops; 
   //PrintFormat("%s: %i Objects Generated.", __FUNCTION__, TradeObjects.Size()); 
}

int         CReports::Export(ENUM_SIGNAL signal = -1) {
   if (TradeObjects_.Size() <= 0) {
      //Print("Trade Objects is empty. Nothing to export."); 
      return 0; 
   } 
   
   if (reason_ == NULL && signal == -1) {
      //Print("Error exporting closed trades. No values given for reason/signal."); 
      return 0;
   }
   
   if (reason_ == NULL) reason_ = CloseReason(signal); 
   
   int size = TradeObjects_.Size();
   
   if (!FileValid() && !HeaderExist()) Write(Header()); 
   
   for (int i = 0; i < size; i++) {
      TradeObj trade = TradeObjects_.Item(i); 
      string message = Message(trade); 
      Write(message); 
   }
   
   return 1;    
}

bool        CReports::HeaderExist(void) {
   int handle = FileOpen(Path(), FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON); 
   
   while(!FileIsLineEnding(handle)) {
      string file_string = FileReadString(handle); 
      if (file_string == Header()) {
         Clear(handle);
         return true; 
      }      
      break; 
   }
   Clear(handle);
   return false;
   
}

string      CReports::Message(TradeObj &obj) {
   string message = StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", 
      (string)obj.ticket,
      TimeToString(obj.open_time), 
      EnumToString(obj.order_type), 
      (string)obj.volume, 
      obj.symbol, 
      (string)obj.open_price, 
      (string)obj.stop_loss,
      (string)obj.take_profit,
      TimeToString(obj.close_time), 
      (string)obj.close_price, 
      (string)obj.profit,
      (string)obj.magic,
      reason_); 
      
   return message; 
}


bool        CReports::FileValid(void) {
   if (!FileIsExist(Path())) return false; 
   return true; 
}

bool        CReports::Write(string row) {
   int handle = FileOpen(Path(), FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON); 
   FileSeek(handle, 0, SEEK_END); 
   FileWrite(handle, row); 
   Clear(handle); 
   return handle; 
}

void        CReports::Clear(int handle) {
   FileClose(handle);
   FileFlush(handle); 
}

string      CReports::Header(void) {
   const string header = "ticket,order_open_time,order_type,lots,symbol,order_open_price,sl,tp,order_close_time,order_close_price,profit,magic,reason";
   return header; 
}   

string      CReports::CloseReason(ENUM_SIGNAL signal) {
   switch(signal) {
      case TRADE_LONG:
      case TRADE_SHORT: 
         return "trade"; 
      case CUT_LONG:
      case CUT_SHORT:   
         return "cut";
      case TAKE_PROFIT_LONG:
      case TAKE_PROFIT_SHORT:
         return "take profit"; 
       
   }
   return ""; 
}