/*
========== MARCH 29, 2024 =========
1. Updated trade matching to use tickets instead of index.
   Affected files: trade_ops.mqh, trade_mt4.mqh
   
========== MARCH 24, 2024 =========

1. Fixed Var/Lot
   - Fixed Lot / Risk Reference for small accounts (100USD)
   
2. Main Documentation

3. Stacking:
   - Max simultaneous open positiosns 
   - Daily Trade Allocation/Limit
   - Cut Losses/Martingale 
   - Stack on profit 
   
4. Scale Lots 
   - Manual Lot Size scale factor (User input) 
   
5. Data Structure for handling open positions (ALGO_POSITIONS)
   - Handles Open positions 
   
6. CSV Logging Trade Info and Close Reason (reports.mqh) 
   - For model validation 
   
7. Risk Management: Trail & BE 
   - Position management 
   
8. Secure Morning Buffer
   - Used in case basket reaches a certain threshold during a certain time period.
   - Ex: Basket reaches a 5% profit during the AM session, algo closes all positions and secures profit. 
   
9. Restructure Configuration Folder

*/


#include "../dependencies/definition.mqh"
#include "positions.mqh"
#include "reports.mqh"
//#include "accounts_secondary.mqh"
class CRecurveTrade : public CTradeOps {

   protected:
   
      //--- ACCOUNTS
      //CAccounts      *Accounts_; 
   
      //-- SYMBOL PROPERTIES 
      double         tick_value_, trade_points_, contract_size_;
      int            digits_; 
      
      //-- INTERVALS
      CPoolGeneric<int> INTERVALS_;
      CPositions<int>   ALGO_POSITIONS_;
      
      
      // Temporary. Counter used to track number of trades opened today. 
      int            symbol_trades_today_;
      
      string         SYMBOLS_PATH_, SETTINGS_PATH_; 
   private:
      
   public: 
      CLogging       *Log; 
      //-- SYMBOL PROPERTIES WRAPPERS 
      double         TICK_VALUE() const   { return tick_value_; }
      double         TRADE_POINTS() const { return trade_points_; }
      double         DIGITS() const       { return digits_; }
      double         CONTRACT() const     { return contract_size_; }
      
   
      //-- CONSTRUCTOR
      CRecurveTrade(); 
      ~CRecurveTrade(); 
  
      //-- INITIALIZATION
      void           Init(); 
      void           InitializeConfigurationPaths(); 
      void           InitializeFeatureParameters();
      void           InitializeSymbolProperties();
      void           InitializeIntervals();
      void           InitializeDays();
      void           InitializeConfiguration();
      void           InitializeOpenPositions(); 
      void           InitializeAccounts(); 
      void           OnEndOfDay(); 
      void           TrackAccounts(); 
      
      //-- CONFIG
      void           LoadSettingsFromFile();
      void           LoadSettingsFromInput();
      void           LoadSymbolConfigFromFile();
      void           LoadSymbolConfigFromInput();
  
      void           GenerateInterval(int &intervals[]);
  
      //-- FEATURES 
      string         indicator_path(string indicator_name); 
      
      
      double         DAILY_VOLATILITY(int volatility_mode, int shift = 1); 
      double         STANDARD_SCORE(int shift = 1);
      double         SKEW(int shift = 1);
      #ifdef __MQL4__
      double         BBANDS(int mode, int num_sd = 2, int shift = 1);
      double         BBANDS_SLOW(int mode, int num_sd = 2, int shift = 1);
      #endif 
      
      #ifdef __MQL5__ 
      
      double         BBANDS(ENUM_BBANDS_MODE mode, int num_sd = 2, int shift = 1); 
      double         BBANDS_SLOW(ENUM_BBANDS_MODE mode, int num_sd = 2, int shift = 1); 
      double         BBANDS_VALUE(int handle, ENUM_BBANDS_MODE mode); 
      #endif 
      
