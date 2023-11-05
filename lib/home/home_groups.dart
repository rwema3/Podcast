import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:focused_menu/focused_menu.dart';
import 'package:focused_menu/modals.dart';
import 'package:line_icons/line_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart' as tuple;

import '../episodes/episode_detail.dart';
import '../local_storage/key_value_storage.dart';
import '../local_storage/sqflite_localpodcast.dart';
import '../podcasts/podcast_detail.dart';
import '../podcasts/podcast_manage.dart';
import '../podcasts/podcastlist.dart';
import '../state/audio_state.dart';
import '../state/download_state.dart';
import '../state/podcast_group.dart';
import '../state/refresh_podcast.dart';
import '../state/setting_state.dart';
import '../type/episodebrief.dart';
import '../type/play_histroy.dart';
import '../type/podcastlocal.dart';
import '../util/extension_helper.dart';
import '../util/hide_player_route.dart';
import '../util/pageroute.dart';
import '../widgets/custom_widget.dart';
import '../widgets/general_dialog.dart';

class ScrollPodcasts extends StatefulWidget {
  @override
  _ScrollPodcastsState createState() => _ScrollPodcastsState();
}

class _ScrollPodcastsState extends State<ScrollPodcasts>
    with SingleTickerProviderStateMixin {
  int _groupIndex = 0;
  late AnimationController _controller;
  late TweenSequence _slideTween;
  TweenSequence<double> _getSlideTween(double value) => TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: value), weight: 3 / 5),
        TweenSequenceItem(tween: ConstantTween<double>(value), weight: 1 / 5),
        TweenSequenceItem(
            tween: Tween<double>(begin: -value, end: 0), weight: 1 / 5)
      ]);

  @override
  void initState() {
    super.initState();
    _groupIndex = 0;
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 150))
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _controller.reset();
          });
    _slideTween = _getSlideTween(0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final s = context.s;
    return Selector2<GroupList, RefreshWorker,
        tuple.Tuple3<List<PodcastGroup?>, bool, bool>>(
      selector: (_, groupList, refreshWorker) => tuple.Tuple3(
          groupList.groups, groupList.created, refreshWorker.created),
      builder: (_, data, __) {
        final groups = data.item1;
        final import = data.item2;
        if (groups.isEmpty) {
          return SizedBox(
            height: (width - 20) / 3 + 140,
          );
        }
        if (groups[_groupIndex]!.podcastList.length == 0) {
          return SizedBox(
            height: (width - 20) / 3 + 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onVerticalDragEnd: (event) {
                    if (event.primaryVelocity! > 200) {
                      if (groups.length == 1) {
                        Fluttertoast.showToast(
                          msg: s.addSomeGroups,
                          gravity: ToastGravity.BOTTOM,
                        );
                      } else {
                        if (mounted) {
                          setState(() {
                            (_groupIndex != 0)
                                ? _groupIndex--
                                : _groupIndex = groups.length - 1;
                          });
                        }
                      }
                    } else if (event.primaryVelocity! < -200) {
                      if (groups.length == 1) {
                        Fluttertoast.showToast(
                          msg: s.addSomeGroups,
                          gravity: ToastGravity.BOTTOM,
                        );
                      } else {
                        if (mounted) {
                          setState(
                            () {
                              (_groupIndex < groups.length - 1)
                                  ? _groupIndex++
                                  : _groupIndex = 0;
                            },
                          );
                        }
                      }
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 30,
                        child: Row(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 15.0),
                              child: Text(
                                groups[_groupIndex]!.name!,
                                style: context.textTheme.bodyText1!
                                    .copyWith(color: context.accentColor),
                              ),
                            ),
                            Spacer(),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 15),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () {
                                  if (!import) {
                                    Navigator.push(
                                      context,
                                      SlideLeftRoute(
                                        page: context
                                                .read<SettingState>()
                                                .openAllPodcastDefalt!
                                            ? PodcastList()
                                            : PodcastManage(),
                                      ),
                                    );
                                  }
                                },
                                onLongPress: () {
                                  if (!import) {
                                    Navigator.push(
                                      context,
                                      SlideLeftRoute(page: PodcastList()),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: Text(
                                    s.homeGroupsSeeAll,
                                    style:
                                        context.textTheme.bodyText1!.copyWith(
                                      color: import
                                          ? context.primaryColorDark
                                          : context.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                          height: 70,
                          color: context.background,
                          child: Row(
                            children: <Widget>[
                              _circleContainer(context),
                              _circleContainer(context),
                              _circleContainer(context)
                            ],
                          )),
                    ],
                  ),
                ),
                Container(
                  height: (width - 20) / 3 + 40,
                  color: context.background,
                  margin: EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                      child: _groupIndex == 0
                          ? Text.rich(TextSpan(
                              style: context.textTheme.headline6!
                                  .copyWith(height: 2),
                              children: [
                                TextSpan(
                                    text: 'Welcome to Tsacdop\n',
                                    style: context.textTheme.headline6!
                                        .copyWith(color: context.accentColor)),
                                TextSpan(
                                    text: 'Get started\n',
                                    style: context.textTheme.headline6!
                                        .copyWith(color: context.accentColor)),
                                TextSpan(text: 'Tap '),
                                WidgetSpan(
                                    child: Icon(Icons.add_circle_outline)),
                                TextSpan(text: ' to search podcasts')
                              ],
                            ))
                          : Text(s.noPodcastGroup,
                              style: TextStyle(
                                  color: context.textTheme.bodyText2!.color!
                                      .withOpacity(0.5)))),
                ),
              ],
            ),
          );
        }
        return DefaultTabController(
          length: groups[_groupIndex]!.podcasts.length,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onVerticalDragEnd: (event) async {
                  if (event.primaryVelocity! > 200) {
                    if (groups.length == 1) {
                      Fluttertoast.showToast(
                        msg: s.addSomeGroups,
                        gravity: ToastGravity.BOTTOM,
                      );
                    } else {
                      if (mounted) {
                        setState(() => _slideTween = _getSlideTween(20));
                        _controller.forward();
                        await Future.delayed(Duration(milliseconds: 50));
                        if (mounted) {
                          setState(() {
                            (_groupIndex != 0)
                                ? _groupIndex--
                                : _groupIndex = groups.length - 1;
                          });
                        }
                      }
                    }
                  } else if (event.primaryVelocity! < -200) {
                    if (groups.length == 1) {
                      Fluttertoast.showToast(
                        msg: s.addSomeGroups,
                        gravity: ToastGravity.BOTTOM,
                      );
                    } else {
                      setState(() => _slideTween = _getSlideTween(-20));
                      await Future.delayed(Duration(milliseconds: 50));
                      _controller.forward();
                      if (mounted) {
                        setState(() {
                          (_groupIndex < groups.length - 1)
                              ? _groupIndex++
                              : _groupIndex = 0;
                        });
                      }
                    }
                  }
                },
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: <Widget>[
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15.0),
                              child: Text(
                                groups[_groupIndex]!.name!,
                                style: context.textTheme.bodyText1!
                                    .copyWith(color: context.accentColor),
                              )),
                          Spacer(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: InkWell(
                              onTap: () {
                                if (!import) {
                                  Navigator.push(
                                    context,
                                    SlideLeftRoute(
                                        page: context
                                                .read<SettingState>()
                                                .openAllPodcastDefalt!
                                            ? PodcastList()
                                            : PodcastManage()),
                                  );
                                }
                              },
                              onLongPress: () {
                                if (!import) {
                                  Navigator.push(
                                    context,
                                    SlideLeftRoute(page: PodcastList()),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(5),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Text(
                                  s.homeGroupsSeeAll,
                                  style: context.textTheme.bodyText1!.copyWith(
                                      color: import
                                          ? context.primaryColorDark
                                          : context.accentColor),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Container(
                      height: 70,
                      width: width,
                      alignment: Alignment.centerLeft,
                      color: context.background,
                      child: TabBar(
                        labelPadding: EdgeInsets.fromLTRB(6.0, 5.0, 6.0, 10.0),
                        indicator: CircleTabIndicator(
                            color: context.accentColor, radius: 3),
                        isScrollable: true,
                        tabs: groups[_groupIndex]!
                            .podcasts
                            .map<Widget>((podcastLocal) {
                          final color = podcastLocal.backgroudColor(context);
                          return Tab(
                            child: Transform.translate(
                              offset: Offset(
                                  0, _slideTween.animate(_controller).value),
                              child: LimitedBox(
                                maxHeight: 50,
                                maxWidth: 50,
                                child: CircleAvatar(
                                    backgroundColor: color.withOpacity(0.5),
                                    backgroundImage: podcastLocal.avatarImage,
                                    child: _updateIndicator(podcastLocal)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: (width - 20) / 3 + 40,
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBarView(
                  children: groups[_groupIndex]!.podcasts.map<Widget>(
                    (podcastLocal) {
                      return Container(
                        decoration: BoxDecoration(
                            color: context.brightness == Brightness.light
                                ? context.primaryColor
                                : Colors.black12),
                        margin: EdgeInsets.symmetric(horizontal: 5.0),
                        key: ObjectKey(podcastLocal.title),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                HidePlayerRoute(
                                  PodcastDetail(
                                    podcastLocal: podcastLocal,
                                  ),
                                  PodcastDetail(
                                      podcastLocal: podcastLocal, hide: true),
                                  duration: Duration(milliseconds: 300),
                                ),
                              );
                            },
                            child: PodcastPreview(
                              podcastLocal: podcastLocal,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _getPodcastUpdateCounts(String? id) async {
    final dbHelper = DBHelper();
    return await dbHelper.getPodcastUpdateCounts(id);
  }

  Widget _circleContainer(BuildContext context) => Container(
        margin: EdgeInsets.symmetric(horizontal: 10),
        height: 50,
        width: 50,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: context.primaryColor),
      );

  Widget _updateIndicator(PodcastLocal podcastLocal) => FutureBuilder<int?>(
        future: _getPodcastUpdateCounts(podcastLocal.id),
        initialData: 0,
        builder: (context, snapshot) {
          return snapshot.data! > 0
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    alignment: Alignment.center,
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                        color: Colors.red,
                        border:
                            Border.all(color: context.primaryColor, width: 2),
                        shape: BoxShape.circle),
                  ),
                )
              : Center();
        },
      );
}

class PodcastPreview extends StatefulWidget {
  final PodcastLocal? podcastLocal;

  PodcastPreview({this.podcastLocal, Key? key}) : super(key: key);

  @override
  _PodcastPreviewState createState() => _PodcastPreviewState();
}

class _PodcastPreviewState extends State<PodcastPreview> {
  Future? _getRssItem;

  @override
  void initState() {
    super.initState();
    _getRssItem = _getRssItemTop(widget.podcastLocal!);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.podcastLocal!.backgroudColor(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: Selector2<RefreshWorker, GroupList, tuple.Tuple2<bool, bool>>(
            selector: (_, refreshWorker, groupWorker) =>
                tuple.Tuple2(refreshWorker.created, groupWorker.created),
            builder: (_, data, __) {
              _getRssItem = _getRssItemTop(widget.podcastLocal!);
              return FutureBuilder<List<EpisodeBrief>>(
                future:
                    _getRssItem!.then((value) => value as List<EpisodeBrief>),
                builder: (context, snapshot) {
                  return (snapshot.hasData)
                      ? ShowEpisode(
                          episodes: snapshot.data,
                          podcastLocal: widget.podcastLocal,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(5.0),
                        );
                },
              );
            },
          ),
        ),
        Container(
          height: 40,
          padding: EdgeInsets.only(left: 10.0),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Text(
                  widget.podcastLocal!.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: c),
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<EpisodeBrief>> _getRssItemTop(PodcastLocal podcastLocal) async {
    final dbHelper = DBHelper();
    final episodes = await dbHelper.getRssItemTop(podcastLocal.id);
    return episodes;
  }
}

class ShowEpisode extends StatelessWidget {
  final List<EpisodeBrief>? episodes;
  final PodcastLocal? podcastLocal;
  final DBHelper _dbHelper = DBHelper();
  ShowEpisode({Key? key, this.episodes, this.podcastLocal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = context.width;
    final s = context.s;
    final audio = Provider.of<AudioPlayerNotifier>(context, listen: false);
    return CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      primary: false,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.all(5.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              childAspectRatio: 1.5,
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final c = podcastLocal!.backgroudColor(context);
                return Selector<AudioPlayerNotifier,
                    tuple.Tuple3<EpisodeBrief?, List<String>, bool>>(
                  selector: (_, audio) => tuple.Tuple3(
                      audio.episode,
                      audio.queue.episodes.map((e) => e!.enclosureUrl).toList(),
                      audio.playerRunning),
                  builder: (_, data, __) => FutureBuilder<
                      tuple.Tuple5<int, bool, bool, bool, List<int>>>(
                    future: _initData(episodes![index]),
                    initialData: tuple.Tuple5(0, false, false, false, []),
                    builder: (context, snapshot) {
                      final isListened = snapshot.data!.item1;
                      final isLiked = snapshot.data!.item2;
                      final isDownloaded = snapshot.data!.item3;
                      final tapToOpen = snapshot.data!.item4;
                      final menuList = snapshot.data!.item5;
                      return Align(
                        alignment: Alignment.center,
                        child: FocusedMenuHolder(
                          blurSize: 0.0,
                          menuItemExtent: 45,
                          menuBoxDecoration: BoxDecoration(
                            color: context.priamryContainer,
                            borderRadius: BorderRadius.all(
                              Radius.circular(15.0),
                            ),
                          ),
                          duration: Duration(milliseconds: 100),
                          tapMode:
                              tapToOpen ? TapMode.onTap : TapMode.onLongPress,
                          animateMenuItems: false,
                          blurBackgroundColor:
                              context.brightness == Brightness.light
                                  ? Colors.white38
                                  : Colors.black38,
                          bottomOffsetHeight: 10,
                          menuOffset: 6,
                          menuItems: <FocusedMenuItem>[
                            FocusedMenuItem(
                                backgroundColor: context.priamryContainer,
                                title: Text(data.item1 != episodes![index] ||
                                        !data.item3
                                    ? s.play
                                    : s.playing),
                                trailingIcon: Icon(
                                  LineIcons.playCircle,
                                  color: context.accentColor,
                                ),
                                onPressed: () {
                                  if (data.item1 != episodes![index] ||
                                      !data.item3) {
                                    audio.episodeLoad(episodes![index]);
                                  }
                                }),
                            if (menuList.contains(1))
                              FocusedMenuItem(
                                  backgroundColor: context.priamryContainer,
                                  title: data.item2.contains(
                                          episodes![index].enclosureUrl)
                                      ? Text(s.remove)
                                      : Text(s.later),
                                  trailingIcon: Icon(
                                    LineIcons.clock,
                                    color: Colors.cyan,
                                  ),
                                  onPressed: () {
                                    if (!data.item2.contains(
                                        episodes![index].enclosureUrl)) {
                                      audio.addToPlaylist(episodes![index]);
                                      Fluttertoast.showToast(
                                        msg: s.toastAddPlaylist,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    } else {
                                      audio.delFromPlaylist(episodes![index]);
                                      Fluttertoast.showToast(
                                        msg: s.toastRemovePlaylist,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    }
                                  }),
                            if (menuList.contains(2))
                              FocusedMenuItem(
                                  backgroundColor: context.priamryContainer,
                                  title:
                                      isLiked ? Text(s.unlike) : Text(s.like),
                                  trailingIcon: Icon(LineIcons.heart,
                                      color: Colors.red, size: 21),
                                  onPressed: () async {
                                    if (isLiked) {
                                      await _setUnliked(
                                          episodes![index].enclosureUrl);
                                      audio.setEpisodeState = true;
                                      Fluttertoast.showToast(
                                        msg: s.unliked,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    } else {
                                      await _saveLiked(
                                          episodes![index].enclosureUrl);
                                      audio.setEpisodeState = true;
                                      Fluttertoast.showToast(
                                        msg: s.liked,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    }
                                  }),
                            if (menuList.contains(3))
                              FocusedMenuItem(
                                  backgroundColor: context.priamryContainer,
                                  title: isListened > 0
                                      ? Text(s.listened,
                                          style: TextStyle(
                                              color: context.textColor
                                                  .withOpacity(0.5)))
                                      : Text(
                                          s.markListened,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  trailingIcon: SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CustomPaint(
                                        painter: ListenedAllPainter(Colors.blue,
                                            stroke: 1.5)),
                                  ),
                                  onPressed: () async {
                                    if (isListened < 1) {
                                      await _markListened(episodes![index]);
                                      audio.setEpisodeState = true;
                                      Fluttertoast.showToast(
                                        msg: s.markListened,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    }
                                  }),
                            if (menuList.contains(4))
                              FocusedMenuItem(
                                  backgroundColor: context.priamryContainer,
                                  title: isDownloaded
                                      ? Text(s.downloaded,
                                          style: TextStyle(
                                              color: context.textColor
                                                  .withOpacity(0.5)))
                                      : Text(s.download),
                                  trailingIcon: Icon(LineIcons.download,
                                      color: Colors.green),
                                  onPressed: () {
                                    if (!isDownloaded) {
                                      _requestDownload(context,
                                          episode: episodes![index]);
                                      //   downloader
                                      //       .startTask(episodes[index]);
                                    }
                                  }),
                            if (menuList.contains(5))
                              FocusedMenuItem(
                                backgroundColor: context.priamryContainer,
                                title: Text(s.playNext),
                                trailingIcon: Icon(
                                  LineIcons.lightningBolt,
                                  color: Colors.amber,
                                ),
                                onPressed: () {
                                  audio.moveToTop(episodes![index]);
                                  Fluttertoast.showToast(
                                    msg: s.playNextDes,
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                },
                              ),
                          ],
                          onPressed: () => Navigator.push(
                            context,
                            ScaleRoute(
                                page: EpisodeDetail(
                              episodeItem: episodes![index],
                              heroTag: 'scroll',
                              //unique hero tag
                            )),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: podcastLocal!.cardColor(context),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: <Widget>[
                                      Hero(
                                        tag:
                                            '${episodes![index].enclosureUrl}scroll',
                                        child: Container(
                                          height: width / 18,
                                          width: width / 18,
                                          child: CircleAvatar(
                                            backgroundImage:
                                                podcastLocal!.avatarImage,
                                          ),
                                        ),
                                      ),
                                      Spacer(),
                                      Selector<
                                              AudioPlayerNotifier,
                                              tuple
                                                  .Tuple2<EpisodeBrief?, bool>>(
                                          selector: (_, audio) => tuple.Tuple2(
                                              audio.episode,
                                              audio.playerRunning),
                                          builder: (_, data, __) {
                                            return (episodes![index]
                                                            .enclosureUrl ==
                                                        data.item1
                                                            ?.enclosureUrl &&
                                                    data.item2)
                                                ? Container(
                                                    height: 20,
                                                    width: 20,
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 2),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: WaveLoader(
                                                        color: context
                                                            .accentColor))
                                                : Center();
                                          }),
                                      episodes![index].isNew == 1
                                          ? Text(
                                              'New',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontStyle: FontStyle.italic),
                                            )
                                          : Center(),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    padding: EdgeInsets.only(top: 2.0),
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      episodes![index].title!,
                                      style: TextStyle(
                                          //fontSize: _width / 32,
                                          ),
                                      maxLines: 4,
                                      overflow: TextOverflow.fade,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        episodes![index]
                                            .pubDate!
                                            .toDate(context),
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          height: 1,
                                          fontSize: width / 35,
                                          color: c,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      Spacer(),
                                      if (episodes![index].duration != 0)
                                        Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            episodes![index].duration!.toTime,
                                            style: TextStyle(
                                              fontSize: width / 35,
                                              // color: _c,
                                              // fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      episodes![index].duration == 0 ||
                                              episodes![index]
                                                      .enclosureLength ==
                                                  null ||
                                              episodes![index]
                                                      .enclosureLength ==
                                                  0
                                          ? Center()
                                          : Text(
                                              '|',
                                              style: TextStyle(
                                                fontSize: width / 35,
                                              ),
                                            ),
                                      if (episodes![index].enclosureLength !=
                                              null &&
                                          episodes![index].enclosureLength != 0)
                                        Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${episodes![index].enclosureLength! ~/ 1000000}MB',
                                            style:
                                                TextStyle(fontSize: width / 35),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              childCount: math.min(episodes!.length, 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<tuple.Tuple5<int, bool, bool, bool, List<int>>> _initData(
      EpisodeBrief episode) async {
    final menuList = await _getEpisodeMenu();
    final tapToOpen = await _getTapToOpenPopupMenu();
    final listened = await _isListened(episode);
    final liked = await _isLiked(episode);
    final downloaded = await _isDownloaded(episode);

    return tuple.Tuple5(listened, liked, downloaded, tapToOpen, menuList);
  }

  Future<int> _isListened(EpisodeBrief episode) async {
    return await _dbHelper.isListened(episode.enclosureUrl);
  }

  Future<bool> _isLiked(EpisodeBrief episode) async {
    return await _dbHelper.isLiked(episode.enclosureUrl);
  }

  Future<List<int>> _getEpisodeMenu() async {
    final popupMenuStorage = KeyValueStorage(episodePopupMenuKey);
    final list = await popupMenuStorage.getMenu();
    return list;
  }

  Future<bool> _isDownloaded(EpisodeBrief episode) async {
    return await _dbHelper.isDownloaded(episode.enclosureUrl);
  }

  Future<bool> _getTapToOpenPopupMenu() async {
    final tapToOpenPopupMenuStorage = KeyValueStorage(tapToOpenPopupMenuKey);
    final boo = await tapToOpenPopupMenuStorage.getInt(defaultValue: 0);
    return boo == 1;
  }

  Future<void> _markListened(EpisodeBrief episode) async {
    var marked = await _dbHelper.checkMarked(episode);
    if (!marked) {
      final history = PlayHistory(episode.title, episode.enclosureUrl, 0, 1);
      await _dbHelper.saveHistory(history);
    }
  }

  Future<void> _saveLiked(String url) async {
    await _dbHelper.setLiked(url);
  }

  Future<void> _setUnliked(String url) async {
    await _dbHelper.setUniked(url);
  }

  Future<void> _requestDownload(BuildContext context,
      {EpisodeBrief? episode}) async {
    final permissionReady = await _checkPermmison();
    final downloadUsingData = await KeyValueStorage(downloadUsingDataKey)
        .getBool(defaultValue: true, reverse: true);
    final result = await Connectivity().checkConnectivity();
    final usingData = result == ConnectivityResult.mobile;
    var dataConfirm = true;
    if (permissionReady) {
      if (downloadUsingData && usingData) {
        dataConfirm = await _useDataConfirm(context);
      }
      if (dataConfirm) {
        Provider.of<DownloadState>(context, listen: false).startTask(episode!);
      }
    }
  }

  Future<bool> _checkPermmison() async {
    var permission = await Permission.storage.status;
    if (permission != PermissionStatus.granted) {
      var permissions = await [Permission.storage].request();
      if (permissions[Permission.storage] == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }

  Future<bool> _useDataConfirm(BuildContext context) async {
    var ifUseData = false;
    final s = context.s;
    await generalDialog(
      context,
      title: Text(s.cellularConfirm),
      content: Text(s.cellularConfirmDes),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            s.cancel,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        TextButton(
          onPressed: () {
            ifUseData = true;
            Navigator.of(context).pop();
          },
          child: Text(
            s.confirm,
            style: TextStyle(color: Colors.red),
          ),
        )
      ],
    );
    return ifUseData;
  }
}

//Circle Indicator
class CircleTabIndicator extends Decoration {
  final BoxPainter _painter;
  CircleTabIndicator({required Color color, required double radius})
      : _painter = _CirclePainter(color, radius);
  static _returnNull() => null;
  @override
  BoxPainter createBoxPainter([VoidCallback onChanged = _returnNull]) =>
      _painter;
}

class _CirclePainter extends BoxPainter {
  final Paint _paint;
  final double radius;

  _CirclePainter(Color color, this.radius)
      : _paint = Paint()
          ..color = color
          ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final circleOffset =
        offset + Offset(cfg.size!.width / 2, cfg.size!.height - radius);
    canvas.drawCircle(circleOffset, radius, _paint);
  }
}
