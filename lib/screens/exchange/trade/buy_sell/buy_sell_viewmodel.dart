/*
* Copyright (c) 2020 Exchangily LLC
*
* Licensed under Apache License v2.0
* You may obtain a copy of the License at
*
*      https://www.apache.org/licenses/LICENSE-2.0
*
*----------------------------------------------------------------------
* Author: barry-ruprai@exchangily.com
*----------------------------------------------------------------------
*/

import 'dart:async';
import 'dart:typed_data';

import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/enums/screen_state.dart';
import 'package:exchangilymobileapp/environments/environment.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/models/wallet/wallet.dart';
import 'package:exchangilymobileapp/screens/exchange/exchange_balance_model.dart';

import 'package:exchangilymobileapp/screens/exchange/trade/my_orders/my_order_model.dart';

import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/api_service.dart';
import 'package:exchangilymobileapp/services/db/wallet_database_service.dart';
import 'package:exchangilymobileapp/services/dialog_service.dart';
import 'package:exchangilymobileapp/services/local_storage_service.dart';
import 'package:exchangilymobileapp/services/navigation_service.dart';
import 'package:exchangilymobileapp/services/order_service.dart';
import 'package:exchangilymobileapp/services/shared_service.dart';
import 'package:exchangilymobileapp/services/trade_service.dart';
import 'package:exchangilymobileapp/services/wallet_service.dart';
import 'package:exchangilymobileapp/utils/abi_util.dart';
import 'package:exchangilymobileapp/utils/kanban.util.dart';
import 'package:exchangilymobileapp/utils/keypair_util.dart';
import 'package:exchangilymobileapp/utils/string_util.dart';
import 'package:flutter/material.dart';
import 'package:keccak/keccak.dart';
import 'package:random_string/random_string.dart';
import 'package:showcaseview/showcase_widget.dart';
import 'package:stacked/stacked.dart';
import 'package:web_socket_channel/io.dart';

import 'package:exchangilymobileapp/shared/globals.dart' as globals;
import 'package:convert/convert.dart';
import 'package:hex/hex.dart';
import 'dart:core';

class BuySellViewModel extends ReactiveViewModel {
  @override
  List<ReactiveServiceMixin> get reactiveServices => [tradeService];

  final log = getLogger('BuySellViewModel');
  List<WalletInfo> walletInfo;
  WalletInfo targetCoinWalletData;
  WalletInfo baseCoinWalletData;
  WalletService walletService = locator<WalletService>();
  SharedService sharedService = locator<SharedService>();
  TradeService tradeService = locator<TradeService>();
  OrderService _orderService = locator<OrderService>();
  WalletDataBaseService databaseService = locator<WalletDataBaseService>();
  NavigationService navigationService = locator<NavigationService>();

  BuildContext context;
  bool bidOrAsk;
  String baseCoinName;
  String targetCoinName;

  TextEditingController kanbanGasPriceTextController = TextEditingController();
  TextEditingController kanbanGasLimitTextController = TextEditingController();
  TextEditingController quantityTextController = TextEditingController();
  TextEditingController priceTextController = TextEditingController();

  double kanbanTransFee = 0.0;
  bool transFeeAdvance = false;

  List<OrderModel> sell;
  List<OrderModel> buy;
  DialogService _dialogService = locator<DialogService>();
  double currentPrice = 0;
  double currentQuantity = 0;
  double sliderValue = 10.0;
  IOWebSocketChannel orderListChannel;
  IOWebSocketChannel tradeListChannel;
  double price = 0.0;
  double quantity;

  double get priceFromTradeService => tradeService.price;
  double get quantityFromTradeService => tradeService.quantity;
  String exgAddress;
  WalletInfo coin;
  // final GlobalKey<MyOrdersState> myordersState = new GlobalKey<MyOrdersState>();
  List<OrderModel> orderList;
  double transactionAmount = 0;
  List<PairDecimalConfig> pairDecimalConfigList = [];
  int priceDecimal = 0;
  int quantityDecimal = 0;
  ApiService apiService = locator<ApiService>();
  String pair = '';
  String tickerName = '';

  //Price passedPair;
  GlobalKey globalKeyOne;
  GlobalKey globalKeyTwo;
  var storageService = locator<LocalStorageService>();
  double unlockedAmount;
  double lockedAmount;
  ExchangeBalanceModel targetCoinExchangeBalance;
  ExchangeBalanceModel baseCoinExchangeBalance;
  bool isReloadMyOrders = false;
  String pairSymbolWithSlash = '';

  bool _isOrderbookLoaded = false;
  bool get isOrderbookLoaded => _isOrderbookLoaded;

