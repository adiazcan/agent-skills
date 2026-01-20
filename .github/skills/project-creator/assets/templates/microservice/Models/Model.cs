namespace {{PROJECT_NAME}}.Models;

/// <summary>
/// {{SERVICE_NAME}} domain model (Logical View)
/// </summary>
public record {{SERVICE_NAME}}Item(
    Guid Id,
    string Name,
    DateTime CreatedAt)
{
    public static {{SERVICE_NAME}}Item Create(string name) =>
        new(Guid.NewGuid(), name, DateTime.UtcNow);
}
