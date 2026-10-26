# Sondes Windows pour check-player.sh : état réel des fenêtres d'OptiFin et de la barre des tâches.
#   probe.ps1 window <titre>  →  "x,y,largeur,hauteur;style;voilée" de la fenêtre au titre donné
#   probe.ps1 screen          →  "x,y,largeur,hauteur" de l'écran principal
#   probe.ps1 taskbar         →  "oui" si un bouton OptiFin est dans la barre des tâches
param([string]$What, [string]$Title)
switch ($What) {
  'window' {
    Add-Type @"
using System; using System.Runtime.InteropServices;
public static class P {
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L, T, R, B; }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern IntPtr GetLong(IntPtr h, int i);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
}
"@
    $h = [P]::FindWindow("WinUIDesktopWin32WindowClass", $Title)
    if ($h -eq [IntPtr]::Zero) { "absente"; break }
    $r = New-Object P+RC; [void][P]::GetWindowRect($h, [ref]$r)
    $cloak = 0; [void][P]::DwmGetWindowAttribute($h, 14, [ref]$cloak, 4)
    "{0},{1},{2},{3};{4:X};{5}" -f $r.L, $r.T, ($r.R - $r.L), ($r.B - $r.T), [long][P]::GetLong($h, -16), $cloak
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
