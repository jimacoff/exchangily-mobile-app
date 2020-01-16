import 'dart:convert';

import 'package:exchangilymobileapp/enums/screen_state.dart';
import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/models/wallet.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/wallet_service.dart';
import 'package:exchangilymobileapp/screen_state/base_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreenState extends BaseState {
  final log = getLogger('DahsboardScreenState');
  List<WalletInfo> walletInfo;
  WalletService walletService = locator<WalletService>();
  final double elevation = 5;
  double totalUsdBalance = 0;
  double coinUsdBalance;
  double gasAmount = 0;
  String exgAddress = '';
  List<double> assetsInExchange = [];
  final storage = new FlutterSecureStorage();
  String wallets;

  calcTotalBal(numberOfCoins) {
    totalUsdBalance = 0;
    for (var i = 0; i < numberOfCoins; i++) {
      log.e(walletInfo[i].usdValue);
      totalUsdBalance = totalUsdBalance + walletInfo[i].usdValue;
      log.i('Total ${totalUsdBalance.toStringAsFixed(2)}');
    }
    setState(ViewState.Idle);
    return totalUsdBalance.toStringAsFixed(2);
  }

  getGas() async {
    setState(ViewState.Busy);
    for (var i = 0; i < walletInfo.length; i++) {
      String tName = walletInfo[i].tickerName;
      if (tName == 'EXG') {
        exgAddress = walletInfo[i].address;
        gasAmount = await walletService.gasBalance(exgAddress);
        log.w(gasAmount);
        setState(ViewState.Idle);
        return gasAmount;
      }
    }
    setState(ViewState.Idle);
  }

  // Retrive Wallets Object From Storage

  retrieveWallets() async {
    setState(ViewState.Busy);

    await storage.read(key: 'wallets').then((encodedJsonWallets) async {
      final decodedWallets = jsonDecode(encodedJsonWallets);
      log.w(decodedWallets);
      WalletInfoList walletInfoList = WalletInfoList.fromJson(decodedWallets);
      log.e(walletInfoList.wallets[0].usdValue);

      walletInfo = walletInfoList.wallets;
      log.i(walletInfo.length);
      calcTotalBal(walletInfo.length);
      // await refreshBalance();
      setState(ViewState.Idle);
    }).catchError((error) {
      log.e('Catch Error $error');
      setState(ViewState.Idle);
    });
  }

  /* Get Exchange Assets */

  getExchangeAssets() async {
    setState(ViewState.Busy);
    assetsInExchange.clear();
    var res = await walletService.assetsBalance(exgAddress);
    for (var i = 0; i < res.length; i++) {
      String coin = res[i]['coin'];

      for (var j = 0; j < walletInfo.length; j++) {
        if (coin == walletInfo[j].tickerName)
          walletInfo[j].assetsInExchange = res[i]['amount'];
      }
    }
    setState(ViewState.Idle);
  }

  Future refreshBalance() async {
    setState(ViewState.Busy);
    //walletService.totalUsdBalance.clear();
    int length = walletInfo.length;
    log.e('Length $length');
    List<String> token = ['', '', '', 'ETH', 'FAB'];
    if (walletInfo.isNotEmpty) {
      double walletBal = 0;
      // double walletLockedBal = 0;
      for (var i = 0; i < length; i++) {
        String tickerName = walletInfo[i].tickerName;
        String address = walletInfo[i].address;
        String name = walletInfo[i].name;
        await walletService
            .coinBalanceByAddress(tickerName, address, token[i])
            .then((balance) async {
          walletBal = balance['balance'];
          //  walletLockedBal = balance['lockbalance'];
          double marketPrice = await walletService.getCoinMarketPrice(name);
          await walletService.calculateCoinUsdBalance(marketPrice, walletBal);
          double assetsInExg = 0.0;
          // PENDING: Something went wrong  - type 'int' is not a subtype of type 'double'
          // and sometimes it shows the locked bal but sometimes it doesn't
          //log.e('$tickerName - $walletLockedBal');
          //  walletInfo[i].lockedBalance = walletLockedBal;
          WalletInfo wi = WalletInfo(
              tickerName: tickerName,
              tokenType: token[i],
              address: address,
              availableBalance: walletBal,
              usdValue: coinUsdBalance,
              name: name,
              assetsInExchange: assetsInExg);
          walletInfo.add(wi);
          wallets = jsonEncode(walletInfo);
        }).catchError((error) {
          log.e('Something went wrong  - $error');
        });
      }
      calcTotalBal(length);
      //  await storage.delete(key: 'wallets');
      //   await storage.write(key: 'wallets', value: wallets);
      setState(ViewState.Idle);
      return walletInfo;
    } else {
      setState(ViewState.Idle);
      log.e('In else wallet list - 0');
    }
  }
}
