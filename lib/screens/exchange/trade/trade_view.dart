import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/screens/exchange/markets/price_model.dart';
import 'package:exchangilymobileapp/screens/exchange/trade/buy_sell/buy_sell_view.dart';
import 'package:exchangilymobileapp/screens/exchange/trade/my_orders/my_exchange_assets_view.dart';

import 'package:exchangilymobileapp/screens/exchange/trade/pair_price_view.dart';
import 'package:exchangilymobileapp/screens/exchange/trade/trade_viewmodel.dart';
import 'package:exchangilymobileapp/screens/trade/widgets/trading_view.dart';
import 'package:exchangilymobileapp/shared/ui_helpers.dart';
import 'package:exchangilymobileapp/widgets/shimmer_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';

import 'market_trades/market_trades_view.dart';
import 'my_orders/my_orders_view.dart';
import 'orderbook/orders_book_view.dart';
import 'package:flutter/cupertino.dart';

class TradeView extends StatelessWidget {
  final Price pairPriceByRoute;
  TradeView({Key key, this.pairPriceByRoute}) : super(key: key);
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TradeViewModel>.reactive(
      disposeViewModel: true,
      // passing tickername in the constructor of the viewmodal so that we can pass it to the streamMap
      // which is required override
      viewModelBuilder: () =>
          TradeViewModel(pairPriceByRoute: pairPriceByRoute),
      onModelReady: (model) {
        print('in init trade view');
        model.context = context;
        model.init();
      },
      builder: (context, model, _) => Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
            backgroundColor: primaryColor.withOpacity(0.25),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios),
              onPressed: () {
                model.setBusy(true);
                Navigator.pop(context);
              },
            ),
            title: Text(
              model.updateTickerName(pairPriceByRoute.symbol),
              style: Theme.of(context).textTheme.headline4,
            ),
            centerTitle: true,
            automaticallyImplyLeading: false),
        // drawer: Container(
        //     margin: EdgeInsets.only(top: 10),
        //     child: Stack(overflow: Overflow.visible, children: [
        //       Align(
        //         alignment: Alignment.topCenter,
        //         child: Container(
        //           child: model.dataReady('allPrices')
        //               ? MarketPairsTabView(
        //                   marketPairsTabBarView:
        //                       model.marketPairsTabBar,
        //                   isBusy: false,
        //                 )
        //               : Container(
        //                   child: Center(
        //                     child: Text(
        //                         AppLocalizations.of(context).loading),
        //                   ),
        //                 ),
        //         ),
        //       ),
        //       // Close button position bottom right
        //       Positioned(
        //           bottom: 0,
        //           right: 0,
        //           child: Container(
        //             padding: EdgeInsets.all(5),
        //             decoration: BoxDecoration(
        //                 color: red,
        //                 borderRadius: BorderRadius.only(
        //                     topLeft: Radius.circular(90),
        //                     bottomLeft: Radius.circular(1))),
        //             child: Padding(
        //               padding:
        //                   const EdgeInsets.only(left: 8.0, top: 8.0),
        //               child: IconButton(
        //                 icon: Icon(
        //                   Icons.close,
        //                   color: white,
        //                   size: 30,
        //                 ),
        //                 onPressed: () {
        //                   model.resumeAllStreams();
        //                   model.navigationService.goBack();
        //                 },
        //               ),
        //             ),
        //           )),
        //       // Icon(Icons.access_alarm)
        //     ])),

        body: model.isBusy && model.isDisposing
            ? Container(
                child: Center(
                child: model.sharedService.loadingIndicator(),
              ))
            : Container(
                child: ListView(children: [
                  /// Ticker price stream

                  Container(
                    margin: EdgeInsets.only(top: 5.0),
                    child: PairPriceView(
                      pairPrice: model.dataReady(model.tickerStreamKey)
                          ? model.currentPairPrice
                          : model.pairPriceByRoute,
                      isBusy: !model.dataReady(model.tickerStreamKey),
                      decimalConfig: model.singlePairDecimalConfig,
                      usdValue: model.usdValue,
                    ),
                  ),

                  //  Below container contains trading view chart in the trade tab
                  Container(
                    child: LoadHTMLFileToWEbView(
                        model.updateTickerName(pairPriceByRoute.symbol)),
                  ),

                  UIHelper.verticalSpaceMedium,
                  DefaultTabController(
                    length: 4,
                    //ordersViewTabBody.length,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TabBar(
                          labelPadding: EdgeInsets.only(bottom: 5),
                          onTap: (int tabIndex) {
                            //  model.switchStreams(tabIndex);
                          },
                          indicatorColor: primaryColor,
                          indicatorSize: TabBarIndicatorSize.tab,
                          // Tabs
                          tabs: [
                            Text(AppLocalizations.of(context).orderBook,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1
                                    .copyWith(
                                        fontWeight: FontWeight.w500,
                                        decorationThickness: 3)),
                            Text(AppLocalizations.of(context).marketTrades,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1
                                    .copyWith(
                                        fontWeight: FontWeight.w500,
                                        decorationThickness: 3)),
                            Text(AppLocalizations.of(context).myOrders,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1
                                    .copyWith(
                                        fontWeight: FontWeight.w500,
                                        decorationThickness: 3)),
                            Text(AppLocalizations.of(context).assets,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1
                                    .copyWith(
                                        fontWeight: FontWeight.w500,
                                        decorationThickness: 3)),
                          ]),
                      UIHelper.verticalSpaceSmall,
                      // Tabs view container
                      Container(
                        height: MediaQuery.of(context).size.height * 0.60,
                        child: TabBarView(
                          children: [
                            // order book container
                            Container(
                              child: !model.dataReady(model.orderBookStreamKey)
                                  ? ShimmerLayout(
                                      layoutType: 'orderbook',
                                    )
                                  : OrderBookView(
                                      orderbook: model.orderbook,
                                      decimalConfig:
                                          model.singlePairDecimalConfig),
                            ),

                            // Market trades
                            Container(
                              child:
                                  !model.dataReady(model.marketTradesStreamKey)
                                      ? ShimmerLayout(
                                          layoutType: 'marketTrades',
                                        )
                                      : MarketTradesView(
                                          marketTrades: model.marketTradesList),
                            ),
                            MyOrdersView(tickerName: pairPriceByRoute.symbol),
                            // My Exchange Asssets
                            model.busy(model.myExchangeAssets)
                                ? Container(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 5),
                                    height: 150,
                                    child: ShimmerLayout(
                                      layoutType: 'marketTrades',
                                    ),
                                  )
                                : MyExchangeAssetsView(
                                    myExchangeAssets: model.myExchangeAssets)
                          ],
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
        // Floatin Button buy/sell
        // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        // floatingActionButton:
        // bottomNavigationBar: BottomNavBar(count: 1),
        bottomNavigationBar: Container(
          padding: EdgeInsets.symmetric(horizontal: 10),
          width: 160,
          //margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // Buy button
              SizedBox(width: 5),
              Flexible(
                flex: 1,
                child: RaisedButton(
                  padding: EdgeInsets.all(0),
                  color: buyPrice,
                  onPressed: () {
                    if (model.currentPairPrice != null &&
                        model.dataReady(model.orderBookStreamKey) &&
                        !model.isBusy)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BuySellView(
                                orderbook: model.orderbook,
                                pairSymbolWithSlash: model.pairSymbolWithSlash,
                                bidOrAsk: true)),
                      );
                  },
                  child: Text(AppLocalizations.of(context).buy,
                      style: TextStyle(fontSize: 13, color: white)),
                ),
              ),
              // Sell button
              SizedBox(width: 5),
              Flexible(
                  flex: 1,
                  child: RaisedButton(
                    padding: EdgeInsets.all(0),
                    color: sellPrice,
                    shape: StadiumBorder(
                        side: BorderSide(color: sellPrice, width: 1)),
                    onPressed: () {
                      if (model.currentPairPrice != null &&
                          model.dataReady(model.orderBookStreamKey) &&
                          !model.isBusy)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => BuySellView(
                                  orderbook: model.orderbook,
                                  pairSymbolWithSlash:
                                      model.pairSymbolWithSlash,
                                  bidOrAsk: false)),
                        );
                    },
                    child: Text(AppLocalizations.of(context).sell,
                        style: TextStyle(fontSize: 13, color: Colors.white)),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
