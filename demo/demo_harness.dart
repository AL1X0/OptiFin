import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin/app/app.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativeGlassView;
import 'package:optifin/core/design_system/design_system.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/network/retry_policy.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/core/storage/token_vault.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/auth/presentation/auth_providers.dart';
import 'package:optifin/features/downloads/data/file_transfers.dart';
import 'package:optifin/features/downloads/presentation/downloads_providers.dart';
import 'package:optifin/features/player/domain/device_capabilities.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/source_profile.dart';
import 'package:optifin/features/player/presentation/playback_providers.dart';
import 'package:optifin/features/settings/domain/app_settings.dart';
import 'package:optifin/features/settings/presentation/settings_providers.dart';

import 'demo_assets.dart';
import 'demo_engine.dart';
import 'demo_fonts.dart';
import 'demo_library.dart';
import 'demo_server.dart';

/// Taille logique d'un iPhone 15 Pro et zones sûres (portrait / paysage).
const phone = Size(393, 852);
const fps = 30;
const frameTime = Duration(microseconds: 1000000 ~/ fps);

class _MemoryVault implements TokenVault {
  final _m = <String, String>{};
  @override
  Future<String?> read(String accountId) async => _m[accountId];
  @override
  Future<void> write(String accountId, String token) async => _m[accountId] = token;
  @override
  Future<void> delete(String accountId) async => _m.remove(accountId);
}

/// App OptiFin réelle, branchée sur le serveur simulé et les illustrations générées.
class DemoHarness {
  DemoHarness(
    this.tester, {
    this.device = phone,
    this.tablet = false,
    this.tv = false,
    this.desktop = false,
    this.signedIn = true,
  });

  /// Ordinateur (Windows) : souris, barre latérale, 1440 × 900 logiques.
  final bool desktop;

  /// false : l'app démarre sur l'écran de connexion (serveur et profils simulés).
  final bool signedIn;

  final WidgetTester tester;

  /// Taille logique de l'appareil filmé (portrait).
  final Size device;

  /// iPad : pas d'îlot, marges de sécurité réduites.
  final bool tablet;

  /// Téléviseur (Android TV) : 960 × 540 logiques, télécommande, interface TV.
  final bool tv;

  double get _dpr => desktop ? 1 : (tv || tablet ? 2 : 3);
  final assets = DemoAssets();
  final _boundary = GlobalKey();
  final _touches = GlobalKey<_TouchesState>();
  late final AppDatabase db;
  DemoEngine? engine;
  bool landscape = false;

  Directory? _dir;
  int _frame = 0;

  /// Images où un doigt touche l'écran (bruitages synchronisés au montage).
  final _taps = <int>[];

