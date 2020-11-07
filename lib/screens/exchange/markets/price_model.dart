/*
* Copyright (c) 2020 Exchangily LLC
*
* Licensed under Apache License v2.0
* You may obtain a copy of the License at
*
*      https://www.apache.org/licenses/LICENSE-2.0
*
*----------------------------------------------------------------------
* Author: ken.qiu@exchangily.com, barry-ruprai@exchangily.com
*----------------------------------------------------------------------
*/

class Price {
  String _symbol;
  double _price;
  double _high;
  double _low;
  double _open;
  double _close;
  double _volume;
  double _change;
  double _changeValue;

  Price(
      {String symbol,
      double price,
      double high,
      double low,
      double open,
      double close,
      double volume,
      double change,
      double changeValue}) {
    this._symbol = symbol;
    this._price = price ?? 0.0;
    this._high = high ?? 0.0;
    this._low = low ?? 0.0;
    this._open = open ?? 0.0;
    this._close = close ?? 0.0;
    this._volume = volume ?? 0.0;
    this._change =
        //change ?? 0.0;
        (close - open) / open * 100 ?? 0.0;
    this._changeValue = changeValue ?? 0.0;
  }

  factory Price.fromJson(Map<String, dynamic> json) {
    return Price(
        symbol: json['s'].toString(),
        price: json['p'].toDouble(),
        high: json['h'].toDouble(),
        low: json['l'].toDouble(),
        open: json['o'].toDouble(),
        close: json['c'].toDouble(),
        volume: json['v'].toDouble());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['s'] = this._symbol;
    data['p'] = this._price;
    data['h'] = this._high;
    data['l'] = this._low;
    data['o'] = this._open;
    data['c'] = this._close;
    data['v'] = this._volume;
    return data;
  }

  String get symbol => _symbol;
  set symbol(String symbol) {
    this._symbol = symbol;
  }

  double get price => _price;
  set price(double price) {
    this._price = price;
  }

  double get high => _high;
  set high(double high) {
    this._high = high;
  }

  double get low => _low;
  set low(double low) {
    this._low = low;
  }

  double get open => _open;
  set open(double open) {
    this._open = open;
  }

  double get close => _close;
  set close(double close) {
    this._close = close;
  }

  double get volume => _volume;
  set volume(double volume) {
    this._volume = volume;
  }

  double get changeValue => _changeValue;
  set changeValue(double changeValue) {
    this._changeValue = changeValue;
  }

  double get change => _change;
  set change(double change) {
    this._change = change;
  }
}

class PriceList {
  final List<Price> prices;
  PriceList({this.prices});
  factory PriceList.fromJson(List<dynamic> parsedJson) {
    List<Price> prices = new List<Price>();
    parsedJson.forEach((i) {
      // print('0000 ${i}');
      Price price = Price.fromJson(i);
      //  print('1111 ${price.toJson()}');
      prices.add(price);
    });

    return new PriceList(prices: prices);
  }
}