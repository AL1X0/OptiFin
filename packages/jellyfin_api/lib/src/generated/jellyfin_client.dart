// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/system_client.dart';
import 'clients/authentication_client.dart';
import 'clients/artist_client.dart';
import 'clients/audio_client.dart';
import 'clients/branding_client.dart';
import 'clients/collection_client.dart';
import 'clients/display_preference_client.dart';
import 'clients/filter_client.dart';
import 'clients/genre_client.dart';
import 'clients/instant_mix_client.dart';
import 'clients/library_client.dart';
import 'clients/user_data_client.dart';
import 'clients/live_tv_client.dart';
import 'clients/lyric_client.dart';
import 'clients/media_info_client.dart';
import 'clients/media_segment_client.dart';
import 'clients/movie_client.dart';
import 'clients/music_genre_client.dart';
import 'clients/person_client.dart';
import 'clients/playlist_client.dart';
import 'clients/session_client.dart';
import 'clients/search_client.dart';
import 'clients/studio_client.dart';
import 'clients/subtitle_client.dart';
import 'clients/suggestion_client.dart';
import 'clients/sync_play_client.dart';
import 'clients/trailer_client.dart';
import 'clients/trick_play_client.dart';
import 'clients/show_client.dart';
import 'clients/user_client.dart';
import 'clients/user_view_client.dart';
import 'clients/video_client.dart';
import 'clients/year_client.dart';

/// Jellyfin API `v12.1.0`
class JellyfinClient {
  JellyfinClient(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '12.1.0';

  SystemClient? _system;
  AuthenticationClient? _authentication;
  ArtistClient? _artist;
  AudioClient? _audio;
  BrandingClient? _branding;
  CollectionClient? _collection;
  DisplayPreferenceClient? _displayPreference;
  FilterClient? _filter;
  GenreClient? _genre;
  InstantMixClient? _instantMix;
  LibraryClient? _library;
  UserDataClient? _userData;
  LiveTvClient? _liveTv;
  LyricClient? _lyric;
  MediaInfoClient? _mediaInfo;
  MediaSegmentClient? _mediaSegment;
  MovieClient? _movie;
  MusicGenreClient? _musicGenre;
  PersonClient? _person;
  PlaylistClient? _playlist;
  SessionClient? _session;
  SearchClient? _search;
  StudioClient? _studio;
  SubtitleClient? _subtitle;
  SuggestionClient? _suggestion;
  SyncPlayClient? _syncPlay;
  TrailerClient? _trailer;
  TrickPlayClient? _trickPlay;
  ShowClient? _show;
  UserClient? _user;
  UserViewClient? _userView;
  VideoClient? _video;
  YearClient? _year;

  SystemClient get system => _system ??= SystemClient(_dio, baseUrl: _baseUrl);

  AuthenticationClient get authentication => _authentication ??= AuthenticationClient(_dio, baseUrl: _baseUrl);

  ArtistClient get artist => _artist ??= ArtistClient(_dio, baseUrl: _baseUrl);

  AudioClient get audio => _audio ??= AudioClient(_dio, baseUrl: _baseUrl);

  BrandingClient get branding => _branding ??= BrandingClient(_dio, baseUrl: _baseUrl);

  CollectionClient get collection => _collection ??= CollectionClient(_dio, baseUrl: _baseUrl);

  DisplayPreferenceClient get displayPreference => _displayPreference ??= DisplayPreferenceClient(_dio, baseUrl: _baseUrl);

  FilterClient get filter => _filter ??= FilterClient(_dio, baseUrl: _baseUrl);

  GenreClient get genre => _genre ??= GenreClient(_dio, baseUrl: _baseUrl);

  InstantMixClient get instantMix => _instantMix ??= InstantMixClient(_dio, baseUrl: _baseUrl);

  LibraryClient get library => _library ??= LibraryClient(_dio, baseUrl: _baseUrl);

  UserDataClient get userData => _userData ??= UserDataClient(_dio, baseUrl: _baseUrl);

  LiveTvClient get liveTv => _liveTv ??= LiveTvClient(_dio, baseUrl: _baseUrl);

  LyricClient get lyric => _lyric ??= LyricClient(_dio, baseUrl: _baseUrl);

  MediaInfoClient get mediaInfo => _mediaInfo ??= MediaInfoClient(_dio, baseUrl: _baseUrl);

  MediaSegmentClient get mediaSegment => _mediaSegment ??= MediaSegmentClient(_dio, baseUrl: _baseUrl);

  MovieClient get movie => _movie ??= MovieClient(_dio, baseUrl: _baseUrl);

  MusicGenreClient get musicGenre => _musicGenre ??= MusicGenreClient(_dio, baseUrl: _baseUrl);

  PersonClient get person => _person ??= PersonClient(_dio, baseUrl: _baseUrl);

  PlaylistClient get playlist => _playlist ??= PlaylistClient(_dio, baseUrl: _baseUrl);

  SessionClient get session => _session ??= SessionClient(_dio, baseUrl: _baseUrl);

  SearchClient get search => _search ??= SearchClient(_dio, baseUrl: _baseUrl);

  StudioClient get studio => _studio ??= StudioClient(_dio, baseUrl: _baseUrl);

  SubtitleClient get subtitle => _subtitle ??= SubtitleClient(_dio, baseUrl: _baseUrl);

  SuggestionClient get suggestion => _suggestion ??= SuggestionClient(_dio, baseUrl: _baseUrl);

  SyncPlayClient get syncPlay => _syncPlay ??= SyncPlayClient(_dio, baseUrl: _baseUrl);

  TrailerClient get trailer => _trailer ??= TrailerClient(_dio, baseUrl: _baseUrl);

  TrickPlayClient get trickPlay => _trickPlay ??= TrickPlayClient(_dio, baseUrl: _baseUrl);

  ShowClient get show => _show ??= ShowClient(_dio, baseUrl: _baseUrl);

  UserClient get user => _user ??= UserClient(_dio, baseUrl: _baseUrl);

  UserViewClient get userView => _userView ??= UserViewClient(_dio, baseUrl: _baseUrl);

  VideoClient get video => _video ??= VideoClient(_dio, baseUrl: _baseUrl);

  YearClient get year => _year ??= YearClient(_dio, baseUrl: _baseUrl);
}
