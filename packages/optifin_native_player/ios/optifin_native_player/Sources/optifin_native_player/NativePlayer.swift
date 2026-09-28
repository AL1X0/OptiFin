import AVFoundation
import AVKit
import Flutter

/// Un lecteur AVPlayer piloté depuis Dart.
///
/// Canal de commandes `optifin_native_player/player_<id>`, événements sur
/// `optifin_native_player/events_<id>` : `state` (position, durée, tampon,
/// lecture, taille vidéo, images perdues), `error`, `completed`.
/// Les sous-titres sont dessinés par OptiFin : aucune piste « legible » n'est sélectionnée.
/// Picture-in-Picture : automatique quand l'app passe en arrière-plan pendant la lecture,
/// ou sur demande (`startPip`) ; événement `pip` à chaque changement.
final class NativePlayer: NSObject, FlutterStreamHandler, AVPictureInPictureControllerDelegate {
  let id: Int
  let player = AVPlayer()

  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var pending: [[String: Any]] = []
  private var timeObserver: Any?
  private var playerObservations: [NSKeyValueObservation] = []
  private var itemObservations: [NSKeyValueObservation] = []
  private var notificationTokens: [NSObjectProtocol] = []
  private let onDispose: () -> Void

  private var started = false
  private var ended = false
  private var disposed = false
  private var desiredRate: Float = 1
  private var startTime: CMTime = .zero
  private var pipController: AVPictureInPictureController?

  var gravity: AVLayerVideoGravity = .resizeAspect {
    didSet { view?.gravity = gravity }
  }

  weak var view: PlayerLayerView? {
    didSet {
      view?.player = player
      view?.gravity = gravity
      setUpPictureInPicture()
    }
  }

