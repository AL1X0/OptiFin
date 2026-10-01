using System.Runtime.InteropServices;

namespace OptiFin.Mpv;

/// <summary>API client de libmpv (mpv/client.h), appels natifs générés à la compilation (NativeAOT).</summary>
internal static unsafe partial class MpvNative
{
    private const string Lib = "libmpv-2.dll";

    public const int FormatNone = 0;
    public const int FormatString = 1;
    public const int FormatFlag = 3;
    public const int FormatInt64 = 4;
    public const int FormatDouble = 5;

    public const int EventNone = 0;
    public const int EventShutdown = 1;
    public const int EventLogMessage = 2;
    public const int EventStartFile = 6;
    public const int EventEndFile = 7;
    public const int EventFileLoaded = 8;
    public const int EventVideoReconfig = 17;
    public const int EventPlaybackRestart = 21;
    public const int EventPropertyChange = 22;

    public const int EndFileEof = 0;
    public const int EndFileStop = 2;
    public const int EndFileQuit = 3;
    public const int EndFileError = 4;

    [StructLayout(LayoutKind.Sequential)]
    public struct Event
    {
        public int EventId;
        public int Error;
        public ulong ReplyUserdata;
        public nint Data;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropertyData
    {
        public nint Name;
        public int Format;
        public nint Data;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LogMessageData
    {
        public nint Prefix;
        public nint Level;
        public nint Text;
        public int LogLevel;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct EndFileData
    {
        public int Reason;
        public int Error;
    }

    [LibraryImport(Lib, EntryPoint = "mpv_create")]
    public static partial nint Create();

    [LibraryImport(Lib, EntryPoint = "mpv_initialize")]
    public static partial int Initialize(nint ctx);

    [LibraryImport(Lib, EntryPoint = "mpv_terminate_destroy")]
    public static partial void TerminateDestroy(nint ctx);

    [LibraryImport(Lib, EntryPoint = "mpv_set_option_string", StringMarshalling = StringMarshalling.Utf8)]
    public static partial int SetOptionString(nint ctx, string name, string data);

    [LibraryImport(Lib, EntryPoint = "mpv_set_property_string", StringMarshalling = StringMarshalling.Utf8)]
    public static partial int SetPropertyString(nint ctx, string name, string data);

    [LibraryImport(Lib, EntryPoint = "mpv_get_property_string", StringMarshalling = StringMarshalling.Utf8)]
    public static partial nint GetPropertyString(nint ctx, string name);

    [LibraryImport(Lib, EntryPoint = "mpv_get_property", StringMarshalling = StringMarshalling.Utf8)]
    public static partial int GetProperty(nint ctx, string name, int format, void* data);

    [LibraryImport(Lib, EntryPoint = "mpv_command")]
    public static partial int Command(nint ctx, nint* args);

    [LibraryImport(Lib, EntryPoint = "mpv_observe_property", StringMarshalling = StringMarshalling.Utf8)]
    public static partial int ObserveProperty(nint ctx, ulong replyUserdata, string name, int format);

    [LibraryImport(Lib, EntryPoint = "mpv_request_log_messages", StringMarshalling = StringMarshalling.Utf8)]
    public static partial int RequestLogMessages(nint ctx, string minLevel);

    [LibraryImport(Lib, EntryPoint = "mpv_wait_event")]
    public static partial Event* WaitEvent(nint ctx, double timeout);

    [LibraryImport(Lib, EntryPoint = "mpv_wakeup")]
    public static partial void Wakeup(nint ctx);

    [LibraryImport(Lib, EntryPoint = "mpv_free")]
    public static partial void Free(nint data);

    [LibraryImport(Lib, EntryPoint = "mpv_error_string")]
    public static partial nint ErrorString(int error);

    public static string Error(int code) => Marshal.PtrToStringUTF8(ErrorString(code)) ?? $"erreur {code}";
}
