import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/api.dart';
import 'package:exchangilymobileapp/utils/btc_util.dart';
import 'package:exchangilymobileapp/utils/fab_util.dart';
import 'package:flushbar/flushbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:bip39/bip39.dart' as bip39;
import '../packages/bip32/bip32_base.dart' as bip32;
import 'package:hex/hex.dart';
import "package:pointycastle/pointycastle.dart";
import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../shared/globals.dart' as globals;
import '../environments/coins.dart' as coinList;
import '../utils/abi_util.dart';
import '../utils/string_util.dart' as stringUtils;
import '../utils/kanban.util.dart';
import '../utils/keypair_util.dart';
import '../utils/eth_util.dart';
import '../utils/fab_util.dart';
import '../utils/coin_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wallet.dart';
import 'dart:io';
import 'dart:convert';
import 'package:bitcoin_flutter/src/models/networks.dart';
import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:bitcoin_flutter/src/transaction_builder.dart';
import 'package:bitcoin_flutter/src/transaction.dart' as btcTransaction;
import 'package:bitcoin_flutter/src/ecpair.dart';
import 'package:bitcoin_flutter/src/utils/script.dart' as script;
import '../environments/environment.dart';
import 'package:bitcoin_flutter/src/bitcoin_flutter_base.dart';
import 'package:web_socket_channel/io.dart';
import 'package:encrypt/encrypt.dart' as prefix0;

class WalletService {
  final log = getLogger('Wallet Service');
  Api _api = locator<Api>();

  List<WalletInfo> _walletInfo = [];

  List<double> totalUsdBalance = [];
  String randomMnemonic = '';
  Uint8List seed;
  var sum;
  double coinUsdBalance;
  var root;
  List<String> coinTickers = ['BTC', 'ETH', 'FAB', 'USDT', 'EXG'];
  List<String> tokenType = ['', '', '', 'ETH', 'FAB'];
  List<double> coinUsdMarketPrice = [];
  List<String> coinNames = [
    'bitcoin',
    'ethereum',
    'fabcoin',
    'tether',
    'exchangily'
  ];

  // Get Random Mnemonic
  Future<String> getRandomMnemonic() {
    randomMnemonic = bip39.generateMnemonic();
    if (isLocal) {
      randomMnemonic =
          'culture sound obey clean pretty medal churn behind chief cactus alley ready';
      // 'dune stem onion cliff equip seek kiwi salute area elegant atom injury';
    }
    //log.w(randomMnemonic);

    return Future.value(randomMnemonic);
  }

  // Save Encrypted Data to Storage
  saveEncryptedData(String data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/my_file.byte');
      final text = data;
      await file.writeAsString(text);
      log.w('Encrypted data saved in storage');
    } catch (e) {
      log.e("Couldn't write encrypted datra to file!! $e");
    }
  }

  // Read Encrypted Data from Storage
  Future<String> readEncryptedData(String userPass) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/my_file.byte');

      String test = await file.readAsString();
      prefix0.Encrypted encryptedText = prefix0.Encrypted.fromBase64(test);
      final key = prefix0.Key.fromLength(32);
      final iv = prefix0.IV.fromUtf8(userPass);
      final encrypter = prefix0.Encrypter(prefix0.AES(key));
      final decrypted = encrypter.decrypt(encryptedText, iv: iv);
      return Future.value(decrypted);
    } catch (e) {
      log.e("Couldn't read file -$e");
      return Future.value('');
    }
  }

  // Generate Seed

  generateSeed(String mnemonic) {
    seed = bip39.mnemonicToSeed(mnemonic);
    log.w(seed);
    return seed;
  }

  Future getCoinAddresses() async {
    root = bip32.BIP32.fromSeed(seed);
    for (int i = 0; i < coinTickers.length; i++) {
      var tickerName = coinTickers[i];
      var addr =
          await getAddressForCoin(root, tickerName, tokenType: tokenType[i]);
      log.w('name $tickerName - address $addr');
      return addr;
    }
  }

