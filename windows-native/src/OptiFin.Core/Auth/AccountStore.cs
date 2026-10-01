using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace OptiFin.Core.Auth;

/// <summary>Compte enregistré (le jeton est chiffré à part).</summary>
public sealed class StoredAccount
{
    public string ServerId { get; set; } = "";
    public string ServerName { get; set; } = "";
    public string BaseUrl { get; set; } = "";
    public string ServerVersion { get; set; } = "";
    public string UserId { get; set; } = "";
    public string UserName { get; set; } = "";
    public string? AvatarTag { get; set; }
    public DateTimeOffset LastUsed { get; set; }

    /// <summary>Jeton chiffré par DPAPI (lié à la session Windows de l'utilisateur), en base 64.</summary>
    public string ProtectedToken { get; set; } = "";

    [JsonIgnore]
    public string Id => $"{ServerId}:{UserId}";

    public JellyfinServer Server => new(ServerId, ServerName, new Uri(BaseUrl), ServerVersion);
    public Account Account => new(ServerId, UserId, UserName, AvatarTag);
}

public sealed class AccountFile
{
    public int Version { get; set; } = 1;
    public string? ActiveId { get; set; }
    public List<StoredAccount> Accounts { get; set; } = [];
    public string? DeviceId { get; set; }
}

[JsonSourceGenerationOptions(WriteIndented = true)]
[JsonSerializable(typeof(AccountFile))]
internal sealed partial class AccountJson : JsonSerializerContext;

/// <summary>
/// Comptes enregistrés (%LOCALAPPDATA%\OptiFin\accounts.json). Les jetons sont chiffrés par
/// DPAPI : illisibles pour un autre utilisateur ou une autre machine. Jamais de mot de passe
/// stocké.
/// </summary>
public sealed class AccountStore(string? directory = null)
{
    private readonly string _path = Path.Combine(directory ?? Logging.AppLog.Directory, "accounts.json");
    private readonly Lock _gate = new();

    private AccountFile Load()
    {
        try
        {
            if (!File.Exists(_path)) return new AccountFile();
            return JsonSerializer.Deserialize(File.ReadAllText(_path), AccountJson.Default.AccountFile) ?? new AccountFile();
        }
        catch
        {
            return new AccountFile();
        }
    }

    private void Save(AccountFile file)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        var tmp = _path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(file, AccountJson.Default.AccountFile));
        File.Move(tmp, _path, overwrite: true);
    }

    /// <summary>Identifiant d'appareil stable (créé au premier lancement).</summary>
    public string DeviceId()
    {
        lock (_gate)
        {
            var file = Load();
            if (string.IsNullOrEmpty(file.DeviceId))
            {
                file.DeviceId = Guid.NewGuid().ToString();
                Save(file);
            }
            return file.DeviceId;
        }
    }

    public IReadOnlyList<StoredAccount> Accounts()
    {
        lock (_gate) return [.. Load().Accounts.OrderByDescending(a => a.LastUsed)];
    }

    public void Remember(ActiveSession session)
    {
        lock (_gate)
        {
            var file = Load();
            var id = session.Account.Id;
            file.Accounts.RemoveAll(a => a.Id == id);
            file.Accounts.Add(new StoredAccount
            {
                ServerId = session.Server.Id,
                ServerName = session.Server.Name,
                BaseUrl = session.Server.BaseUrl.ToString(),
                ServerVersion = session.Server.Version,
                UserId = session.Account.UserId,
                UserName = session.Account.UserName,
                AvatarTag = session.Account.AvatarTag,
                LastUsed = DateTimeOffset.Now,
                ProtectedToken = Dpapi.Protect(session.Token),
            });
            file.ActiveId = id;
            Save(file);
        }
    }

    /// <summary>Session du dernier compte utilisé (null si aucun, ou jeton illisible).</summary>
    public ActiveSession? Restore(string? accountId = null)
    {
        lock (_gate)
        {
            var file = Load();
            var stored = file.Accounts.FirstOrDefault(a => a.Id == (accountId ?? file.ActiveId));
            if (stored is null) return null;
            var token = Dpapi.Unprotect(stored.ProtectedToken);
            if (string.IsNullOrEmpty(token)) return null;
            if (accountId != null && file.ActiveId != accountId)
            {
                file.ActiveId = accountId;
                stored.LastUsed = DateTimeOffset.Now;
                Save(file);
            }
            return new ActiveSession(stored.Server, stored.Account, token);
        }
    }

    /// <summary>Déconnexion : le compte reste listé sans jeton (reconnexion rapide), ou est oublié.</summary>
    public void SignOut(string accountId, bool forget)
    {
        lock (_gate)
        {
            var file = Load();
            if (forget)
            {
                file.Accounts.RemoveAll(a => a.Id == accountId);
            }
            else if (file.Accounts.FirstOrDefault(a => a.Id == accountId) is { } a)
            {
                a.ProtectedToken = "";
            }
            if (file.ActiveId == accountId) file.ActiveId = null;
            Save(file);
        }
    }
}

/// <summary>Chiffrement DPAPI de Windows (CryptProtectData), propre à l'utilisateur.</summary>
internal static partial class Dpapi
{
    private static readonly byte[] Entropy = "OptiFin.token.v1"u8.ToArray();

    public static string Protect(string secret)
    {
        var data = Encoding.UTF8.GetBytes(secret);
        return Convert.ToBase64String(Transform(data, protect: true) ?? []);
    }

    public static string? Unprotect(string protectedBase64)
    {
        if (string.IsNullOrEmpty(protectedBase64)) return null;
        try
        {
            var plain = Transform(Convert.FromBase64String(protectedBase64), protect: false);
            return plain is null ? null : Encoding.UTF8.GetString(plain);
        }
        catch (FormatException)
        {
            return null;
        }
    }

    private static unsafe byte[]? Transform(byte[] input, bool protect)
    {
        fixed (byte* inPtr = input)
        fixed (byte* entPtr = Entropy)
        {
            var inBlob = new DataBlob { Size = input.Length, Data = (nint)inPtr };
            var entBlob = new DataBlob { Size = Entropy.Length, Data = (nint)entPtr };
            var ok = protect
                ? CryptProtectData(ref inBlob, null, ref entBlob, 0, 0, CryptProtectUiForbidden, out var outBlob)
                : CryptUnprotectData(ref inBlob, 0, ref entBlob, 0, 0, CryptProtectUiForbidden, out outBlob);
            if (!ok) return null;
            try
            {
                var result = new byte[outBlob.Size];
                Marshal.Copy(outBlob.Data, result, 0, outBlob.Size);
                return result;
            }
            finally
            {
                LocalFree(outBlob.Data);
            }
        }
    }

    private const int CryptProtectUiForbidden = 0x1;

    [StructLayout(LayoutKind.Sequential)]
    private struct DataBlob
    {
        public int Size;
        public nint Data;
    }

    [LibraryImport("crypt32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CryptProtectData(ref DataBlob dataIn, string? description, ref DataBlob entropy,
        nint reserved, nint prompt, int flags, out DataBlob dataOut);

    [LibraryImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CryptUnprotectData(ref DataBlob dataIn, nint description, ref DataBlob entropy,
        nint reserved, nint prompt, int flags, out DataBlob dataOut);

    [LibraryImport("kernel32.dll")]
    private static partial nint LocalFree(nint mem);
}
