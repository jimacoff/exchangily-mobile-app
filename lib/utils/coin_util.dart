import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/routes.dart';
import 'package:exchangilymobileapp/utils/fab_util.dart';

import '../packages/bip32/bip32_base.dart' as bip32;

import '../packages/bip32/utils/ecurve.dart' as ecc;
import 'package:bitcoin_flutter/src/models/networks.dart';
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bitcoin_flutter/src/bitcoin_flutter_base.dart';
import '../utils/string_util.dart';
import '../environments/environment.dart';
import './btc_util.dart';
import './eth_util.dart';
import "package:pointycastle/pointycastle.dart";
import 'dart:typed_data';
import 'dart:convert';
import 'package:bitcoin_flutter/src/bitcoin_flutter_base.dart';
import 'package:web3dart/crypto.dart';
import "package:pointycastle/api.dart";
import "package:pointycastle/impl.dart";
import "package:pointycastle/ecc/curves/secp256k1.dart";
import "package:pointycastle/digests/sha256.dart";
import "package:pointycastle/signers/ecdsa_signer.dart";
import 'package:pointycastle/macs/hmac.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'varuint.dart';

final ECDomainParameters _params = ECCurve_secp256k1();
final BigInt _halfCurveOrder = _params.n >> 1;
final log = getLogger('coin_util');

Uint8List hash256(Uint8List buffer) {
  Uint8List _tmp = new SHA256Digest().process(buffer);
  return new SHA256Digest().process(_tmp);
}

encodeSignature(signature, recovery, compressed, segwitType) {
  if (segwitType != null) {
    recovery += 8;
    if (segwitType == 'p2wpkh') recovery += 4;
  } else {
    if (compressed) recovery += 4;
  }
  recovery += 27;
  return recovery.toRadixString(16);
}

/*
Future signedBitcoinMessage(String originalMessage, String wif) async {
  print('originalMessage=');
  print(originalMessage);
  var hdWallet = Wallet.fromWIF(wif);
  var compressed = false;
  var sigwitType;
  var signedMess = await hdWallet.sign(originalMessage);
  var recovery = 0;
  var r = encodeSignature(signedMess, recovery, compressed, sigwitType);
  print('r=');
  print(r);
  print('signedMess=');
  print(signedMess);
  return signedMess;
}
*/

MsgSignature sign(Uint8List messageHash, Uint8List privateKey) {
  final digest = SHA256Digest();
  final signer = ECDSASigner(null, HMac(digest, 64));
  final key = ECPrivateKey(bytesToInt(privateKey), _params);

  signer.init(true, PrivateKeyParameter(key));
  var sig = signer.generateSignature(messageHash) as ECSignature;

  print('ssssinhhhere');
  print(sig);
  /*
	This is necessary because if a message can be signed by (r, s), it can also
	be signed by (r, -s (mod N)) which N being the order of the elliptic function
	used. In order to ensure transactions can't be tampered with (even though it
	would be harmless), Ethereum only accepts the signature with the lower value
	of s to make the signature for the message unique.
	More details at
	https://github.com/web3j/web3j/blob/master/crypto/src/main/java/org/web3j/crypto/ECDSASignature.java#L27
	 */
  if (sig.s.compareTo(_halfCurveOrder) > 0) {
    final canonicalisedS = _params.n - sig.s;
    sig = ECSignature(sig.r, canonicalisedS);
  }

  final publicKey = bytesToInt(privateKeyBytesToPublic(privateKey));

  //Implementation for calculating v naively taken from there, I don't understand
  //any of this.
  //https://github.com/web3j/web3j/blob/master/crypto/src/main/java/org/web3j/crypto/Sign.java
  var recId = -1;
  for (var i = 0; i < 4; i++) {
    final k = _recoverFromSignature(i, sig, messageHash, _params);
    if (k == publicKey) {
      recId = i;
      break;
    }
  }

  if (recId == -1) {
    throw Exception(
        'Could not construct a recoverable key. This should never happen');
  }

  return MsgSignature(sig.r, sig.s, recId + 27);
}