  init() async {
    // log.e(pair);
    setBusy(true);

    //  await splitPair(pairSymbolWithSlash);
    setDefaultGasPrice();
    sharedService.context = context;
    getOrderbookLoadedStatus();
    // orderListFromTradeService();
    print('3');
    //  tradeListFromTradeService();
    // print('4');
    //await retrieveWallets();
    exgAddress = await sharedService.getExgAddressFromWalletDatabase();

    await getDecimalPairConfig();
    fillPriceAndQuantityTextFields();
    print('8');
    setBusy(false);
  }

/*----------------------------------------------------------------------
                    get orderbook loaded status
----------------------------------------------------------------------*/
  void getOrderbookLoadedStatus() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      log.i('getOrderbookLoadedStatus timer started');
      _isOrderbookLoaded = tradeService.isOrderbookLoaded;
      if (_isOrderbookLoaded) {
        setBusy(true);
        price = priceFromTradeService;
        quantity = quantityFromTradeService;
        priceTextController.text = price.toString();
        quantityTextController.text = quantityFromTradeService.toString();
        timer.cancel();
        log.i(
            'getOrderbookLoadedStatus timer cancel -- price $price -- controller ${priceTextController.text}');
      } else
        price = 300.0;
      setBusy(false);
      log.w('getOrderbookLoadedStatus $isOrderbookLoaded');
    });
  }

/*----------------------------------------------------------------------
                Single coin exchange balance using old api
----------------------------------------------------------------------*/
  Future getSingleCoinExchangeBalanceFromAll(
      String targetCoin, String baseCoin) async {
    setBusy(true);
    log.e('In get exchange assets');

    targetCoinExchangeBalance =
        await apiService.getSingleCoinExchangeBalance(targetCoin);
    log.i('targetCoin Balance using api ${targetCoinExchangeBalance.toJson()}');

    baseCoinExchangeBalance =
        await apiService.getSingleCoinExchangeBalance(baseCoin);
    log.i('baseCoin Balance using api ${baseCoinExchangeBalance.toJson()}');

    if (targetCoinExchangeBalance == null || baseCoinExchangeBalance == null) {
      String exgAddress = await sharedService.getExgAddressFromWalletDatabase();
      List res = await walletService.getAllExchangeBalances(exgAddress);

      targetCoinExchangeBalance = new ExchangeBalanceModel();
      baseCoinExchangeBalance = new ExchangeBalanceModel();

      res.forEach((coin) {
        if (coin['coin'] == baseCoin) {
          log.w('baseCoin ExchangeBalance $coin');
          baseCoinExchangeBalance.unlockedAmount = coin['amount'];
          baseCoinExchangeBalance.lockedAmount = coin['lockedAmount'];
          print(
              'exchangeBalance using all coins for loop ${baseCoinExchangeBalance.toJson()}');
        }
        // else{
        //     baseCoinExchangeBalance.unlockedAmount = 0.0;
        //   baseCoinExchangeBalance.lockedAmount = 0.0;
        // }
        if (coin['coin'] == targetCoin) {
          log.w('targetCoin ExchangeBalance $coin');
          targetCoinExchangeBalance.unlockedAmount = coin['amount'];
          targetCoinExchangeBalance.lockedAmount = coin['lockedAmount'];
          print(
              'exchangeBalance using all coins for loop ${targetCoinExchangeBalance.toJson()}');
        }
        // else{
        //     targetCoinExchangeBalance.unlockedAmount = 0.0;
        //   targetCoinExchangeBalance.lockedAmount = 0.0;
        // }
      });
    }
    setBusy(false);
  }

  /*----------------------------------------------------------------------
                        Showcase Feature
----------------------------------------------------------------------*/
  showcaseEvent(BuildContext test) async {
    if (!storageService.isShowCaseView)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(test).startShowCase([globalKeyOne, globalKeyTwo]);
      });
  }

  /*----------------------------------------------------------------------
                        Fill text fields
----------------------------------------------------------------------*/
  fillPriceAndQuantityTextFields() {
    setBusy(true);
    // priceTextController.text = priceFromTradeService.toString();
    // price = priceFromTradeService;
    // quantityTextController.text = quantityFromTradeService.toString();
    // quantity = quantityFromTradeService;
    setBusy(false);
  }

  // Set default price for kanban gas price and limit
  setDefaultGasPrice() {
    setBusy(true);
    kanbanGasLimitTextController.text =
        environment["chains"]["KANBAN"]["gasLimit"].toString();
    kanbanGasPriceTextController.text =
        environment["chains"]["KANBAN"]["gasPrice"].toString();
    setBusy(false);
  }

