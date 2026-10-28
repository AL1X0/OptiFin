# Sondes Windows pour check-player.sh : état réel des fenêtres d'OptiFin et de la barre des tâches.
#   probe.ps1 window <titre>  →  "x,y,largeur,hauteur;style;voilée" de la fenêtre au titre donné
#   probe.ps1 screen          →  "x,y,largeur,hauteur" de l'écran principal
#   probe.ps1 taskbar         →  "oui" si un bouton OptiFin est dans la barre des tâches
#   probe.ps1 top <titre>     →  luminosité moyenne (0-255) des 6 premières lignes visibles de la fenêtre
#                                (« indisponible » sans écran à capturer : session déconnectée)
#   probe.ps1 hit <titre>     →  réponse de Windows (WM_NCHITTEST) au milieu du haut de la fenêtre (2 = barre de titre)
param([string]$What, [string]$Title)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class P {
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L, T, R, B; }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern IntPtr GetLong(IntPtr h, int i);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")] public static extern int DwmRect(IntPtr h, int a, out RC v, int s);
  [DllImport("user32.dll", EntryPoint = "SendMessageW")] public static extern IntPtr Send(IntPtr h, int m, IntPtr w, IntPtr l);
}
"@
switch ($What) {
  'window' {
    $h = [P]::FindWindow("WinUIDesktopWin32WindowClass", $Title)
    if ($h -eq [IntPtr]::Zero) { "absente"; break }
    $r = New-Object P+RC; [void][P]::GetWindowRect($h, [ref]$r)
    $cloak = 0; [void][P]::DwmGetWindowAttribute($h, 14, [ref]$cloak, 4)
    "{0},{1},{2},{3};{4:X};{5}" -f $r.L, $r.T, ($r.R - $r.L), ($r.B - $r.T), [long][P]::GetLong($h, -16), $cloak
  }
  'top' {
    # Cadre visible (DWM, sans l'ombre ni les bords de redimensionnement invisibles), capturé à l'écran.
    $h = [P]::FindWindow("WinUIDesktopWin32WindowClass", $Title)
    $r = New-Object P+RC; [void][P]::DwmRect($h, 9, [ref]$r, 16)
    Add-Type -AssemblyName System.Drawing
    $w = [Math]::Max(1, $r.R - $r.L - 200)
    $bmp = New-Object Drawing.Bitmap $w, 6
    $g = [Drawing.Graphics]::FromImage($bmp); try { $g.CopyFromScreen($r.L + 100, $r.T, 0, 0, $bmp.Size) } catch { "indisponible"; break } finally { $g.Dispose() }
    $sum = 0; $n = 0
    for ($y = 0; $y -lt 6; $y++) { for ($x = 0; $x -lt $w; $x += 8) { $c = $bmp.GetPixel($x, $y); $sum += ($c.R + $c.G + $c.B) / 3; $n++ } }
    $bmp.Dispose()
    [int]($sum / $n)
  }
  'hit' {
    $h = [P]::FindWindow("WinUIDesktopWin32WindowClass", $Title)
    $r = New-Object P+RC; [void][P]::DwmRect($h, 9, [ref]$r, 16)
    $x = [int](($r.L + $r.R) / 2); $y = $r.T + 12
    [long][P]::Send($h, 0x84, [IntPtr]::Zero, [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF)))
  }
  'screen' {
    Add-Type -AssemblyName System.Windows.Forms
    $b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    "{0},{1},{2},{3}" -f $b.X, $b.Y, $b.Width, $b.Height
  }
  'taskbar' {
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
    $root = [Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty, "Shell_TrayWnd")
    $tray = $root.FindFirst([Windows.Automation.TreeScope]::Children, $cond)
    $found = $false
    if ($tray) {
      foreach ($e in $tray.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
        if ($e.Current.ClassName -like "*TaskListButton*" -and $e.Current.Name -like "OptiFin*") { $found = $true }
      }
    }
    if ($found) { "oui" } else { "non" }
  }
}