      //-- FEATURE WRAPPER 
      double         DAY_VOL();
      double         DAY_PEAK_VOL();
      double         UPPER_BANDS();
      double         LOWER_BANDS();
      double         EXTREME_UPPER();
      double         EXTREME_LOWER();
      double         SLOW_UPPER();
      double         SLOW_LOWER();
      double         PD_UPPER_BANDS();
      double         PD_LOWER_BANDS(); 
      
      
      //-- LOGIC
      bool           ValidTradeWindow(); 
      bool           ValidDayVolatility(); 
      bool           ValidDayOfWeek();
      ENUM_SIGNAL    Signal(FeatureValues &features);
      ENUM_SIGNAL    CutLoss(FeatureValues &features); 
      ENUM_SIGNAL    TakeProfit(FeatureValues &features);
      bool           EndOfDay();
      bool           ValidInterval();
      bool           DayOfWeekInTradingDays();
      bool           ValidRecoveryWindow(); 
     
      
      //-- OPERATIONS 
      int            Stage();
      int            SendOrder(ENUM_SIGNAL signal);
      TradeParams    ParamsLong(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer); 
      TradeParams    ParamsShort(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      TradeParams    SetTradeParameters(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      double         CalcLot(double sl_distance);
      double         SLFactor(double entry_price);
      int            SendTradeOrder(TradeParams &PARAMS);
      int            CloseOrder();
      double         CatastrophicSLFactor(double lot, double var);
      double         CatastrophicLossVAR();
      double         ValueAtRisk();
      double         FloatingPL();
      bool           InFloatingLoss();
      FeatureValues  SetLatestFeatureValues();
      bool           PreviousDayValid(ENUM_DIRECTION direction);
      string         IntervalsAsString();
      string         DaysAsString();
      bool           ValidStack(); 
      bool           ValidInvert(); 
      bool           ValidTakeProfit(ENUM_ORDER_TYPE order); 
      double         CalcBuffer();
      int            SecureBuffer(); 
      double         PortfolioRunningPL(); 
      int            UnwindPositions();
      CReports       *GenerateReports(); 
      string         PresetKey(); 
      int            Recover(); 
      
      //--- POSITION MANAGEMENT
      bool           ValidFloatingGain(); 
      bool           ValidFloatingLoss(); 
      bool           ValidTrailStopParams(TrailStopParams &trail_params); 
      //bool           ValidLayers(); 
      bool           Breakeven(int ticket); 
      bool           TrailStop(int ticket); 
      bool           IsRiskFree(int ticket); 
      
      bool           PassedGainThreshold(int ticket);
      bool           ValidTradeToday(); 
      
      //-- DATA STRUCTURE
      int               UpdatePositions();   
      int               RepopulateAlgoPositions(CPoolGeneric<int> *&synthetic); 
      ENUM_ORDER_TYPE   CurrentOpenPosition(); 
      
      int            ClosePositions(ENUM_SIGNAL reason); 
      
      
      //-- GENERIC
      template <typename T>   string      ArrayAsString(T &data[]);
      template <typename T>   void        ClearArray(T &data[]);  
      template <typename T>   void        Append(T &data[], T item);
      template <typename T>   bool        ElementInArray(T element, T &src[]); 
      
      
      //--- SIGNAL MANAGEMENT ---// 
      //--- TEMPORARY ---// 
      
      
      bool        ValidCloseOnTradeLong(int ticket); 
      bool        ValidCloseOnTradeShort(int ticket);
      bool        ValidCloseOnCutLong(int ticket);
      bool        ValidCloseOnCutShort(int ticket);
      bool        ValidCloseOnTakeProfitLong(int ticket);
      bool        ValidCloseOnTakeProfitShort(int ticket); 
      
      
      bool        ValidTradeOpen();
      bool        ValidFeatureBreakeven(int ticket); 
      
      string      TradeLogicErrorReason(ENUM_TRADE_LOGIC_ERROR_REASON reason); 
      
      
   
}; 
CRecurveTrade::CRecurveTrade() : CTradeOps(Symbol(), InpMagic) {
   Log = new CLogging(InpTerminalMsg, InpPushNotifs, false); 
}

CRecurveTrade::~CRecurveTrade() {
   CONFIG.TRADING_DAYS.Clear(); 
   INTERVALS_.Clear();
   ALGO_POSITIONS_.Clear(); 
   delete Log;
   //delete Accounts_; 
}