/* ---------------------------------------------------
            Full screen Stack loading indicator
--------------------------------------------------- */
  // Split Pair Name
  splitPair(String pair) async {
    setBusy(true);
    log.e('pair $pair');
    var coinsArray = pair.split("/");
    targetCoinName = coinsArray[0];
    baseCoinName = coinsArray[1];
    tickerName = targetCoinName + baseCoinName;
    log.e('tickername $tickerName');
    await getSingleCoinExchangeBalanceFromAll(targetCoinName, baseCoinName);
    setBusy(false);
  }

/* ---------------------------------------------------
            Handle Text Change
--------------------------------------------------- */
  void handleTextChanged(String name, String text) {
    setBusy(true);
    if (name == 'price') {
      try {
        price = double.parse(text);
        log.w('price $price');
        caculateTransactionAmount();
        updateTransFee();
      } catch (e) {
        setBusy(false);
        log.e('Handle text price changed $e');
      }
    }
    if (name == 'quantity') {
      try {
        quantity = double.parse(text);
        log.w('quantity $quantity');
        caculateTransactionAmount();
        updateTransFee();
      } catch (e) {
        setBusy(false);
        log.e('Handle text quantity changed $e');
      }
    }
    setBusy(false);
  }

  //
/* ---------------------------------------------------
            getPairDecimalConfig
--------------------------------------------------- */
  getDecimalPairConfig() async {
    setBusy(true);
    await apiService.getPairDecimalConfig().then((res) {
      pairDecimalConfigList = res;
      String currentCoinName = targetCoinName + baseCoinName;
      log.w('Current coin name in get decimal config $currentCoinName');
      for (PairDecimalConfig pair in pairDecimalConfigList) {
        if (pair.name == currentCoinName) {
          priceDecimal = pair.priceDecimal;
          quantityDecimal = pair.qtyDecimal;
          log.e('Price and quantity decimal $priceDecimal -- $quantityDecimal');
        }
      }
    });
    log.w(pairDecimalConfigList.length);
    setBusy(false);
  }

/* ---------------------------------------------------
            Full screen Stack loading indicator
--------------------------------------------------- */
  selectBuySellTab(bool value) {
    setBusy(true);
    bidOrAsk = value;
    log.w('bid $bidOrAsk');
    setBusy(false);
  }

/* ---------------------------------------------------
            Retrieve Wallets
--------------------------------------------------- */
  retrieveWallets() async {
    setBusy(true);
    await databaseService.getAll().then((walletList) {
      walletInfo = walletList;

      for (var i = 0; i < walletInfo.length; i++) {
        coin = walletInfo[i];
        if (coin.tickerName == targetCoinName.toUpperCase()) {
          log.e(
              'Coin from wallet info ${coin.tickerName} ---  Target coin name $targetCoinName');
          targetCoinWalletData = coin;
        }
        if (coin.tickerName == baseCoinName.toUpperCase()) {
          log.e(
              'Coin from wallet info ${coin.tickerName} ---  Target coin name $baseCoinName');
          baseCoinWalletData = coin;
        }
        if (coin.tickerName == 'EXG') {
          exgAddress = coin.address;
          // this.refresh(exgAddress);
        }
      }
      setBusy(false);
    }).catchError((error) {
      setBusy(false);
    });
  }

/* ---------------------------------------------------
          Generate Order Hash
--------------------------------------------------- */
  generateOrderHash(bidOrAsk, orderType, baseCoin, targetCoin, amount, price,
      timeBeforeExpiration) {
    setBusy(true);
    var randomStr = randomString(32);
    var concatString = [
      bidOrAsk,
      orderType,
      baseCoin,
      targetCoin,
      amount,
      price,
      timeBeforeExpiration,
      randomStr
    ].join('');
    var outputHashData = keccak(stringToUint8List(concatString));

    // if needed convert the output byte array into hex string.
    var output = hex.encode(outputHashData);
    setBusy(false);
    return output;
  }

/* ---------------------------------------------------
            To Big Int
--------------------------------------------------- */
  toBitInt(num) {
    var numString = num.toString();
    var numStringArray = numString.split('.');
    var zeroLength = 18;
    var val = '';
    if (numStringArray != null) {
      val = numStringArray[0];
      if (numStringArray.length == 2) {
        zeroLength -= numStringArray[1].length;
        val += numStringArray[1];
      }
    }

    var valInt = int.parse(val);
    val = valInt.toString();
    for (var i = 0; i < zeroLength; i++) {
      val += '0';
    }

    return val;
  }