BigInt _recoverFromSignature(
    int recId, ECSignature sig, Uint8List msg, ECDomainParameters params) {
  final n = params.n;
  final i = BigInt.from(recId ~/ 2);
  final x = sig.r + (i * n);

  //Parameter q of curve
  final prime = BigInt.parse(
      'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
      radix: 16);
  if (x.compareTo(prime) >= 0) return null;

  final R = _decompressKey(x, (recId & 1) == 1, params.curve);
  if (!(R * n).isInfinity) return null;

  final e = bytesToInt(msg);

  final eInv = (BigInt.zero - e) % n;
  final rInv = sig.r.modInverse(n);
  final srInv = (rInv * sig.s) % n;
  final eInvrInv = (rInv * eInv) % n;

  final q = (params.G * eInvrInv) + (R * srInv);

  final bytes = q.getEncoded(false);
  return bytesToInt(bytes.sublist(1));
}

const _ethMessagePrefix = '\u0019Ethereum Signed Message:\n';
const _btcMessagePrefix = '\x18Bitcoin Signed Message:\n';
Uint8List uint8ListFromList(List<int> data) {
  if (data is Uint8List) return data;

  return Uint8List.fromList(data);
}

ECPoint _decompressKey(BigInt xBN, bool yBit, ECCurve c) {
  List<int> x9IntegerToBytes(BigInt s, int qLength) {
    //https://github.com/bcgit/bc-java/blob/master/core/src/main/java/org/bouncycastle/asn1/x9/X9IntegerConverter.java#L45
    final bytes = intToBytes(s);

    if (qLength < bytes.length) {
      return bytes.sublist(0, bytes.length - qLength);
    } else if (qLength > bytes.length) {
      final tmp = List<int>.filled(qLength, 0);

      final offset = qLength - bytes.length;
      for (var i = 0; i < bytes.length; i++) {
        tmp[i + offset] = bytes[i];
      }

      return tmp;
    }

    return bytes;
  }

  final compEnc = x9IntegerToBytes(xBN, 1 + ((c.fieldSize + 7) ~/ 8));
  compEnc[0] = yBit ? 0x03 : 0x02;
  return c.decodePoint(compEnc);
}

Uint8List _padTo32(Uint8List data) {
  assert(data.length <= 32);
  if (data.length == 32) return data;

  // todo there must be a faster way to do this?
  return Uint8List(32)..setRange(32 - data.length, 32, data);
}

Future<Uint8List> signBtcMessageWith(originalMessage,Uint8List privateKey,
    {int chainId}) async{
  Uint8List messageHash =
  magicHash(originalMessage, environment["chains"]["BTC"]["network"]);

  print('messageHash1=');
  print(messageHash);
  print(privateKey);
  var signature = sign(messageHash, privateKey);

  // https://github.com/ethereumjs/ethereumjs-util/blob/8ffe697fafb33cefc7b7ec01c11e3a7da787fe0e/src/signature.ts#L26
  // be aware that signature.v already is recovery + 27
  final chainIdV =
  chainId != null ? (signature.v - 27 + (chainId * 2 + 35)) : signature.v;

  signature = MsgSignature(signature.r, signature.s, chainIdV);

  final r = _padTo32(intToBytes(signature.r));
  final s = _padTo32(intToBytes(signature.s));
  final v = intToBytes(BigInt.from(signature.v));

  // https://github.com/ethereumjs/ethereumjs-util/blob/8ffe697fafb33cefc7b7ec01c11e3a7da787fe0e/src/signature.ts#L63
  return uint8ListFromList(r + s + v);
}
Future<Uint8List> signPersonalMessageWith(
    String _messagePrefix, Uint8List privateKey, Uint8List payload,
    {int chainId}) async {
  final prefix = _messagePrefix + payload.length.toString();
  final prefixBytes = ascii.encode(prefix);

  // will be a Uint8List, see the documentation of Uint8List.+
  final concat = uint8ListFromList(prefixBytes + payload);

  //final signature = await credential.signToSignature(concat, chainId: chainId);

  print('concat=');
  print(concat);
  print(keccak256(concat));
  print(privateKey);

  var signature = sign(keccak256(concat), privateKey);

  // https://github.com/ethereumjs/ethereumjs-util/blob/8ffe697fafb33cefc7b7ec01c11e3a7da787fe0e/src/signature.ts#L26
  // be aware that signature.v already is recovery + 27
  final chainIdV =
      chainId != null ? (signature.v - 27 + (chainId * 2 + 35)) : signature.v;

  signature = MsgSignature(signature.r, signature.s, chainIdV);

  final r = _padTo32(intToBytes(signature.r));
  final s = _padTo32(intToBytes(signature.s));
  final v = intToBytes(BigInt.from(signature.v));

  // https://github.com/ethereumjs/ethereumjs-util/blob/8ffe697fafb33cefc7b7ec01c11e3a7da787fe0e/src/signature.ts#L63
  return uint8ListFromList(r + s + v);
  //return credential.sign(concat, chainId: chainId);
}

