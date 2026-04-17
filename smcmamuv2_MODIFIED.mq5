//+------------------------------------------------------------------+
//| smcmamuv2_MODIFIED.mq5                                           |
//| Optimized Version with Enhanced Risk Management                  |
//+------------------------------------------------------------------+

#property copyright "smcmamuv2_MODIFIED"
#property version   "2.1"
#property description "Optimized with Dynamic Risk Management"
#property strict

//--- input parameters
input group "=== CORE SETTINGS ==="
input string TradeSymbol = "GOLD#";   // Symbol to trade
input bool EnableFVG = true;           // Enable FVG Strategy
input bool EnableOB = true;            // Enable Order Blocks Strategy
input bool EnableBOS = true;           // Enable Break of Structure

input group "=== RISK MANAGEMENT ==="
input double RiskPerTrade = 0.5;       // Risk 0.5% per trade (replaces fixed lots)
input int StopLoss = 150;              // SL in points
input int TakeProfit = 300;            // TP in points
input double DailyLossLimit = 30.0;    // Max daily loss in account currency
input ulong MagicNumber = 12345;       // Magic Number

input group "=== OPTIMIZED SETTINGS ==="
input bool UseDynamicRR = true;        // Dynamic Risk-Reward
input bool UseTrendFilter = true;      // Trend Alignment Filter
input bool UseTimeFilter = true;       // Trading Hours Filter
input bool UseTrailingStop = true;     // Enable Trailing Stop
input bool UseDailyLimit = true;       // Daily Loss Protection

input group "=== FVG SETTINGS ==="
input int FVG_MinSize = 181;           // Min FVG size in points
input int FVG_Lookback = 248;          // Bars to look back

input group "=== ORDER BLOCK SETTINGS ==="
input double OB_FibLevel = 61.8;       // Fib retracement level
input int OB_Lookback = 60;            // Bars to look back

input group "=== BOS SETTINGS ==="
input int BOS_SwingPeriod = 5;         // Swing detection period

//--- global variables
datetime lastBar = 0;
double swingHigh = 0.0, swingLow = 0.0;
double dailyProfit = 0.0;
datetime lastDailyCheck = 0;
datetime lastProcessedDealTime = 0;
double point = 0.0;
string symbol = "";

//--- MA handles for MQL5
int ma20Handle = INVALID_HANDLE;
int ma50Handle = INVALID_HANDLE;

enum SignalType
{
   SIGNAL_NONE = 0,
   SIGNAL_FVG_BULL,
   SIGNAL_OB_BULL,
   SIGNAL_BOS_BULL,
   SIGNAL_FVG_BEAR,
   SIGNAL_OB_BEAR,
   SIGNAL_BOS_BEAR
};

