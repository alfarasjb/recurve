

#include "../dependencies/definition.mqh"
#include "../dependencies/logging.mqh"

struct Currency {
   string base, quote; 
};

enum ENUM_CORRELATION_TYPE {
   DIRECT,
   INDIRECT,
   NO_CORRELATION
};

class CCorrelation : CTradeOps {
private:
         int      correlation_limit_, num_correlated_pairs_; 

         bool     Match(const string target_symbol); 
         bool     IsCorrelated(const int ticket, ENUM_ORDER_TYPE order_type); 
         Currency Split(string symbol); 
         ENUM_CORRELATION_TYPE CorrelationType(Currency& current_symbol, Currency& target_symbol); 
public:
   
   CCorrelation(int magic, int limit);
   ~CCorrelation(); 

         int      CorrelatedPairs(ENUM_ORDER_TYPE order_type); 
         bool     CorrelationValid(ENUM_ORDER_TYPE order_type); 
         void     RaiseError(ENUM_ORDER_TYPE order_type); 
         
         int      NumCorrelatedPairs() const { return num_correlated_pairs_; }
         void     NumCorrelatedPairs(int value) { num_correlated_pairs_ = value; }
         
}; 


CCorrelation::CCorrelation(int magic, int limit) 
   : correlation_limit_ (limit)
   , CTradeOps(Symbol(), magic) {
         
}

CCorrelation::~CCorrelation() {}

bool        CCorrelation::CorrelationValid(ENUM_ORDER_TYPE order_type) {
   NumCorrelatedPairs(CorrelatedPairs(order_type)); 
   return NumCorrelatedPairs() < correlation_limit_; 
}

int         CCorrelation::CorrelatedPairs(ENUM_ORDER_TYPE order_type) {
   int s, correlated_positions, ticket; 
   for (int i = 0; i < PosTotal(); i++) {
      s = OP_OrderSelectByIndex(i); 
      ticket = PosTicket();
      if (OrderIsPending(ticket)) continue;  
      if (!Match(PosSymbol())) continue; 
      if (!IsCorrelated(ticket, order_type)) continue; 
      correlated_positions++; 
   }
   return correlated_positions; 
}

bool        CCorrelation::Match(const string target_symbol) {
   Currency curr = Split(Symbol()); 
   
   if (Symbol() == target_symbol) return false; 
   if (StringFind(target_symbol, curr.base) >= 0) return true;
   if (StringFind(target_symbol, curr.quote) >= 0) return true;
   return false;
}

bool        CCorrelation::IsCorrelated(const int ticket, ENUM_ORDER_TYPE order_type) {
   if (PosTicket() != ticket) OP_OrderSelectByTicket(ticket); 
   
   Currency current_symbol = Split(Symbol());
   Currency target_symbol = Split(PosSymbol()); 
   
   switch(CorrelationType(current_symbol, target_symbol)) {
      case DIRECT:
         return order_type == PosOrderType(); 
      case INDIRECT:
         return order_type != PosOrderType(); 
   }
   // dummy 
   return false;  
   
}

ENUM_CORRELATION_TYPE CCorrelation::CorrelationType(Currency &current_symbol,Currency &target_symbol) {
   if (current_symbol.base == target_symbol.base) return DIRECT;
   if (current_symbol.quote == target_symbol.quote) return DIRECT;
   if (current_symbol.base == target_symbol.quote) return INDIRECT;
   if (current_symbol.quote == target_symbol.base) return INDIRECT; 
   return NO_CORRELATION;
}

Currency    CCorrelation::Split(string symbol) {
   Currency curr;
   curr.base = StringSubstr(symbol, 0, 3);
   curr.quote = StringSubstr(symbol, 3, 3);
   return curr;
}


         
         
void        CCorrelation::RaiseError(ENUM_ORDER_TYPE order_type) {
   Log_.LogInformation(StringFormat("Maximum correlated positions reached for %s - %s. Num Correlated Positions: %i", 
      Symbol(), 
      EnumToString(order_type), 
      NumCorrelatedPairs()), __FUNCTION__); 
}