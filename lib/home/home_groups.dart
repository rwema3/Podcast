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