// Future Get Coin Balance By Address
  Future coinBalanceByAddress(
      String name, String address, String tokenType) async {
    var bal =
        await getCoinBalanceByAddress(name, address, tokenType: tokenType);
    log.w('$name - Coin Balance $bal');
    if (bal['balance'].isNaN) {
      return 0.0;
    }
    return bal;
  }

  // Get Current Market Price For The Coin By Name

  Future<double> getCoinMarketPrice(String name) async {
    double currentUsdValue;
    var usdVal = await _api.getCoinsUsdValue();
    if (name == 'exchangily') {
      return currentUsdValue = 0.2;
    }
    currentUsdValue = usdVal[name]['usd'];
    log.w('USD VAL of $name - $currentUsdValue');
    return currentUsdValue;
  }

// Future GetAllCoins
  Future<List<WalletInfo>> getAllCoins() async {
    if (_walletInfo != null) {
      _walletInfo.clear();
    } else {
      _walletInfo = [];
    }
    coinUsdMarketPrice.clear();
    // totalUsdBalance.clear();
    log.w('Seed in wallet service getallbalanced method $seed');
    root = bip32.BIP32.fromSeed(seed);
    String wallets;
    try {
      //   log.w('List of coins length ${coinTickers.length}');
      for (int i = 0; i < coinTickers.length; i++) {
        String tickerName = coinTickers[i];
        String name = coinNames[i];
        String token = tokenType[i];
        var marketValue = await getCoinMarketPrice(name);
        //    print('Market Value of coin $marketValue');
        coinUsdMarketPrice.add(marketValue);
        //   log.w('coinUsdMarketPriceList $coinUsdMarketPrice');
        String addr =
            await getAddressForCoin(root, tickerName, tokenType: token);
        //  log.w('Address $addr');
        var bal =
            await getCoinBalanceByAddress(tickerName, addr, tokenType: token);
        //   log.w('BAL $bal');
        double walletBal = bal['balance'];
        double walletLockedBal = bal['lockedBalance'];
        //  log.w('tickername $tickerName - address: $addr - balance: $walletBal');
        // totalUsdBalance.clear();
        calculateCoinUsdBalance(coinUsdMarketPrice[i], walletBal);
        //  log.i('printing calculated bal $coinUsdBalance');
        double assetsInExg = 0.0;
        WalletInfo wi = new WalletInfo(
            tickerName: tickerName,
            tokenType: token,
            address: addr,
            availableBalance: walletBal,
            usdValue: coinUsdBalance,
            name: name,
            assetsInExchange: assetsInExg);

        // String wallet = jsonEncode(wi);
        // log.e('with $wallet');
        // Map<String, dynamic> decodedWallet = jsonDecode(wallet);
        // log.w('Decoded Walelt $decodedWallet');
        _walletInfo.add(wi);
        wallets = jsonEncode(_walletInfo);
        //  log.w('Wallets $wallets');
      }
      final storage = new FlutterSecureStorage();
      await storage.delete(key: 'wallets');
      await storage.write(key: 'wallets', value: wallets);
      // var test = await storage.read(key: 'wallets');
      // log.e(test);
      // log.e('Wallet info ${_walletInfo.length}');
      return _walletInfo;
    } catch (e) {
      log.e(e);
      _walletInfo = null;
      log.i('Catch GetAllbalances Failed');
      return _walletInfo;
    }
  }

  // Gas Balance
  gasBalance(String addr) async {
    double gasAmount;
    await _api.getGasBalance(addr).then((res) {
      var newBal = int.parse(res['balance']['FAB']);
      gasAmount = newBal / 1e18;
    }).catchError((onError) {
      log.w('On error $onError');
      gasAmount = 0.0;
    });
    return gasAmount; // return here implies that it will return gas amount whatever value it gets assigned above
  }

  // Assets Balance
  assetsBalance(String exgAddress) async {
    List<Map<String, dynamic>> bal = [];
    await _api.getAssetsBalance(exgAddress).then((res) {
      for (var i = 0; i < res.length; i++) {
        var tempBal = res[i];
        var coinType = int.parse(tempBal['coinType']);
        var unlockedAmount = double.parse(tempBal['unlockedAmount']) / 1e18;
        var lockedAmount = double.parse(tempBal['lockedAmount']) / 1e18;
        var finalBal = {
          'coin': coinList.coin_list[coinType]['name'],
          'amount': unlockedAmount,
          'lockedAmount': lockedAmount
        };
        bal.add(finalBal);
      }
    }).catchError((onError) {
      log.w('On error assetsBalance $onError');
      bal = [];
    });
    return bal;
  }

  /* ---------------------------------------------------
                Flushbar Notification bar
    -------------------------------------------------- */

  void showInfoFlushbar(String title, String message, IconData iconData,
      Color leftBarColor, BuildContext context) {
    Flushbar(
      backgroundColor: globals.secondaryColor.withOpacity(0.75),
      title: title,
      message: message,
      icon: Icon(
        iconData,
        size: 24,
        color: globals.primaryColor,
      ),
      leftBarIndicatorColor: leftBarColor,
      duration: Duration(seconds: 3),
    ).show(context);
  }

  // Calculate Only Usd Balance For Individual Coin
  double calculateCoinUsdBalance(
      double marketPrice, double actualWalletBalance) {
    log.w('usdVal =$marketPrice, actualwallet bal $actualWalletBalance');
    if (actualWalletBalance != 0 && marketPrice != null) {
      coinUsdBalance = (marketPrice * actualWalletBalance);

      // totalUsdBalance.add(coinUsdBalance);
      // log.w('Total coin usd balance list $totalUsdBalance');
      return coinUsdBalance;
    } else {
      coinUsdBalance = 0.0;
      log.i('calculateCoinUsdBalance - Wallet balance 0');
    }
    return coinUsdBalance;
  }

  // Calculate Total Usd Balance

  // calculateTotalUsdBalance() {
  //   sum = 0;
  //   if (totalUsdBalance.isNotEmpty) {
  //     log.w('Total usd balance list count ${totalUsdBalance.length}');
  //     for (var i = 0; i < totalUsdBalance.length; i++) {
  //       sum = sum + totalUsdBalance[i];
  //     }
  //     log.w('Sum $sum');
  //     return sum;
  //   }
  //   log.w('totalUsdBalance List empty');
  //   return 0.0;
  // }