  private func setUpPictureInPicture() {
    guard let layer = view?.playerLayer, AVPictureInPictureController.isPictureInPictureSupported() else { return }
    let pip = AVPictureInPictureController(playerLayer: layer)
    pip?.delegate = self
    if #available(iOS 14.2, *) {
      pip?.canStartPictureInPictureAutomaticallyFromInline = true
    }
    pipController = pip
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    send(["event": "pip", "active": true])
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    send(["event": "pip", "active": false])
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    send(["event": "pip", "active": false, "error": error.localizedDescription])
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }

  init(id: Int, messenger: FlutterBinaryMessenger, onDispose: @escaping () -> Void) {
    self.id = id
    self.onDispose = onDispose
    channel = FlutterMethodChannel(name: "optifin_native_player/player_\(id)", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "optifin_native_player/events_\(id)", binaryMessenger: messenger)
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.handle(call, result: result)
    }
    eventChannel.setStreamHandler(self)

    player.automaticallyWaitsToMinimizeStalling = true
    player.appliesMediaSelectionCriteriaAutomatically = false
    // AirPlay : la vidéo part sur l'Apple TV, l'iPhone devient la télécommande.
    player.allowsExternalPlayback = true
    player.usesExternalPlaybackWhileExternalScreenIsActive = true
    playerObservations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      self?.emitState()
    })
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(value: 250, timescale: 1000),
      queue: .main
    ) { [weak self] _ in
      self?.emitState()
    }
  }

  // MARK: - Événements

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    for event in pending { events(event) }
    pending.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  /// Les notifications KVO peuvent arriver hors du thread principal ; Flutter exige celui-ci.
  private func send(_ event: [String: Any]) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in self?.send(event) }
      return
    }
    if let sink { sink(event) } else { pending.append(event) }
  }

  private func sendError(_ message: String) {
    send(["event": "error", "message": message, "startup": !started])
  }

  private func emitState() {
    guard !disposed else { return }
    let item = player.currentItem
    let position = player.currentTime().seconds
    let duration = item?.duration.seconds ?? 0
    var buffered = 0.0
    if let ranges = item?.loadedTimeRanges.map({ $0.timeRangeValue }) {
      for range in ranges where range.containsTime(player.currentTime()) || range.start.seconds > position {
        buffered = max(buffered, range.end.seconds)
      }
    }
    let size = item?.presentationSize ?? .zero
    let status: String
    if ended {
      status = "ended"
    } else if started {
      status = "ready"
    } else {
      status = "loading"
    }
    send([
      "event": "state",
      "status": status,
      "playing": player.timeControlStatus == .playing,
      "buffering": player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
      "positionMs": Int((position.isFinite ? position : 0) * 1000),
      "durationMs": Int((duration.isFinite ? duration : 0) * 1000),
      "bufferedMs": Int((buffered.isFinite ? buffered : 0) * 1000),
      "rate": Double(desiredRate),
      "width": Double(size.width),
      "height": Double(size.height),
      "droppedFrames": item?.accessLog()?.events.last?.numberOfDroppedVideoFrames ?? 0,
    ])
  }

  // MARK: - Commandes

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "open":
      open(args)
      result(nil)
    case "play":
      ended = false
      player.playImmediately(atRate: desiredRate)
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      let ms = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      ended = false
      player.seek(to: CMTime(value: ms, timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
        self?.emitState()
      }
      result(nil)
    case "setRate":
      desiredRate = Float((args["rate"] as? NSNumber)?.doubleValue ?? 1)
      if player.timeControlStatus != .paused { player.rate = desiredRate }
      emitState()
      result(nil)
    case "selectAudio":
      selectAudio(args["ordinal"] as? Int)
      result(nil)
    case "setFit":
      switch args["fit"] as? String {
      case "cover": gravity = .resizeAspectFill
      case "fill": gravity = .resize
      default: gravity = .resizeAspect
      }
      result(nil)
    case "startPip":
      pipController?.startPictureInPicture()
      result(pipController != nil)
    case "stopPip":
      pipController?.stopPictureInPicture()
      result(nil)
    case "dispose":
      dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func open(_ args: [String: Any]) {
    guard let raw = args["url"] as? String, let url = URL(string: raw) else {
      return sendError("URL invalide")
    }
    let headers = args["headers"] as? [String: String] ?? [:]
    let startMs = (args["startMs"] as? NSNumber)?.int64Value ?? 0
    let audioOrdinal = args["audioOrdinal"] as? Int
    started = false
    ended = false
    startTime = CMTime(value: startMs, timescale: 1000)
    configureAudioSession()

    // En-têtes (Authorization) : clé reconnue par AVURLAsset, le token n'apparaît jamais dans l'URL.
    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    let item = AVPlayerItem(asset: asset)
    observe(item, audioOrdinal: audioOrdinal)
    player.replaceCurrentItem(with: item)
    emitState()
  }

  private func observe(_ item: AVPlayerItem, audioOrdinal: Int?) {
    itemObservations.forEach { $0.invalidate() }
    itemObservations.removeAll()
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    notificationTokens.removeAll()

    itemObservations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      switch item.status {
      case .readyToPlay:
        guard !self.started else { return }
        self.disableLegibleTracks(item)
        if let audioOrdinal { self.selectAudio(audioOrdinal) }
        let begin = { [weak self] in
          guard let self else { return }
          self.started = true
          self.player.playImmediately(atRate: self.desiredRate)
          self.emitState()
        }
        if self.startTime > .zero {
          item.seek(to: self.startTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in begin() }
        } else {
          begin()
        }
      case .failed:
        self.sendError(Self.describe(item.error))
      default:
        break
      }
    })
    itemObservations.append(item.observe(\.presentationSize, options: [.new]) { [weak self] _, _ in
      self?.emitState()
    })
    itemObservations.append(item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, _ in
      self?.emitState()
    })

    let center = NotificationCenter.default
    notificationTokens.append(center.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.ended = true
      self.emitState()
      self.send(["event": "completed"])
    })
    notificationTokens.append(center.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
    ) { [weak self] note in
      let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self?.sendError(Self.describe(error))
    })
  }

  /// Message d'erreur détaillé (domaine, code, cause) : indispensable pour diagnostiquer
  /// un fichier refusé par AVFoundation (-11828 format non pris en charge, etc.).
  private static func describe(_ error: Error?) -> String {
    guard let error = error as NSError? else { return "Erreur AVPlayer inconnue" }
    var parts = ["\(error.domain) \(error.code) : \(error.localizedDescription)"]
    if let reason = error.localizedFailureReason { parts.append(reason) }
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      parts.append("cause \(underlying.domain) \(underlying.code) : \(underlying.localizedDescription)")
    }
    return parts.joined(separator: " — ")
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
    try? session.setActive(true)
  }

  private func disableLegibleTracks(_ item: AVPlayerItem) {
    Task { @MainActor in
      if let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) {
        item.select(nil, in: group)
      }
    }
  }

  private func selectAudio(_ ordinal: Int?) {
    guard let item = player.currentItem else { return }
    Task { @MainActor in
      guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
      if let ordinal, ordinal >= 0, ordinal < group.options.count {
        item.select(group.options[ordinal], in: group)
      } else {
        item.selectMediaOptionAutomatically(in: group)
      }
    }
  }

  func dispose() {
    guard !disposed else { return }
    disposed = true
    player.pause()
    pipController?.stopPictureInPicture()
    pipController = nil
    if let timeObserver { player.removeTimeObserver(timeObserver) }
    timeObserver = nil
    playerObservations.forEach { $0.invalidate() }
    itemObservations.forEach { $0.invalidate() }
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    player.replaceCurrentItem(with: nil)
    view?.player = nil
    channel.setMethodCallHandler(nil)
    eventChannel.setStreamHandler(nil)
    sink = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    onDispose()
  }
}
