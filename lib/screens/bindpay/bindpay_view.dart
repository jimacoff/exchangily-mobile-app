import 'dart:io';

import 'package:exchangilymobileapp/constants/colors.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/screens/bindpay/bindpay_viewmodel.dart';
import 'package:exchangilymobileapp/shared/ui_helpers.dart';
import 'package:exchangilymobileapp/widgets/bottom_nav.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class BindpayView extends StatelessWidget {
  const BindpayView({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // PersistentBottomSheetController persistentBottomSheetController;
    return ViewModelBuilder<BindpayViewmodel>.reactive(
      viewModelBuilder: () => BindpayViewmodel(),
      onModelReady: (model) {
        model.context = context;
        model.init();
      },
      builder: (context, model, _) => WillPopScope(
        onWillPop: () async {
          model.onBackButtonPressed();
          return new Future(() => false);
        },
        child: Scaffold(
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
              print('Close keyboard');
              // persistentBottomSheetController.closed
              //     .then((value) => print(value));
              if (model.isShowBottomSheet) {
                Navigator.pop(context);
                model.setBusy(true);
                model.isShowBottomSheet = false;
                model.setBusy(false);
                print('Close bottom sheet');
              }
            },
            child: Container(
              color: secondaryColor,
              margin: EdgeInsets.only(top: 40),
              child: Stack(children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                      height: 80,
                      width: 105,
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                color: primaryColor.withAlpha(175),
                                width: 4.0,
                              ),
                              left: BorderSide(
                                  color: secondaryColor.withAlpha(175),
                                  width: 12.0),
                              right: BorderSide(
                                  color: secondaryColor.withAlpha(175),
                                  width: 12.0))),
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        'assets/images/bindpay/bindpay.png',
                        color: white,
                      )),
                ),
                Container(
                  margin: EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
/*----------------------------------------------------------------------------------------------------
                                        Coin list dropdown
----------------------------------------------------------------------------------------------------*/

                      // InkWell(
                      //   onTap: () {

                      //   },
                      //   child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //       children: [
                      //         Text('Choose Coin'),
                      //         Icon(Icons.arrow_drop_down)
                      //       ]),
                      // ),
                      Platform.isIOS
                          ? CoinListBottomSheetFloatingActionButton(
                              model: model)
                          // Container(
                          //     color: walletCardColor,
                          //     child: CupertinoPicker(
                          //         diameterRatio: 1.3,
                          //         offAxisFraction: 5,
                          //         scrollController: model.scrollController,
                          //         itemExtent: 50,
                          //         onSelectedItemChanged: (int newValue) {
                          //           model.updateSelectedTickernameIOS(newValue);
                          //         },
                          //         children: [
                          //           for (var i = 0; i < model.coins.length; i++)
                          //             Container(
                          //               margin: EdgeInsets.only(left: 10),
                          //               child: Row(
                          //                 children: [
                          //                   Text(
                          //                       model.coins[i]['tickerName']
                          //                           .toString(),
                          //                       style: Theme.of(context)
                          //                           .textTheme
                          //                           .headline5),
                          //                   UIHelper.horizontalSpaceSmall,
                          //                   Text(
                          //                     model.coins[i]['quantity']
                          //                         .toString(),
                          //                     style: Theme.of(context)
                          //                         .textTheme
                          //                         .headline5
                          //                         .copyWith(color: grey),
                          //                   )
                          //                 ],
                          //               ),
                          //             ),
                          //           //    })
                          //           model.coins.length > 0
                          //               ? Container()
                          //               : SizedBox(
                          //                   width: double.infinity,
                          //                   child: Center(
                          //                     child: Text(
                          //                       AppLocalizations.of(context)
                          //                           .insufficientBalance,
                          //                       style: Theme.of(context)
                          //                           .textTheme
                          //                           .bodyText2,
                          //                     ),
                          //                   ),
                          //                 ),
                          //         ]),
                          //   )
                          : Container(
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(
                                    color: model.coins.isEmpty
                                        ? Colors.transparent
                                        : primaryColor,
                                    style: BorderStyle.solid,
                                    width: 0.50),
                              ),
                              child: DropdownButton(
                                  underline: SizedBox.shrink(),
                                  elevation: 5,
                                  isExpanded: true,
                                  icon: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Icon(Icons.arrow_drop_down),
                                  ),
                                  iconEnabledColor: primaryColor,
                                  iconDisabledColor: model.coins.isEmpty
                                      ? secondaryColor
                                      : grey,
                                  iconSize: 30,
                                  hint: Padding(
                                    padding: model.coins.isEmpty
                                        ? EdgeInsets.all(0)
                                        : const EdgeInsets.only(left: 10.0),
                                    child: model.coins.isEmpty
                                        ? ListTile(
                                            dense: true,
                                            leading: Icon(
                                              Icons.account_balance_wallet,
                                              color: red,
                                              size: 18,
                                            ),
                                            title: Text(
                                                AppLocalizations.of(context)
                                                    .noCoinBalance,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2),
                                            subtitle: Text(
                                                AppLocalizations.of(context)
                                                    .transferFundsToExchangeUsingDepositButton,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .subtitle2))
                                        : Text(
                                            AppLocalizations.of(context)
                                                .selectCoin,
                                            textAlign: TextAlign.start,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5,
                                          ),
                                  ),
                                  value: model.tickerName,
                                  onChanged: (newValue) {
                                    model.updateSelectedTickername(newValue);
                                  },
                                  items: model.coins.map(
                                    (coin) {
                                      return DropdownMenuItem(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10.0),
                                          child: Row(
                                            children: [
                                              Text(
                                                  coin['tickerName'].toString(),
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline5),
                                              UIHelper.horizontalSpaceSmall,
                                              Text(
                                                coin['quantity'].toString(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(color: grey),
                                              )
                                            ],
                                          ),
                                        ),
                                        value: coin['tickerName'],
                                      );
                                    },
                                  ).toList()),
                            ),

