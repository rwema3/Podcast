import 'package:flutter/material.dart';
import 'package:flare_flutter/flare_actor.dart';
import '../util/extension_helper.dart';

class FourthPage extends StatefulWidget {
  FourthPage({Key? key}) : super(key: key);

  @override
  _FourthPageState createState() => _FourthPageState();
}

class _FourthPageState extends State<FourthPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromRGBO(77, 145, 190, 1),
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
                context.s.introFourthPage,
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
            SizedBox(
                height: context.width * 3 / 4,
                child: FlareActor(
                  'assets/longtap.flr',
                  alignment: Alignment.center,
                  animation: 'longtap',
                  fit: BoxFit.cover,
                )),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
