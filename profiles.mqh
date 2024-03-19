
struct TradeProfile {
   string   trade_symbol;
   int      trade_days[], trade_use_pd;
   double   low_volatility_threshold;
} TRADE_PROFILE;

class CProfiles {
   protected:
   private:
   public: 
      int FILE_HANDLE;
      string FILE_PATH;
      string SYMBOLS[];

      CProfiles(string path);
      ~CProfiles();
      
      TradeProfile BuildProfile();
      int   ClearHandle();
      int   ClearTradingDays();
      int   NumTradingDays();
      int   AddToSymbols(string symbol);

}; 

CProfiles::CProfiles(string path) {
   FILE_PATH   = path; 
}

CProfiles::~CProfiles(void) {
   ClearHandle(); 
   ClearTradingDays();
}

int   CProfiles::ClearHandle(void) {
   FileClose(FILE_HANDLE);
   FileFlush(FILE_HANDLE);
   
   
   FILE_HANDLE = 0;
   return FILE_HANDLE;
}

int   CProfiles::ClearTradingDays(void) {
   ArrayResize(TRADE_PROFILE.trade_days, 0);
   ArrayFree(TRADE_PROFILE.trade_days);
   return ArraySize(TRADE_PROFILE.trade_days);
}

int   CProfiles::AddToSymbols(string symbol) {
   int size = ArraySize(SYMBOLS);
   ArrayResize(SYMBOLS, size+1);
   SYMBOLS[size] = symbol;
   return 1; 
}

TradeProfile     CProfiles::BuildProfile(void) {

   ResetLastError();
   ClearHandle(); 
   
   if (FileIsExist(FILE_PATH, FILE_COMMON)) {
      PrintFormat("%s File %s found", __FUNCTION__, FILE_PATH);
      
   } else PrintFormat("%s File %s not found.", __FUNCTION__, FILE_PATH);
   
   FILE_HANDLE    = FileOpen(FILE_PATH, FILE_CSV | FILE_READ | FILE_ANSI | FILE_COMMON, "\n");
   if (FILE_HANDLE == -1) return TRADE_PROFILE; 
   
   string      result[];
   
   while (!FileIsLineEnding(FILE_HANDLE)) {
      string file_string = FileReadString(FILE_HANDLE);
      int split = (int)StringSplit(file_string, ',', result);
      
      if (split < 4) continue; 
      
      
      AddToSymbols(result[0]);
      if (result[0] != Symbol()) continue; 
      
      PrintFormat("%s PROFILE FOUND FOR %s", __FUNCTION__, Symbol());
      TRADE_PROFILE.trade_symbol       = result[0];
      TRADE_PROFILE.low_volatility_threshold = StringToDouble(result[1]);
      
      uchar char_array[];
      int num_days = StringToCharArray(StringTrimRight(StringTrimLeft(result[2])), char_array); 
      
      for(int i = 0; i < num_days - 1; i++) {
         int size = ArraySize(TRADE_PROFILE.trade_days);
         ArrayResize(TRADE_PROFILE.trade_days, size+1);
         TRADE_PROFILE.trade_days[i] = (int)StringToInteger(CharToString(char_array[i])); 
         
      } 
      
      ArraySort(TRADE_PROFILE.trade_days, WHOLE_ARRAY, 0, MODE_ASCEND);
      
      TRADE_PROFILE.trade_use_pd    = (int)result[3];
   }
   ClearHandle();
   return TRADE_PROFILE;
}

int      CProfiles::NumTradingDays(void)  { return ArraySize(TRADE_PROFILE.trade_days); }