  Future<void> setUp() async {
    debugDefaultTargetPlatformOverride = desktop
        ? TargetPlatform.windows
        : (tv ? TargetPlatform.android : TargetPlatform.iOS);
    OFDevice.tv = tv;
    OFDevice.desktop = desktop;
    OFGlass.blur = !tv;
    if (tv) {
      // Android simulé : flux Picture-in-Picture natif absent des tests.
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('optifin_native_player/pip'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
    NativeGlassView.enabled = false; // pas de vue native dans un rendu de test
    await tester.runAsync(() async {
      await loadDemoFonts();
      await assets.generate();
    });
    OFImageSource.override(assets.provider);
    _portrait();
    db = AppDatabase(NativeDatabase.memory());

    final session = ActiveSession(
      server: JellyfinServer(
        id: 'srv',
        name: 'Maison',
        baseUrl: Uri.parse('https://jellyfin.maison/jf'),
        version: '10.10.7',
      ),
      account: const Account(serverId: 'srv', userId: 'demo-user', userName: 'Léa'),
      token: 'demo',
    );
    const identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'iPhone', deviceId: 'demo', version: '1.0');
    final dio = createJellyfinDio(baseUrl: session.server.baseUrl, identity: identity, tokenProvider: () => 'demo')
      ..httpClientAdapter = DemoJellyfinAdapter()
      ..transformer = SyncTransformer();
    const caps = DeviceCapabilities(
      platform: DevicePlatform.ios,
      model: 'iPhone16,1',
      videoCodecs: {'h264', 'hevc', 'av1'},
      hevcMain10: true,
      ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hlg, DynamicRange.dolbyVision},
      dolbyVisionProfiles: {5, 8},
      audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'alac', 'flac'},
      containers: {'mp4', 'm4v', 'mov'},
      maxWidth: 3840,
      pictureInPicture: true,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: _boundary,
          child: _Touches(
            key: _touches,
            child: Stack(
              children: [
                ProviderScope(
                  retry: networkRetry,
                  overrides: [
                    appDatabaseProvider.overrideWithValue(db),
                    tokenVaultProvider.overrideWithValue(_MemoryVault()),
                    clientIdentityProvider.overrideWithValue(identity),
                    initialSessionProvider.overrideWithValue(signedIn ? session : null),
                    if (!signedIn) ...[
                      discoveredServersProvider.overrideWith(
                        (ref) => Stream.value([
                          DiscoveredServer(id: 'srv', name: 'Maison', address: Uri.parse('http://192.168.1.20:8096')),
                        ]),
                      ),
                      publicUsersProvider.overrideWith(
                        (ref, server) async => const [
                          PublicUser(id: 'u1', name: 'Léa', hasPassword: true),
                          PublicUser(id: 'u2', name: 'Hugo', hasPassword: true),
                          PublicUser(id: 'u3', name: 'Enfants', hasPassword: false),
                        ],
                      ),
                      quickConnectEnabledProvider.overrideWith((ref, server) async => true),
                    ],
                    initialSettingsProvider.overrideWithValue(const AppSettings()),
                    jellyfinDioProvider.overrideWithValue(dio),
                    fileTransfersProvider.overrideWithValue(_DemoTransfers()),
                    deviceCapabilitiesProvider.overrideWith((ref) async => caps),
                    maxBitrateResolverProvider.overrideWithValue(() async => 120000000),
                    playbackEngineFactoryProvider.overrideWithValue(
                      (kind) async => engine = DemoEngine(
                        assets.videoFrame,
                        durationOf: (id) => Duration(minutes: titleById(id).minutes),
                        name: kind == EngineKind.native ? 'AVPlayer' : 'mpv',
                      ),
                    ),
                  ],
                  child: const OptiFinApp(),
                ),
                _StatusBar(visible: () => !landscape && !tablet && !desktop),
              ],
            ),
          ),
        ),
      ),
    );
    // Toutes les illustrations décodées d'avance : aucune image ne « pop » pendant les captures.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(OptiFinApp));
      for (final p in assets.all) {
        await precacheImage(p, context);
      }
    });
  }

  void _portrait() {
    landscape = false;
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = device * _dpr;
    final pad = tablet
        ? const FakeViewPadding(top: 24 * 2, bottom: 20 * 2)
        : const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
  }

  void goLandscape() {
    landscape = true;
    tester.view.physicalSize = Size(device.height, device.width) * _dpr;
    final pad = tv || desktop
        ? FakeViewPadding.zero
        : tablet
        ? const FakeViewPadding(top: 24 * 2, bottom: 20 * 2)
        : const FakeViewPadding(left: 59 * 3, right: 59 * 3, bottom: 21 * 3);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
  }

  void goPortrait() => _portrait();

  Future<void> tearDown() async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    await tester.runAsync(db.close);
    debugDefaultTargetPlatformOverride = null;
    OFDevice.tv = false;
    OFDevice.desktop = false;
    OFGlass.blur = true;
    tester.view.reset();
  }

  GoRouter get router => GoRouter.of(tester.element(find.byType(Scaffold).first));

  // ------------------------------------------------------------ Captures

  void begin(String scene) {
    _dir = Directory('build/demo/frames/$scene')
      ..createSync(recursive: true)
      ..listSync().forEach((f) => f.deleteSync());
    _frame = 0;
    _taps.clear();
  }

  void _saveTaps() {
    final dir = _dir;
    if (dir != null) File('${dir.path}/taps.json').writeAsStringSync(jsonEncode(_taps));
  }

  /// Laisse le temps réel décoder ce qui doit l'être, sans avancer l'horloge.
  Future<void> _decode() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));

  Future<void> _capture() async {
    final dir = _dir;
    if (dir == null) return;
    final index = _frame++;
    await tester.runAsync(() async {
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${dir.path}/${index.toString().padLeft(5, '0')}.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  /// Avance d'une image (1/30 s) et la capture.
  Future<void> frame() async {
    await tester.pump(frameTime);
    await _capture();
  }

  Future<void> hold(Duration d) async {
    for (var i = 0; i < d.inMicroseconds ~/ frameTime.inMicroseconds; i++) {
      await frame();
    }
  }

  /// Avance sans capturer (mise en place hors champ).
  Future<void> idle(Duration d) async {
    for (var i = 0; i < d.inMicroseconds ~/ frameTime.inMicroseconds; i++) {
      await tester.pump(frameTime);
      if (i % 6 == 0) await _decode();
    }
  }

  Future<void> screenshot(String name) async {
    await tester.runAsync(() async {
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: desktop ? 1 : (tv ? 2 : (tablet ? 1 : 3)));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory('build/demo/shots').createSync(recursive: true);
      File('build/demo/shots/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  // ------------------------------------------------------------ Gestes filmés

  /// Toucher visible : le doigt apparaît, appuie, se relève.
  Future<void> tap(Finder finder) async {
    await tester.pump();
    final target = finder.hitTestable().first;
    await tester.ensureVisible(target);
    await tester.pump();
    final at = tester.getCenter(target);
    await tapAt(at);
  }

  Future<void> tapAt(Offset at) async {
    _taps.add(_frame);
    _saveTaps();
    await tester.pump(); // mise en page à jour avant le test de toucher
    final g = await tester.startGesture(at);
    for (var i = 0; i < 3; i++) {
      await frame();
    }
    await g.up();
    await frame();
  }

  /// Glissé filmé, avec accélération / décélération naturelles.
  Future<void> drag(Offset from, Offset by, Duration d, {bool fling = false}) async {
    final g = await tester.startGesture(from);
    final n = d.inMicroseconds ~/ frameTime.inMicroseconds;
    var done = Offset.zero;
    for (var i = 1; i <= n; i++) {
      final t = Curves.easeInOut.transform(i / n);
      final target = by * t;
      await g.moveBy(target - done);
      done = target;
      await frame();
    }
    if (!fling) {
      // Arrêt net : pas d'inertie.
      await g.moveBy(Offset.zero);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await g.up();
  }

  /// Saisie lettre par lettre, filmée.
  Future<void> type(Finder field, String text, {Duration perLetter = const Duration(milliseconds: 140)}) async {
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(field, text.substring(0, i));
      await hold(perLetter);
    }
  }
}

/// Barre d'état iOS (heure, îlot, réseau, batterie) dessinée au-dessus de l'app.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.visible});

  final bool Function() visible;

  @override
  Widget build(BuildContext context) {
    // Paysage (lecteur) : iOS masque la barre d'état.
    if (!visible() || MediaQuery.orientationOf(context) == Orientation.landscape) return const SizedBox.shrink();
    const style = TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
    return IgnorePointer(
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            const Positioned(left: 42, top: 17, child: Text('9:41', style: style)),
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 124,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const Positioned(
              right: 30,
              top: 17,
              child: Row(
                children: [
                  Icon(Icons.signal_cellular_alt_rounded, size: 17, color: Colors.white),
                  SizedBox(width: 5),
                  Icon(Icons.wifi_rounded, size: 17, color: Colors.white),
                  SizedBox(width: 5),
                  RotatedBox(quarterTurns: 1, child: Icon(Icons.battery_full_rounded, size: 20, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visualise les doigts (cercle blanc translucide) pour que les gestes se lisent à l'écran.
class _Touches extends StatefulWidget {
  const _Touches({super.key, required this.child});

  final Widget child;

  @override
  State<_Touches> createState() => _TouchesState();
}

class _Touch {
  _Touch(this.position);

  Offset position;
  bool down = true;
  double fade = 1;
}

class _TouchesState extends State<_Touches> with SingleTickerProviderStateMixin {
  final _touches = <int, _Touch>{};
  late final _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    setState(() {
      for (final t in _touches.values.where((t) => !t.down)) {
        t.fade -= dt / 0.25;
      }
      _touches.removeWhere((_, t) => t.fade <= 0);
    });
    if (_touches.isEmpty) {
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) {
      setState(() => _touches[e.pointer] = _Touch(e.localPosition));
      if (!_ticker.isActive) _ticker.start();
    },
    onPointerMove: (e) => setState(() => _touches[e.pointer]?.position = e.localPosition),
    onPointerUp: (e) => setState(() => _touches[e.pointer]?.down = false),
    child: Stack(
      children: [
        widget.child,
        for (final t in _touches.values)
          Positioned(
            left: t.position.dx - 24,
            top: t.position.dy - 24,
            child: IgnorePointer(
              child: Opacity(
                opacity: t.fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: t.down ? 1 : 1 + (1 - t.fade) * 0.4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Transferts simulés : aucune requête, fichiers dans un dossier temporaire.
class _DemoTransfers implements FileTransfers {
  final _updates = StreamController<TransferUpdate>.broadcast();

  @override
  Stream<TransferUpdate> get updates => _updates.stream;

  @override
  Future<String> rootPath() async => Directory.systemTemp.path;

  @override
  Future<void> start({
    required String taskId,
    required Uri url,
    required String relativePath,
    Map<String, String> headers = const {},
    bool wifiOnly = false,
    String? displayName,
  }) async {}

  @override
  Future<void> pause(String taskId) async {}

  @override
  Future<void> resume(String taskId) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<TransferStatus?> statusOf(String taskId) async => null;
}

extension DemoDownloads on DemoHarness {
  /// Quelques téléchargements fictifs (terminés, en cours, en pause) pour les captures.
  Future<void> seedDownloads() async {
    Future<void> add(String id, String status, double progress, int mb) async {
      final t = titleById(id);
      final dto = DemoJellyfinAdapter.dto(t, full: true);
      await tester.runAsync(
        () => db
            .into(db.downloads)
            .insert(
              DownloadsCompanion.insert(
                itemId: id,
                accountId: 'srv:demo-user',
                kind: t.seriesId == null ? 'movie' : 'episode',
                title: t.name,
                seriesId: Value(t.seriesId),
                itemJson: jsonEncode(dto),
                playbackJson: jsonEncode(DemoJellyfinAdapter.playbackInfo(id)),
                filePath: 'downloads/$id.mp4',
                sizeBytes: Value(mb * 1024 * 1024),
                progress: Value(progress),
                status: status,
                createdAt: DateTime.now().subtract(Duration(minutes: allTitles.indexOf(t))),
              ),
            ),
      );
    }

    await add('horizon', 'complete', 1, 4210);
    await add('nebuleuse', 'running', 0.46, 3120);
    await add('veilleurs-s1e1', 'complete', 1, 1480);
    await add('veilleurs-s1e2', 'complete', 1, 1395);
    await add('veilleurs-s1e3', 'paused', 0.18, 1510);
  }
}
