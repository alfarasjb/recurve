
#include "dependencies/definition.mqh"

// --- TEMPORARY

template <typename T>
class CPositions : public CPoolGeneric<int>{
   protected:   
   private:
   public:
      CPositions();
      ~CPositions();  
      
      int      Init(); 
      
};

template <typename T>
CPositions::CPositions(void) {}

template <typename T>
CPositions::~CPositions(void) {}

template <typename T>
int         CPositions::Init(void) {

   CTradeOps *ops = new CTradeOps();
   ops.SYMBOL(Symbol());
   ops.MAGIC(InpMagic); 
   Clear(); 
   
   int pos_total = ops.PosTotal(); 
   //int pos_total = PosTotal(); 
   for(int i = 0; i < pos_total; i++) {
      int s = ops.OP_OrderSelectByIndex(i); 
      if (!ops.OP_TradeMatch(i)) continue; 
      //int ticket = PosTicket();
      int ticket = ops.PosTicket();
      Append(ticket); 
   }
   
   delete ops; 
   return Size(); 
}