Uint8List magicHash(String message, [NetworkType network]) {
  network = network ?? bitcoin;
  Uint8List messagePrefix = utf8.encode(network.messagePrefix);
  int messageVISize = encodingLength(message.length);
  int length = messagePrefix.length + messageVISize + message.length;
  Uint8List buffer = new Uint8List(length);
  buffer.setRange(0, messagePrefix.length, messagePrefix);
  encode(message.length, buffer, messagePrefix.length);
  buffer.setRange(
      messagePrefix.length + messageVISize, length, utf8.encode(message));
  return hash256(buffer);
}

signedMessage(String originalMessage, seed, coinName, tokenType) async {
  print('originalMessage=');
  print(originalMessage);
  var r = '';
  var s = '';
  var v = '';

  final root = bip32.BIP32.fromSeed(
      seed,
      bip32.NetworkType(
          wif: environment["chains"]["BTC"]["network"].wif,
          bip32: new bip32.Bip32Type(
              public: environment["chains"]["BTC"]["network"].bip32.public,
              private: environment["chains"]["BTC"]["network"].bip32.private)));

  var signedMess;
  if (coinName == 'ETH' || tokenType == 'ETH') {
    var coinType = environment["CoinType"]["ETH"];
    final ethCoinChild =
        root.derivePath("m/44'/" + coinType.toString() + "'/0'/0/0");
    var privateKey = ethCoinChild.privateKey;
    //var credentials = EthPrivateKey.fromHex(privateKey);
    var credentials = EthPrivateKey(privateKey);

    var signedMessOrig = await credentials
        .signPersonalMessage(stringToUint8List(originalMessage));

    signedMess = await signPersonalMessageWith(
        _ethMessagePrefix, privateKey, stringToUint8List(originalMessage));
    String ss = HEX.encode(signedMess);
    String ss2 = HEX.encode(signedMessOrig);
    if (ss == ss2) {
      print('signiture is right');
    } else {
      print('signiture is wrong');
    }
    r = ss.substring(0, 64);
    s = ss.substring(64, 128);
    v = ss.substring(128);
  } else if (coinName == 'FAB' || coinName == 'BTC' || tokenType == 'FAB') {
    //var hdWallet = new HDWallet.fromSeed(seed, network: testnet);

    var coinType = environment["CoinType"]["FAB"];
    if (coinName == 'BTC') {
      coinType = environment["CoinType"]["BTC"];
    }

    var bitCoinChild =
        root.derivePath("m/44'/" + coinType.toString() + "'/0'/0/0");
    //var btcWallet =
    //    hdWallet.derivePath("m/44'/" + coinType.toString() + "'/0'/0/0");
    var privateKey = bitCoinChild.privateKey;
    var credentials = EthPrivateKey(privateKey);

    signedMess = await signBtcMessageWith(
        originalMessage, privateKey);
    String ss = HEX.encode(signedMess);
    r = ss.substring(0, 64);
    s = ss.substring(64, 128);
    v = ss.substring(128);

    /*
    var btcWallet = new HDWallet.fromBase58(bitCoinChild.toBase58(), network: environment["chains"]["BTC"]["network"]);
    print('privateKey=');
    print(HEX.decode(btcWallet.privKey));
    signedMess = await btcWallet.sign(originalMessage);
    */

    Uint8List messageHash =
        magicHash(originalMessage, environment["chains"]["BTC"]["network"]);
    print('messageHash=');
    print(messageHash);
    print(privateKey);
    signedMess = await ecc.sign(messageHash, privateKey);

    var recovery = 0;
    var compressed = true;
    var sigwitType;
    v = encodeSignature(signedMess, recovery, compressed, sigwitType);
    String sss = HEX.encode(signedMess);
    var r1 = sss.substring(0, 64);
    var s1 = sss.substring(64, 128);

    if (r == r1) {
      print('signiture is right');
    } else {
      print('signiture is wrong');
    }

    print('r1=' + r1);
    print('s1=' + s1);
    //amount=0.01
    //r1=d2c3555da5b1deb7147e63cbc6d431f4ac15433b16bdd95ab6da214a442c8f12
    //s1=0d6564a5e6ae55ed429330189affc31a3f50a1bcf30c2dbd8d814886d2c7d71e
  }

  if (signedMess != null) {}

  return {'r': r, 's': s, 'v': v};
}

