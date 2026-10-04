package app.optifin.tv

import app.optifin.tv.core.api.BaseItemDto
import app.optifin.tv.core.api.ClientIdentity
import app.optifin.tv.core.api.JellyfinJson
import app.optifin.tv.core.api.MediaSourceInfo
import app.optifin.tv.core.api.MediaStream
import app.optifin.tv.core.api.PlaybackInfoResponse
import app.optifin.tv.core.api.UserItemDataDto
import app.optifin.tv.core.api.Urls
import app.optifin.tv.core.auth.ServerAddress
import app.optifin.tv.core.auth.ServerDiscovery
import app.optifin.tv.core.media.MediaFormat
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.MediaMapper
import app.optifin.tv.core.media.QualityBadges
import app.optifin.tv.core.playback.Delivery
import app.optifin.tv.core.playback.DeviceCapabilities
import app.optifin.tv.core.playback.DynamicRange
import app.optifin.tv.core.playback.EngineKind
import app.optifin.tv.core.playback.EnginePreference
import app.optifin.tv.core.playback.EngineSelector
import app.optifin.tv.core.playback.PlayMethod
import app.optifin.tv.core.playback.PlaybackService
import app.optifin.tv.core.playback.SelectionRequest
import app.optifin.tv.core.playback.SourceProfile
import app.optifin.tv.core.playback.SubtitleInfo
import app.optifin.tv.core.playback.SubtitleRoute
import app.optifin.tv.core.playback.VideoInfo
import app.optifin.tv.core.playback.AudioInfo
import app.optifin.tv.core.settings.AppSettings
import app.optifin.tv.core.settings.SubtitleMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CoreTest {
    @Test
    fun `adresses de serveur candidates`() {
        assertEquals(listOf("https://jelly.local", "http://jelly.local", "http://jelly.local:8096"), ServerAddress.candidates(" jelly.local/ "))
        assertEquals(listOf("https://h:8920", "http://h:8920"), ServerAddress.candidates("h:8920"))
        assertEquals(listOf("https://h.fr/jellyfin"), ServerAddress.candidates("https://H.fr/jellyfin/"))
        assertEquals(emptyList<String>(), ServerAddress.candidates("ftp://x"))
        assertTrue(ServerAddress.isSupportedVersion("10.9.1"))
        assertTrue(ServerAddress.isSupportedVersion("12.1.0"))
        assertFalse(ServerAddress.isSupportedVersion("10.8.13"))
    }

    @Test
    fun `réponse de découverte UDP`() {
        val s = ServerDiscovery.parse("""{"Address":"http://192.168.1.5:8096","Id":"abc","Name":"Salon"}""")!!
        assertEquals("Salon", s.name)
        assertEquals("http://192.168.1.5:8096", s.address)
        assertNull(ServerDiscovery.parse("pas du json"))
    }

    @Test
    fun `URL serveur avec sous-chemin et requête`() {
        val url = Urls.resolve("https://h.fr/jellyfin", "Videos/1/master.m3u8?a=1", listOf("b" to "x y", "c" to null))
        assertEquals("https://h.fr/jellyfin/Videos/1/master.m3u8?a=1&b=x%20y", url.toString())
        assertEquals("/Items", Urls.resolve("http://h:8096", "/Items").encodedPath)
    }

    @Test
    fun `en-tête d'authentification encodé`() {
        val h = ClientIdentity("OptiFin TV", "Salon \"TV\"", "id", "1.2.3").authorizationHeader("tok")
        assertTrue(h.startsWith("MediaBrowser Client=\"OptiFin%20TV\""))
        assertTrue(h.contains("Device=\"Salon%20%22TV%22\""))
        assertTrue(h.endsWith("Token=\"tok\""))
    }

    @Test
    fun `élément Jellyfin converti`() {
        val dto = JellyfinJson.decodeFromString(BaseItemDto.serializer(), """
            {"Id":"e1","Name":"Pilote","Type":"Episode","IndexNumber":3,"ParentIndexNumber":1,"SeriesId":"s","SeriesPrimaryImageTag":"sp",
             "UserData":{"PlayedPercentage":40,"PlaybackPositionTicks":6000000000},"RunTimeTicks":36000000000,
             "Overview":"Un <b>début</b><br/>fort &amp; tendu","ImageTags":{"Primary":"p"},"UnknownField":1}
        """.trimIndent())
        val item = MediaMapper.fromDto(dto)
        assertEquals(MediaKind.Episode, item.kind)
        assertEquals("S1 · É3", item.episodeLabel)
        assertEquals("Un début\nfort & tendu", item.overview)
        assertEquals("s", item.poster?.itemId)
        assertEquals(0.4, item.user.progress!!, 0.001)
        assertEquals("50 min restantes", MediaFormat.remaining(item))
    }

    @Test
    fun `mise en forme`() {
        assertEquals("2 h 05 min", MediaFormat.duration(125 * 60_000L))
        assertEquals("1:02:03", MediaFormat.clock(3_723_000))
        assertEquals("4:05", MediaFormat.clock(245_000))
        assertEquals(listOf("4K", "Dolby Vision", "Atmos", "7.1"), QualityBadges.forStreams(listOf(
            app.optifin.tv.core.media.StreamSummary(true, "hevc", 3840, 1600, app.optifin.tv.core.media.VideoRange.DolbyVision),
            app.optifin.tv.core.media.StreamSummary(false, "truehd", channels = 8, spatial = app.optifin.tv.core.media.SpatialAudio.Atmos),
        )))
    }

    private val tv4k = DeviceCapabilities(
        videoCodecs = setOf("h264", "hevc", "vp9", "av1"), hevcMain10 = true,
        ranges = setOf(DynamicRange.Sdr, DynamicRange.Hdr10, DynamicRange.Hlg), maxWidth = 3840,
    )

    private fun source(container: String, video: VideoInfo, audio: String = "aac", subtitle: SubtitleInfo? = null, bitrate: Long = 20_000_000) =
        SourceProfile(container, bitrate, video, listOf(AudioInfo(1, audio)), listOfNotNull(subtitle))

    @Test
    fun `sélection du moteur sur TV`() {
        // MKV HEVC 10 bits HDR10 + TrueHD : natif en lecture directe (FFmpeg pour l'audio).
        var s = EngineSelector.select(SelectionRequest(
            source("mkv", VideoInfo("hevc", bitDepth = 10, width = 3840, height = 2160, range = DynamicRange.Hdr10), "truehd"), tv4k))
        assertEquals(EngineKind.Native, s.primary.engine)
        assertEquals(Delivery.DirectPlay, s.primary.delivery)
        assertEquals(EngineKind.Mpv, s.fallbacks.first().engine)

        // PGS intégrés en lecture directe : natif, sous-titres rendus par Media3.
        s = EngineSelector.select(SelectionRequest(
            source("mkv", VideoInfo("h264", width = 1920), subtitle = SubtitleInfo(3, "pgssub", isText = false)), tv4k, subtitleIndex = 3))
        assertEquals(EngineKind.Native, s.primary.engine)
        assertEquals(SubtitleRoute.Engine, s.primary.subtitles)

        // Conteneur WMV : remux natif ; avec PGS (perdus au remux) : mpv en direct.
        s = EngineSelector.select(SelectionRequest(source("wmv", VideoInfo("h264", width = 1920)), tv4k))
        assertEquals(Delivery.Remux, s.primary.delivery)
        s = EngineSelector.select(SelectionRequest(
            source("wmv", VideoInfo("h264", width = 1920), subtitle = SubtitleInfo(3, "pgssub", isText = false)), tv4k, subtitleIndex = 3))
        assertEquals(EngineKind.Mpv, s.primary.engine)

        // VC-1 non décodé par le natif : mpv (logiciel, 1080p).
        s = EngineSelector.select(SelectionRequest(source("mkv", VideoInfo("vc1", width = 1920)), tv4k))
        assertEquals(EngineKind.Mpv, s.primary.engine)

        // Débit au-delà de la limite : transcodage.
        s = EngineSelector.select(SelectionRequest(source("mkv", VideoInfo("h264", width = 1920), bitrate = 80_000_000), tv4k, maxBitrate = 20_000_000))
        assertEquals(Delivery.Transcode, s.primary.delivery)

        // HDR10 sur un écran SDR : mpv (tone-mapping), sinon transcodage.
        s = EngineSelector.select(SelectionRequest(
            source("mkv", VideoInfo("hevc", bitDepth = 10, width = 1920, range = DynamicRange.Hdr10)), tv4k.copy(ranges = setOf(DynamicRange.Sdr))))
        assertEquals(EngineKind.Mpv, s.primary.engine)

        // Préférence mpv.
        s = EngineSelector.select(SelectionRequest(source("mp4", VideoInfo("h264", width = 1920)), tv4k, preference = EnginePreference.Mpv))
        assertEquals(EngineKind.Mpv, s.primary.engine)
    }

    @Test
    fun `plan de lecture depuis PlaybackInfo`() {
        val response = PlaybackInfoResponse(
            playSessionId = "ps",
            mediaSources = listOf(MediaSourceInfo(
                id = "src", container = "mkv", supportsDirectPlay = false, supportsDirectStream = true,
                transcodingUrl = "/videos/i/master.m3u8?MediaSourceId=src&api_key=SECRET&VideoCodec=hevc",
                defaultAudioStreamIndex = 1, defaultSubtitleStreamIndex = 3,
                mediaStreams = listOf(
                    MediaStream(type = "Video", index = 0, codec = "hevc"),
                    MediaStream(type = "Audio", index = 1, codec = "eac3", language = "fre", displayTitle = "Français"),
                    MediaStream(type = "Subtitle", index = 3, codec = "srt", deliveryMethod = "External",
                        deliveryUrl = "/Videos/i/src/Subtitles/3/0/Stream.srt?api_key=SECRET"),
                ),
            )),
        )
        val plan = PlaybackService.planFromResponse(response, "i", "https://h.fr/jf", 5000)
        assertEquals(PlayMethod.DirectStream, plan.method)
        assertFalse(plan.streamUrl.contains("SECRET"))
        assertEquals("https://h.fr/jf/videos/i/master.m3u8?MediaSourceId=src&VideoCodec=hevc", plan.streamUrl)
        assertEquals(3, plan.subtitleIndex)
        assertEquals("https://h.fr/jf/Videos/i/src/Subtitles/3/0/Stream.srt", plan.currentSubtitle?.deliveryUrl)
        assertTrue(plan.embedded(app.optifin.tv.core.playback.TrackType.Subtitle).isEmpty())
    }

    @Test
    fun `préférences de pistes`() {
        val plan = PlaybackService.planFromResponse(PlaybackInfoResponse(mediaSources = listOf(MediaSourceInfo(
            id = "s", supportsDirectPlay = true, defaultAudioStreamIndex = 1,
            mediaStreams = listOf(
                MediaStream(type = "Audio", index = 1, codec = "aac", language = "eng"),
                MediaStream(type = "Audio", index = 2, codec = "ac3", language = "fra"),
                MediaStream(type = "Subtitle", index = 3, codec = "srt", language = "fre", isForced = true),
                MediaStream(type = "Subtitle", index = 4, codec = "srt", language = "fre"),
            ),
        ))), "i", "http://h", 0)
        val settings = AppSettings(audioLanguage = "fre", subtitleLanguage = "fre", subtitleMode = SubtitleMode.Always)
        assertEquals(2 to 4, PlaybackService.preferredTracks(plan, settings))
        assertEquals(2 to 3, PlaybackService.preferredTracks(plan, settings.copy(subtitleMode = SubtitleMode.ForcedOnly)))
        assertEquals(2 to null, PlaybackService.preferredTracks(plan, settings.copy(subtitleMode = SubtitleMode.None)))
    }

    @Test
    fun `état utilisateur et progression`() {
        val d = UserItemDataDto(played = false, playedPercentage = 100.0)
        assertNull(app.optifin.tv.core.media.UserState(playedPercentage = d.playedPercentage).progress)
    }
}
