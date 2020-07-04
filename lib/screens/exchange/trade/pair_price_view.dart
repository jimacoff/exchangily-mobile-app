import 'dart:ui';

import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/models/shared/decimal_config.dart';
import 'package:exchangilymobileapp/models/trade/price.dart';
import 'package:exchangilymobileapp/shared/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PairPriceView extends StatelessWidget {
  final Price pairPrice;
  final bool isBusy;
  final DecimalConfig decimalConfig;
  const PairPriceView(
      {Key key, this.pairPrice, this.isBusy, this.decimalConfig})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isBusy
        ? Shimmer.fromColors(
            child: buildContainer(context),
            baseColor: grey,
            highlightColor: primaryColor)
        : buildContainer(context);
  }

  Container buildContainer(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Text(pairPrice.price.toStringAsFixed(decimalConfig.priceDecimal),
                  style: TextStyle(fontSize: 30, color: priceColor)),
              Column(
                children: [
                  Text(
                      "\$" +
                          pairPrice.price
                              .toStringAsFixed(decimalConfig.priceDecimal),
                      style: Theme.of(context).textTheme.headline3),
                  Row(
                    children: [
                      Text(
                          (pairPrice.close - pairPrice.open).toStringAsFixed(2),
                          style: Theme.of(context).textTheme.headline5.copyWith(
                              color: Color(pairPrice.close > pairPrice.open
                                  ? 0XFF0da88b
                                  : 0XFFe2103c))),
                      UIHelper.horizontalSpaceSmall,
                      Text(pairPrice.change.toStringAsFixed(2) + "%",
                          style: Theme.of(context).textTheme.headline5.copyWith(
                              color: Color(pairPrice.change >= 0
                                  ? 0XFF0da88b
                                  : 0XFFe2103c))),
                    ],
                  ),
                ],
              )
            ],
          ),
          // Change Price Value Row
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 15.0),
            color: isBusy ? Colors.transparent : walletCardColor,

            // color: Colors.redAccent,

            child: Column(children: <Widget>[
              Row(
                children: <Widget>[
                  UIHelper.horizontalSpaceMedium,
                  Expanded(
                    flex: 2,
                    child: Text(AppLocalizations.of(context).volume,
                        style: Theme.of(context).textTheme.subtitle2),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(AppLocalizations.of(context).low.toString(),
                        style: Theme.of(context).textTheme.subtitle2),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(AppLocalizations.of(context).high.toString(),
                        style: Theme.of(context).textTheme.subtitle2),
                  ),
                ],
              ),
              // Low Volume High Row
              Row(
                children: <Widget>[
                  UIHelper.horizontalSpaceMedium,
                  Expanded(
                    flex: 2,
                    child: Text(
                        pairPrice.volume
                            .toStringAsFixed(decimalConfig.priceDecimal),
                        style: Theme.of(context).textTheme.headline6),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                        pairPrice.low
                            .toStringAsFixed(decimalConfig.priceDecimal),
                        style: Theme.of(context).textTheme.headline6),
                  ),
                  Expanded(
                      flex: 2,
                      child: Text(
                          pairPrice.high
                              .toStringAsFixed(decimalConfig.priceDecimal),
                          style: Theme.of(context).textTheme.headline6)),
                ],
              ),
            ]),
          )
        ],
      ),
    );
  }
}
