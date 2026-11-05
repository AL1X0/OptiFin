using System.Text.RegularExpressions;
using OptiFin.Core.Localization;

namespace OptiFin.Core.Tests;

/// <summary>Traduction anglaise : aucune phrase du code oubliée, variables identiques des deux côtés.</summary>
public partial class LocalizationTests
{
    [GeneratedRegex("""L\.(?:T|F)\("((?:[^"\\]|\\.)*)"|L\.Count\([^,"]+,\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)""")]
    private static partial Regex Keys();

    [GeneratedRegex(@"\{\d+")]
    private static partial Regex Placeholder();

    [GeneratedRegex("""(?:Text|PlaceholderText|ToolTipService\.ToolTip|Content)="([^"{]+)"[^>]*""")]
    private static partial Regex XamlText();

    private static DirectoryInfo Sources()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
            if (Directory.Exists(Path.Combine(dir.FullName, "src", "OptiFin.Core"))) return new DirectoryInfo(Path.Combine(dir.FullName, "src"));
        throw new InvalidOperationException("Sources introuvables");
    }

    private static IEnumerable<FileInfo> Files(string pattern) =>
        Sources().EnumerateFiles(pattern, SearchOption.AllDirectories).Where(f => !f.FullName.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}")
            && !f.FullName.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}"));

    [Fact]
    public void Toute_phrase_du_code_est_traduite()
    {
        var missing = new SortedSet<string>();
        foreach (var file in Files("*.cs"))
        {
            if (file.Name == "L.cs") continue;
            foreach (Match m in Keys().Matches(File.ReadAllText(file.FullName)))
            {
                foreach (var key in m.Groups.Cast<Group>().Skip(1).Where(g => g.Success).Select(g => g.Value))
                    if (!English.Texts.ContainsKey(key)) missing.Add($"{file.Name} : {key}");
            }
        }
        Assert.True(missing.Count == 0, "Sans traduction :\n" + string.Join("\n", missing));
    }

    [Fact]
    public void Les_textes_du_xaml_sont_traduits()
    {
        // Ces libellés s'écrivent pareil dans les deux langues.
        string[] same = ["OptiFin", "Audio", "Volume (↑ ↓, M)"];
        var missing = new SortedSet<string>();
        foreach (var file in Files("*.xaml"))
        {
            foreach (Match m in XamlText().Matches(File.ReadAllText(file.FullName)))
                if (!English.Texts.ContainsKey(m.Groups[1].Value) && !same.Contains(m.Groups[1].Value)) missing.Add($"{file.Name} : {m.Groups[1].Value}");
        }
        Assert.True(missing.Count == 0, "Sans traduction :\n" + string.Join("\n", missing));
    }

    [Fact]
    public void Memes_variables_dans_les_deux_langues()
    {
        foreach (var (french, english) in English.Texts)
        {
            var a = Placeholder().Matches(french).Select(m => m.Value).Order();
            var b = Placeholder().Matches(english).Select(m => m.Value).Order();
            Assert.True(a.SequenceEqual(b), $"Variables différentes : « {french} » / « {english} »");
        }
    }

    [Fact]
    public void Phrases_en_anglais_et_pluriels()
    {
        Assert.Equal("Lecture", L.T("Lecture"));
        Assert.Equal("1 élément", L.Count(1, "{0} élément", "{0} éléments"));
        Assert.Equal("0 élément", L.Count(0, "{0} élément", "{0} éléments"));
        L.IsEnglish = true;
        try
        {
            Assert.Equal("Play", L.T("Lecture"));
            Assert.Equal("1 item", L.Count(1, "{0} élément", "{0} éléments"));
            Assert.Equal("0 items", L.Count(0, "{0} élément", "{0} éléments"));
            Assert.Equal("Une phrase inconnue", L.T("Une phrase inconnue"));
        }
        finally
        {
            L.IsEnglish = false;
        }
    }
}
