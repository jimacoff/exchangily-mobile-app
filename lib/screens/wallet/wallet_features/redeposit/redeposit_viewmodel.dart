import 'dart:typed_data';

import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/environments/coins.dart';
import 'package:exchangilymobileapp/environments/environment.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/models/wallet/transaction_history.dart';
import 'package:exchangilymobileapp/models/wallet/wallet.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/db/transaction_history_database_service.dart';
import 'package:exchangilymobileapp/services/dialog_service.dart';
import 'package:exchangilymobileapp/services/shared_service.dart';
import 'package:exchangilymobileapp/services/wallet_service.dart';
import 'package:exchangilymobileapp/utils/abi_util.dart';
import 'package:exchangilymobileapp/utils/coin_util.dart';
import 'package:exchangilymobileapp/utils/kanban.util.dart';
import 'package:exchangilymobileapp/utils/keypair_util.dart';
import 'package:exchangilymobileapp/utils/string_util.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:hex/hex.dart';

class RedepositViewModel extends FutureViewModel {
  DialogService dialogService = locator<DialogService>();
  WalletService walletService = locator<WalletService>();
  SharedService sharedService = locator<SharedService>();

  final kanbanGasPriceTextController = TextEditingController();
  final kanbanGasLimitTextController = TextEditingController();
  double kanbanTransFee = 0.0;
  bool transFeeAdvance = false;
  // String coinName = '';
  // String tokenType = '';
  String errDepositTransactionID;
  List errDepositList = new List();
  TransactionHistoryDatabaseService transactionHistoryDatabaseService =
      locator<TransactionHistoryDatabaseService>();

  WalletInfo walletInfo;
  BuildContext context;

  @override
  Future futureToRun() => getErrDeposit();

  void init() {}

/*----------------------------------------------------------------------
                      Get Error Deposit
----------------------------------------------------------------------*/

  Future getErrDeposit() async {
    setBusy(true);
    var address = await this.sharedService.getExgAddressFromWalletDatabase();
    await walletService.getErrDeposit(address).then((errDepositData) {
      for (var i = 0; i < errDepositData.length; i++) {
        var item = errDepositData[i];
        log.w('errDepositData single occurance $item');
        var coinType = item['coinType'];
        if (newCoinTypeMap[coinType.toString()] == walletInfo.tickerName) {
          errDepositList.add(item);
          break;
        }
      }
    });

    var gasPrice = environment["chains"]["KANBAN"]["gasPrice"];
    var gasLimit = environment["chains"]["KANBAN"]["gasLimit"];
    kanbanGasPriceTextController.text = gasPrice.toString();
    kanbanGasLimitTextController.text = gasLimit.toString();

    var kanbanTransFee = bigNum2Double(gasPrice * gasLimit);

    log.w('errDepositList=== $errDepositList');
    if (errDepositList != null && errDepositList.length > 0) {
      this.errDepositList = errDepositList;
      this.errDepositTransactionID = errDepositList[0]["transactionID"];
      this.kanbanTransFee = kanbanTransFee;
    }

    setBusy(false);
    return errDepositList;
  }

/*----------------------------------------------------------------------
                    Check pass
----------------------------------------------------------------------*/

