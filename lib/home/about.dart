import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';

import '../util/extension_helper.dart';
import '../widgets/custom_widget.dart';

const String version = '0.6.0';

class AboutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    OverlayEntry _createOverlayEntry(TapDownDetails detail) {
      // RenderBox renderBox = context.findRenderObject();
      final offset = detail.globalPosition;
      return OverlayEntry(
        builder: (constext) => Positioned(
          left: offset.dx - 5,
          top: offset.dy - 120,
          child: Container(
              width: 20,
              height: 120,
              color: Colors.transparent,
              alignment: Alignment.topCenter,
              child: HeartSet(height: 120, width: 20)),
        ),
      );
    }

    final s = context.s;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: context.background,
        statusBarIconBrightness: context.iconBrightness,
        systemNavigationBarColor: context.background,
        systemNavigationBarIconBrightness: context.iconBrightness,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            title: Text(s.homeToprightMenuAbout),
            scrolledUnderElevation: 1,
            leading: CustomBackButton(),
          ),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 110.0,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Image(
                          image: AssetImage('assets/logo.png'),
                          height: 80,
                        ),
                        Text(s.version(version)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Tsacdop is a podcast player built with flutter, a clean, simply beautiful and friendly app.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            'https://tsacdop.stonegate.me/#/privacy'.launchUrl,
                        style: TextButton.styleFrom(
                            primary: context.accentColor,
                            textStyle: TextStyle(fontWeight: FontWeight.bold)),
                        child: Text(
                          s.privacyPolicy,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 4,
                        width: 4,
                        decoration: BoxDecoration(
                            color: context.accentColor, shape: BoxShape.circle),
                      ),
                      TextButton(
                        onPressed: () =>
                            'https://tsacdop.stonegate.me/#/changelog'
                                .launchUrl,
                        style: TextButton.styleFrom(
                            primary: context.accentColor,
                            textStyle: TextStyle(fontWeight: FontWeight.bold)),
                        child: Text(s.changelog,
                            style: TextStyle(color: context.accentColor)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _listItem(context, 'Twitter @tsacdop',
                            LineIcons.twitter, 'https://twitter.com/tsacdop'),
                        _listItem(context, 'GitHub', LineIcons.alternateGithub,
                            'https://github.com/stonega/tsacdop'),
                        _listItem(context, 'Telegram', LineIcons.telegram,
                            'https://t.me/joinchat/Bk3LkRpTHy40QYC78PK7Qg'),
                        _listItem(context, 'Reddit', LineIcons.redditLogo,
                            'https://www.reddit.com/r/Tsacdop'),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: () =>
                                  'https://www.buymeacoffee.com/stonegate'
                                      .launchUrl,
                              style: ElevatedButton.styleFrom(
                                primary: Color(0xffffdd00),
                                elevation: 0,
                                enableFeedback: false,
                              ),
                              child: Container(
                                height: 30.0,
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Buy Me A Coffee',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Image(
                                      image:
                                          AssetImage('assets/buymeacoffee.png'),
                                      height: 20,
                                      fit: BoxFit.fitHeight,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: [
                            SizedBox(width: 25),
                            Text(
                              s.translators,
                              style: TextStyle(
                                  color: context.accentColor,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.favorite, color: Colors.red, size: 20),
                          ],
                        ),
                        _translatorInfo(context, name: 'Atrate'),
                        _translatorInfo(context, name: 'ppp', flag: 'fr'),
                        _translatorInfo(context,
                            name: 'Joel Israel', flag: 'mx'),
                        _translatorInfo(context,
                            name: 'Bruno Pinheiro', flag: 'pt'),
                        _translatorInfo(context,
                            name: 'Edoardo Maria Elidoro', flag: 'it'),
                        _translatorInfo(context,
                            name: 'Murat T. Akyuz', flag: 'tr'),
                      ],
                    ),
                  ),
                  //Spacer(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTapDown: (detail) async {
                        OverlayEntry _overlayEntry;
                        _overlayEntry = _createOverlayEntry(detail);
                        Overlay.of(context)!.insert(_overlayEntry);
                        await Future.delayed(Duration(seconds: 2));
                        _overlayEntry.remove();
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Image.asset(
                            'assets/text.png',
                            height: 25,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                          ),
                          Icon(
                            Icons.favorite,
                            color: Colors.blue,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                          ),
                          FlutterLogo(
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _listItem(
          BuildContext context, String text, IconData icons, String url) =>
      InkWell(
        onTap: () => url.launchUrl,
        child: Container(
          height: 50.0,
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: Divider.createBorderSide(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icons, color: context.accentColor),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
              ),
              Text(text),
            ],
          ),
        ),
      );

  Widget _translatorInfo(BuildContext context,
          {required String name, String? flag}) =>
      Container(
        height: 50.0,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            bottom: Divider.createBorderSide(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(LineIcons.user, color: context.accentColor),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.fade,
              ),
            ),
            if (flag != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image(
                  image: AssetImage('assets/$flag.png'),
                  height: 20,
                  width: 30,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      );
}
