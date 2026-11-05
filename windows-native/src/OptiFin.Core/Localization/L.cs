using System.Globalization;

namespace OptiFin.Core.Localization;

/// <summary>
/// Langue de l'appli : français si Windows est en français, anglais sinon. La phrase française reste
/// dans le code et sert de clé au dictionnaire <see cref="English.Texts"/> (un test vérifie qu'elle y figure).
/// </summary>
public static class L
{
    private static readonly CultureInfo French = CultureInfo.GetCultureInfo("fr-FR");
    private static readonly CultureInfo Us = CultureInfo.GetCultureInfo("en-US");

    public static bool IsEnglish { get; set; }

    public static CultureInfo Culture => IsEnglish ? Us : French;

    /// <summary>Langue de Windows (OPTIFIN_LANGUAGE=en|fr la remplace, pour les tests et les captures).</summary>
    public static void UseSystemLanguage()
    {
        var language = Environment.GetEnvironmentVariable("OPTIFIN_LANGUAGE") is { Length: > 0 } forced
            ? forced
            : CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        IsEnglish = language != "fr";
    }

    public static string T(string french) =>
        IsEnglish && English.Texts.TryGetValue(french, out var text) ? text : french;

    /// <summary>Phrase avec variables : « Aucun résultat pour « {0} ». ».</summary>
    public static string F(string french, params object?[] values) => string.Format(Culture, T(french), values);

    /// <summary>Singulier ou pluriel ({0} : le nombre). Zéro est au singulier en français, au pluriel en anglais.</summary>
    public static string Count(long n, string one, string many) =>
        F(n > 1 || (n == 0 && IsEnglish) ? many : one, n);
}
