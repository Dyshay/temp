var builder = WebApplication.CreateBuilder(args);

// Configure JSON options
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.WriteIndented = false;
});

var app = builder.Build();

// Simple GET endpoint
app.MapGet("/api/hello", () => new { message = "Hello from .NET!", timestamp = DateTime.UtcNow });

// GET with parameter
app.MapGet("/api/echo/{text}", (string text) => new { echo = text, length = text.Length });

// POST endpoint with JSON body
app.MapPost("/api/data", (DataRequest request) =>
{
    return new DataResponse
    {
        Id = Guid.NewGuid().ToString(),
        ReceivedName = request.Name,
        ReceivedValue = request.Value,
        ProcessedAt = DateTime.UtcNow
    };
});

// CPU intensive endpoint for performance testing
app.MapGet("/api/compute/{iterations:int}", (int iterations) =>
{
    long sum = 0;
    for (int i = 0; i < iterations; i++)
    {
        sum += i;
    }
    return new { result = sum, iterations };
});

// Memory allocation endpoint for RAM testing
app.MapGet("/api/memory/{sizeMb:int}", (int sizeMb) =>
{
    var data = new byte[sizeMb * 1024 * 1024];
    Array.Fill(data, (byte)42);
    return new { allocated = $"{sizeMb}MB", checksum = data.Sum(b => (long)b) };
});

app.Run();

// DTOs
record DataRequest(string Name, int Value);
record DataResponse
{
    public required string Id { get; init; }
    public required string ReceivedName { get; init; }
    public required int ReceivedValue { get; init; }
    public required DateTime ProcessedAt { get; init; }
}