/* ---------------------------------------------------
            Tx Hex For Place Order
--------------------------------------------------- */
  txHexforPlaceOrder(seed) async {
    setBusy(true);
    var timeBeforeExpiration = 423434342432;
    var orderType = 1;
    var baseCoin = walletService.getCoinTypeIdByName(baseCoinName);
    var targetCoin = walletService.getCoinTypeIdByName(targetCoinName);

    if (!bidOrAsk) {
      var tmp = baseCoin;
      baseCoin = targetCoin;
      targetCoin = tmp;
    }

    var orderHash = this.generateOrderHash(bidOrAsk, orderType, baseCoin,
        targetCoin, quantity, price, timeBeforeExpiration);

    var qtyBigInt = this.toBitInt(quantity);
    var priceBigInt = this.toBitInt(price);

    print('qtyBigInt==' + qtyBigInt);
    print('priceBigInt==' + priceBigInt);

    var abiHex = getCreateOrderFuncABI(
        bidOrAsk,
        orderType,
        baseCoin,
        targetCoin,
        qtyBigInt,
        priceBigInt,
        timeBeforeExpiration,
        false,
        orderHash);
    log.e('exg addr $exgAddress');

    var nonce = await getNonce(exgAddress);

    var keyPairKanban = getExgKeyPair(seed);
    var exchangilyAddress = await getExchangilyAddress();
    int kanbanGasPrice = int.parse(kanbanGasPriceTextController.text);
    int kanbanGasLimit = int.parse(kanbanGasLimitTextController.text);

    var txKanbanHex = await signAbiHexWithPrivateKey(
        abiHex,
        HEX.encode(keyPairKanban["privateKey"]),
        exchangilyAddress,
        nonce,
        kanbanGasPrice,
        kanbanGasLimit);
    setBusy(false);
    return txKanbanHex;
  }

/* ---------------------------------------------------
            Update Transfer Fee
--------------------------------------------------- */
  updateTransFee() async {
    setBusy(true);
    var kanbanPrice = int.tryParse(kanbanGasPriceTextController.text);
    var kanbanGasLimit = int.tryParse(kanbanGasLimitTextController.text);
    if (kanbanGasLimit != null && kanbanPrice != null) {
      var kanbanPriceBig = BigInt.from(kanbanPrice);
      var kanbanGasLimitBig = BigInt.from(kanbanGasLimit);
      var kanbanTransFeeDouble =
          bigNum2Double(kanbanPriceBig * kanbanGasLimitBig);
      kanbanTransFee = kanbanTransFeeDouble;
      log.w('fee $kanbanPrice $kanbanGasLimit $kanbanTransFeeDouble');
    }
    setBusy(false);
  }

/* ---------------------------------------------------
            Calculate Transaction Amount
--------------------------------------------------- */
  caculateTransactionAmount() {
    if (price != null && quantity != null && price >= 0 && quantity >= 0) {
      transactionAmount = quantity * price;
    }
    return transactionAmount;
  }

/* ---------------------------------------------------
            Place Buy/Sell Order
--------------------------------------------------- */
  Future placeBuySellOrder() async {
    setBusy(true);
    isReloadMyOrders = false;
    var res = await _dialogService.showDialog(
        title: AppLocalizations.of(context).enterPassword,
        description:
            AppLocalizations.of(context).dialogManagerTypeSamePasswordNote,
        buttonTitle: AppLocalizations.of(context).confirm);
    if (res.confirmed) {
      String mnemonic = res.returnedText;
      Uint8List seed = walletService.generateSeed(mnemonic);

      var txHex = await txHexforPlaceOrder(seed);
      log.e('txhex $txHex');
      var resKanban = await sendKanbanRawTransaction(txHex);
      log.e('resKanban $resKanban');
      if (resKanban != null && resKanban['transactionHash'] != null) {
        sharedService.showInfoFlushbar(
            AppLocalizations.of(context).placeOrderTransactionSuccessful,
            'txid:' + resKanban['transactionHash'],
            Icons.check,
            green,
            context);
        // Future.delayed(new Duration(seconds: 2), () {
        //   getSingleCoinExchangeBalanceFromAll(targetCoinName, baseCoinName);
        //   // isReloadMyOrders = true;
        // });
        Timer.periodic(Duration(seconds: 3), (timer) async {
          var res =
              await tradeService.getTxStatus(resKanban["transactionHash"]);
          if (res != null) {
            log.i('RES $res');
            String status = res['status'];
            if (status == '0x1') {
              setBusy(true);
              log.e('isReloadMyOrders $isReloadMyOrders -- isBusy $isBusy');
              isReloadMyOrders = true;
              getSingleCoinExchangeBalanceFromAll(targetCoinName, baseCoinName);
              Future.delayed(new Duration(milliseconds: 500), () {
                setBusy(true);
                isReloadMyOrders = false;
                log.e('isReloadMyOrders $isReloadMyOrders');
                setBusy(false);
              });
              setBusy(false);
            }
            log.e('isReloadMyOrders $isReloadMyOrders');
            log.i('timer cancelled');
            timer.cancel();
          }
        });
      } else {
        walletService.showInfoFlushbar(
            AppLocalizations.of(context).placeOrderTransactionFailed,
            resKanban.toString(),
            Icons.cancel,
            red,
            context);
      }
    } else {
      if (res.returnedText != 'Closed') {
        showNotification(context);
        setBusy(false);
      }
    }
    setBusy(false);
  }