//+------------------------------------------------------------------+
//| Utility: create start-of-day time                               |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime value)
{
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Utility: normalize volume by symbol step                        |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      step = 0.01;

   volume = MathMax(minLot, MathMin(maxLot, volume));
   volume = MathFloor(volume / step) * step;

   int digits = 2;
   if(step > 0.0)
      digits = (int)MathRound(-MathLog10(step));

   return NormalizeDouble(volume, MathMax(0, digits));
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   symbol = (StringLen(TradeSymbol) > 0) ? TradeSymbol : _Symbol;

   if(!SymbolSelect(symbol, true))
   {
      Print("Failed to select symbol: ", symbol, " Error: ", GetLastError());
      return(INIT_FAILED);
   }

   point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
   {
      Print("Invalid point value for symbol: ", symbol);
      return(INIT_FAILED);
   }

   if(StopLoss <= 0)
   {
      Print("StopLoss must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
   }

   Print("=== smcmamuv2_MODIFIED Loaded ===");
   Print("Symbol: ", symbol);
   Print("Risk Management: ", RiskPerTrade, "% per trade");
   Print("StopLoss: ", StopLoss, " points | TakeProfit: ", TakeProfit, " points");
   Print("R/R Ratio: ", (StopLoss > 0 ? double(TakeProfit) / StopLoss : 0));

   ResetDailyProfit();

   // Initialize MA handles for MQL5
   ma20Handle = iMA(symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   ma50Handle = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);

   if(ma20Handle == INVALID_HANDLE || ma50Handle == INVALID_HANDLE)
   {
      Print("Error creating MA handles. Error code: ", GetLastError());
      return(INIT_FAILED);
   }

   Print("MA handles created successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Reset daily profit tracking                                      |
//+------------------------------------------------------------------+
void ResetDailyProfit()
{
   datetime now = TimeCurrent();
   lastDailyCheck = GetDayStart(now);
   dailyProfit = 0.0;
   lastProcessedDealTime = lastDailyCheck;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== smcmamuv2_MODIFIED Unloaded ===");
   Print("Total Daily P/L: $", dailyProfit);

   // Release MA handles
   if(ma20Handle != INVALID_HANDLE) IndicatorRelease(ma20Handle);
   if(ma50Handle != INVALID_HANDLE) IndicatorRelease(ma50Handle);
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBar = iTime(symbol, PERIOD_CURRENT, 0);
   if(currentBar != lastBar)
   {
      lastBar = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if already in position                                     |
//+------------------------------------------------------------------+
bool IsInPosition()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update tracked daily profit from deal history                    |
//+------------------------------------------------------------------+
void UpdateDailyProfitFromHistory()
{
   if(!UseDailyLimit)
      return;

   datetime now = TimeCurrent();
   datetime dayStart = GetDayStart(now);

   if(dayStart != lastDailyCheck)
   {
      lastDailyCheck = dayStart;
      dailyProfit = 0.0;
      lastProcessedDealTime = dayStart;
   }

   if(!HistorySelect(lastProcessedDealTime, now))
      return;

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      if(dealTime <= lastProcessedDealTime)
         continue;

      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != symbol)
         continue;

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)MagicNumber)
         continue;

      long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY)
         continue;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                      HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                      HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      dailyProfit += profit;

      if(dealTime > lastProcessedDealTime)
         lastProcessedDealTime = dealTime;

      Print("Deal closed. P/L: $", profit, " | Daily Total: $", dailyProfit);
   }
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
   if(!UseDailyLimit)
      return false;

   UpdateDailyProfitFromHistory();
   return (dailyProfit <= -MathAbs(DailyLossLimit));
}

//+------------------------------------------------------------------+
//| Check trading hours                                              |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTimeFilter) return true;

   MqlDateTime dt;
   TimeCurrent(dt);
   int currentHour = dt.hour;

   // Trade during active Gold hours (Asian/London sessions)
   return (currentHour >= 1 && currentHour <= 20); // 01:00 - 20:00
}

//+------------------------------------------------------------------+
//| Check trend alignment                                            |
//+------------------------------------------------------------------+
bool IsTrendAligned(int type) // 1 for buy, -1 for sell
{
   if(!UseTrendFilter) return true;

   double ma20Arr[1], ma50Arr[1];

   // Get MA values from previous bar (shift 1)
   if(CopyBuffer(ma20Handle, 0, 1, 1, ma20Arr) < 1) return true;
   if(CopyBuffer(ma50Handle, 0, 1, 1, ma50Arr) < 1) return true;

   double ma20 = ma20Arr[0];
   double ma50 = ma50Arr[0];

   double currentPrice = (type == 1) ?
                         SymbolInfoDouble(symbol, SYMBOL_ASK) :
                         SymbolInfoDouble(symbol, SYMBOL_BID);

   if(type == 1) // Buy
      return (currentPrice > ma20 && ma20 > ma50);

   // Sell
   return (currentPrice < ma20 && ma20 < ma50);
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on risk %                       |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, int slPoints)
{
   if(slPoints <= 0)
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * riskPercent / 100.0;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0)
   {
      Print("Invalid tick data. Fallback to minimum lot.");
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }

   double slDistancePrice = slPoints * point;
   double valuePerLotAtSL = (slDistancePrice / tickSize) * tickValue;

   if(valuePerLotAtSL <= 0.0)
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double lotSize = riskAmount / valuePerLotAtSL;
   lotSize = NormalizeVolume(lotSize);

   Print("Dynamic Lot: ", lotSize, " | Balance: $", accountBalance, " | Risk: $", riskAmount);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Open buy position with enhanced risk management                  |
