using {{PROJECT_NAME}}.Models;

namespace {{PROJECT_NAME}}.Services;

/// <summary>
/// {{SERVICE_NAME}} service interface (Process View - Service Contract)
/// </summary>
public interface I{{SERVICE_NAME}}Service
{
    Task<IEnumerable<{{SERVICE_NAME}}Item>> GetAllAsync();
    Task<{{SERVICE_NAME}}Item?> GetByIdAsync(Guid id);
    Task<{{SERVICE_NAME}}Item> CreateAsync(string name);
}
