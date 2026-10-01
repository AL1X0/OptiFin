using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace OptiFin.App.Player;

/// <summary>Appels Win32 du lecteur (fenêtre vidéo, propriétaire, veille), générés pour NativeAOT.</summary>
internal static unsafe partial class Win32
{
    public const uint WS_POPUP = 0x80000000;
    public const uint WS_VISIBLE = 0x10000000;
    public const uint WS_CLIPCHILDREN = 0x02000000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_NOACTIVATE = 0x08000000;
    public const int GWLP_HWNDPARENT = -8;
    public const int DWMWA_CLOAK = 13;
    public const uint DWM_BB_ENABLE = 0x1;
    public const uint DWM_BB_BLURREGION = 0x2;
    public const int SW_HIDE = 0;
    public const int SW_SHOWNOACTIVATE = 4;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const uint WM_ERASEBKGND = 0x0014;
    public const uint WM_NCHITTEST = 0x0084;
    public const uint WM_MOUSEACTIVATE = 0x0021;
    public const int MA_NOACTIVATE = 3;
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;

    [StructLayout(LayoutKind.Sequential)]
    public struct WndClassEx
    {
        public uint Size;
        public uint Style;
        public delegate* unmanaged<nint, uint, nint, nint, nint> WndProc;
        public int ClsExtra;
        public int WndExtra;
        public nint Instance;
        public nint Icon;
        public nint Cursor;
        public nint Background;
        public nint MenuName;
        public nint ClassName;
        public nint IconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public int Left, Top, Right, Bottom;
    }

    /// <summary>Identité de l'appli pour la barre des tâches et les contrôles multimédias (même valeur que le raccourci de l'installateur).</summary>
    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)]
    public static partial int SetCurrentProcessExplicitAppUserModelID(string appId);

    [LibraryImport("user32.dll", EntryPoint = "RegisterClassExW")]
    public static partial ushort RegisterClassEx(WndClassEx* wc);

    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateWindowEx(int exStyle, string className, string title, uint style, int x, int y, int w, int h,
        nint parent, nint menu, nint instance, nint param);

    [LibraryImport("user32.dll", EntryPoint = "DefWindowProcW")]
    public static partial nint DefWindowProc(nint hwnd, uint msg, nint wparam, nint lparam);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DestroyWindow(nint hwnd);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool ShowWindow(nint hwnd, int cmd);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetWindowPos(nint hwnd, nint after, int x, int y, int w, int h, uint flags);

    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    public static partial nint SetWindowLongPtr(nint hwnd, int index, nint value);

    [StructLayout(LayoutKind.Sequential)]
    public struct BlurBehind
    {
        public uint Flags;
        public int Enable;
        public nint Region;
        public int TransitionOnMaximized;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Point
    {
        public int X;
        public int Y;
    }

    /// <summary>
    /// Transparence réelle de la fenêtre : sans cela, Windows compose la fenêtre comme opaque même si
    /// son contenu est transparent. Une région de flou vide n'ajoute aucun flou, seulement l'alpha.
    /// </summary>
    [LibraryImport("dwmapi.dll")]
    public static partial int DwmEnableBlurBehindWindow(nint hwnd, BlurBehind* blur);

    /// <summary>Masque (« voile ») une fenêtre sans la fermer : elle garde le focus et le clavier.</summary>
    [LibraryImport("dwmapi.dll")]
    public static partial int DwmSetWindowAttribute(nint hwnd, int attribute, int* value, int size);

    [LibraryImport("gdi32.dll")]
    public static partial nint CreateRectRgn(int left, int top, int right, int bottom);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DeleteObject(nint obj);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetCursorPos(out Point point);

    public static int EnableTransparency(nint hwnd)
    {
        var region = CreateRectRgn(-2, -2, -1, -1);
        var blur = new BlurBehind { Flags = DWM_BB_ENABLE | DWM_BB_BLURREGION, Enable = 1, Region = region };
        var hr = DwmEnableBlurBehindWindow(hwnd, &blur);
        DeleteObject(region);
        return hr;
    }

    public static void Cloak(nint hwnd, bool cloaked)
    {
        var value = cloaked ? 1 : 0;
        DwmSetWindowAttribute(hwnd, DWMWA_CLOAK, &value, sizeof(int));
    }

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetClientRect(nint hwnd, out Rect rect);

    [LibraryImport("gdi32.dll", EntryPoint = "GetStockObject")]
    public static partial nint GdiStockObject(int index);

    [LibraryImport("user32.dll", EntryPoint = "LoadCursorW")]
    public static partial nint LoadCursor(nint instance, nint name);

    [LibraryImport("kernel32.dll", EntryPoint = "GetModuleHandleW")]
    public static partial nint GetModuleHandle(nint name);

    [LibraryImport("kernel32.dll")]
    public static partial uint SetThreadExecutionState(uint flags);

    [LibraryImport("user32.dll")]
    public static partial nint SetCursor(nint cursor);

    public const int BLACK_BRUSH = 4;
}

/// <summary>
/// Fenêtre vidéo : fenêtre Windows sans bordure ni bouton de barre des tâches, jamais active (la
/// fenêtre des commandes, au-dessus, garde clavier et souris). mpv y dessine avec sa propre chaîne
/// d'affichage Direct3D 11 : le HDR peut partir tel quel vers l'écran.
/// </summary>
internal sealed unsafe class VideoHost : IDisposable
{
    private const string ClassName = "OptiFinVideo";
    private static bool _registered;

    public nint Hwnd { get; private set; }

    public VideoHost()
    {
        if (!_registered)
        {
            var name = Marshal.StringToHGlobalUni(ClassName);
            var wc = new Win32.WndClassEx
            {
                Size = (uint)sizeof(Win32.WndClassEx),
                WndProc = &WndProc,
                Instance = Win32.GetModuleHandle(0),
                Background = Win32.GdiStockObject(Win32.BLACK_BRUSH),
                Cursor = Win32.LoadCursor(0, 32512 /* IDC_ARROW */),
                ClassName = name,
            };
            Win32.RegisterClassEx(&wc);
            _registered = true;
        }
        Hwnd = Win32.CreateWindowEx(Win32.WS_EX_TOOLWINDOW | Win32.WS_EX_NOACTIVATE, ClassName, "OptiFin vidéo",
            Win32.WS_POPUP | Win32.WS_CLIPCHILDREN, 0, 0, 1280, 720, 0, 0, Win32.GetModuleHandle(0), 0);
    }

    [UnmanagedCallersOnly]
    private static nint WndProc(nint hwnd, uint msg, nint wparam, nint lparam) => msg switch
    {
        Win32.WM_MOUSEACTIVATE => Win32.MA_NOACTIVATE,
        _ => Win32.DefWindowProc(hwnd, msg, wparam, lparam),
    };

    public void Place(int x, int y, int width, int height, bool visible) =>
        Win32.SetWindowPos(Hwnd, 0, x, y, width, height, Win32.SWP_NOACTIVATE | Win32.SWP_NOZORDER | (visible ? Win32.SWP_SHOWWINDOW : 0));

    public void Show(bool visible) => Win32.ShowWindow(Hwnd, visible ? Win32.SW_SHOWNOACTIVATE : Win32.SW_HIDE);

    /// <summary>La fenêtre <paramref name="owned"/> reste toujours au-dessus de la vidéo.</summary>
    public void Own(nint owned) => Win32.SetWindowLongPtr(owned, Win32.GWLP_HWNDPARENT, Hwnd);

    public void Dispose()
    {
        if (Hwnd == 0) return;
        Win32.DestroyWindow(Hwnd);
        Hwnd = 0;
    }
}
