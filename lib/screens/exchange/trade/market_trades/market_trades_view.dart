import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/screens/exchange/trade/market_trades/market_trade_model.dart';
import 'package:exchangilymobileapp/shared/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:exchangilymobileapp/utils/number_util.dart';

class MarketTradesView extends StatelessWidget {
  final List<MarketTrades> marketTrades;
  const MarketTradesView({Key key, this.marketTrades}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(5.0),
        child: Column(
          children: [
            Container(
              color: secondaryColor,
              child: SizedBox(
                height: 20,
                child: Row(
                  children: <Widget>[
                    UIHelper.horizontalSpaceSmall,
                    UIHelper.horizontalSpaceSmall,
                    Expanded(
                        flex: 1,
                        child: Text(AppLocalizations.of(context).price,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.subtitle2)),
                    UIHelper.horizontalSpaceMedium,
                    Expanded(
                        flex: 2,
                        child: Text(AppLocalizations.of(context).quantity,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.subtitle2)),
                    UIHelper.horizontalSpaceSmall,
                    Expanded(
                        flex: 2,
                        child: Text(AppLocalizations.of(context).date,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.subtitle2)),
                    UIHelper.horizontalSpaceMedium,
                  ],
                ),
              ),
            ),
            Expanded(child: MarketTradeDetailView(marketTrades: marketTrades)),
          ],
        ));
  }
}

class MarketTradeDetailView extends StatelessWidget {
  const MarketTradeDetailView({
    Key key,
    @required this.marketTrades,
  }) : super(key: key);

  final List<MarketTrades> marketTrades;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView.builder(
          shrinkWrap: true,
          itemCount: marketTrades.length,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              color: marketTrades[index].bidOrAsk ? buyOrders : sellOrders,
              padding: EdgeInsets.all(4.0),
              margin: EdgeInsets.only(bottom: 1.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  UIHelper.horizontalSpaceSmall,
                  UIHelper.horizontalSpaceSmall,
                  Expanded(
                      flex: 1,
                      child: Text(marketTrades[index].price.toStringAsFixed(5),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.headline6)),
                  UIHelper.horizontalSpaceMedium,
                  Expanded(
                      flex: 2,
                      child: Text(
                          marketTrades[index].quantity.toStringAsFixed(6),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.headline6)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          NumberUtil()
                              .timeFormatted(marketTrades[index].time)
                              .toString(),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.headline6)),
                  UIHelper.verticalSpaceMedium
                ],
              ),
            );
          }),
    );
  }
}
