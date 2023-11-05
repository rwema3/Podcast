import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html/parser.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../home/audioplayer.dart';
import '../local_storage/key_value_storage.dart';
import '../local_storage/sqflite_localpodcast.dart';
import '../state/audio_state.dart';
import '../state/download_state.dart';
import '../type/episodebrief.dart';
import '../type/fireside_data.dart';
import '../type/podcastlocal.dart';
import '../util/extension_helper.dart';
import '../widgets/audiopanel.dart';
import '../widgets/custom_widget.dart';
import '../widgets/episodegrid.dart';
import '../widgets/general_dialog.dart';
import '../widgets/muiliselect_bar.dart';
import 'podcast_settings.dart';

const String kDefaultAvatar = """http://xuanmei.us/assets/default/avatar_small-
170afdc2be97fc6148b283083942d82c101d4c1061f6b28f87c8958b52664af9.jpg""";

class PodcastDetail extends StatefulWidget {
  PodcastDetail({Key? key, required this.podcastLocal, this.hide = false})
      : super(key: key);
  final PodcastLocal? podcastLocal;
  final bool hide;
  @override
  _PodcastDetailState createState() => _PodcastDetailState();
}

class _PodcastDetailState extends State<PodcastDetail> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  final GlobalKey<AudioPanelState> _playerKey = GlobalKey<AudioPanelState>();
  final _dbHelper = DBHelper();

  /// Episodes total count.
  int? _episodeCount;

  /// Default layout.
  Layout? _layout;

  /// If true, stop grid load animation.
  bool _scroll = false;

  double _topHeight = 0;

  late ScrollController _controller;

  /// Episodes num load first time.
  int _top = 96;
  int _dataCount = 0;

  /// Load more episodes when scroll to bottom.
  bool _loadMore = false;

  /// Change sort by.
  bool _reverse = false;

  /// Filter type.
  Filter _filter = Filter.all;

  /// Query string
  String _query = '';

  ///Hide listened.
  bool? _hideListened;

  ///Selected episode list.
  List<EpisodeBrief>? _selectedEpisodes;

  ///Toggle for multi-select.
  bool? _multiSelect;
  bool? _selectAll;
  late bool _selectBefore;
  late bool _selectAfter;

  ///Show podcast info.
  bool? _showInfo;

  @override
  void initState() {
    super.initState();
    _loadMore = false;
    _reverse = false;
    _controller = ScrollController();
    _scroll = false;
    _multiSelect = false;
    _selectAll = false;
    _selectAfter = false;
    _selectBefore = false;
    _showInfo = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _updateRssItem(
      BuildContext context, PodcastLocal podcastLocal) async {
    final result = await _dbHelper.updatePodcastRss(podcastLocal);
    if (result >= 0) {
      Fluttertoast.showToast(
        msg: context.s.updateEpisodesCount(result),
        gravity: ToastGravity.TOP,
      );
    }
    if (result > 0) {
      final autoDownload = await _dbHelper.getAutoDownload(podcastLocal.id);
      if (autoDownload) {
        final downloader = Provider.of<DownloadState>(context, listen: false);
        final result = await Connectivity().checkConnectivity();
        final autoDownloadStorage = KeyValueStorage(autoDownloadNetworkKey);
        final autoDownloadNetwork = await autoDownloadStorage.getInt();
        if (autoDownloadNetwork == 1) {
          var episodes = await _dbHelper.getNewEpisodes(podcastLocal.id);
          // For safety
          if (episodes.length < 100) {
            for (var episode in episodes) {
              downloader.startTask(episode, showNotification: false);
            }
          }
        } else if (result == ConnectivityResult.wifi) {
          var episodes = await _dbHelper.getNewEpisodes(podcastLocal.id);
          //For safety
          if (episodes.length < 100) {
            for (var episode in episodes) {
              downloader.startTask(episode, showNotification: false);
            }
          }
        }
      }
    } else if (result != 0) {
      Fluttertoast.showToast(
        msg: context.s.updateFailed,
        gravity: ToastGravity.TOP,
      );
    }
    if (mounted && result > 0) setState(() {});
  }

  Future<List<EpisodeBrief>> _getRssItem(PodcastLocal podcastLocal,
      {int? count, bool? reverse, Filter? filter, String? query}) async {
    var episodes = <EpisodeBrief>[];
    _episodeCount = await _dbHelper.getPodcastCounts(podcastLocal.id);
    final layoutStorage = KeyValueStorage(podcastLayoutKey);
    final hideListenedStorage = KeyValueStorage(hideListenedKey);
    final index = await layoutStorage.getInt(defaultValue: 1);
    if (_layout == null) _layout = Layout.values[index];
    if (_hideListened == null) {
      _hideListened = await hideListenedStorage.getBool(defaultValue: false);
    }
    episodes = await _dbHelper.getRssItem(podcastLocal.id, count,
        reverse: reverse,
        filter: filter,
        query: query,
        hideListened: _hideListened!);
    _dataCount = episodes.length;
    return episodes;
  }

  Future<Tuple2<String?, List<PodcastHost>?>> _getHosts(
      PodcastLocal podcastLocal) async {
    if (!podcastLocal.provider!.contains('fireside')) return Tuple2('', []);
    var data = FiresideData(podcastLocal.id, podcastLocal.link);
    await data.getData();
    var backgroundImage = data.background;
    var hosts = data.hosts;
    return Tuple2(backgroundImage, hosts);
  }

  Future<int?> _getLayout() async {
    var storage = KeyValueStorage(podcastLayoutKey);
    var index = await storage.getInt(defaultValue: 1);
    return index;
  }

  Future<bool> _getHideListened() async {
    var hideListenedStorage = KeyValueStorage(hideListenedKey);
    var hideListened = await hideListenedStorage.getBool(defaultValue: false);
    return hideListened;
  }

  Future<void> _checkPodcast() async {
    final exist = await _dbHelper.checkPodcast(widget.podcastLocal!.rssUrl);
    if (exist == '') {
      Navigator.of(context).pop();
    }
  }

  Future<int?> _getNewCount() async {
    return await _dbHelper.getPodcastUpdateCounts(widget.podcastLocal!.id);
  }

  Future<void> _removePodcastNewMark() async {
    await _dbHelper.removePodcastNewMark(widget.podcastLocal!.id);
  }

  Widget _podcastInfo(BuildContext context) {
    return Container(
      height: 170,
      padding: EdgeInsets.only(top: 50, left: 80, right: 130),
      alignment: Alignment.topLeft,
      child: Text(
        widget.podcastLocal!.title!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.headline5!.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _podcastLink(
      {required String title,
      Widget? child,
      VoidCallback? onTap,
      required Color backgroundColor}) {
    return Container(
      padding: EdgeInsets.fromLTRB(5, 10, 5, 0),
      width: 60.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: CircleAvatar(
              radius: 20,
              child: child,
              backgroundColor: backgroundColor.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: context.textTheme.subtitle2,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.fade,
          ),
        ],
      ),
    );
  }

  Widget _hostsList(BuildContext context, PodcastLocal podcastLocal) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FutureBuilder<Tuple2<String?, List<PodcastHost>?>>(
            future: _getHosts(podcastLocal),
            builder: (context, snapshot) {
              return Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _podcastLink(
                            title: 'Link',
                            child: Icon(Icons.link, size: 30),
                            backgroundColor: Colors.green[600]!,
                            onTap: () => widget.podcastLocal!.link!.launchUrl),
                        _podcastLink(
                            title: 'Rss',
                            child: Icon(LineIcons.rssSquare, size: 30),
                            backgroundColor: Colors.blue[600]!,
                            onTap: () => widget.podcastLocal!.rssUrl.launchUrl),
                        if (widget.podcastLocal!.funding.isNotEmpty)
                          for (var funding in widget.podcastLocal!.funding)
                            _podcastLink(
                                title: 'Donate',
                                child: Icon(
                                    funding.contains(
                                      'paypal',
                                    )
                                        ? LineIcons.paypal
                                        : LineIcons.donate,
                                    size: 30),
                                backgroundColor: Colors.red[600]!,
                                onTap: () => funding.launchUrl),
                        if (snapshot.hasData)
                          ...snapshot.data!.item2!
                              .map<Widget>((host) {
                                final image = host.image == kDefaultAvatar
                                    ? kDefaultAvatar
                                    : host.image;
                                return Container(
                                  padding: EdgeInsets.fromLTRB(5, 10, 5, 0),
                                  width: 60.0,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CachedNetworkImage(
                                        imageUrl: image!,
                                        progressIndicatorBuilder:
                                            (context, url, downloadProgress) =>
                                                CircleAvatar(
                                          backgroundColor: Colors.cyan[600]!
                                              .withOpacity(0.5),
                                          child: SizedBox(
                                            width: 30,
                                            height: 2,
                                            child: LinearProgressIndicator(
                                                value:
                                                    downloadProgress.progress),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            CircleAvatar(
                                          backgroundColor: Colors.grey[400],
                                          backgroundImage:
                                              AssetImage('assets/fireside.jpg'),
                                        ),
                                        imageBuilder: (context, hostImage) =>
                                            CircleAvatar(
                                                backgroundColor:
                                                    Colors.grey[400],
                                                backgroundImage: hostImage),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        host.name!,
                                        style: context.textTheme.subtitle2,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.fade,
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList()
                              .cast<Widget>()
                      ]),
                ),
              );
            }),
        Container(
          padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
          alignment: Alignment.topLeft,
          color: context.background,
          child: AboutPodcast(podcastLocal: widget.podcastLocal),
        ),
      ],
    );
  }

  Widget _customPopupMenu({
    Widget? child,
    String? tooltip,
    List<PopupMenuEntry<int>>? itemBuilder,
    Function(int)? onSelected,
  }) =>
      Material(
        key: UniqueKey(),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.hardEdge,
        child: PopupMenuButton<int>(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
          tooltip: tooltip,
          child: child,
          itemBuilder: (context) => itemBuilder!,
          onSelected: (value) => onSelected!(value),
        ),
      );

  Widget _actionBar(BuildContext context) {
    final s = context.s;
    return SizedBox(
        height: 30,
        child: Row(
          children: <Widget>[
            SizedBox(width: 15),
            _customPopupMenu(
                tooltip: s.filter,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: context.primaryColorDark)),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(s.filter),
                      SizedBox(width: 5),
                      Icon(
                        LineIcons.filter,
                        color:
                            _filter != Filter.all ? context.accentColor : null,
                        size: 18,
                      )
                    ],
                  ),
                ),
                itemBuilder: [
                  PopupMenuItem(
                    value: 0,
                    child: Row(
                      children: [
                        Text(s.all),
                        Spacer(),
                        if (_filter == Filter.all) DotIndicator(),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        Text(s.homeTabMenuFavotite),
                        Spacer(),
                        if (_filter == Filter.liked) DotIndicator()
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Text(s.downloaded),
                        Spacer(),
                        if (_filter == Filter.downloaded) DotIndicator()
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 3,
                    child: Container(
                      padding:
                          EdgeInsets.only(top: 5, bottom: 5, left: 2, right: 2),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              width: 2,
                              color: context.textColor.withOpacity(0.2))),
                      child: _query == ''
                          ? Row(
                              children: [
                                Text(
                                  s.search,
                                  style: TextStyle(
                                    color: context.textColor.withOpacity(0.4),
                                  ),
                                ),
                                Spacer()
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Text(_query,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: context.accentColor)),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 0:
                      if (_filter != Filter.all) {
                        setState(() {
                          _filter = Filter.all;
                          _query = '';
                        });
                      }
                      break;
                    case 1:
                      if (_filter != Filter.liked) {
                        setState(() {
                          _query = '';
                          _filter = Filter.liked;
                        });
                      }
                      break;
                    case 2:
                      if (_filter != Filter.downloaded) {
                        setState(() {
                          _query = '';
                          _filter = Filter.downloaded;
                        });
                      }
                      break;
                    case 3:
                      showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: MaterialLocalizations.of(context)
                              .modalBarrierDismissLabel,
                          barrierColor: Colors.black54,
                          transitionDuration: const Duration(milliseconds: 200),
                          pageBuilder:
                              (context, animaiton, secondaryAnimation) =>
                                  SearchEpisode(
                                    onSearch: (query) {
                                      setState(() {
                                        if (query != null && query != '') {
                                          _query = query;
                                          _filter = Filter.search;
                                        }
                                      });
                                    },
                                  ));
                      break;
                    default:
                  }
                }),
            Spacer(),
            FutureBuilder<int?>(
                future: _getNewCount(),
                initialData: 0,
                builder: (context, snapshot) {
                  return snapshot.data != 0
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: Colors.transparent,
                            clipBehavior: Clip.hardEdge,
                            borderRadius: BorderRadius.circular(100),
                            child: SizedBox(
                              width: 30,
                              child: IconButton(
                                  padding: EdgeInsets.only(bottom: 5),
                                  tooltip: s.removeNewMark,
                                  icon: Container(
                                      height: 18,
                                      width: 18,
                                      child: CustomPaint(
                                          painter: RemoveNewFlagPainter(
                                              context
                                                  .textTheme.bodyText1!.color,
                                              Colors.red))),
                                  onPressed: () async {
                                    await _removePodcastNewMark();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  }),
                            ),
                          ),
                        )
                      : Center();
                }),
            if (!widget.hide)
              Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.hardEdge,
                  borderRadius: BorderRadius.circular(100),
                  child: TweenAnimationBuilder(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOutQuart,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, dynamic angle, child) =>
                        Transform.rotate(
                      angle: math.pi * 2 * angle,
                      child: SizedBox(
                        width: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: s.homeSubMenuSortBy,
                          icon: Icon(
                            _reverse
                                ? LineIcons.hourglassStart
                                : LineIcons.hourglassEnd,
                            color: _reverse ? context.accentColor : null,
                          ),
                          iconSize: 18,
                          onPressed: () {
                            setState(() => _reverse = !_reverse);
                          },
                        ),
                      ),
                    ),
                  )),
            FutureBuilder<bool>(
                future: _getHideListened(),
                builder: (context, snapshot) {
                  if (_hideListened == null) {
                    _hideListened = snapshot.data;
                  }
                  return Material(
                      color: Colors.transparent,
                      clipBehavior: Clip.hardEdge,
                      borderRadius: BorderRadius.circular(100),
                      child: IconButton(
                        icon: SizedBox(
                          width: 30,
                          height: 30,
                          child: HideListened(
                            hideListened: _hideListened ?? false,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _hideListened = !_hideListened!);
                        },
                      ));
                }),
            FutureBuilder<int?>(
                future: _getLayout(),
                builder: (context, snapshot) {
                  if (_layout == null && snapshot.data != null) {
                    _layout = Layout.values[snapshot.data!];
                  }
                  return Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(100),
                    child: LayoutButton(
                      layout: _layout ?? Layout.two,
                      onPressed: (layout) => setState(() {
                        _layout = layout;
                      }),
                    ),
                  );
                }),
            Material(
                color: Colors.transparent,
                clipBehavior: Clip.hardEdge,
                borderRadius: BorderRadius.circular(100),
                child: IconButton(
                  icon: SizedBox(
                    width: 20,
                    height: 10,
                    child: CustomPaint(
                        painter:
                            MultiSelectPainter(color: context.accentColor)),
                  ),
                  onPressed: () {
                    setState(() {
                      _top = -1;
                      _selectedEpisodes = [];
                      _multiSelect = true;
                    });
                  },
                )),
            SizedBox(width: 10)
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.podcastLocal!.primaryColor!.colorizedark();
    final s = context.s;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: color, statusBarIconBrightness: Brightness.light),
      child: WillPopScope(
        onWillPop: () {
          if (_playerKey.currentState != null &&
              _playerKey.currentState!.initSize! > 100) {
            _playerKey.currentState!.backToMini();
            return Future.value(false);
          } else {
            return Future.value(true);
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              displacement: context.paddingTop + 40,
              color: context.accentColor,
              onRefresh: () async {
                await _updateRssItem(context, widget.podcastLocal!);
              },
              child: Stack(
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: NoGrowBehavior(),
                          child: CustomScrollView(
                            controller: _controller
                              ..addListener(() async {
                                if (_controller.offset ==
                                        _controller.position.maxScrollExtent &&
                                    _dataCount == _top) {
                                  if (mounted) {
                                    setState(() => _loadMore = true);
                                  }
                                  await Future.delayed(Duration(seconds: 3));
                                  if (mounted && _loadMore) {
                                    setState(() {
                                      _top = _top + 36;
                                      _loadMore = false;
                                    });
                                  }
                                }
                                if (_controller.offset > 0 &&
                                    mounted &&
                                    !_scroll) {
                                  setState(() => _scroll = true);
                                }
                              }),
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: <Widget>[
                              SliverAppBar(
                                actions: <Widget>[
                                  IconButton(
                                    icon: Icon(Icons.more_vert),
                                    splashRadius: 20,
                                    tooltip: s.menu,
                                    onPressed: () => generalSheet(
                                      context,
                                      title: widget.podcastLocal!.title,
                                      child: PodcastSetting(
                                          podcastLocal: widget.podcastLocal),
                                    ).then((value) {
                                      _checkPodcast();
                                      if (mounted) setState(() {});
                                    }),
                                  ),
                                ],
                                elevation: 0,
                                scrolledUnderElevation: 0,
                                iconTheme: IconThemeData(
                                  color: Colors.white,
                                ),
                                expandedHeight:
                                    math.max(130 + context.paddingTop, 180),
                                backgroundColor: color,
                                floating: true,
                                pinned: true,
                                leading: CustomBackButton(),
                                flexibleSpace: LayoutBuilder(
                                    builder: (context, constraints) {
                                  _topHeight = constraints.biggest.height;
                                  return FlexibleSpaceBar(
                                    background: Stack(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.only(
                                              top: 120 + context.paddingTop),
                                          child: InkWell(
                                            onTap: () => setState(
                                                () => _showInfo = !_showInfo!),
                                            child: Container(
                                              padding: EdgeInsets.only(
                                                  left: 80, right: 130),
                                              color: Colors.white10,
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Text(
                                                            widget.podcastLocal!
                                                                    .author ??
                                                                '',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        if (widget
                                                            .podcastLocal!
                                                            .provider!
                                                            .isNotEmpty)
                                                          Text(
                                                            s.hostedOn(widget
                                                                .podcastLocal!
                                                                .provider!),
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  UpDownIndicator(
                                                      status: _showInfo,
                                                      color: Colors.white),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          alignment: Alignment.bottomRight,
                                          padding: EdgeInsets.only(
                                              right: 20, bottom: 10),
                                          child: Container(
                                            height: 100,
                                            width: 100,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: Image.file(
                                              File(
                                                  "${widget.podcastLocal!.imagePath}"),
                                              errorBuilder: (context, _, __) {
                                                return ColoredBox(
                                                    color: color,
                                                    child: Icon(Icons.error));
                                              },
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.center,
                                          child: _podcastInfo(context),
                                        ),
                                      ],
                                    ),
                                    title: _topHeight < 70 + context.paddingTop
                                        ? SizedBox(
                                            width: context.width * 4 / 5,
                                            child: Text(
                                                widget.podcastLocal!.title!,
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          )
                                        : Center(),
                                  );
                                }),
                              ),
                              SliverToBoxAdapter(
                                child: _showInfo!
                                    ? _hostsList(context, widget.podcastLocal!)
                                    : SizedBox(height: 10),
                              ),
                              SliverToBoxAdapter(
                                  child: _multiSelect!
                                      ? Center()
                                      : _actionBar(context)),
                              if (!widget.hide)
                                FutureBuilder<List<EpisodeBrief>>(
                                    future: _getRssItem(widget.podcastLocal!,
                                        count: _top,
                                        reverse: _reverse,
                                        filter: _filter,
                                        query: _query),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        if (_selectAll!) {
                                          _selectedEpisodes = snapshot.data;
                                        }
                                        if (_selectBefore) {
                                          final index = snapshot.data!.indexOf(
                                              _selectedEpisodes!.first);
                                          if (index != 0) {
                                            _selectedEpisodes = snapshot.data!
                                                .sublist(0, index + 1);
                                          }
                                        }
                                        if (_selectAfter) {
                                          final index = snapshot.data!.indexOf(
                                              _selectedEpisodes!.first);
                                          _selectedEpisodes =
                                              snapshot.data!.sublist(index);
                                        }
                                        return EpisodeGrid(
                                          episodes: snapshot.data,
                                          showFavorite: true,
                                          showNumber: _filter == Filter.all &&
                                                  !_hideListened!
                                              ? true
                                              : false,
                                          layout: _layout,
                                          reverse: _reverse,
                                          episodeCount: _episodeCount,
                                          initNum: _scroll ? 0 : 12,
                                          multiSelect: _multiSelect,
                                          selectedList: _selectedEpisodes ?? [],
                                          onSelect: (value) => setState(() {
                                            _selectAll = false;
                                            _selectBefore = false;
                                            _selectAfter = false;
                                            _selectedEpisodes = value;
                                          }),
                                        );
                                      }
                                      return SliverToBoxAdapter(
                                          child: Center());
                                    }),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return _loadMore
                                        ? Container(
                                            height: 2,
                                            child: LinearProgressIndicator())
                                        : Center();
                                  },
                                  childCount: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Selector<AudioPlayerNotifier,
                              Tuple2<bool, PlayerHeight?>>(
                          selector: (_, audio) =>
                              Tuple2(audio.playerRunning, audio.playerHeight),
                          builder: (_, data, __) {
                            var height = kMinPlayerHeight[data.item2!.index];
                            return Column(
                              children: [
                                if (_multiSelect!)
                                  MultiSelectMenuBar(
                                    selectedList: _selectedEpisodes,
                                    selectAll: _selectAll,
                                    onSelectAll: (value) {
                                      setState(() {
                                        _selectAll = value;
                                        _selectAfter = false;
                                        _selectBefore = false;
                                        if (!value) {
                                          _selectedEpisodes = [];
                                        }
                                      });
                                    },
                                    onSelectAfter: (value) {
                                      setState(() {
                                        _selectBefore = false;
                                        _selectAfter = true;
                                      });
                                    },
                                    onSelectBefore: (value) {
                                      setState(() {
                                        _selectAfter = false;
                                        _selectBefore = true;
                                      });
                                    },
                                    onClose: (value) {
                                      setState(() {
                                        if (value) {
                                          _multiSelect = false;
                                          _selectAll = false;
                                          _selectAfter = false;
                                          _selectBefore = false;
                                        }
                                      });
                                    },
                                  ),
                                SizedBox(
                                  height: data.item1 ? height : 0,
                                ),
                              ],
                            );
                          }),
                    ],
                  ),
                  Container(
                      child: PlayerWidget(
                    playerKey: _playerKey,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutPodcast extends StatefulWidget {
  final PodcastLocal? podcastLocal;
  AboutPodcast({this.podcastLocal, Key? key}) : super(key: key);

  @override
  _AboutPodcastState createState() => _AboutPodcastState();
}

class _AboutPodcastState extends State<AboutPodcast> {
  late String _description;
  late bool _load;

  @override
  void initState() {
    super.initState();
    _load = false;
    getDescription(widget.podcastLocal!.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_load)
      return Linkify(
        text: _description,
        onOpen: (link) {
          link.url!.launchUrl;
        },
        linkStyle: TextStyle(
            color: context.accentColor,
            decoration: TextDecoration.underline,
            textBaseline: TextBaseline.ideographic),
      );
    return Center();
  }

  void getDescription(String? id) async {
    final dbHelper = DBHelper();
    final description = await dbHelper.getFeedDescription(id);
    if (description == null || description.isEmpty) {
      _description = '';
    } else {
      final doc = parse(description);
      _description = parse(doc.body!.text).documentElement!.text;
    }
    if (mounted) setState(() => _load = true);
  }
}

class SearchEpisode extends StatefulWidget {
  SearchEpisode({this.onSearch, Key? key}) : super(key: key);
  final ValueChanged<String?>? onSearch;
  @override
  _SearchEpisodeState createState() => _SearchEpisodeState();
}

class _SearchEpisodeState extends State<SearchEpisode> {
  TextEditingController? _controller;
  String? _query;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor:
            Theme.of(context).brightness == Brightness.light
                ? Color.fromRGBO(113, 113, 113, 1)
                : Color.fromRGBO(5, 5, 5, 1),
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        elevation: 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        titlePadding: const EdgeInsets.all(20),
        actionsPadding: EdgeInsets.zero,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              s.cancel,
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              if ((_query ?? '').isNotEmpty) {
                widget.onSearch!(_query);
                Navigator.of(context).pop();
              }
            },
            child:
                Text(s.confirm, style: TextStyle(color: context.accentColor)),
          )
        ],
        title: SizedBox(width: context.width - 160, child: Text(s.search)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                hintText: s.searchEpisode,
                hintStyle: TextStyle(fontSize: 18),
                filled: true,
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: context.accentColor, width: 2.0),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: context.accentColor, width: 2.0),
                ),
              ),
              cursorRadius: Radius.circular(2),
              autofocus: true,
              maxLines: 1,
              controller: _controller,
              onChanged: (value) {
                setState(() => _query = value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