// Add Gas
  Future<int> addGas() async {
    return 0;
  }

// Get Coin Type Id By Name

  getCoinTypeIdByName(String coinName) {
    var coins =
        coinList.coin_list.where((coin) => coin['name'] == coinName).toList();
    if (coins != null) {
      return coins[0]['id'];
    }
    return 0;
  }

// Get Original Message

  getOriginalMessage(
      int coinType, String txHash, BigInt amount, String address) {
    var buf = '';
    buf += stringUtils.fixLength(coinType.toString(), 4);
    buf += stringUtils.fixLength(txHash, 64);
    var hexString = amount.toRadixString(16);
    buf += stringUtils.fixLength(hexString, 64);
    buf += stringUtils.fixLength(address, 64);

    return buf;
  }

// Future Deposit Do

  Future<Map<String, dynamic>> depositDo(
      seed, String coinName, String tokenType, double amount) async {
    var errRes = new Map();
    errRes['success'] = false;

    var officalAddress = getOfficalAddress(coinName);
    if (officalAddress == null) {
      errRes['data'] = 'no official address';
      return errRes;
    }
    var option = {};
    if ((coinName != null) && (coinName != '')) {
      option = {
        'tokenType': tokenType,
        'contractAddress': environment["addresses"]["smartContract"][coinName]
      };
    }

    var resST = await sendTransaction(
        coinName, seed, [0], officalAddress, amount, option, false);

    if (resST['errMsg'] != '') {
      print(resST['errMsg']);
      errRes['data'] = resST['errMsg'];
      return errRes;
    }

    if (resST['txHex'] == '' || resST['txHash'] == '') {
      print(resST['txHex']);
      print(resST['txHash']);
      errRes['data'] = 'no txHex or txHash';
      return errRes;
    }

    var txHex = resST['txHex'];
    var txHash = resST['txHash'];

    var amountInLink = BigInt.from(amount * 1e18);
    print('amountInLink=');
    print(amountInLink);

    var coinType = getCoinTypeIdByName(coinName);

    if (coinType == 0) {
      errRes['data'] = 'invalid coinType for ' + coinName;
      return errRes;
    }

    var keyPairKanban = getExgKeyPair(seed);
    var addressInKanban = keyPairKanban["address"];
    var originalMessage = getOriginalMessage(
        coinType,
        stringUtils.trimHexPrefix(txHash),
        amountInLink,
        stringUtils.trimHexPrefix(addressInKanban));

    var signedMess =
        await signedMessage(originalMessage, seed, coinName, tokenType);

    var coinPoolAddress = await getCoinPoolAddress();

    var abiHex = getDepositFuncABI(
        coinType, txHash, amountInLink, addressInKanban, signedMess);

    var nonce = await getNonce(addressInKanban);

    var txKanbanHex = await signAbiHexWithPrivateKey(abiHex,
        HEX.encode(keyPairKanban["privateKey"]), coinPoolAddress, nonce);

    var res = await submitDeposit(txHex, txKanbanHex);
    print('res from depositDo');
    print(res);
    return res;
  }

  /* --------------------------------------------
              Methods Called in Send State 
  ----------------------------------------------*/