  checkPass() async {
    TransactionHistory transactionByTxId = new TransactionHistory();
    var res = await dialogService.showDialog(
        title: AppLocalizations.of(context).enterPassword,
        description:
            AppLocalizations.of(context).dialogManagerTypeSamePasswordNote,
        buttonTitle: AppLocalizations.of(context).confirm);
    if (res.confirmed) {
      String mnemonic = res.returnedText;
      Uint8List seed = walletService.generateSeed(mnemonic);
      var keyPairKanban = getExgKeyPair(seed);
      var exgAddress = keyPairKanban['address'];
      var nonce = await getNonce(exgAddress);

      var errDepositItem;
      for (var i = 0; i < errDepositList.length; i++) {
        if (errDepositList[i]["transactionID"] == errDepositTransactionID) {
          errDepositItem = errDepositList[i];
          break;
        }
      }

      if (errDepositItem == null) {
        sharedService.showInfoFlushbar(
            '${AppLocalizations.of(context).redepositError}',
            '${AppLocalizations.of(context).redepositItemNotSelected}',
            Icons.cancel,
            red,
            context);
      }

      print('errDepositItem $errDepositItem');
      num errDepositAmount = num.parse(errDepositItem['amount']);
      print('errDepositAmount $errDepositAmount');
      var amountInLink = BigInt.from(errDepositAmount);
      print('amountInLink $amountInLink');
      var coinType = errDepositItem['coinType'];

      var transactionID = errDepositItem['transactionID'];

      var addressInKanban = keyPairKanban["address"];
      var originalMessage = walletService.getOriginalMessage(
          coinType,
          trimHexPrefix(transactionID),
          amountInLink,
          trimHexPrefix(addressInKanban));

      var signedMess = await signedMessage(
          originalMessage, seed, walletInfo.tickerName, walletInfo.tokenType);

      var resRedeposit = await this.submitredeposit(amountInLink, keyPairKanban,
          nonce, coinType, transactionID, signedMess);

      if ((resRedeposit != null) && (resRedeposit['success'])) {
        var newTransactionId = resRedeposit['data']['transactionID'];
        print(
            'NEW REDEPOSIT TXID $newTransactionId --Old txid $transactionID ');
        sharedService.alertDialog(
            AppLocalizations.of(context).redepositCompleted,
            AppLocalizations.of(context).transactionId + newTransactionId,
            path: '/dashboard');

        // get transaction from database
        transactionByTxId =
            await transactionHistoryDatabaseService.getByTxId(transactionID);

        // update transaction history status with new txid
        String date = DateTime.now().toString();
        TransactionHistory transactionHistory = new TransactionHistory(
            id: transactionByTxId.id,
            tickerName: walletInfo.tickerName,
            address: '',
            amount: 0.0,
            date: date.toString(),
            txId: newTransactionId,
            status: 'pending',
            quantity: transactionByTxId.quantity,
            tag: transactionByTxId.tag);

        await transactionHistoryDatabaseService.update(transactionHistory);
        await transactionHistoryDatabaseService.getByTxId(newTransactionId);
        walletService.checkDepositTransactionStatus(transactionHistory);

        // sharedService.showInfoFlushbar(
        //     '${AppLocalizations.of(context).redepositCompleted}',
        //     '${AppLocalizations.of(context).transactionId}' +
        //         resRedeposit['data']['transactionID'],
        //     Icons.cancel,
        //     globals.white,
        //     context);
      } else {
        sharedService.showInfoFlushbar(
            AppLocalizations.of(context).redepositFailedError,
            AppLocalizations.of(context).serverError,
            Icons.cancel,
            red,
            context);
      }
    } else {
      if (res.returnedText != 'Closed') {
        showNotification(context);
      }
    }
  }

  submitredeposit(amountInLink, keyPairKanban, nonce, coinType, transactionID,
      signedMess) async {
    log.w('transactionID for submitredeposit:' + transactionID);
    var coinPoolAddress = await getCoinPoolAddress();
    //var signedMess = {'r': r, 's': s, 'v': v};

    var abiHex = getDepositFuncABI(coinType, transactionID, amountInLink,
        keyPairKanban['address'], signedMess);

    var kanbanPrice = int.tryParse(kanbanGasPriceTextController.text);
    var kanbanGasLimit = int.tryParse(kanbanGasLimitTextController.text);

    var txKanbanHex = await signAbiHexWithPrivateKey(
        abiHex,
        HEX.encode(keyPairKanban["privateKey"]),
        coinPoolAddress,
        nonce,
        kanbanPrice,
        kanbanGasLimit);

    var res = await submitReDeposit(txKanbanHex);
    return res;
  }

  showNotification(context) {
    sharedService.showInfoFlushbar(
        AppLocalizations.of(context).passwordMismatch,
        AppLocalizations.of(context).pleaseProvideTheCorrectPassword,
        Icons.cancel,
        red,
        context);
  }

  updateTransFee() async {
    var kanbanPrice = int.tryParse(kanbanGasPriceTextController.text);
    var kanbanGasLimit = int.tryParse(kanbanGasLimitTextController.text);
    var kanbanTransFeeDouble = bigNum2Double(kanbanPrice * kanbanGasLimit);

    kanbanTransFee = kanbanTransFeeDouble;
  }
}