getOfficalAddress(String coinName) {
  var address = environment['addresses']['exchangilyOfficial']
      .where((addr) => addr['name'] == coinName)
      .toList();

  if (address != null) {
    return address[0]['address'];
  }
  return null;
}

/*
usage:
getAddressForCoin(root, 'BTC');
getAddressForCoin(root, 'ETH');
getAddressForCoin(root, 'FAB');
getAddressForCoin(root, 'USDT', tokenType: 'ETH');
getAddressForCoin(root, 'EXG', tokenType: 'FAB');
 */
Future getAddressForCoin(root, String coinName,
    {tokenType = '', index = 0}) async {
  if (coinName == 'BTC') {
    var node = getBtcNode(root, index: index);
    return getBtcAddressForNode(node);
  } else if ((coinName == 'ETH') || (tokenType == 'ETH')) {
    var node = getEthNode(root, index: index);
    return await getEthAddressForNode(node);
  } else if (coinName == 'FAB') {
    var node = getFabNode(root, index: index);
    return getBtcAddressForNode(node);
  } else if (tokenType == 'FAB') {
    var node = getFabNode(root, index: index);
    var fabPublicKey = node.publicKey;
    Digest sha256 = new Digest("SHA-256");
    var pass1 = sha256.process(fabPublicKey);
    Digest ripemd160 = new Digest("RIPEMD-160");
    var pass2 = ripemd160.process(pass1);
    var fabTokenAddr = '0x' + HEX.encode(pass2);
    return fabTokenAddr;
  }
  return '';
}

// Future Coin Balances With Addresses
Future getCoinBalanceByAddress(String coinName, String address,
    {tokenType = ''}) async {
  try {
    if (coinName == 'BTC') {
      return await getBtcBalanceByAddress(address);
    } else if (coinName == 'ETH') {
      return await getEthBalanceByAddress(address);
    } else if (coinName == 'FAB') {
      return await getFabBalanceByAddress(address);
    } else if (tokenType == 'ETH') {
      return await getEthTokenBalanceByAddress(address, coinName);
    } else if (tokenType == 'FAB') {
      return await getFabTokenBalanceByAddress(address, coinName);
    }
  } catch (e) {
    log.e(e);
  }

  return {'balance': -1, 'lockbalance': -1};
}

Future getBalanceForCoin(root, coinName, {tokenType = '', index = 0}) async {
  var address = await getAddressForCoin(root, coinName,
      tokenType: tokenType, index: index);
  try {
    if (coinName == 'BTC') {
      return await getBtcBalanceByAddress(address);
    } else if (coinName == 'ETH') {
      return await getEthBalanceByAddress(address);
    } else if (coinName == 'FAB') {
      return await getFabBalanceByAddress(address);
    } else if (tokenType == 'ETH') {
      return await getEthTokenBalanceByAddress(address, coinName);
    } else if (tokenType == 'FAB') {
      return await getFabTokenBalanceByAddress(address, coinName);
    }
  } catch (e) {}

  return {'balance': -1, 'lockbalance': -1};
}