/*----------------------------------------------------------------------------------------------------
                                        Receiver Address textfield
----------------------------------------------------------------------------------------------------*/

                      UIHelper.verticalSpaceSmall,
                      TextField(
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                              prefixIcon: IconButton(
                                  padding: EdgeInsets.only(left: 10),
                                  alignment: Alignment.centerLeft,
                                  tooltip:
                                      AppLocalizations.of(context).scanBarCode,
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: white,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    model.scanBarcode();
                                    FocusScope.of(context)
                                        .requestFocus(FocusNode());
                                  }),
                              suffixIcon: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.content_paste,
                                    color: green,
                                    size: 18,
                                  ),
                                  onPressed: () => model.contentPaste()),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color(0XFF871fff), width: 0.5)),
                              hintText:
                                  AppLocalizations.of(context).recieveAddress,
                              hintStyle: Theme.of(context).textTheme.headline5),
                          controller: model.addressController,
                          style: Theme.of(context).textTheme.headline5),

/*----------------------------------------------------------------------------------------------------
                                        Transfer amount textfield
----------------------------------------------------------------------------------------------------*/

                      UIHelper.verticalSpaceSmall,
                      TextField(
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color(0XFF871fff), width: 0.5)),
                              hintText:
                                  AppLocalizations.of(context).enterAmount,
                              hintStyle: Theme.of(context).textTheme.headline5),
                          controller: model.amountController,
                          style: Theme.of(context).textTheme.headline5),
                      UIHelper.verticalSpaceMedium,
/*----------------------------------------------------------------------------------------------------
                                        Transfer - Receive Button Row
----------------------------------------------------------------------------------------------------*/

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration:
                                  model.sharedService.gradientBoxDecoration(),
                              child: FlatButton(
                                textColor: Colors.white,
                                onPressed: () {
                                  model.isBusy
                                      ? print('busy')
                                      : model.transfer();
                                },
                                child: Text(
                                    AppLocalizations.of(context).tranfser,
                                    style:
                                        Theme.of(context).textTheme.headline4),
                              ),
                            ),
                          ),
                          UIHelper.horizontalSpaceSmall,

/*----------------------------------------------------------------------------------------------------
                                            Receive Button
----------------------------------------------------------------------------------------------------*/

                          Expanded(
                            child: OutlineButton(
                              borderSide: BorderSide(color: primaryColor),
                              padding: EdgeInsets.all(15),
                              color: primaryColor,
                              textColor: Colors.white,
                              onPressed: () {
                                model.isBusy
                                    ? print('busy')
                                    : model.showBarcode();
                              },
                              child: Text(AppLocalizations.of(context).receive,
                                  style: Theme.of(context).textTheme.headline4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

/*----------------------------------------------------------------------------------------------------
                                        Stack loading container
----------------------------------------------------------------------------------------------------*/

                model.isBusy
                    ? Align(
                        alignment: Alignment.center,
                        child: model.sharedService
                            .stackFullScreenLoadingIndicator())
                    : Container()
              ]),
            ),
          ),
          bottomNavigationBar: BottomNavBar(count: 2),
        ),
      ),
    );
  }
}

class CoinListBottomSheetFloatingActionButton extends StatelessWidget {
  const CoinListBottomSheetFloatingActionButton({Key key, this.model})
      : super(key: key);
  final BindpayViewmodel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: EdgeInsets.all(10.0),
      width: double.infinity,
      child: FloatingActionButton(
          backgroundColor: secondaryColor,
          child: Container(
            decoration: BoxDecoration(
              color: primaryColor,
              border: Border.all(width: 1),
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            width: 400,
            height: 220,
            //  color: secondaryColor,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Padding(
                padding: const EdgeInsets.only(right: 5.0),
                child: model.coins.isEmpty
                    ? Text(AppLocalizations.of(context).noCoinBalance)
                    : Text(model.tickerName == ''
                        ? AppLocalizations.of(context).selectCoin
                        : model.tickerName),
              ),
              Text(model.quantity == 0.0 ? '' : model.quantity.toString()),
               model.coins.isNotEmpty?
              Icon( Icons.arrow_drop_down):Container()
            ]),
          ),
          onPressed: () {
            if(model.coins.isNotEmpty)
            model.coinListBottomSheet(context);
          }),
    );
  }
}
