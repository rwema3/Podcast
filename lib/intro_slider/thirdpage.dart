import 'package:flutter/material.dart';
import 'package:flare_flutter/flare_actor.dart';
import '../util/extension_helper.dart';

class ThirdPage extends StatefulWidget {
  ThirdPage({Key? key}) : super(key: key);

  @override
  _ThirdPageState createState() => _ThirdPageState();
}

class _ThirdPageState extends State<ThirdPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromRGBO(35, 204, 198, 1),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 200,
              alignment: Alignment.center,
              padding: EdgeInsets.fromLTRB(40, context.paddingTop + 20, 40, 20),
              child: Text(
                context.s.introThirdPage,
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
            SizedBox(
                height: context.width * 3 / 4,
                child: FlareActor(
                  'assets/swipe.flr',
                  alignment: Alignment.center,
                  animation: 'swipe',
                  fit: BoxFit.cover,
                )),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
