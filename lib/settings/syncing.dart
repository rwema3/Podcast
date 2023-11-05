import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../state/setting_state.dart';
import '../util/extension_helper.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/custom_widget.dart';

class SyncingSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    var settings = Provider.of<SettingState>(context, listen: false);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.overlay,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.settingsSyncing),
          leading: CustomBackButton(),
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: SingleChildScrollView(
          child: Selector<SettingState, Tuple2<bool?, int?>>(
            selector: (_, settings) =>
                Tuple2(settings.autoUpdate, settings.updateInterval),
            builder: (_, data, __) => Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(70, 20, 70, 10),
                  child: Text(s.settingsSyncing,
                      style: context.textTheme.bodyText1!
                          .copyWith(color: context.accentColor)),
                ),
                ListTile(
                  onTap: () {
                    if (settings.autoUpdate!) {
                      settings.autoUpdate = false;
                      settings.cancelWork();
                    } else {
                      settings.autoUpdate = true;
                      settings.setWorkManager(data.item2);
                    }
                  },
                  contentPadding:
                      const EdgeInsets.only(left: 70.0, right: 20, bottom: 10),
                  title: Text(s.settingsEnableSyncing),
                  subtitle: Text(s.settingsEnableSyncingDes),
                  trailing: Transform.scale(
                    scale: 0.9,
                    child: Switch(
                        value: data.item1!,
                        onChanged: (boo) async {
                          settings.autoUpdate = boo;
                          if (boo) {
                            settings.setWorkManager(data.item2);
                          } else {
                            settings.cancelWork();
                          }
                        }),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 70.0, right: 20),
                  title: Text(s.settingsUpdateInterval),
                  subtitle: Text(s.settingsUpdateIntervalDes),
                  trailing: MyDropdownButton(
                      hint: Text(s.hoursCount(data.item2!)),
                      underline: Center(),
                      elevation: 1,
                      displayItemCount: 5,
                      value: data.item2,
                      onChanged: data.item1!
                          ? (dynamic value) async {
                              await settings.cancelWork();
                              settings.setWorkManager(value);
                            }
                          : (int i) {},
                      items: <int>[1, 2, 4, 8, 24, 48]
                          .map<DropdownMenuItem<int>>((e) {
                        return DropdownMenuItem<int>(
                            value: e, child: Text(s.hoursCount(e)));
                      }).toList()),
                ),
                Divider(height: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
