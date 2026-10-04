package app.optifin.tv.core.playback

import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.ApiErrorKind
import app.optifin.tv.core.api.ApiException
import app.optifin.tv.core.api.BaseItemDtoQueryResult
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.api.MediaSegmentDtoQueryResult
import app.optifin.tv.core.api.MediaStream
import app.optifin.tv.core.api.PlaybackInfoResponse
import app.optifin.tv.core.api.PlaybackReportDto
import app.optifin.tv.core.api.RemoteSubtitleInfo
import app.optifin.tv.core.api.Urls
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.MediaRepository
import app.optifin.tv.core.settings.AppSettings
import app.optifin.tv.core.settings.SubtitleMode
import java.net.URLEncoder
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Préparation des lectures (PlaybackInfo), compléments et rapports de progression au serveur. */
class PlaybackService(private val api: JellyfinClient, private val userId: String) {

    /** Plan de lecture pour une décision de l'EngineSelector. */
    suspend fun prepare(
        itemId: String,
        startMs: Long,
        decision: EngineDecision?,
        caps: DeviceCapabilities,
        maxBitrate: Long,
        audioIndex: Int? = null,
        subtitleIndex: Int? = null,
        mediaSourceId: String? = null,
    ): PlaybackPlan {
        val profile: JsonObject = if (decision == null || decision.isNative) DeviceProfiles.native(caps, maxBitrate) else DeviceProfiles.mpv(maxBitrate)
        val delivery = decision?.delivery ?: Delivery.DirectPlay
        val body = buildJsonObject {
            put("UserId", userId)
            put("MaxStreamingBitrate", maxBitrate)
            put("StartTimeTicks", startMs * 10_000)
            put("DeviceProfile", profile)
            put("EnableDirectPlay", delivery == Delivery.DirectPlay)
            put("EnableDirectStream", delivery != Delivery.Transcode)
            put("EnableTranscoding", true)
            put("AllowVideoStreamCopy", decision?.reencodeVideo != true)
            put("AllowAudioStreamCopy", true)
            put("AutoOpenLiveStream", true)
            if (audioIndex != null) put("AudioStreamIndex", audioIndex)
            // -1 explicite : sans cela, le serveur pourrait incruster un sous-titre par défaut.
            put("SubtitleStreamIndex", subtitleIndex ?: -1)
            if (mediaSourceId != null) put("MediaSourceId", mediaSourceId)
        }
        val response: PlaybackInfoResponse = api.post("Items/$itemId/PlaybackInfo", JellyfinClient.json(body))
        return planFromResponse(response, itemId, api.baseUrl, startMs, audioIndex, subtitleIndex)
    }

