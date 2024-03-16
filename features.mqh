
struct Settings {
   int      day_vol_lookback, day_peak_lookback, norm_spread_lookback, norm_spread_ma_lookback;
   int      skew_lookback, bbands_lookback, slow_bbands_lookback, bbands_num_sdev;
   double   spread_threshold, skew_threshold; 
   
   int      entry_window_open, entry_window_close, trade_deadline; 
   
   double   catloss, rpt; 
   
   int      min_sl_distance;
   
   string   indicator_path, skew_filename, spread_filename, sdev_filename;
} SETTINGS; 

struct SymbolConfig {
   int      trade_days[], trade_use_pd;
   double   low_volatility_threshold, sl;
} SYMBOL_CONFIG;

typedef  bool (*TParse) (string, string);

class CFeatureLoader {
   protected:
   private:
      string      directory;
      string      file_name; 
      string      file_path; 
      
   public:
      CFeatureLoader(string directory_value, string file_name_value);
      ~CFeatureLoader() {}; 
   
      void     DIRECTORY(string value)    { directory = value; }
      
      string   DIRECTORY(void)            { return directory; }
      string   FILENAME(void)             { return file_name; }
      string   FILEPATH(void)             { return file_path; }
      
      bool     LoadFile(TParse parse_func); 
      void     PrintSettings();
      
      
};


CFeatureLoader::CFeatureLoader(string directory_value, string file_name_value) {
   // DIRECTORY: recurve\\settings\\
   DIRECTORY(directory_value); 
   file_name      = StringFormat("%s.ini", file_name_value); 
   file_path      = directory+file_name; 
   
   PrintFormat("Config File Path: %s", file_path); 
}

//bool        CFeatureLoader::ParseData(string key,string value) { return true; }

bool        CFeatureLoader::LoadFile(TParse parse_func) {
   
   
   if (!FileIsExist(FILEPATH(), FILE_COMMON)) {
      PrintFormat("Configuration file not found at directory: %s", DIRECTORY());
      return false; 
   }
   else {
      Print("Configuration file found.");
   }
   string result[];
   
   int handle  = FileOpen(FILEPATH(), FILE_COMMON | FILE_SHARE_READ | FILE_TXT | FILE_ANSI); 
   if (handle == INVALID_HANDLE) {
      PrintFormat("Failed to load configuration file: %s", FILEPATH());
      return false; 
   }
   
   FileSeek(handle, 0, SEEK_SET); 
   while (!FileIsEnding(handle)) {
      
      string   filestring     = StringTrimLeft(StringTrimRight(FileReadString(handle))); 
      
      int      split          = StringSplit(filestring, '=', result);  
      
      string key = "", value = "";
      
      if (split > 0)    key   = result[0];
      if (split > 1)    value = result[1];
      
      
      bool parse_kv = parse_func(key, value);
      if (!parse_kv) PrintFormat("Error Parsing. Key: %s, Value: %s", key, value); 
      
   }
   FileClose(handle);
   FileFlush(handle);
   return true;
}


bool Parse(string key, string value) {
   if (key == "" || value == "") return true; 
   if (key == "day_vol_lookback")               SETTINGS.day_vol_lookback     = StringToInteger(value);  
   else if (key == "day_peak_lookback")         SETTINGS.day_peak_lookback    = StringToInteger(value); 
   else if (key == "norm_spread_lookback")      SETTINGS.norm_spread_lookback = StringToInteger(value); 
   else if (key == "norm_spread_ma_lookback")   SETTINGS.norm_spread_ma_lookback = StringToInteger(value);
   else if (key == "skew_lookback")             SETTINGS.skew_lookback        = StringToInteger(value);
   else if (key == "bbands_lookback")           SETTINGS.bbands_lookback      = StringToInteger(value);
   else if (key == "slow_bbands_lookback")      SETTINGS.slow_bbands_lookback = StringToInteger(value);
   else if (key == "bbands_num_sdev")           SETTINGS.bbands_num_sdev      = StringToInteger(value);
   else if (key == "spread_threshold")          SETTINGS.spread_threshold     = StringToDouble(value);
   else if (key == "skew_threshold")            SETTINGS.skew_threshold       = StringToDouble(value);
   else if (key == "entry_window_open")         SETTINGS.entry_window_open    = StringToInteger(value);
   else if (key == "entry_window_close")        SETTINGS.entry_window_close   = StringToInteger(value);
   else if (key == "trade_deadline")            SETTINGS.trade_deadline       = StringToInteger(value);
   else if (key == "catloss")                   SETTINGS.catloss              = StringToDouble(value);
   else if (key == "rpt")                       SETTINGS.rpt                  = StringToDouble(value);
   else if (key == "min_sl_distance")           SETTINGS.min_sl_distance      = StringToInteger(value); 
   else if (key == "indicator_path")            SETTINGS.indicator_path       = value;
   else if (key == "skew_filename")             SETTINGS.skew_filename        = value;
   else if (key == "spread_filename")           SETTINGS.spread_filename      = value;
   else if (key == "sdev_filename")             SETTINGS.sdev_filename        = value; 
   return true; 
}

bool  ParseSymbolConfig(string key, string value) {
   if (key == "" || value == "") return true; 
   else if (key == "low_vol_threshold")   SYMBOL_CONFIG.low_volatility_threshold = StringToDouble(value);
   else if (key == "use_pd")              SYMBOL_CONFIG.trade_use_pd             = StringToInteger(value);
   else if (key == "sl")                  SYMBOL_CONFIG.sl                       = StringToDouble(value);
   else if (key == "days") {
      string result[];
      int split = StringSplit(value, ',', result);
      ArrayResize(SYMBOL_CONFIG.trade_days, split);
      for (int i = 0; i < split; i++) SYMBOL_CONFIG.trade_days[i]      = (int)result[i]; 
   }
   return true; 
}