/* ---------------------------------------------------
            Check Pass
--------------------------------------------------- */
  checkPass(context) async {
    setBusy(true);

    var targetCoinbalance = targetCoinExchangeBalance.unlockedAmount;

    //targetCoinWalletData.inExchange; // coin(asset) bal for sell
    var baseCoinbalance = baseCoinExchangeBalance.unlockedAmount;
    // baseCoinWalletData.inExchange; // usd bal for buy

    if (price == null ||
        quantity == null ||
        price.isNegative ||
        quantity.isNegative) {
      setBusy(false);
      sharedService.alertDialog("", AppLocalizations.of(context).invalidAmount,
          isWarning: false);
      return;
    }

    if (!bidOrAsk) {
      log.e('SELL tx amount $quantity -- targetCoinbalance $targetCoinbalance');
      if (quantity > targetCoinbalance) {
        sharedService.alertDialog(
            "", AppLocalizations.of(context).invalidAmount,
            isWarning: false);
        setBusy(false);
        return;
      } else {
        await placeBuySellOrder();
      }
    } else {
      log.w(
          'BUY tx amount ${caculateTransactionAmount()} -- baseCoinbalance $baseCoinbalance');
      if (caculateTransactionAmount() > baseCoinbalance) {
        sharedService.alertDialog(
            "", AppLocalizations.of(context).invalidAmount,
            isWarning: false);
        setBusy(false);
        return;
      } else {
        print('going to place order');
        await placeBuySellOrder();
      }
    }

    /// load orders here after the end of placing order
    /// MyOrdersView(tickerName: tickerName);
    setBusy(false);
  }

/* ---------------------------------------------------
            Slider Onchange
--------------------------------------------------- */
  sliderOnchange(newValue) {
    setBusy(true);
    sliderValue = newValue;
    var targetCoinbalance =
        targetCoinExchangeBalance.unlockedAmount; // usd bal for buy
    //  targetCoinWalletData.inExchange;
    var baseCoinbalance =
        baseCoinExchangeBalance.unlockedAmount; //coin(asset) bal for sell
    //baseCoinWalletData
    //  .inExchange;
    if (quantity.isNaN) quantity = 0.0;
    if (price != null &&
        quantity != null &&
        !price.isNegative &&
        !quantity.isNegative) {
      if (!bidOrAsk) {
        var changeQuantityWithSlider = targetCoinbalance * sliderValue / 100;
        print('changeQuantityWithSlider $changeQuantityWithSlider');
        quantity = changeQuantityWithSlider;
        transactionAmount = quantity * price;
        quantityTextController.text = quantity.toStringAsFixed(quantityDecimal);
        updateTransFee();
        log.i(transactionAmount);
        log.e(changeQuantityWithSlider);
      } else {
        var changeBalanceWithSlider = baseCoinbalance * sliderValue / 100;
        quantity = changeBalanceWithSlider / price;
        transactionAmount = quantity * price;
        quantityTextController.text = quantity.toStringAsFixed(quantityDecimal);
        updateTransFee();
        log.w('Slider value $sliderValue');
        log.i('calculated tx amount $transactionAmount');
        log.e('Balance change with slider $changeBalanceWithSlider');
      }
    } else {
      log.e(
          'In sliderOnchange else where quantity $quantity or price $price is null/empty');
    }
    setBusy(false);
  }

/* ---------------------------------------------------
            Show Notification
--------------------------------------------------- */
  showNotification(context) {
    sharedService.showInfoFlushbar(
        AppLocalizations.of(context).passwordMismatch,
        AppLocalizations.of(context).pleaseProvideTheCorrectPassword,
        Icons.cancel,
        globals.red,
        context);
  }
}