//+------------------------------------------------------------------+
bool OpenBuyPosition(string comment)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double sl = 0.0, tp = 0.0;

   // Dynamic Risk-Reward
   if(UseDynamicRR)
   {
      sl = ask - StopLoss * point;
      tp = ask + TakeProfit * point;
   }
   else
   {
      sl = (StopLoss > 0) ? ask - StopLoss * point : 0.0;
      tp = (TakeProfit > 0) ? ask + TakeProfit * point : 0.0;
   }

   double lot = CalculateLotSize(RiskPerTrade, StopLoss);

   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = comment;
   request.deviation = 10;

   if(OrderSend(request, result))
   {
      Print("BUY Order: ", comment, " | Lot:", lot, " | SL:", sl, " | TP:", tp);
      return true;
   }

   Print("BUY Order Failed: retcode ", result.retcode, " | Error ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Open sell position with enhanced risk management                 |
//+------------------------------------------------------------------+
bool OpenSellPosition(string comment)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = 0.0, tp = 0.0;

   // Dynamic Risk-Reward
   if(UseDynamicRR)
   {
      sl = bid + StopLoss * point;
      tp = bid - TakeProfit * point;
   }
   else
   {
      sl = (StopLoss > 0) ? bid + StopLoss * point : 0.0;
      tp = (TakeProfit > 0) ? bid - TakeProfit * point : 0.0;
   }

   double lot = CalculateLotSize(RiskPerTrade, StopLoss);

   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = comment;
   request.deviation = 10;

   if(OrderSend(request, result))
   {
      Print("SELL Order: ", comment, " | Lot:", lot, " | SL:", sl, " | TP:", tp);
      return true;
   }

   Print("SELL Order Failed: retcode ", result.retcode, " | Error ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Enhanced trailing stop                                           |
//+------------------------------------------------------------------+
void CheckTrailingStop()
{
   if(!UseTrailingStop || PositionsTotal() == 0) return;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      string positionSymbol = PositionGetString(POSITION_SYMBOL);
      ulong positionMagic = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(positionMagic != MagicNumber || positionSymbol != symbol)
         continue;

      int positionType = (int)PositionGetInteger(POSITION_TYPE);
      double currentSl = PositionGetDouble(POSITION_SL);
      double currentPrice = (positionType == POSITION_TYPE_BUY) ?
                            SymbolInfoDouble(symbol, SYMBOL_BID) :
                            SymbolInfoDouble(symbol, SYMBOL_ASK);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      if(positionType == POSITION_TYPE_BUY)
      {
         double newSL = openPrice + 500 * point; // Break even + 5 pips
         if(currentPrice > openPrice + 1500 * point) // 15 pips profit
            newSL = currentPrice - 1000 * point; // Trail by 10 pips

         if(newSL > currentSl)
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = newSL;
            request.tp = PositionGetDouble(POSITION_TP);
            request.magic = MagicNumber;

            if(OrderSend(request, result))
               Print("Trailing Stop Updated: BUY - New SL: ", newSL);
         }
      }
      else
      {
         double newSL = openPrice - 500 * point; // Break even - 5 pips
         if(currentPrice < openPrice - 1500 * point) // 15 pips profit
            newSL = currentPrice + 1000 * point; // Trail by 10 pips

         if(newSL < currentSl || currentSl == 0.0)
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = newSL;
            request.tp = PositionGetDouble(POSITION_TP);
            request.magic = MagicNumber;

            if(OrderSend(request, result))
               Print("Trailing Stop Updated: SELL - New SL: ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FVG Strategy - integrated                                        |
//+------------------------------------------------------------------+
bool CheckFVG_Bullish()
{
   if(!EnableFVG) return false;

   for(int i = 3; i < FVG_Lookback; i++)
   {
      // Bullish FVG: current low > previous high
      double prevHigh = iHigh(symbol, PERIOD_CURRENT, i + 1);
      double currLow = iLow(symbol, PERIOD_CURRENT, i - 1);

      if(currLow > prevHigh + FVG_MinSize * point)
      {
         double fvgMid = (currLow + prevHigh) / 2;
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

         if(currentPrice >= fvgMid && currentPrice <= fvgMid + 500 * point)
            return true;
      }
   }
   return false;
}

bool CheckFVG_Bearish()
{
   if(!EnableFVG) return false;

   for(int i = 3; i < FVG_Lookback; i++)
   {
      // Bearish FVG: current high < previous low
      double prevLow = iLow(symbol, PERIOD_CURRENT, i + 1);
      double currHigh = iHigh(symbol, PERIOD_CURRENT, i - 1);

      if(currHigh < prevLow - FVG_MinSize * point)
      {
         double fvgMid = (currHigh + prevLow) / 2;
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);

         if(currentPrice <= fvgMid && currentPrice >= fvgMid - 500 * point)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Order Block Strategy - integrated                                |
//+------------------------------------------------------------------+
bool CheckOB_Bullish()
{
   if(!EnableOB) return false;

   for(int i = 2; i < OB_Lookback; i++)
   {
      // Bullish OB: bearish candle followed by strong bullish candle
      if(iClose(symbol, PERIOD_CURRENT, i) < iOpen(symbol, PERIOD_CURRENT, i))
      {
         if(iClose(symbol, PERIOD_CURRENT, i - 1) > iOpen(symbol, PERIOD_CURRENT, i - 1) &&
            MathAbs(iClose(symbol, PERIOD_CURRENT, i - 1) - iOpen(symbol, PERIOD_CURRENT, i - 1)) > 500 * point)
         {
            double obHigh = iHigh(symbol, PERIOD_CURRENT, i);
            double obLow = iLow(symbol, PERIOD_CURRENT, i);
            double fibLevel = obLow + (obHigh - obLow) * (OB_FibLevel / 100.0);

            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            if(currentPrice >= fibLevel && currentPrice <= fibLevel + 300 * point)
               return true;
         }
      }
   }
   return false;
}

bool CheckOB_Bearish()
{
   if(!EnableOB) return false;

   for(int i = 2; i < OB_Lookback; i++)
   {
      // Bearish OB: bullish candle followed by strong bearish candle
      if(iClose(symbol, PERIOD_CURRENT, i) > iOpen(symbol, PERIOD_CURRENT, i))
      {
         if(iClose(symbol, PERIOD_CURRENT, i - 1) < iOpen(symbol, PERIOD_CURRENT, i - 1) &&
            MathAbs(iOpen(symbol, PERIOD_CURRENT, i - 1) - iClose(symbol, PERIOD_CURRENT, i - 1)) > 500 * point)
         {
            double obHigh = iHigh(symbol, PERIOD_CURRENT, i);
            double obLow = iLow(symbol, PERIOD_CURRENT, i);
            double fibLevel = obHigh - (obHigh - obLow) * (OB_FibLevel / 100.0);

            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            if(currentPrice <= fibLevel && currentPrice >= fibLevel - 300 * point)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Break of Structure Strategy - integrated                         |
//+------------------------------------------------------------------+
bool IsSwingHigh(int bar)
{
   if(bar < BOS_SwingPeriod) return false;

   double high = iHigh(symbol, PERIOD_CURRENT, bar);
   for(int i = 1; i <= BOS_SwingPeriod; i++)
   {
      if(iHigh(symbol, PERIOD_CURRENT, bar - i) >= high) return false;
      if(iHigh(symbol, PERIOD_CURRENT, bar + i) >= high) return false;
   }
   return true;
}

bool IsSwingLow(int bar)
{
   if(bar < BOS_SwingPeriod) return false;

   double low = iLow(symbol, PERIOD_CURRENT, bar);
   for(int i = 1; i <= BOS_SwingPeriod; i++)
   {
      if(iLow(symbol, PERIOD_CURRENT, bar - i) <= low) return false;
      if(iLow(symbol, PERIOD_CURRENT, bar + i) <= low) return false;
   }
   return true;
}

bool CheckBOS_Bullish()
{
   if(!EnableBOS) return false;

   for(int i = BOS_SwingPeriod; i < 20; i++)
   {
      if(IsSwingHigh(i)) swingHigh = iHigh(symbol, PERIOD_CURRENT, i);
      if(IsSwingLow(i)) swingLow = iLow(symbol, PERIOD_CURRENT, i);
   }

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   return (swingHigh > 0 && ask > swingHigh + 200 * point);
}

bool CheckBOS_Bearish()
{
   if(!EnableBOS) return false;

   for(int i = BOS_SwingPeriod; i < 20; i++)
   {
      if(IsSwingHigh(i)) swingHigh = iHigh(symbol, PERIOD_CURRENT, i);
      if(IsSwingLow(i)) swingLow = iLow(symbol, PERIOD_CURRENT, i);
   }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   return (swingLow > 0 && bid < swingLow - 200 * point);
}

//+------------------------------------------------------------------+
//| Get bullish signal type                                          |
//+------------------------------------------------------------------+
SignalType GetBullishSignal()
{
   if(CheckFVG_Bullish()) return SIGNAL_FVG_BULL;
   if(CheckOB_Bullish()) return SIGNAL_OB_BULL;
   if(CheckBOS_Bullish()) return SIGNAL_BOS_BULL;
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get bearish signal type                                          |
//+------------------------------------------------------------------+
SignalType GetBearishSignal()
{
   if(CheckFVG_Bearish()) return SIGNAL_FVG_BEAR;
   if(CheckOB_Bearish()) return SIGNAL_OB_BEAR;
   if(CheckBOS_Bearish()) return SIGNAL_BOS_BEAR;
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Map signal to order comment                                      |
//+------------------------------------------------------------------+
string SignalToComment(SignalType signal)
{
   switch(signal)
   {
      case SIGNAL_FVG_BULL: return "FVG_Bullish";
      case SIGNAL_OB_BULL: return "OB_Bullish";
      case SIGNAL_BOS_BULL: return "BOS_Break_High";
      case SIGNAL_FVG_BEAR: return "FVG_Bearish";
      case SIGNAL_OB_BEAR: return "OB_Bearish";
      case SIGNAL_BOS_BEAR: return "BOS_Break_Low";
      default: return "";
   }
}

//+------------------------------------------------------------------+
//| Main Tick Function - optimized                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDailyProfitFromHistory();

   if(!IsNewBar())
   {
      CheckTrailingStop();
      return;
   }

   CheckTrailingStop();

   if(!IsTradingTime() || IsDailyLossLimitReached() || IsInPosition())
      return;

   SignalType buySignal = SIGNAL_NONE;
   SignalType sellSignal = SIGNAL_NONE;

   if(IsTrendAligned(1))
      buySignal = GetBullishSignal();

   if(IsTrendAligned(-1))
      sellSignal = GetBearishSignal();

   if(buySignal != SIGNAL_NONE)
   {
      OpenBuyPosition(SignalToComment(buySignal));
      return;
   }

   if(sellSignal != SIGNAL_NONE)
      OpenSellPosition(SignalToComment(sellSignal));
}
