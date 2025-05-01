//+------------------------------------------------------------------+
//| Expert Advisor MQL5 - Multi-confirmation trading bot             |
//| Features:                                                       |
//| - 8 signals returning +1, -1, or 0                              |
//| - MinConfirmations customizable                                 |
//| - Dynamic risk management (RiskPercent, SL/TP, trailing stop)  |
//| - Debug logs                                                   |
//+------------------------------------------------------------------+
#property copyright "Formation Trading Algorithmique 2024"
#property link      ""
#property version   "1.00"
#property strict

input int MinConfirmations = 4;          // Minimum confirmations to open trade
input double RiskPercent = 1.0;          // Risk percent per trade
input double ATRMultiplier = 1.0;        // ATR multiplier for SL/TP and trailing stop
input int ATRPeriod = 14;                 // ATR period
input bool DebugMode = true;              // Enable debug logs

//--- Global variables
int bullCount = 0;
int bearCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(DebugMode)
      Print("Expert Advisor initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(DebugMode)
      Print("Expert Advisor deinitialized.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Reset counts
   bullCount = 0;
   bearCount = 0;

   // Calculate signals
   int signals[8];
   signals[0] = SignalBreakOfStructure();
   signals[1] = SignalTrendlineBreak();
   signals[2] = SignalDoubleTopBottom();
   signals[3] = SignalMACD();
   signals[4] = SignalRSI();
   signals[5] = SignalFibonacci();
   signals[6] = SignalSupportResistance();
   signals[7] = SignalVolume();

   // Count bulls and bears
   for(int i=0; i<8; i++)
     {
      if(signals[i] == 1) bullCount++;
      else if(signals[i] == -1) bearCount++;
     }

   if(DebugMode)
     {
      PrintFormat("Signals: %d %d %d %d %d %d %d %d", signals[0], signals[1], signals[2], signals[3], signals[4], signals[5], signals[6], signals[7]);
      PrintFormat("BullCount: %d, BearCount: %d", bullCount, bearCount);
     }

   // Check if we have enough confirmations
   if(bullCount >= MinConfirmations)
     {
      if(PositionSelect(Symbol()) == false)
        {
         OpenPosition(ORDER_TYPE_BUY);
        }
     }
   else if(bearCount >= MinConfirmations)
     {
      if(PositionSelect(Symbol()) == false)
        {
         OpenPosition(ORDER_TYPE_SELL);
        }
     }
   else
     {
      // Close positions if trend reverses or no confirmation
      ClosePositionsIfNeeded();
     }
  }

//+------------------------------------------------------------------+
//| Signal functions (simplified placeholders)                      |
//+------------------------------------------------------------------+
int SignalBreakOfStructure()
  {
   // Placeholder: Implement BOS logic here
   return 0;
  }

int SignalTrendlineBreak()
  {
   // Placeholder: Implement SMA20/SMA50 crossover logic here
   return 0;
  }

int SignalDoubleTopBottom()
  {
   // Placeholder: Implement Double Top/Bottom detection here
   return 0;
  }

int SignalMACD()
  {
   // Placeholder: Implement MACD signal here
   return 0;
  }

int SignalRSI()
  {
   // Placeholder: Implement RSI signal here
   return 0;
  }

int SignalFibonacci()
  {
   // Placeholder: Implement Fibonacci retracement signal here
   return 0;
  }

int SignalSupportResistance()
  {
   // Placeholder: Implement Support/Resistance signal here
   return 0;
  }

int SignalVolume()
  {
   // Placeholder: Implement Volume signal here
   return 0;
  }

//+------------------------------------------------------------------+
//| Open position function                                           |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
  {
   double lotSize = CalculateLotSize();
   double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double sl = 0, tp = 0;
   double atr = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod, 0);

   if(orderType == ORDER_TYPE_BUY)
     {
      sl = price - ATRMultiplier * atr;
      tp = price + ATRMultiplier * atr * 2;
     }
   else if(orderType == ORDER_TYPE_SELL)
     {
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      sl = price + ATRMultiplier * atr;
      tp = price - ATRMultiplier * atr * 2;
     }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "MultiConfirm EA";

   if(!OrderSend(request, result))
     {
      if(DebugMode)
         Print("OrderSend failed: ", GetLastError());
     }
   else
     {
      if(DebugMode)
         Print("Order opened: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " Lot: ", lotSize);
     }
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percent                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;
   double atr = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod, 0);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double stopLossPoints = ATRMultiplier * atr / tickSize;
   double lotSize = riskAmount / (stopLossPoints * tickValue);
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   return lotSize;
  }

//+------------------------------------------------------------------+
//| Close positions if trend reverses or no confirmation            |
//+------------------------------------------------------------------+
void ClosePositionsIfNeeded()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if((posType == POSITION_TYPE_BUY && bearCount >= MinConfirmations) ||
            (posType == POSITION_TYPE_SELL && bullCount >= MinConfirmations))
           {
            ClosePosition(ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close position by ticket                                         |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   request.action = TRADE_ACTION_CLOSE_BY;
   request.position = ticket;
   if(!OrderSend(request, result))
     {
      if(DebugMode)
         Print("Close position failed: ", GetLastError());
     }
   else
     {
      if(DebugMode)
         Print("Position closed: ", ticket);
     }
  }
  
//+------------------------------------------------------------------+
