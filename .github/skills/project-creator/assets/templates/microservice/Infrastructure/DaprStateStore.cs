using Dapr.Client;

namespace {{PROJECT_NAME}}.Infrastructure;

/// <summary>
/// Dapr state store abstraction (Physical View - Infrastructure)
/// </summary>
public interface IStateStore<T>
{
    Task<T?> GetAsync(string key);
    Task SaveAsync(string key, T value);
    Task DeleteAsync(string key);
}

public class DaprStateStore<T>(DaprClient daprClient, IConfiguration configuration) : IStateStore<T>
{
    private readonly string _storeName = configuration["Dapr:StateStoreName"] ?? "statestore";

    public async Task<T?> GetAsync(string key)
    {
        return await daprClient.GetStateAsync<T>(_storeName, key);
    }

    public async Task SaveAsync(string key, T value)
    {
        await daprClient.SaveStateAsync(_storeName, key, value);
    }

    public async Task DeleteAsync(string key)
    {
        await daprClient.DeleteStateAsync(_storeName, key);
    }
}