// Get Fab Transaction Status
  Future getFabTxStatus(String txId) async {
    await getFabTransactionStatus(txId);
  }

// Get Fab Transaction Balance
  Future getFabBalance(String address) async {
    await getFabBalanceByAddress(address);
  }

  // Get ETH Transaction Status
  Future getEthTxStatus(String txId) async {
    await getFabTransactionStatus(txId);
  }

// Get ETH Transaction Balance
  Future getEthBalance(String address) async {
    await getFabBalanceByAddress(address);
  }

// Future Add Gas Do
  Future<Map<String, dynamic>> AddGasDo(seed, double amount) async {
    var satoshisPerBytes = 14;
    var scarContractAddress = await getScarAddress();
    scarContractAddress = stringUtils.trimHexPrefix(scarContractAddress);
    print('scarContractAddress=');
    print(scarContractAddress);
    var fxnDepositCallHex = '4a58db19';
    var contractInfo =
        await getFabSmartContract(scarContractAddress, fxnDepositCallHex);

    var res1 = await getFabTransactionHex(seed, [0], contractInfo['contract'],
        amount, contractInfo['totalFee'], satoshisPerBytes);
    var txHex = res1['txHex'];
    var errMsg = res1['errMsg'];
    print('errMsg=');
    print(errMsg);
    var txHash = '';
    if (txHex != null && txHex != '') {
      var res = await _api.postFabTx(txHex);
      txHash = res['txHash'];
      errMsg = res['errMsg'];
    }

    return {'txHex': txHex, 'txHash': txHash, 'errMsg': errMsg};
  }

  convertLiuToFabcoin(amount) {
    return (amount * 1e-8);
  }

  isFabTransactionLocked(String txid, int idx) async {
    if (idx != 0) {
      return false;
    }
    var response = await _api.getFabTransactionJson(txid);

    if ((response['vin'] != null) && (response['vin'].length > 0)) {
      var vin = response['vin'][0];
      if (vin['coinbase'] != null) {
        if (response['onfirmations'] <= 800) {
          return true;
        }
      }
    }
    return false;
  }

  getFabTransactionHex(seed, addressIndexList, toAddress, double amount,
      double extraTransactionFee, int satoshisPerBytes) async {
    final txb = new TransactionBuilder(
        network: environment["chains"]["BTC"]["network"]);
    final root = bip32.BIP32.fromSeed(seed);
    var totalInput = 0;
    var changeAddress = '';
    var finished = false;
    var receivePrivateKeyArr = [];

    var totalAmount = amount + extraTransactionFee;
    var amountNum = totalAmount * 1e8;

    var bytesPerInput = 148;
    var feePerInput = bytesPerInput * satoshisPerBytes;

    for (var i = 0; i < addressIndexList.length; i++) {
      var index = addressIndexList[i];
      var fabCoinChild = root.derivePath("m/44'/" +
          environment["CoinType"]["FAB"].toString() +
          "'/0'/0/" +
          index.toString());
      final fromAddress = getBtcAddressForNode(fabCoinChild);
      print('from address=' + fromAddress);
      if (i == 0) {
        changeAddress = fromAddress;
      }
      final privateKey = fabCoinChild.privateKey;
      var utxos = await _api.getFabUtxos(fromAddress);
      if ((utxos != null) && (utxos.length > 0)) {
        for (var j = 0; j < utxos.length; i++) {
          var utxo = utxos[i];
          var idx = utxo['idx'];
          var txid = utxo['txid'];
          var value = utxo['value'];
          /*
          var isLocked = await isFabTransactionLocked(txid, idx);
          if (isLocked) {
            continue;
          }
           */
          txb.addInput(txid, idx);
          receivePrivateKeyArr.add(privateKey);
          totalInput += value;

          amountNum -= value;
          amountNum += feePerInput;
          if (amountNum <= 0) {
            finished = true;
            break;
          }
        }
      }

      if (!finished) {
        print('not enough fab coin to make the transaction.');
        return {
          'txHex': '',
          'errMsg': 'not enough fab coin to make the transaction.'
        };
      }

      var transFee = (receivePrivateKeyArr.length) * feePerInput + 2 * 34 + 10;

      var output1 =
          (totalInput - amount * 1e8 - extraTransactionFee * 1e8 - transFee)
              .round();
      var output2 = (amount * 1e8).round();

      if (output1 < 0 || output2 < 0) {
        print('output1 or output2 should be greater than 0.');
        return {
          'txHex': '',
          'errMsg': 'output1 or output2 should be greater than 0.'
        };
      }

      txb.addOutput(changeAddress, output1);
      txb.addOutput(toAddress, output2);

      print('receivePrivateKeyArr.length=' +
          receivePrivateKeyArr.length.toString());
      for (var i = 0; i < receivePrivateKeyArr.length; i++) {
        print('i=' + i.toString());
        var privateKey = receivePrivateKeyArr[i];
        print('there we go');
        var alice = ECPair.fromPrivateKey(privateKey,
            compressed: true, network: environment["chains"]["BTC"]["network"]);
        print('alice.network=');
        print(alice.network);
        txb.sign(i, alice);
        print('enf for i');
      }

      print('begin build()');
      var txHex = txb.build().toHex();

      print('txHex=' + txHex);
      return {'txHex': txHex, 'errMsg': ''};
    }
  }

  // Send Transaction

  Future sendTransaction(String coin, seed, List addressIndexList,
      String toAddress, double amount, options, bool doSubmit) async {
    print('seed from sendTransaction=');
    print(seed);
    final root = bip32.BIP32.fromSeed(seed);
    log.w('coin=' + coin);
    log.w(addressIndexList);
    log.w(toAddress);
    log.w(amount);
    var totalInput = 0;
    var finished = false;
    var gasPrice = 10.2;
    var gasLimit = 21000;
    var satoshisPerBytes = 14;
    var txHex = '';
    var txHash = '';
    var errMsg = '';
    var amountSent = 0;
    var receivePrivateKeyArr = [];

    var tokenType = options['tokenType'] ?? '';
    var contractAddress = options['contractAddress'] ?? '';
    var changeAddress = '';
    if (coin == 'BTC') {
      var bytesPerInput = 148;
      var amountNum = amount * 1e8;
      amountNum += (2 * 34 + 10);
      final txb = new TransactionBuilder(
          network: environment["chains"]["BTC"]["network"]);
      // txb.setVersion(1);

      log.w('addressIndexList=');
      log.w(addressIndexList);
      log.w(addressIndexList.length);
      for (var i = 0; i < addressIndexList.length; i++) {
        var index = addressIndexList[i];
        var bitCoinChild = root.derivePath("m/44'/" +
            environment["CoinType"]["BTC"].toString() +
            "'/0'/0/" +
            index.toString());
        final fromAddress = getBtcAddressForNode(bitCoinChild);
        if (i == 0) {
          changeAddress = fromAddress;
        }
        final privateKey = bitCoinChild.privateKey;
        var utxos = await _api.getBtcUtxos(fromAddress);
        print('utxos=');
        print(utxos);
        if ((utxos == null) || (utxos.length == 0)) {
          continue;
        }
        for (var j = 0; j < utxos.length; j++) {
          var tx = utxos[j];
          if (tx['idx'] < 0) {
            continue;
          }
          txb.addInput(tx['txid'], tx['idx']);
          print('amountNum=' + amountNum.toString());
          print('txvalue=' + tx['value']);
          amountNum -= tx['value'];
          print('amountNum1=' + amountNum.toString());
          amountNum += bytesPerInput * satoshisPerBytes;
          print('amountNum2=' + amountNum.toString());
          totalInput += tx['value'];
          receivePrivateKeyArr.add(privateKey);
          if (amountNum <= 0) {
            finished = true;
            break;
          }
        }
      }

      print('finished=' + finished.toString());
      if (!finished) {
        txHex = '';
        txHash = '';
        errMsg = 'not enough fund.';
        return {'txHex': txHex, 'txHash': txHash, 'errMsg': errMsg};
      }

      var transFee =
          (receivePrivateKeyArr.length) * bytesPerInput * satoshisPerBytes +
              2 * 34 +
              10;
      var output1 = (totalInput - amount * 1e8 - transFee).round();
      var output2 = (amount * 1e8).round();
      print('111, output there we go:');
      print(totalInput);
      print(output1);
      print(output2);
      print(receivePrivateKeyArr.length);
      txb.addOutput(changeAddress, output1);
      print('222');
      txb.addOutput(toAddress, output2);
      print('333');
      for (var i = 0; i < receivePrivateKeyArr.length; i++) {

        var privateKey = receivePrivateKeyArr[i];
        var alice = ECPair.fromPrivateKey(privateKey,
            compressed: true, network: environment["chains"]["BTC"]["network"]);
        txb.sign(i, alice);
      }

      var tx = txb.build();
      txHex = tx.toHex();
      if (doSubmit) {
        var res = await _api.postBtcTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
        return {'txHash': txHash, 'errMsg': errMsg};
      } else {
        txHash = '0x' + tx.getId();
      }
    }

    // ETH Transaction

    else if (coin == 'ETH') {
      // Credentials fromHex = EthPrivateKey.fromHex("c87509a[...]dc0d3");
      final ropstenChainId = 3;
      final ethCoinChild = root.derivePath(
          "m/44'/" + environment["CoinType"]["ETH"].toString() + "'/0'/0/0");
      final privateKey = HEX.encode(ethCoinChild.privateKey);
      var amountNum = (amount * 1e18).round();
      Credentials credentials = EthPrivateKey.fromHex(privateKey);

      final address = await credentials.extractAddress();
      final addressHex = address.hex;
      final nonce = await _api.getEthNonce(addressHex);

      var apiUrl =
          "https://ropsten.infura.io/v3/6c5bdfe73ef54bbab0accf87a6b4b0ef"; //Replace with your API

      var httpClient = new http.Client();
      var ethClient = new Web3Client(apiUrl, httpClient);

      log.i('amountNum=');
      log.w(amount);
      log.w(amountNum);
      final signed = await ethClient.signTransaction(
          credentials,
          Transaction(
            nonce: nonce,
            to: EthereumAddress.fromHex(toAddress),
            gasPrice:
                EtherAmount.fromUnitAndValue(EtherUnit.gwei, gasPrice.round()),
            maxGas: gasLimit,
            value: EtherAmount.fromUnitAndValue(EtherUnit.wei, amountNum),
          ),
          chainId: ropstenChainId,
          fetchChainIdFromNetworkId: false);
      log.i('signed=');
      log.w(signed);
      txHex = '0x' + HEX.encode(signed);
      log.w('TxHex $txHex');
      if (doSubmit) {
        var res = await _api.postEthTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
      } else {
        txHash = getTransactionHash(signed);
      }
    } else if (coin == 'FAB') {
      var res1 = await getFabTransactionHex(
          seed, addressIndexList, toAddress, amount, 0, satoshisPerBytes);
      txHex = res1['txHex'];
      errMsg = res1['errMsg'];
      if ((errMsg == '') && (txHex != '')) {
        if (doSubmit) {
          var res = await _api.postFabTx(txHex);
          print('res therrrr');
          print(res);
          txHash = res['txHash'];
          errMsg = res['errMsg'];
        } else {
          var tx = btcTransaction.Transaction.fromHex(txHex);
          txHash = '0x' + tx.getId();
        }
      }
    } else if (tokenType == 'FAB') {
      var transferAbi = 'a9059cbb';
      amountSent = (amount * 1e18).round();
      var fxnCallHex = transferAbi +
          stringUtils.fixLength(stringUtils.trimHexPrefix(toAddress), 64) +
          stringUtils.fixLength(
              stringUtils.trimHexPrefix(amountSent.toRadixString(16)), 64);
      contractAddress = stringUtils.trimHexPrefix(contractAddress);

      var contractInfo = await getFabSmartContract(contractAddress, fxnCallHex);

      var res1 = await getFabTransactionHex(
          seed,
          addressIndexList,
          contractInfo['contract'],
          0,
          contractInfo['totalFee'],
          satoshisPerBytes);
      txHex = res1['txHex'];
      errMsg = res1['errMsg'];
      if (txHex != null && txHex != '') {
        if (doSubmit) {
          var res = await _api.postFabTx(txHex);
          txHash = res['txHash'];
          errMsg = res['errMsg'];
        } else {
          var tx = btcTransaction.Transaction.fromHex(txHex);
          txHash = '0x' + tx.getId();
        }
      }
    } else if (tokenType == 'ETH') {
      final ropstenChainId = 3;
      final ethCoinChild = root.derivePath(
          "m/44'/" + environment["CoinType"]["ETH"].toString() + "'/0'/0/0");
      final privateKey = HEX.encode(ethCoinChild.privateKey);
      Credentials credentials = EthPrivateKey.fromHex(privateKey);

      final address = await credentials.extractAddress();
      final addressHex = address.hex;
      final nonce = await _api.getEthNonce(addressHex);
      gasLimit = 100000;
      var amountSent = (amount * 1e6).round();
      var transferAbi = 'a9059cbb';
      var fxnCallHex = transferAbi +
          stringUtils.fixLength(stringUtils.trimHexPrefix(toAddress), 64) +
          stringUtils.fixLength(
              stringUtils.trimHexPrefix(amountSent.toRadixString(16)), 64);
      var apiUrl =
          "https://ropsten.infura.io/v3/6c5bdfe73ef54bbab0accf87a6b4b0ef"; //Replace with your API

      var httpClient = new http.Client();
      var ethClient = new Web3Client(apiUrl, httpClient);

      final signed = await ethClient.signTransaction(
          credentials,
          Transaction(
              nonce: nonce,
              to: EthereumAddress.fromHex(contractAddress),
              gasPrice: EtherAmount.fromUnitAndValue(
                  EtherUnit.gwei, gasPrice.round()),
              maxGas: gasLimit,
              value: EtherAmount.fromUnitAndValue(EtherUnit.wei, 0),
              data: Uint8List.fromList(stringUtils.hex2Buffer(fxnCallHex))),
          chainId: ropstenChainId,
          fetchChainIdFromNetworkId: false);
      log.w('signed=');
      txHex = '0x' + HEX.encode(signed);

      if (doSubmit) {
        var res = await _api.postEthTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
        await Future.delayed(Duration(seconds: 7));
        log.w('In if delay complete');
      } else {
        txHash = getTransactionHash(signed);
        await Future.delayed(Duration(seconds: 7));
        log.w('In else delay complete');
      }
    }
    await Future.delayed(Duration(seconds: 7));
    log.w('delay complete');
    return {
      'txHex': txHex,
      'txHash': txHash,
      'errMsg': errMsg,
      'amountSent': amountSent
    };
  }

  getFabSmartContract(String contractAddress, String fxnCallHex) async {
    contractAddress = stringUtils.trimHexPrefix(contractAddress);
    fxnCallHex = stringUtils.trimHexPrefix(fxnCallHex);
    var gasLimit = 800000;
    var gasPrice = 40;
    var totalAmount = gasLimit * gasPrice / 1e8;
    // let cFee = 3000 / 1e8 // fee for the transaction

    var totalFee = totalAmount;
    var chunks = new List<dynamic>();
    chunks.add(84);
    chunks.add(Uint8List.fromList(stringUtils.number2Buffer(gasLimit)));
    chunks.add(Uint8List.fromList(stringUtils.number2Buffer(gasPrice)));
    chunks.add(Uint8List.fromList(stringUtils.hex2Buffer(fxnCallHex)));
    chunks.add(Uint8List.fromList(stringUtils.hex2Buffer(contractAddress)));
    chunks.add(194);

    print('chunks=');
    print(chunks);
    var contract = script.compile(chunks);
    print('contract=');
    print(contract);
    var contractSize = contract.toString().length;

    totalFee += convertLiuToFabcoin(contractSize * 10);

    var res = {'contract': contract, 'totalFee': totalFee};
    return res;
  }
}
