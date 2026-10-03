using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.App.Services;

/// <summary>
/// Actions sur les éléments depuis les cartes (menu du clic droit, sélection multiple) : vu / non vu,
/// favoris. Les cartes affichées se mettent à jour d'elles-mêmes via <see cref="UserStateChanged"/>.
/// </summary>
public static class MediaActions
{
    private static readonly List<MediaItem> _selected = [];

    /// <summary>État utilisateur d'un élément modifié (id, nouvel état).</summary>
    public static event Action<string, UserState>? UserStateChanged;
    /// <summary>Sélection modifiée (entrée, sortie, ajout, retrait).</summary>
    public static event Action? SelectionChanged;
    /// <summary>Annonce courte à afficher (résultat d'une action groupée, erreur).</summary>
    public static event Action<string>? Notice;

    public static bool Selecting { get; private set; }
    public static IReadOnlyList<MediaItem> Selected => _selected;
    public static bool IsSelected(MediaItem item) => _selected.Any(i => i.Id == item.Id);

    /// <summary>Éléments qui se marquent comme vus (pas les personnes, collections, dossiers).</summary>
    public static bool CanMarkPlayed(MediaItem item) =>
        item.Kind is MediaKind.Movie or MediaKind.Series or MediaKind.Season or MediaKind.Episode or MediaKind.Video or MediaKind.MusicVideo;

    public static bool CanFavorite(MediaItem item) =>
        item.Kind is not (MediaKind.Person or MediaKind.CollectionFolder or MediaKind.Folder or MediaKind.TvChannel);

    public static void StartSelection(MediaItem? first = null)
    {
        Selecting = true;
        if (first != null && !IsSelected(first)) _selected.Add(first);
        SelectionChanged?.Invoke();
    }

    public static void Toggle(MediaItem item)
    {
        if (IsSelected(item)) _selected.RemoveAll(i => i.Id == item.Id);
        else _selected.Add(item);
        SelectionChanged?.Invoke();
    }

    public static void EndSelection()
    {
        if (!Selecting && _selected.Count == 0) return;
        Selecting = false;
        _selected.Clear();
        SelectionChanged?.Invoke();
    }

    public static Task SetPlayedAsync(IReadOnlyList<MediaItem> items, bool played) =>
        ApplyAsync(items.Where(CanMarkPlayed).ToList(), (m, id) => m.SetPlayedAsync(id, played),
            n => played ? $"{n} élément{S(n)} marqué{S(n)} comme vu{S(n)}" : $"{n} élément{S(n)} marqué{S(n)} comme non vu{S(n)}");

    public static Task SetFavoriteAsync(IReadOnlyList<MediaItem> items, bool favorite) =>
        ApplyAsync(items.Where(CanFavorite).ToList(), (m, id) => m.SetFavoriteAsync(id, favorite),
            n => favorite ? $"{n} élément{S(n)} ajouté{S(n)} aux favoris" : $"{n} élément{S(n)} retiré{S(n)} des favoris");

    private static string S(int n) => n > 1 ? "s" : "";

    private static async Task ApplyAsync(List<MediaItem> items, Func<MediaRepository, string, Task<UserState>> action, Func<int, string> done)
    {
        if (AppServices.Media is not { } media || items.Count == 0) return;
        var ok = 0;
        foreach (var item in items)
        {
            try
            {
                var state = await action(media, item.Id);
                ok++;
                UserStateChanged?.Invoke(item.Id, state);
            }
            catch (Exception e)
            {
                AppLog.Warn("actions", $"« {item.Name} » : {e.Message}");
                Notice?.Invoke(e is ApiException api ? api.UserMessage : $"« {item.Name} » n’a pas pu être modifié.");
                return;
            }
        }
        // Une seule carte : son changement se voit, pas besoin d'annonce.
        if (items.Count > 1) Notice?.Invoke(done(ok));
    }
}