    companion object {
        /** Réponse PlaybackInfo → plan (pur, testé). */
        fun planFromResponse(
            response: PlaybackInfoResponse,
            itemId: String,
            baseUrl: String,
            startMs: Long,
            requestedAudio: Int? = null,
            requestedSubtitle: Int? = null,
        ): PlaybackPlan {
            val code = response.errorCode
            if (!code.isNullOrEmpty() && code != "Unknown") throw ApiException(ApiErrorKind.PlaybackDenied, code)
            val source = response.mediaSources?.firstOrNull() ?: throw ApiException(ApiErrorKind.PlaybackDenied, "NoCompatibleStream")
            val method: PlayMethod
            val url: String
            val transcoding = source.transcodingUrl
            when {
                source.supportsDirectPlay == true -> {
                    method = PlayMethod.DirectPlay
                    url = Urls.resolve(baseUrl, "Videos/$itemId/stream", listOf(
                        "static" to "true", "mediaSourceId" to (source.id ?: itemId), "playSessionId" to response.playSessionId, "tag" to source.eTag,
                    )).toString()
                }
                transcoding != null -> {
                    method = if (source.supportsDirectStream == true) PlayMethod.DirectStream else PlayMethod.Transcode
                    url = Urls.resolve(baseUrl, withoutApiKey(transcoding)).toString()
                }
                else -> throw ApiException(ApiErrorKind.PlaybackDenied, "NoCompatibleStream")
            }
            val streams = source.mediaStreams.orEmpty().sortedBy { it.index ?: 0 }
            val audio = streams.filter { it.type == "Audio" && it.index != null }.map { track(it, TrackType.Audio, baseUrl) }
            val subtitles = streams.filter { it.type == "Subtitle" && it.index != null }.map { track(it, TrackType.Subtitle, baseUrl) }
            val video = streams.firstOrNull { it.type == "Video" }
            val defaultSub = requestedSubtitle ?: source.defaultSubtitleStreamIndex
            return PlaybackPlan(
                itemId = itemId,
                mediaSourceId = source.id ?: itemId,
                playSessionId = response.playSessionId,
                method = method,
                streamUrl = url,
                audioTracks = audio,
                subtitleTracks = subtitles,
                audioIndex = requestedAudio ?: source.defaultAudioStreamIndex ?: audio.firstOrNull()?.index,
                subtitleIndex = defaultSub?.takeIf { s -> s >= 0 && subtitles.any { it.index == s } },
                container = source.container,
                bitrate = source.bitrate,
                videoCodec = video?.codec,
                videoRangeType = video?.videoRangeType,
                startMs = startMs,
                runtimeMs = source.runTimeTicks?.div(10_000),
                source = SourceProfile.from(source),
            )
        }

        /** L'URL de transcodage contient la clé d'API : retirée (authentification par en-tête). */
        fun withoutApiKey(url: String): String {
            val q = url.indexOf('?')
            if (q < 0) return url
            val kept = url.substring(q + 1).split('&').filter {
                !it.startsWith("api_key=", ignoreCase = true) && !it.startsWith("ApiKey=", ignoreCase = true)
            }
            return if (kept.isEmpty()) url.substring(0, q) else url.substring(0, q) + "?" + kept.joinToString("&")
        }

        private fun track(s: MediaStream, type: TrackType, baseUrl: String): MediaTrack {
            val language = s.language
            val codec = s.codec?.lowercase()
            val fallback = listOfNotNull(
                language?.takeIf { it.isNotEmpty() }?.uppercase(), codec?.uppercase(),
                if (type == TrackType.Audio && s.channels != null) "${s.channels} can." else null,
            ).joinToString(" · ")
            return MediaTrack(
                index = s.index!!,
                type = type,
                label = s.displayTitle?.takeIf { it.isNotEmpty() } ?: fallback.ifEmpty { "Piste ${s.index}" },
                language = language,
                codec = codec,
                isDefault = s.isDefault ?: false,
                isForced = s.isForced ?: false,
                isExternal = s.isExternal ?: false,
                isTextBased = s.isTextSubtitleStream ?: true,
                deliveryUrl = s.deliveryUrl?.let { Urls.resolve(baseUrl, withoutApiKey(it)).toString() },
                deliveryMethod = s.deliveryMethod,
                channels = s.channels,
            )
        }

        fun chaptersFrom(chapters: List<app.optifin.tv.core.api.ChapterInfo>?): List<Chapter> =
            chapters.orEmpty().mapIndexed { i, c ->
                Chapter(i, (c.startPositionTicks ?: 0) / 10_000, c.name?.trim()?.ifEmpty { null } ?: "Chapitre ${i + 1}", c.imageTag)
            }.sortedBy { it.startMs }

        fun segmentsFrom(items: List<app.optifin.tv.core.api.MediaSegmentDto>): List<MediaSegment> = items.mapNotNull { d ->
            val type = when (d.type) {
                "Intro" -> SegmentType.Intro
                "Recap" -> SegmentType.Recap
                "Preview" -> SegmentType.Preview
                "Commercial" -> SegmentType.Commercial
                "Outro" -> SegmentType.Outro
                else -> null
            }
            val s = d.startTicks
            val e = d.endTicks
            if (type == null || s == null || e == null || e <= s) null else MediaSegment(type, s / 10_000, e / 10_000)
        }.sortedBy { it.startMs }

        /** Pistes à utiliser selon les préférences locales (pur, testé). */
        fun preferredTracks(plan: PlaybackPlan, settings: AppSettings): Pair<Int?, Int?> {
            var audio = plan.audioIndex
            val audioLang = normalizeLanguage(settings.audioLanguage)
            if (audioLang != null) {
                val matches = plan.audioTracks.filter { normalizeLanguage(it.language) == audioLang }
                if (matches.isNotEmpty() && matches.none { it.index == audio }) {
                    audio = (matches.firstOrNull { it.isDefault } ?: matches.first()).index
                }
            }
            val subLang = normalizeLanguage(settings.subtitleLanguage)
            val subs = plan.subtitleTracks
            fun inLang(tracks: List<MediaTrack>) = if (subLang == null) tracks else tracks.filter { normalizeLanguage(it.language) == subLang }
            val subtitle = when (settings.subtitleMode) {
                SubtitleMode.Server -> plan.subtitleIndex
                SubtitleMode.None -> null
                SubtitleMode.Always -> (inLang(subs.filter { !it.isForced }).firstOrNull() ?: inLang(subs).firstOrNull())?.index ?: plan.subtitleIndex
                SubtitleMode.ForcedOnly -> inLang(subs.filter { it.isForced }).firstOrNull()?.index
            }
            return audio to subtitle
        }

        private val languageAliases = mapOf(
            "fr" to "fre", "fra" to "fre", "fre" to "fre", "en" to "eng", "eng" to "eng", "es" to "spa", "spa" to "spa",
            "de" to "ger", "deu" to "ger", "ger" to "ger", "it" to "ita", "ita" to "ita", "pt" to "por", "por" to "por",
            "ja" to "jpn", "jpn" to "jpn", "ko" to "kor", "kor" to "kor", "zh" to "chi", "zho" to "chi", "chi" to "chi",
            "ru" to "rus", "rus" to "rus", "ar" to "ara", "ara" to "ara", "nl" to "dut", "nld" to "dut", "dut" to "dut",
        )

        fun normalizeLanguage(code: String?): String? {
            if (code.isNullOrEmpty()) return null
            val c = code.lowercase().split('-', '_').first()
            return languageAliases[c] ?: c
        }
    }

