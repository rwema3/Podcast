import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../local_storage/key_value_storage.dart';
import '../local_storage/sqflite_localpodcast.dart';
import '../state/download_state.dart';
import '../state/podcast_group.dart';
import '../state/refresh_podcast.dart';
import '../util/extension_helper.dart';

class Import extends StatelessWidget {
  Widget importColumn(String text, BuildContext context) {
    return Container(
      color: context.primaryColorDark,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 2.0, child: LinearProgressIndicator()),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            height: 20.0,
            alignment: Alignment.centerLeft,
            child: Text(text),
          ),
        ],
      ),
    );
  }

  _autoDownloadNew(BuildContext context) async {
    final dbHelper = DBHelper();
    final downloader = Provider.of<DownloadState>(context, listen: false);
    final result = await Connectivity().checkConnectivity();
    final autoDownloadStorage = KeyValueStorage(autoDownloadNetworkKey);
    final autoDownloadNetwork = await autoDownloadStorage.getInt();
    if (autoDownloadNetwork == 1) {
      final episodes = await dbHelper.getNewEpisodes('all');
      // For safety
      if (episodes.length < 100 && episodes.length > 0) {
        for (var episode in episodes) {
          await downloader.startTask(episode, showNotification: true);
        }
      }
    } else if (result == ConnectivityResult.wifi) {
      var episodes = await dbHelper.getNewEpisodes('all');
      //For safety
      if (episodes.length < 100 && episodes.length > 0) {
        for (var episode in episodes) {
          await downloader.startTask(episode, showNotification: true);
        }
      }
    }
