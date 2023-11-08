[![Tsacdop Banner][]][google play]

[![github action][]][github action link]
[![GitHub Release][]][github release - recent]
[![Github Downloads][]][github release - recent]
[![style: effective dart][]][effective dart pub]
[![License badge][]][license]
[![fdroid install][]][fdroid link]

## About

Enjoy podcasts.

Tsacdop is a podcast player developed with Flutter, a clean, simply beautiful, and friendly app, which is also free and open source.

Credit to the Flutter team and all involved plugins, especially [webfeed](https://github.com/witochandra/webfeed), [Just_Audio](https://pub.dev/packages/just_audio), and [Provider](https://pub.dev/packages/provider).

The podcast search engine is powered by, [ListenNotes](https://listennotes.com) & [PodcastIndex](https://podcastindex.org/).

## Features

* Podcast group management
* Playlists support
* Sleep timer / speed setting
* OPML file export and import
* Auto-syncing in the background
* Listening and subscription history record
* Dark mode / accent color
* Download for offline play
* Auto-download new episodes / auto-delete outdated downloads
* Settings backup
* Skip silence
* Boost volume

More to come...

## Preview

| Home Page | Group | Podcast | Episode| Dark Mode |
| ----- | ----- | ----- | ------ | ----- |
|![][Homepage ScreenShot]|![][Group Screenshot] | ![][Podcast Screenshot] | ![][Episode Screenshot]| ![][Darkmode Screenshot] |

## Localization

Please [Email](mailto:<tsacdop.app@gmail.com>) me you'd like to contribute to support more languages!

Credit to [Localizely](https://localizely.com/) for kind support to open source projects.

### ![English]

### ![Chinese Simplified]

### ![French] 

### ![Spanish]

### ![Portuguese]

## License

Tsacdop is licensed under the [GPL v3.0](https://github.com/stonega/tsacdop/blob/master/LICENSE) license.

## Build

1. If you don't have Flutter SDK installed; Please visit the official [Flutter][Flutter Install] site.
2. Fetch the latest source code from the master branch.

``` 
git clone https://github.com/stonega/tsacdop.git
```

3. Add api search api configure file.  

Tsacdop uses the ListenNotes API 1.0 pro to search for podcasts, which is not free, so I can not expose the API key in the repo.
If you want to build the app, you need to create a new file named `.env.dart` in the lib folder. Add the following code to `.env.dart`. If you don't have a ListenNotes api key, keep the apiKey empty like ''. Then the app will only support the PodcastIndex search.
You can get your own ListenNotes API key on [ListenNotes](https://www.listennotes.com/api/). Remember that you need to get a pro plan API because the basic plan doesn't provide an rss link for the search result. 

``` dart
final environment = {"apiKey":""};