    // ------------------------------------------------------------ Compléments

    suspend fun extras(item: MediaItem, media: MediaRepository, mediaSourceId: String?): PlaybackExtras = coroutineScope {
        suspend fun <T> safe(what: String, call: suspend () -> T): T? = try {
            call()
        } catch (e: ApiException) {
            AppLog.w("extras", "$what indisponible : ${e.message}")
            null
        }
        val details = async {
            safe("chapitres") {
                api.get<BaseItemDtoQueryResult>("Users/$userId/Items",
                    listOf("Ids" to item.id, "Fields" to "Chapters,Trickplay", "EnableImages" to "false", "EnableTotalRecordCount" to "false"))
            }
        }
        val segments = async { safe("segments") { api.get<MediaSegmentDtoQueryResult>("MediaSegments/${item.id}") } }
        val next = async { if (item.kind == MediaKind.Episode) safe("épisode suivant") { media.nextEpisode(item) } else null }
        val dto = details.await()?.items?.firstOrNull()
        val trickplay = dto?.trickplay?.let { all ->
            val bySource = all[mediaSourceId] ?: all.values.firstOrNull()
            // Plus petite largeur ≥ 240 (légère à charger, lisible à l'écran).
            bySource?.entries?.sortedBy { it.key.toIntOrNull() ?: 0 }
                ?.firstOrNull { (it.key.toIntOrNull() ?: 0) >= 240 } ?: bySource?.entries?.firstOrNull()
        }?.value?.let { t ->
            if (t.width != null && t.height != null && t.tileWidth != null && t.tileHeight != null && t.thumbnailCount != null && t.interval != null)
                Trickplay(t.width, t.height, t.tileWidth, t.tileHeight, t.thumbnailCount, t.interval) else null
        }
        PlaybackExtras(
            chapters = chaptersFrom(dto?.chapters),
            segments = segmentsFrom(segments.await()?.items.orEmpty()),
            nextEpisode = next.await(),
            trickplay = trickplay,
        )
    }

    /** Sous-titres proposés par les fournisseurs du serveur (langue ISO 639-2). */
    suspend fun searchSubtitles(itemId: String, language: String): List<RemoteSubtitle> =
        RemoteSubtitle.from(api.get<List<RemoteSubtitleInfo>>("Items/$itemId/RemoteSearch/Subtitles/$language"))

    suspend fun downloadSubtitle(itemId: String, subtitleId: String) =
        api.postUnit("Items/$itemId/RemoteSearch/Subtitles/${URLEncoder.encode(subtitleId, "UTF-8")}")

    // ------------------------------------------------------------ Rapports

    private fun report(plan: PlaybackPlan, positionMs: Long, paused: Boolean) = PlaybackReportDto(
        itemId = plan.itemId, mediaSourceId = plan.mediaSourceId, playSessionId = plan.playSessionId, positionTicks = positionMs * 10_000,
        isPaused = paused, isMuted = false, canSeek = true, playMethod = plan.method.apiName, audioStreamIndex = plan.audioIndex,
        subtitleStreamIndex = plan.subtitleIndex ?: -1,
    )

    suspend fun reportStart(plan: PlaybackPlan, positionMs: Long) =
        safeReport("début") { api.postUnit("Sessions/Playing", JellyfinClient.json(report(plan, positionMs, false))) }

    suspend fun reportProgress(plan: PlaybackPlan, positionMs: Long, paused: Boolean) =
        safeReport("progression") { api.postUnit("Sessions/Playing/Progress", JellyfinClient.json(report(plan, positionMs, paused))) }

    suspend fun reportStopped(plan: PlaybackPlan, positionMs: Long, failed: Boolean = false) = safeReport("fin") {
        api.postUnit("Sessions/Playing/Stopped", JellyfinClient.json(PlaybackReportDto(
            itemId = plan.itemId, mediaSourceId = plan.mediaSourceId, playSessionId = plan.playSessionId,
            positionTicks = positionMs * 10_000, failed = failed,
        )))
    }

    /** Rapports au mieux : une coupure réseau n'interrompt jamais la lecture. */
    private suspend fun safeReport(what: String, call: suspend () -> Unit) {
        try {
            call()
        } catch (e: Exception) {
            if (e is kotlinx.coroutines.CancellationException) throw e
            AppLog.w("report", "Rapport « $what » non envoyé : ${e.message}")
        }
    }
}
