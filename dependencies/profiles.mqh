
#include "logging.mqh"


struct TradeProfile {
   string   trade_symbol;
   int      trade_days[], trade_use_pd;
   double   low_volatility_threshold;
} TRADE_PROFILE;

class CProfiles {
protected:
private:
   int      file_handle_;
   string   file_path_, symbols_[]; 
   
   CLogging    *Log_; 
   
public: 

   int      FileHandle()   const    { return file_handle_; }
   string   FilePath()     const    { return file_path_; }
   
   CProfiles(string path);
   ~CProfiles();
   
   TradeProfile BuildProfile();
   int   ClearHandle();
   int   ClearTradingDays();
   int   NumTradingDays();
   int   AddToSymbols(string symbol);

}; 

CProfiles::CProfiles(string path) : 
   file_path_(path) {
   
   Log_  = new CLogging(true, false, false);    
   
}

CProfiles::~CProfiles(void) {
   ClearHandle(); 
   ClearTradingDays();
   delete Log_; 
}

int   CProfiles::ClearHandle(void) {
   FileClose(file_handle_);
   FileFlush(file_handle_);
   
   
   file_handle_ = 0;
   return file_handle_;
}

int   CProfiles::ClearTradingDays(void) {
   ArrayResize(TRADE_PROFILE.trade_days, 0);
   ArrayFree(TRADE_PROFILE.trade_days);
   return ArraySize(TRADE_PROFILE.trade_days);
}

int   CProfiles::AddToSymbols(string symbol) {
   int size = ArraySize(symbols_);
   ArrayResize(symbols_, size+1);
   symbols_[size] = symbol;
   return 1; 
}

TradeProfile     CProfiles::BuildProfile(void) {

   ResetLastError();
   ClearHandle(); 
   
   if (FileIsExist(FilePath(), FILE_COMMON)) {
      Log_.LogInformation(StringFormat("File %s found.", FilePath()), __FUNCTION__); 
   } else Log_.LogError(StringFormat("File %s not found.", file_path_), __FUNCTION__);
   
   file_handle_    = FileOpen(file_path_, FILE_CSV | FILE_READ | FILE_ANSI | FILE_COMMON, "\n");
   if (file_handle_ == -1) return TRADE_PROFILE; 
   
   string      result[];
   
   while (!FileIsLineEnding(file_handle_)) {
      string file_string = FileReadString(file_handle_);
      int split = (int)StringSplit(file_string, ',', result);
      
      if (split < 4) continue; 
      
      
      AddToSymbols(result[0]);
      if (result[0] != Symbol()) continue; 
      Log_.LogInformation(StringFormat("Profile found for %s", Symbol()), __FUNCTION__); 
      
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