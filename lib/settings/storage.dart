import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../local_storage/key_value_storage.dart';
import '../settings/downloads_manage.dart';
import '../state/setting_state.dart';
import '../util/extension_helper.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/custom_widget.dart';
import '../widgets/general_dialog.dart';

class StorageSetting extends StatefulWidget {
  @override
  _StorageSettingState createState() => _StorageSettingState();
}

class _StorageSettingState extends State<StorageSetting>
    with SingleTickerProviderStateMixin {
  final KeyValueStorage cacheStorage = KeyValueStorage(cacheMaxKey);
  AnimationController? _controller;
  late Animation<double> _animation;
  List<String>? _dirs;

  late double _value;

  @override
  void initState() {
    super.initState();
    _value = 100;
    _getCacheMax();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    var settings = Provider.of<SettingState>(context, listen: false);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.overlay,
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          title: Text(s.settingStorage),
          leading: CustomBackButton(),
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(10.0),
                ),
                Container(
                  height: 30.0,
                  padding: EdgeInsets.symmetric(horizontal: 70),
                  alignment: Alignment.centerLeft,
                  child: Text(s.network,
                      style: context.textTheme.bodyText1!
                          .copyWith(color: context.accentColor)),
                ),
                Selector<SettingState, bool?>(
                  selector: (_, settings) => settings.downloadUsingData,
                  builder: (_, data, __) {
                    return ListTile(
                      onTap: () => settings.downloadUsingData = !data!,
                      contentPadding: EdgeInsets.only(
                          left: 70.0, right: 25, bottom: 10, top: 10),
                      title: Text(s.settingsNetworkCellular),
                      subtitle: Text(s.settingsNetworkCellularDes),
                      trailing: Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: data!,
                          onChanged: (value) =>
                              settings.downloadUsingData = value,
                        ),
                      ),
                    );
                  },
                ),
                FutureBuilder<bool>(
                    future: _getAutoDownloadNetwork(),
                    initialData: false,
                    builder: (context, snapshot) {
                      return ListTile(
                        onTap: () async {
                          _setAudtDownloadNetwork(!snapshot.data!);
                          setState(() {});
                        },
                        contentPadding: EdgeInsets.only(
                            left: 70.0, right: 25, bottom: 10, top: 10),
                        title: Text(s.settingsNetworkCellularAuto),
                        subtitle: Text(s.settingsNetworkCellularAutoDes),
                        trailing: Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: snapshot.data!,
                            onChanged: (value) async {
                              await _setAudtDownloadNetwork(value);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    }),
                Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(10.0),
                ),
                Container(
                  height: 30.0,
                  padding: EdgeInsets.symmetric(horizontal: 70),
                  alignment: Alignment.centerLeft,
                  child: Text(s.settingStorage,
                      style: context.textTheme.bodyText1!
                          .copyWith(color: context.accentColor)),
                ),
                ListTile(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DownloadsManage())),
                  contentPadding: EdgeInsets.symmetric(horizontal: 70.0),
                  title: Text(s.download),
                  subtitle: Text(s.settingsManageDownloadDes),
                ),
                FutureBuilder<int?>(
                    future: _getDownloadPasition(),
                    initialData: 0,
                    builder: (context, snapshot) {
                      return ListTile(
                        contentPadding: EdgeInsets.fromLTRB(70, 10, 20, 10),
                        title: Text(s.settingsDownloadPosition),
                        subtitle: Text(
                            _dirs == null ? '' : _dirs![snapshot.data!],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        onTap: () => generalSheet(
                          context,
                          title: s.settingsDownloadPosition,
                          child: Column(children: [
                            SizedBox(
                              height: 10,
                            ),
                            for (var dir in _dirs!)
                              ListTile(
                                title: Text(dir),
                                onTap: () =>
                                    _setDownloadPosition(_dirs!.indexOf(dir)),
                                trailing: Radio<int>(
                                    value: _dirs!.indexOf(dir),
                                    groupValue: snapshot.data,
                                    onChanged: _setDownloadPosition),
                              ),
                            SizedBox(
                              height: 30,
                            )
                          ]),
                        ),
                      );
                    }),
                FutureBuilder<int?>(
                  future: _getAutoDeleteDays(),
                  initialData: 30,
                  builder: (context, snapshot) {
                    return ListTile(
                      contentPadding: EdgeInsets.only(left: 70.0, right: 20),
                      title: Text(s.settingsAutoDelete),
                      subtitle: Text(s.settingsAutoDeleteDes),
                      trailing: MyDropdownButton(
                          hint: snapshot.data == -1
                              ? Text(s.daysCount(0))
                              : Text(s.daysCount(snapshot.data!)),
                          underline: Center(),
                          elevation: 1,
                          value: snapshot.data,
                          onChanged: (dynamic value) async {
                            await _setAutoDeleteDays(value);
                          },
                          items: <int>[-1, 5, 10, 15, 30]
                              .map<DropdownMenuItem<int>>((e) {
                            return DropdownMenuItem<int>(
                                value: e,
                                child: e == -1
                                    ? Text(s.daysCount(0))
                                    : Text(s.daysCount(e)));
                          }).toList()),
                    );
                  },
                ),
                FutureBuilder<bool>(
                    future: _getDelteAfterPlayed(),
                    initialData: false,
                    builder: (context, snapshot) {
                      return ListTile(
                        onTap: () async {
                          _setDeleteAfterPlayed(snapshot.data);
                          setState(() {});
                        },
                        contentPadding: EdgeInsets.only(left: 70.0, right: 25),
                        title: Text('Delete download after played'),
                        subtitle: Text('Delete after played'),
                        trailing: Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: snapshot.data!,
                            onChanged: (value) async {
                              await _setDeleteAfterPlayed(value);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    }),
                ListTile(
                  contentPadding: EdgeInsets.only(left: 70.0, right: 25),
                  //  leading: Icon(Icons.colorize),
                  title: Text(s.settingsAudioCache),
                  subtitle: Text(s.settingsAudioCacheDes),
                  trailing: Text.rich(TextSpan(
                      text: '${(_value ~/ 100) * 100}',
                      style: GoogleFonts.teko(
                          textStyle: context.textTheme.headline6!
                              .copyWith(color: context.accentColor)),
                      children: [
                        TextSpan(
                            text: ' Mb', style: context.textTheme.subtitle2),
                      ])),
                ),
                Padding(
                  padding:
                      EdgeInsets.only(left: 50.0, right: 20.0, bottom: 10.0),
                  child: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                        showValueIndicator: ShowValueIndicator.always,
                        trackHeight: 2,
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 6)),
                    child: Slider(
                        label: '${_value ~/ 100 * 100} Mb',
                        activeColor: context.accentColor,
                        inactiveColor: context.primaryColorDark,
                        value: _value,
                        min: 100,
                        max: 1000,
                        divisions: 9,
                        onChanged: (val) {
                          setState(() {
                            _value = val;
                          });
                          cacheStorage.saveInt((val * 1024 * 1024).toInt());
                        }),
                  ),
                ),
                Divider(height: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _getCacheMax() async {
    var cache =
        await cacheStorage.getInt(defaultValue: (200 * 1024 * 1024).toInt());
    if (cache == 0) {
      await cacheStorage.saveInt((200 * 1024 * 1024).toInt());
      cache = 200 * 1024 * 1024;
    }
    var value = cache ~/ (1024 * 1024);
    if (value > 100) {
      _controller = AnimationController(
          vsync: this, duration: Duration(milliseconds: value * 2));
      _animation = Tween<double>(begin: 100, end: value.toDouble()).animate(
          CurvedAnimation(curve: Curves.easeOutQuart, parent: _controller!))
        ..addListener(() {
          setState(() => _value = _animation.value);
        });
      _controller!.forward();
    }
  }

  Future<bool> _getAutoDownloadNetwork() async {
    var storage = KeyValueStorage(autoDownloadNetworkKey);
    var value = await storage.getBool(defaultValue: false);
    return value;
  }

  Future<int?> _getAutoDeleteDays() async {
    var storage = KeyValueStorage(autoDeleteKey);
    var days = await storage.getInt();
    if (days == 0) {
      storage.saveInt(30);
      return 30;
    }
    return days;
  }

  Future<int?> _getDownloadPasition() async {
    final storage = KeyValueStorage(downloadPositionKey);
    final index = await storage.getInt();
    final externalDirs = await getExternalStorageDirectories();
    _dirs = [for (var dir in externalDirs!) dir.path];
    return index;
  }

  Future<bool> _getDelteAfterPlayed() async {
    final storage = KeyValueStorage(deleteAfterPlayedKey);
    return await storage.getBool(defaultValue: false);
  }

  Future<void> _setAutoDeleteDays(int days) async {
    var storage = KeyValueStorage(autoDeleteKey);
    await storage.saveInt(days);
    setState(() {});
  }

  Future<void> _setAudtDownloadNetwork(bool boo) async {
    var storage = KeyValueStorage(autoDownloadNetworkKey);
    await storage.saveBool(boo);
  }

  Future<void> _setDownloadPosition(int? index) async {
    final storage = KeyValueStorage(downloadPositionKey);
    await storage.saveInt(index!);
  }

  Future<void> _setDeleteAfterPlayed(bool? boo) async {
    final storage = KeyValueStorage(deleteAfterPlayedKey);
    await storage.saveBool(boo);
  }
}
