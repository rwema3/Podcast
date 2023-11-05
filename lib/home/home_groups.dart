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
