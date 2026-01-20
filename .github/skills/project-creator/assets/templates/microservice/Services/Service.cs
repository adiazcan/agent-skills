using {{PROJECT_NAME}}.Models;

namespace {{PROJECT_NAME}}.Services;

/// <summary>
/// {{SERVICE_NAME}} service implementation (Process View - Business Logic)
/// </summary>
public class {{SERVICE_NAME}}Service : I{{SERVICE_NAME}}Service
{
    private readonly List<{{SERVICE_NAME}}Item> _items = [];

    public Task<IEnumerable<{{SERVICE_NAME}}Item>> GetAllAsync()
    {
        return Task.FromResult<IEnumerable<{{SERVICE_NAME}}Item>>(_items);
    }

    public Task<{{SERVICE_NAME}}Item?> GetByIdAsync(Guid id)
    {
        var item = _items.FirstOrDefault(x => x.Id == id);
        return Task.FromResult(item);
    }

    public Task<{{SERVICE_NAME}}Item> CreateAsync(string name)
    {
        var item = {{SERVICE_NAME}}Item.Create(name);
        _items.Add(item);
        return Task.FromResult(item);
    }
}
