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

