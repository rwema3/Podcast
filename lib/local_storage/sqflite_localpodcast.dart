import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:webfeed/webfeed.dart';

import '../type/episodebrief.dart';
import '../type/play_histroy.dart';
import '../type/podcastlocal.dart';
import '../type/sub_history.dart';

enum Filter { downloaded, liked, search, all }

const localFolderId = "46e48103-06c7-4fe1-a0b1-68aa7205b7f0";

class DBHelper {
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    var documentsDirectory = await getDatabasesPath();
    var path = join(documentsDirectory, "podcasts.db");
    var theDb = await openDatabase(path,
        version: 7, onCreate: _onCreate, onUpgrade: _onUpgrade);
    return theDb;
  }

  void _onCreate(Database db, int version) async {
    await db
        .execute("""CREATE TABLE PodcastLocal(id TEXT PRIMARY KEY,title TEXT, 
        imageUrl TEXT,rssUrl TEXT UNIQUE, primaryColor TEXT, author TEXT, 
        description TEXT, add_date INTEGER, imagePath TEXT, provider TEXT, link TEXT, 
        background_image TEXT DEFAULT '', hosts TEXT DEFAULT '',update_count INTEGER DEFAULT 0,
        episode_count INTEGER DEFAULT 0, skip_seconds INTEGER DEFAULT 0, 
        auto_download INTEGER DEFAULT 0, skip_seconds_end INTEGER DEFAULT 0,
        never_update INTEGER DEFAULT 0, funding TEXT DEFAULT '[]', 
        hide_new_mark INTEGER DEFAULT 0 )""");
    await db
        .execute("""CREATE TABLE Episodes(id INTEGER PRIMARY KEY,title TEXT, 
        enclosure_url TEXT UNIQUE, enclosure_length INTEGER, pubDate TEXT, 
        description TEXT, feed_id TEXT, feed_link TEXT, milliseconds INTEGER, 
        duration INTEGER DEFAULT 0, explicit INTEGER DEFAULT 0, liked INTEGER DEFAULT 0, 
        liked_date INTEGER DEFAULT 0, downloaded TEXT DEFAULT 'ND', 
        download_date INTEGER DEFAULT 0, media_id TEXT, is_new INTEGER DEFAULT 0, 
        chapter_link TEXT DEFAULT '', hosts TEXT DEFAULT '', episode_image TEXT DEFAULT '')""");
    await db.execute(
        """CREATE TABLE PlayHistory(id INTEGER PRIMARY KEY, title TEXT, enclosure_url TEXT,
        seconds REAL, seek_value REAL, add_date INTEGER, listen_time INTEGER DEFAULT 0)""");
    await db.execute(
        """CREATE TABLE SubscribeHistory(id TEXT PRIMARY KEY, title TEXT, rss_url TEXT UNIQUE, 
        add_date INTEGER, remove_date INTEGER DEFAULT 0, status INTEGER DEFAULT 0)""");
    await db
        .execute("""CREATE INDEX  podcast_search ON PodcastLocal (id, rssUrl);
    """);
    await db.execute(
        """CREATE INDEX  episode_search ON Episodes (enclosure_url, feed_id);
    """);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    switch (oldVersion) {
      case (1):
        await _v2Update(db);
        await _v3Update(db);
        await _v4Update(db);
        await _v5Update(db);
        await _v6Update(db);
        break;
      case (2):
        await _v3Update(db);
        await _v4Update(db);
        await _v5Update(db);
        await _v6Update(db);
        break;
      case (3):
        await _v4Update(db);
        await _v5Update(db);
        await _v6Update(db);
        break;
      case (4):
        await _v5Update(db);
        await _v6Update(db);
        break;
      case (5):
        await _v6Update(db);
        break;
      case (6):
        await _v7Update(db);
    }
  }

  Future<void> _v2Update(Database db) async {
    await db.execute(
        "ALTER TABLE PodcastLocal ADD skip_seconds INTEGER DEFAULT 0 ");
  }

  Future<void> _v3Update(Database db) async {
    await db.execute(
        "ALTER TABLE PodcastLocal ADD auto_download INTEGER DEFAULT 0");
  }

  Future<void> _v4Update(Database db) async {
    await db.execute(
        "ALTER TABLE PodcastLocal ADD skip_seconds_end INTEGER DEFAULT 0 ");
    await db.execute(
        "ALTER TABLE PodcastLocal ADD never_update INTEGER DEFAULT 0 ");
  }

  Future<void> _v5Update(Database db) async {
    await db.execute("ALTER TABLE PodcastLocal ADD funding TEXT DEFAULT '[]' ");
  }

  Future<void> _v6Update(Database db) async {
    await db.execute("ALTER TABLE Episodes ADD chapter_link TEXT DEFAULT '' ");
    await db.execute("ALTER TABLE Episodes ADD hosts TEXT DEFAULT '' ");
    await db.execute("ALTER TABLE Episodes ADD episode_image TEXT DEFAULT '' ");
    await db
        .execute("""CREATE INDEX  podcast_search ON PodcastLocal (id, rssUrl)
    """);
    await db.execute(
        """CREATE INDEX  episode_search ON Episodes (enclosure_url, feed_id)
    """);
  }

  Future<void> _v7Update(Database db) async {
    await db.execute(
        "ALTER TABLE PodcastLocal ADD hide_new_mark INTEGER DEFAULT 0");
  }

  Future<List<PodcastLocal>> getPodcastLocal(List<String?> podcasts,
      {bool updateOnly = false}) async {
    var dbClient = await database;
    var podcastLocal = <PodcastLocal>[];

    for (var s in podcasts) {
      List<Map> list;
      if (updateOnly) {
        list = await dbClient.rawQuery(
            """SELECT id, title, imageUrl, rssUrl, primaryColor, author, imagePath , provider, 
          link ,update_count, episode_count, funding FROM PodcastLocal WHERE id = ? AND 
          never_update = 0""", [s]);
      } else {
        list = await dbClient.rawQuery(
            """SELECT id, title, imageUrl, rssUrl, primaryColor, author, imagePath , provider, 
          link ,update_count, episode_count, funding FROM PodcastLocal WHERE id = ?""",
            [s]);
      }
      if (list.length > 0) {
        podcastLocal.add(PodcastLocal(
            list.first['title'],
            list.first['imageUrl'],
            list.first['rssUrl'],
            list.first['primaryColor'],
            list.first['author'],
            list.first['id'],
            list.first['imagePath'],
            list.first['provider'],
            list.first['link'],
            List<String>.from(jsonDecode(list.first['funding'])),
            updateCount: list.first['update_count'],
            episodeCount: list.first['episode_count']));
      }
    }
    return podcastLocal;
  }

  Future<List<PodcastLocal>> getPodcastLocalAll(
      {bool updateOnly = false}) async {
    var dbClient = await database;

    List<Map> list;
    if (updateOnly) {
      list = await dbClient.rawQuery(
          """SELECT id, title, imageUrl, rssUrl, primaryColor, author, imagePath,
         provider, link, funding FROM PodcastLocal WHERE never_update = 0 ORDER BY 
         add_date DESC""");
    } else {
      list = await dbClient.rawQuery(
          """SELECT id, title, imageUrl, rssUrl, primaryColor, author, imagePath,
         provider, link, funding FROM PodcastLocal ORDER BY add_date DESC""");
    }

    var podcastLocal = <PodcastLocal>[];

    for (var i in list) {
      if (i['id'] != localFolderId) {
        podcastLocal.add(PodcastLocal(
          i['title'],
          i['imageUrl'],
          i['rssUrl'],
          i['primaryColor'],
          i['author'],
          i['id'],
          i['imagePath'],
          i['provider'],
          i['link'],
          List<String>.from(jsonDecode(list.first['funding'])),
        ));
      }
    }
    return podcastLocal;
  }

  Future<PodcastLocal?> getPodcastWithUrl(String? url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT P.id, P.title, P.imageUrl, P.rssUrl, P.primaryColor, P.author, P.imagePath,
         P.provider, P.link ,P.update_count, P.episode_count, P.funding FROM PodcastLocal P INNER JOIN 
         Episodes E ON P.id = E.feed_id WHERE E.enclosure_url = ?""", [url]);
    if (list.isNotEmpty) {
      return PodcastLocal(
          list.first['title'],
          list.first['imageUrl'],
          list.first['rssUrl'],
          list.first['primaryColor'],
          list.first['author'],
          list.first['id'],
          list.first['imagePath'],
          list.first['provider'],
          list.first['link'],
          List<String>.from(jsonDecode(list.first['funding'])),
          updateCount: list.first['update_count'],
          episodeCount: list.first['episode_count']);
    }
    return null;
  }

  Future<int?> getPodcastCounts(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT episode_count FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['episode_count'];
    return 0;
  }

  Future<void> removePodcastNewMark(String? id) async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE Episodes SET is_new = 0 WHERE feed_id = ? AND is_new = 1",
          [id]);
    });
  }

  Future<bool> getNeverUpdate(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT never_update FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['never_update'] == 1;
    return false;
  }

  Future<int> saveNeverUpdate(String? id, {required bool boo}) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET never_update = ? WHERE id = ?",
        [boo ? 1 : 0, id]);
  }

  Future<bool> getHideNewMark(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT hide_new_mark FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['hide_new_mark'] == 1;
    return false;
  }

  Future<int> saveHideNewMark(String? id, {required bool boo}) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET hide_new_mark = ? WHERE id = ?",
        [boo ? 1 : 0, id]);
  }

  Future<int?> getPodcastUpdateCounts(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECt count(*) as count FROM Episodes WHERE feed_id = ? AND is_new = 1',
        [id]);
    if (list.isNotEmpty) return list.first['count'];
    return 0;
  }

  Future<int?> getSkipSecondsStart(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT skip_seconds FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['skip_seconds'];
    return 0;
  }

  Future<int> saveSkipSecondsStart(String? id, int? seconds) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET skip_seconds = ? WHERE id = ?", [seconds, id]);
  }

  Future<int?> getSkipSecondsEnd(String id) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECT skip_seconds_end FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['skip_seconds_end'];
    return 0;
  }

  Future<int> saveSkipSecondsEnd(String? id, int seconds) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET skip_seconds_end = ? WHERE id = ?",
        [seconds, id]);
  }

  Future<bool> getAutoDownload(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT auto_download FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) return list.first['auto_download'] == 1;
    return false;
  }

  Future<int> saveAutoDownload(String? id, {required bool boo}) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET auto_download = ? WHERE id = ?",
        [boo ? 1 : 0, id]);
  }

  Future<String?> checkPodcast(String? url) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT id FROM PodcastLocal WHERE rssUrl = ?', [url]);
    if (list.isEmpty) return '';
    return list.first['id'];
  }

  Future savePodcastLocal(PodcastLocal podcastLocal) async {
    var milliseconds = DateTime.now().millisecondsSinceEpoch;
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawInsert(
          """INSERT OR IGNORE INTO PodcastLocal (id, title, imageUrl, rssUrl, 
          primaryColor, author, description, add_date, imagePath, provider, link, funding) 
          VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
          [
            podcastLocal.id,
            podcastLocal.title,
            podcastLocal.imageUrl,
            podcastLocal.rssUrl,
            podcastLocal.primaryColor,
            podcastLocal.author,
            podcastLocal.description,
            milliseconds,
            podcastLocal.imagePath,
            podcastLocal.provider,
            podcastLocal.link,
            jsonEncode(podcastLocal.funding)
          ]);
      if (podcastLocal.id != localFolderId) {
        await txn.rawInsert(
            """REPLACE INTO SubscribeHistory(id, title, rss_url, add_date) VALUES (?, ?, ?, ?)""",
            [
              podcastLocal.id,
              podcastLocal.title,
              podcastLocal.rssUrl,
              milliseconds
            ]);
      }
    });
  }

  Future<int> updatePodcastImage({String? id, String? filePath}) async {
    var dbClient = await database;
    return await dbClient.rawUpdate(
        "UPDATE PodcastLocal SET imagePath= ? WHERE id = ?", [filePath, id]);
  }

  Future<int> saveFiresideData(List<String?> list) async {
    var dbClient = await database;
    var result = await dbClient.rawUpdate(
        'UPDATE PodcastLocal SET background_image = ? , hosts = ? WHERE id = ?',
        [list[1], list[2], list[0]]);
    return result;
  }

  Future<List<String?>> getFiresideData(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECT background_image, hosts FROM PodcastLocal WHERE id = ?', [id]);
    if (list.isNotEmpty) {
      var data = <String?>[list.first['background_image'], list.first['hosts']];
      return data;
    }
    return ['', ''];
  }

  Future<void> delPodcastLocal(String? id) async {
    var dbClient = await database;
    await dbClient.rawDelete('DELETE FROM PodcastLocal WHERE id =?', [id]);
    List<Map> list = await dbClient.rawQuery(
        """SELECT downloaded FROM Episodes WHERE downloaded != 'ND' AND feed_id = ?""",
        [id]);
    for (var i in list) {
      if (i != null) {
        await FlutterDownloader.remove(
            taskId: i['downloaded'], shouldDeleteContent: true);
      }
    }
    await dbClient.rawDelete('DELETE FROM Episodes WHERE feed_id=?', [id]);
    var milliseconds = DateTime.now().millisecondsSinceEpoch;
    await dbClient.rawUpdate(
        """UPDATE SubscribeHistory SET remove_date = ? , status = ? WHERE id = ?""",
        [milliseconds, 1, id]);
  }

  Future<void> saveHistory(PlayHistory history) async {
    if (history.url!.substring(0, 7) != 'file://') {
      var dbClient = await database;
      final milliseconds = DateTime.now().millisecondsSinceEpoch;
      var recent = await getPlayHistory(1);
      if (recent.isNotEmpty && recent.first.title == history.title) {
        await dbClient.rawDelete("DELETE FROM PlayHistory WHERE add_date = ?",
            [recent.first.playdate!.millisecondsSinceEpoch]);
      }
      await dbClient.transaction((txn) async {
        return await txn.rawInsert(
            """INSERT INTO PlayHistory (title, enclosure_url, seconds, seek_value, add_date, listen_time)
       VALUES (?, ?, ?, ?, ?, ?) """,
            [
              history.title,
              history.url,
              history.seconds,
              history.seekValue,
              milliseconds,
              history.seekValue! > 0.95 ? 1 : 0
            ]);
      });
    }
  }

  Future<List<PlayHistory>> getPlayHistory(int top) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT title, enclosure_url, seconds, seek_value, add_date FROM PlayHistory
         ORDER BY add_date DESC LIMIT ?
     """, [top]);
    var playHistory = <PlayHistory>[];
    for (var record in list) {
      playHistory.add(PlayHistory(record['title'], record['enclosure_url'],
          (record['seconds']).toInt(), record['seek_value'],
          playdate: DateTime.fromMillisecondsSinceEpoch(record['add_date'])));
    }
    return playHistory;
  }

  /// History list in playlist page, not include marked episdoes.
  Future<List<PlayHistory>> getPlayRecords(int? top) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT title, enclosure_url, seconds, seek_value, add_date FROM PlayHistory 
        WHERE seconds != 0 ORDER BY add_date DESC LIMIT ?
     """, [top]);
    var playHistory = <PlayHistory>[];
    for (var record in list) {
      playHistory.add(PlayHistory(record['title'], record['enclosure_url'],
          (record['seconds']).toInt(), record['seek_value'],
          playdate: DateTime.fromMillisecondsSinceEpoch(record['add_date'])));
    }
    return playHistory;
  }

  Future<int> isListened(String url) async {
    var dbClient = await database;
    int? i = 0;
    List<Map> list = await dbClient.rawQuery(
        "SELECT SUM(listen_time) FROM PlayHistory WHERE enclosure_url = ?",
        [url]);
    if (list.isNotEmpty) {
      i = list.first['SUM(listen_time)'];
      return i ?? 0;
    }
    return 0;
  }

  Future<int?> markNotListened(String url) async {
    var dbClient = await database;
    int? count;
    await dbClient.transaction((txn) async {
      count = await txn.rawUpdate(
          "UPDATE OR IGNORE PlayHistory SET listen_time = 0 WHERE enclosure_url = ?",
          [url]);
    });
    await dbClient.rawDelete(
        'DELETE FROM PlayHistory WHERE enclosure_url=? '
        'AND listen_time = 0 AND seconds = 0',
        [url]);
    return count;
  }

  Future<List<SubHistory>> getSubHistory() async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT title, rss_url, add_date, remove_date, status FROM SubscribeHistory
      ORDER BY add_date DESC""");
    return list
        .map((record) => SubHistory(
              DateTime.fromMillisecondsSinceEpoch(record['remove_date']),
              DateTime.fromMillisecondsSinceEpoch(record['add_date']),
              record['rss_url'],
              record['title'],
              status: record['status'] == 0 ? true : false,
            ))
        .toList();
  }

  Future<double> listenMins(int day) async {
    var dbClient = await database;
    var now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: day))
        .millisecondsSinceEpoch;
    var end = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (day - 1)))
        .millisecondsSinceEpoch;
    List<Map> list = await dbClient.rawQuery(
        "SELECT seconds FROM PlayHistory WHERE add_date > ? AND add_date < ?",
        [start, end]);
    var sum = 0.0;
    if (list.isEmpty) {
      sum = 0.0;
    } else {
      for (var record in list) {
        sum += record['seconds'];
      }
    }
    return (sum ~/ 60).toDouble();
  }

  Future<PlayHistory> getPosition(EpisodeBrief episodeBrief) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT title, enclosure_url, seconds, seek_value, add_date FROM PlayHistory 
        WHERE enclosure_url = ? ORDER BY add_date DESC LIMIT 1""",
        [episodeBrief.enclosureUrl]);
    return list.isNotEmpty
        ? PlayHistory(list.first['title'], list.first['enclosure_url'],
            (list.first['seconds']).toInt(), list.first['seek_value'],
            playdate:
                DateTime.fromMillisecondsSinceEpoch(list.first['add_date']))
        : PlayHistory(episodeBrief.title, episodeBrief.enclosureUrl, 0, 0);
  }

  /// Check if episode was marked listend.
  Future<bool> checkMarked(EpisodeBrief episodeBrief) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT title, enclosure_url, seconds, seek_value, add_date FROM PlayHistory 
        WHERE enclosure_url = ? AND seek_value = 1 ORDER BY add_date DESC LIMIT 1""",
        [episodeBrief.enclosureUrl]);
    return list.isNotEmpty;
  }

  DateTime _parsePubDate(String? pubDate) {
    if (pubDate == null) return DateTime.now();
    DateTime date;
    var yyyy = RegExp(r'[1-2][0-9]{3}');
    var hhmm = RegExp(r'[0-2][0-9]\:[0-5][0-9]');
    var ddmmm = RegExp(r'[0-3][0-9]\s[A-Z][a-z]{2}');
    var mmDd = RegExp(r'([1-2][0-9]{3}\-[0-1]|\s)[0-9]\-[0-3][0-9]');
    // RegExp timezone
    var z = RegExp(r'(\+|\-)[0-1][0-9]00');
    var timezone = z.stringMatch(pubDate);
    var timezoneInt = 0;
    if (timezone != null) {
      if (timezone.substring(0, 1) == '-') {
        timezoneInt = int.parse(timezone.substring(1, 2));
      } else {
        timezoneInt = -int.parse(timezone.substring(1, 2));
      }
    }
    try {
      date = DateFormat('EEE, dd MMM yyyy HH:mm:ss Z', 'en_US').parse(pubDate);
    } catch (e) {
      try {
        date = DateFormat('dd MMM yyyy HH:mm:ss Z', 'en_US').parse(pubDate);
      } catch (e) {
        try {
          date = DateFormat('EEE, dd MMM yyyy HH:mm Z', 'en_US').parse(pubDate);
        } catch (e) {
          var year = yyyy.stringMatch(pubDate);
          var time = hhmm.stringMatch(pubDate);
          var month = ddmmm.stringMatch(pubDate);
          if (year != null && time != null && month != null) {
            try {
              date = DateFormat('dd MMM yyyy HH:mm', 'en_US')
                  .parse('$month $year $time');
            } catch (e) {
              date = DateTime.now();
            }
          } else if (year != null && time != null && month == null) {
            var month = mmDd.stringMatch(pubDate);
            try {
              date =
                  DateFormat('yyyy-MM-dd HH:mm', 'en_US').parse('$month $time');
            } catch (e) {
              date = DateTime.now();
            }
          } else {
            date = DateTime.now();
          }
        }
      }
    }
    date.add(Duration(hours: timezoneInt)).add(DateTime.now().timeZoneOffset);
    developer.log(date.toString());
    return date;
  }

  int _getExplicit(bool? b) {
    int result;
    if (b == true) {
      result = 1;
      return result;
    } else {
      result = 0;
      return result;
    }
  }

  bool _isXimalaya(String input) {
    var ximalaya = RegExp(r"ximalaya.com");
    return ximalaya.hasMatch(input);
  }

  String _getDescription(String content, String description, String summary) {
    if (content.length >= description.length) {
      if (content.length >= summary.length) {
        return content;
      } else {
        return summary;
      }
    } else if (description.length >= summary.length) {
      return description;
    } else {
      return summary;
    }
  }

  Future<int> savePodcastRss(RssFeed feed, String id) async {
    feed.items!.removeWhere((item) => item == null);
    var result = feed.items!.length;
    var dbClient = await database;
    String? description, url;
    for (var i = 0; i < result; i++) {
      developer.log(feed.items![i].title!);
      description = _getDescription(
          feed.items![i].content?.value ?? '',
          feed.items![i].description ?? '',
          feed.items![i].itunes!.summary ?? '');
      if (feed.items![i].enclosure != null) {
        _isXimalaya(feed.items![i].enclosure!.url!)
            ? url = feed.items![i].enclosure!.url!.split('=').last
            : url = feed.items![i].enclosure!.url;
      }

      final title = feed.items![i].itunes!.title ?? feed.items![i].title;
      final length = feed.items![i].enclosure?.length;
      final pubDate = feed.items![i].pubDate;
      final date = _parsePubDate(pubDate);
      final milliseconds = date.millisecondsSinceEpoch;
      final duration = feed.items![i].itunes!.duration?.inSeconds ?? 0;
      final explicit = _getExplicit(feed.items![i].itunes!.explicit);
      final chapter = feed.items![i].podcastChapters?.url ?? '';
      final image = feed.items![i].itunes!.image?.href ?? '';
      if (url != null) {
        await dbClient.transaction((txn) {
          return txn.rawInsert(
              """INSERT OR REPLACE INTO Episodes(title, enclosure_url, enclosure_length, pubDate, 
                description, feed_id, milliseconds, duration, explicit, media_id, chapter_link,
                episode_image) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
              [
                title,
                url,
                length,
                pubDate,
                description,
                id,
                milliseconds,
                duration,
                explicit,
                url,
                chapter,
                image
              ]);
        });
      }
    }
    var countUpdate = Sqflite.firstIntValue(await dbClient
        .rawQuery('SELECT COUNT(*) FROM Episodes WHERE feed_id = ?', [id]));

    await dbClient.rawUpdate(
        """UPDATE PodcastLocal SET episode_count = ? WHERE id = ?""",
        [countUpdate, id]);
    return result;
  }

  Future<int> updatePodcastRss(PodcastLocal podcastLocal,
      {int? removeMark = 0}) async {
    final options = BaseOptions(
      connectTimeout: 20000,
      receiveTimeout: 20000,
    );
    final hideNewMark = await getHideNewMark(podcastLocal.id);
    try {
      var response = await Dio(options).get(podcastLocal.rssUrl);
      if (response.statusCode == 200) {
        var feed = RssFeed.parse(response.data);
        String? url, description;
        feed.items!.removeWhere((item) => item == null);

        var dbClient = await database;
        var count = Sqflite.firstIntValue(await dbClient.rawQuery(
            'SELECT COUNT(*) FROM Episodes WHERE feed_id = ?',
            [podcastLocal.id]))!;
        if (removeMark == 0) {
          await dbClient.rawUpdate(
              "UPDATE Episodes SET is_new = 0 WHERE feed_id = ?",
              [podcastLocal.id]);
        }
        for (var item in feed.items!) {
          developer.log(item.title!);
          description = _getDescription(item.content!.value,
              item.description ?? '', item.itunes!.summary ?? '');

          if (item.enclosure?.url != null) {
            _isXimalaya(item.enclosure!.url!)
                ? url = item.enclosure!.url!.split('=').last
                : url = item.enclosure!.url;
          }

          final title = item.itunes!.title ?? item.title;
          final length = item.enclosure?.length ?? 0;
          final pubDate = item.pubDate;
          final date = _parsePubDate(pubDate);
          final milliseconds = date.millisecondsSinceEpoch;
          final duration = item.itunes!.duration?.inSeconds ?? 0;
          final explicit = _getExplicit(item.itunes!.explicit);
          final chapter = item.podcastChapters?.url ?? '';
          final image = item.itunes!.image?.href ?? '';

          if (url != null) {
            await dbClient.transaction((txn) async {
              await txn.rawInsert(
                  """INSERT OR IGNORE INTO Episodes(title, enclosure_url, enclosure_length, pubDate, 
                description, feed_id, milliseconds, duration, explicit, media_id, chapter_link,
                episode_image, is_new) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                  [
                    title,
                    url,
                    length,
                    pubDate,
                    description,
                    podcastLocal.id,
                    milliseconds,
                    duration,
                    explicit,
                    url,
                    chapter,
                    image,
                    hideNewMark ? 0 : 1
                  ]);
            });
          }
        }
        var countUpdate = Sqflite.firstIntValue(await dbClient.rawQuery(
            'SELECT COUNT(*) FROM Episodes WHERE feed_id = ?',
            [podcastLocal.id]))!;

        await dbClient.rawUpdate(
            """UPDATE PodcastLocal SET update_count = ?, episode_count = ? WHERE id = ?""",
            [countUpdate - count, countUpdate, podcastLocal.id]);
        return countUpdate - count;
      }
      return 0;
    } catch (e) {
      developer.log(e.toString(), name: 'Update podcast error');
      return -1;
    }
  }

  Future<void> saveLocalEpisode(EpisodeBrief episode) async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawInsert(
          """INSERT OR REPLACE INTO Episodes(title, enclosure_url, enclosure_length, pubDate, 
                description, feed_id, milliseconds, duration, explicit, media_id, episode_image) 
                VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
          [
            episode.title,
            episode.enclosureUrl,
            episode.enclosureLength,
            '',
            '',
            localFolderId,
            episode.pubDate,
            episode.duration,
            0,
            episode.enclosureUrl,
            episode.episodeImage
          ]);
    });
  }

  Future<void> deleteLocalEpisodes(List<String> files) async {
    var dbClient = await database;
    var s = files.map<String>((e) => "'$e'").toList();
    await dbClient.rawDelete(
        'DELETE FROM Episodes WHERE enclosure_url in (${s.join(',')})');
  }

  Future<List<EpisodeBrief>> getRssItem(String? id, int? count,
      {bool? reverse,
      Filter? filter = Filter.all,
      String? query = '',
      bool hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    var list = <Map>[];
    if (hideListened) {
      if (count == -1) {
        if (reverse!) {
          switch (filter) {
            case Filter.all:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds ASC""", [id]);
              break;
            case Filter.liked:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds ASC""", [id]);
              break;
            case Filter.downloaded:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.media_id != E.enclosure_url ORDER BY E.milliseconds ASC""",
                  [id]);
              break;
            case Filter.search:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.title LIKE ? ORDER BY E.milliseconds ASC""",
                  [id, '%$query%']);
              break;
            default:
          }
        } else {
          switch (filter) {
            case Filter.all:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC""", [id]);
              break;
            case Filter.liked:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds DESC""", [id]);
              break;
            case Filter.downloaded:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.media_id != E.enclosure_url ORDER BY E.milliseconds DESC""",
                  [id]);
              break;
            case Filter.search:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.title LIKE ? ORDER BY E.milliseconds DESC""",
                  [id, '%$query%']);
              break;
            default:
          }
        }
      } else if (reverse!) {
        switch (filter) {
          case Filter.all:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, count]);
            break;
          case Filter.liked:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND E.liked = 1 GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, count]);
            break;
          case Filter.downloaded:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND E.enclosure_url != E.media_id 
        GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0  ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, count]);
            break;
          case Filter.search:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND E.title LIKE ? GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, '%$query%', count]);
            break;
          default:
        }
      } else {
        switch (filter) {
          case Filter.all:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor  FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id  
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ?  GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, count]);
            break;
          case Filter.liked:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND E.liked = 1 GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, count]);
            break;
          case Filter.downloaded:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND E.enclosure_url != E.media_id GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, count]);
            break;
          case Filter.search:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id = ? AND  E.title LIKE ? GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, '%$query%', count]);
            break;
          default:
        }
      }
    } else {
      if (count == -1) {
        if (reverse!) {
          switch (filter) {
            case Filter.all:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? ORDER BY E.milliseconds ASC""", [id]);
              break;
            case Filter.liked:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds ASC""", [id]);
              break;
            case Filter.downloaded:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.media_id != E.enclosure_url ORDER BY E.milliseconds ASC""",
                  [id]);
              break;
            case Filter.search:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.title LIKE ? ORDER BY E.milliseconds ASC""",
                  [id, '%$query%']);
              break;
            default:
          }
        } else {
          switch (filter) {
            case Filter.all:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? ORDER BY E.milliseconds DESC""", [id]);
              break;
            case Filter.liked:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds DESC""", [id]);
              break;
            case Filter.downloaded:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.media_id != E.enclosure_url ORDER BY E.milliseconds DESC""",
                  [id]);
              break;
            case Filter.search:
              list = await dbClient.rawQuery(
                  """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.title LIKE ? ORDER BY E.milliseconds DESC""",
                  [id, '%$query%']);
              break;
            default:
          }
        }
      } else if (reverse!) {
        switch (filter) {
          case Filter.all:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? ORDER BY E.milliseconds ASC LIMIT ?""", [id, count]);
            break;
          case Filter.liked:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, count]);
            break;
          case Filter.downloaded:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.enclosure_url != E.media_id ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, count]);
            break;
          case Filter.search:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, 
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.title LIKE ? ORDER BY E.milliseconds ASC LIMIT ?""",
                [id, '%$query%', count]);
            break;
          default:
        }
      } else {
        switch (filter) {
          case Filter.all:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? ORDER BY E.milliseconds DESC LIMIT ?""", [id, count]);
            break;
          case Filter.liked:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.liked = 1 ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, count]);
            break;
          case Filter.downloaded:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND E.enclosure_url != E.media_id ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, count]);
            break;
          case Filter.search:
            list = await dbClient.rawQuery(
                """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE P.id = ? AND  E.title LIKE ? ORDER BY E.milliseconds DESC LIMIT ?""",
                [id, '%$query%', count]);
            break;
          default:
        }
      }
    }

    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getNewEpisodes(String? id) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    List<Map> list;
    if (id == 'all') {
      list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.is_new = 1 AND E.downloaded = 'ND' AND P.auto_download = 1 ORDER BY E.milliseconds ASC""",
      );
    } else {
      list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
       P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.is_new = 1 AND E.downloaded = 'ND' AND E.feed_id = ? ORDER BY E.milliseconds ASC""",
          [id]);
    }
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getRssItemTop(String? id) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    List<Map> list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.imagePath, P.title as feed_title, E.duration, E.explicit, 
        P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        where E.feed_id = ? ORDER BY E.milliseconds DESC LIMIT 2""", [id]);
    for (var i in list) {
      episodes.add(EpisodeBrief(
          i['title'],
          i['enclosure_url'],
          i['enclosure_length'],
          i['milliseconds'],
          i['feed_title'],
          i['primaryColor'],
          i['duration'],
          i['explicit'],
          i['imagePath'],
          i['is_new']));
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getRecentRssItem(int top,
      {bool hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    var list = <Map>[];
    if (hideListened) {
      list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url WHERE p.id != ? 
        GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ? """,
          [localFolderId, top]);
    } else {
      list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE p.id != ? ORDER BY E.milliseconds DESC LIMIT ? """,
          [localFolderId, top]);
    }
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getRandomRssItem(int random,
      {bool hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    var list = <Map>[];
    if (hideListened) {
      list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url WHERE p.id != ?  
        GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY RANDOM() LIMIT ? """,
          [localFolderId, random]);
    } else {
      list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE p.id != ?  ORDER BY RANDOM() LIMIT ? """,
          [localFolderId, random]);
    }
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getGroupRssItem(int top, List<String?> group,
      {bool? hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    if (group.length > 0) {
      var s = group.map<String>((e) => "'$e'").toList();
      var list = <Map>[];
      if (hideListened!) {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE P.id in (${s.join(',')}) GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ? """,
            [top]);
      } else {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE P.id in (${s.join(',')})
        ORDER BY E.milliseconds DESC LIMIT ? """, [top]);
      }
      if (list.isNotEmpty) {
        for (var i in list) {
          episodes.add(EpisodeBrief(
              i['title'],
              i['enclosure_url'],
              i['enclosure_length'],
              i['milliseconds'],
              i['feed_title'],
              i['primaryColor'],
              i['duration'],
              i['explicit'],
              i['imagePath'],
              i['is_new']));
        }
      }
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getRecentNewRssItem() async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    List<Map> list = await dbClient.rawQuery(
      """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new, E.media_id,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE is_new = 1 ORDER BY E.milliseconds DESC  """,
    );
    for (var i in list) {
      episodes.add(EpisodeBrief(
          i['title'],
          i['enclosure_url'],
          i['enclosure_length'],
          i['milliseconds'],
          i['feed_title'],
          i['primaryColor'],
          i['duration'],
          i['explicit'],
          i['imagePath'],
          i['is_new'],
          mediaId: i['media_id']));
    }
    return episodes;
  }

  Future<List<EpisodeBrief>> getOutdatedEpisode(int deadline,
      {required bool deletePlayed}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    List<Map> list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.download_date < ? AND E.enclosure_url != E.media_id
        ORDER BY E.milliseconds DESC""", [deadline]);
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }
    if (deletePlayed) {
      List<Map> results = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P 
        ON E.feed_id = P.id LEFT JOIN PlayHistory H ON E.enclosure_url = 
        H.enclosure_url WHERE E.enclosure_url != E.media_id 
        GROUP BY E.enclosure_url HAVING SUM(H.listen_time) > 0 ORDER BY 
        E.milliseconds DESC""");
      if (results.isNotEmpty) {
        for (var i in results) {
          episodes.add(EpisodeBrief(
              i['title'],
              i['enclosure_url'],
              i['enclosure_length'],
              i['milliseconds'],
              i['feed_title'],
              i['primaryColor'],
              i['duration'],
              i['explicit'],
              i['imagePath'],
              i['is_new']));
        }
      }
    }
    return episodes.toSet().toList();
  }

  Future<List<EpisodeBrief>> getDownloadedEpisode(int? mode,
      {bool hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    late List<Map> list;
    if (hideListened) {
      if (mode == 0) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE E.enclosure_url != E.media_id GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.download_date DESC""",
        );
      } else if (mode == 1) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date,E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE E.enclosure_url != E.media_id GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.download_date ASC""",
        );
      } else if (mode == 2) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date,E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE E.enclosure_url != E.media_id GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.enclosure_length DESC""",
        );
      }
    } else //Ordered by date
    {
      if (mode == 0) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date, E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.enclosure_url != E.media_id
        ORDER BY E.download_date DESC""",
        );
      } else if (mode == 1) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date,E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.enclosure_url != E.media_id
        ORDER BY E.download_date ASC""",
        );
      } else if (mode == 2) {
        list = await dbClient.rawQuery(
          """SELECT E.title, E.enclosure_url, E.enclosure_length, E.download_date,E.is_new,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.enclosure_url != E.media_id
        ORDER BY E.enclosure_length DESC""",
        );
      }
    }
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new'],
            downloadDate: i['download_date']));
      }
    }
    return episodes;
  }

  Future<void> removeAllNewMark() async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate("UPDATE Episodes SET is_new = 0 ");
    });
  }

  Future<List<EpisodeBrief>> getGroupNewRssItem(List<String?> group) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    if (group.length > 0) {
      var s = group.map<String>((e) => "'$e'").toList();
      List<Map> list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.is_new, E.media_id,
        E.milliseconds, P.title as feed_title, E.duration, E.explicit, 
        P.imagePath, P.primaryColor FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE P.id in (${s.join(',')}) AND is_new = 1
        ORDER BY E.milliseconds DESC""",
      );
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new'],
            mediaId: i['media_id']));
      }
    }
    return episodes;
  }

  Future<void> removeGroupNewMark(List<String?> group) async {
    var dbClient = await database;
    if (group.isNotEmpty) {
      var s = group.map<String>((e) => "'$e'").toList();
      await dbClient.transaction((txn) async {
        await txn.rawUpdate(
            "UPDATE Episodes SET is_new = 0 WHERE feed_id in (${s.join(',')})");
      });
    }
  }

  Future<void> removeEpisodeNewMark(String? url) async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE Episodes SET is_new = 0 WHERE enclosure_url = ?", [url]);
    });
    developer.log('remove episode mark $url');
  }

  Future<List<EpisodeBrief>> getLikedRssItem(int i, int? sortBy,
      {bool hideListened = false}) async {
    var dbClient = await database;
    var episodes = <EpisodeBrief>[];
    var list = <Map>[];
    if (hideListened) {
      if (sortBy == 0) {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.primaryColor, E.is_new
        FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE E.liked = 1 GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.milliseconds DESC LIMIT ?""", [i]);
      } else {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.primaryColor, E.is_new
        FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        LEFT JOIN PlayHistory H ON E.enclosure_url = H.enclosure_url 
        WHERE E.liked = 1 GROUP BY E.enclosure_url HAVING SUM(H.listen_time) is null 
        OR SUM(H.listen_time) = 0 ORDER BY E.liked_date DESC LIMIT ?""", [i]);
      }
    } else {
      if (sortBy == 0) {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.primaryColor, E.is_new
         FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE E.liked = 1 ORDER BY E.milliseconds DESC LIMIT ?""", [i]);
      } else {
        list = await dbClient.rawQuery(
            """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.primaryColor, E.is_new
        FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id
        WHERE E.liked = 1 ORDER BY E.liked_date DESC LIMIT ?""", [i]);
      }
    }
    if (list.isNotEmpty) {
      for (var i in list) {
        episodes.add(EpisodeBrief(
            i['title'],
            i['enclosure_url'],
            i['enclosure_length'],
            i['milliseconds'],
            i['feed_title'],
            i['primaryColor'],
            i['duration'],
            i['explicit'],
            i['imagePath'],
            i['is_new']));
      }
    }

    return episodes;
  }

  Future setLiked(String url) async {
    var dbClient = await database;
    var milliseconds = DateTime.now().millisecondsSinceEpoch;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE Episodes SET liked = 1, liked_date = ? WHERE enclosure_url= ?",
          [milliseconds, url]);
    });
  }

  Future setUniked(String url) async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE Episodes SET liked = 0 WHERE enclosure_url = ?", [url]);
    });
  }

  Future<bool> isLiked(String url) async {
    var dbClient = await database;
    var list = <Map>[];
    list = await dbClient
        .rawQuery("SELECT liked FROM Episodes WHERE enclosure_url = ?", [url]);
    if (list.isNotEmpty) {
      return list.first['liked'] == 0 ? false : true;
    }
    return false;
  }

  Future<bool> isDownloaded(String url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        "SELECT id FROM Episodes WHERE enclosure_url = ? AND enclosure_url != media_id",
        [url]);
    return list.isNotEmpty;
  }

  Future<int?> saveDownloaded(String url, String? id) async {
    var dbClient = await database;
    var milliseconds = DateTime.now().millisecondsSinceEpoch;
    int? count;
    await dbClient.transaction((txn) async {
      count = await txn.rawUpdate(
          "UPDATE Episodes SET downloaded = ?, download_date = ? WHERE enclosure_url = ?",
          [id, milliseconds, url]);
    });
    return count;
  }

  Future<int?> saveMediaId(
      String url, String path, String? id, int size) async {
    var dbClient = await database;
    var milliseconds = DateTime.now().millisecondsSinceEpoch;
    int? count;
    await dbClient.transaction((txn) async {
      count = await txn.rawUpdate(
          "UPDATE Episodes SET enclosure_length = ?, media_id = ?, download_date = ?, downloaded = ? WHERE enclosure_url = ?",
          [size, path, milliseconds, id, url]);
    });
    return count;
  }

  Future<int?> delDownloaded(String url) async {
    var dbClient = await database;
    int? count;
    await dbClient.transaction((txn) async {
      count = await txn.rawUpdate(
          "UPDATE Episodes SET downloaded = 'ND', media_id = ? WHERE enclosure_url = ?",
          [url, url]);
    });
    developer.log('Deleted $url');
    return count;
  }

  Future<String?> getDescription(String url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECT description FROM Episodes WHERE enclosure_url = ?', [url]);
    String? description = list[0]['description'];
    return description;
  }

  Future saveEpisodeDes(String url, {String? description}) async {
    var dbClient = await database;
    await dbClient.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE Episodes SET description = ? WHERE enclosure_url = ?",
          [description, url]);
    });
  }

  Future<String?> getFeedDescription(String? id) async {
    var dbClient = await database;
    List<Map> list = await dbClient
        .rawQuery('SELECT description FROM PodcastLocal WHERE id = ?', [id]);
    String? description = list[0]['description'];
    return description;
  }

  Future<String?> getChapter(String url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECT chapter_link FROM Episodes WHERE enclosure_url = ?', [url]);
    String? chapter = list[0]['chapter_link'];
    return chapter;
  }

  Future<String?> getEpisodeImage(String url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        'SELECT episode_image FROM Episodes WHERE enclosure_url = ?', [url]);
    String? image = list[0]['episode_image'];
    return image;
  }

  Future<EpisodeBrief?> getRssItemWithUrl(String? url) async {
    var dbClient = await database;
    EpisodeBrief episode;
    List<Map> list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.skip_seconds, P.skip_seconds_end, 
        E.is_new, P.primaryColor, E.media_id, E.episode_image, E.chapter_link 
        FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.enclosure_url = ?""", [url]);
    if (list.isEmpty) {
      return null;
    } else {
      episode = EpisodeBrief(
          list.first['title'],
          list.first['enclosure_url'],
          list.first['enclosure_length'],
          list.first['milliseconds'],
          list.first['feed_title'],
          list.first['primaryColor'],
          list.first['duration'],
          list.first['explicit'],
          list.first['imagePath'],
          list.first['is_new'],
          mediaId: list.first['media_id'],
          skipSecondsStart: list.first['skip_seconds'],
          skipSecondsEnd: list.first['skip_seconds_end'],
          episodeImage: list.first['episode_image'],
          chapterLink: list.first['chapter_link']);
      return episode;
    }
  }

  Future<EpisodeBrief?> getRssItemWithMediaId(String id) async {
    var dbClient = await database;
    EpisodeBrief episode;
    List<Map> list = await dbClient.rawQuery(
        """SELECT E.title, E.enclosure_url, E.enclosure_length, E.milliseconds, P.imagePath,
        P.title as feed_title, E.duration, E.explicit, P.skip_seconds, P.skip_seconds_end,
        E.is_new, P.primaryColor, E.media_id, E.episode_image, E.chapter_link 
        FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.media_id = ?""", [id]);
    if (list.isEmpty) {
      return null;
    } else {
      episode = EpisodeBrief(
          list.first['title'],
          list.first['enclosure_url'],
          list.first['enclosure_length'],
          list.first['milliseconds'],
          list.first['feed_title'],
          list.first['primaryColor'],
          list.first['duration'],
          list.first['explicit'],
          list.first['imagePath'],
          list.first['is_new'],
          mediaId: list.first['media_id'],
          skipSecondsStart: list.first['skip_seconds'],
          skipSecondsEnd: list.first['skip_seconds_end'],
          episodeImage: list.first['episode_image'],
          chapterLink: list.first['chapter_link']);
      return episode;
    }
  }

  Future<String?> getImageUrl(String url) async {
    var dbClient = await database;
    List<Map> list = await dbClient.rawQuery(
        """SELECT P.imageUrl FROM Episodes E INNER JOIN PodcastLocal P ON E.feed_id = P.id 
        WHERE E.enclosure_url = ?""", [url]);
    if (list.isEmpty) return null;
    return list.first["imageUrl"];
  }
}
