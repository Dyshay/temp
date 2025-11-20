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

// JSON serialization/deserialization benchmark
app.MapPost("/api/json-benchmark", (JsonBenchmarkRequest request) =>
{
    var startSerialize = DateTime.UtcNow;

    // Create a large object to serialize
    var data = Enumerable.Range(0, request.ObjectCount)
        .Select(i => new Person
        {
            Id = i,
            Name = $"Person {i}",
            Email = $"person{i}@example.com",
            Age = 20 + (i % 50),
            Address = new Address
            {
                Street = $"{i} Main St",
                City = "TestCity",
                ZipCode = $"{10000 + i}",
                Country = "TestCountry"
            }
        })
        .ToList();

    var serializeTime = (DateTime.UtcNow - startSerialize).TotalMilliseconds;

    // Serialize to JSON string
    var startJsonSerialize = DateTime.UtcNow;
    var json = System.Text.Json.JsonSerializer.Serialize(data);
    var jsonSerializeTime = (DateTime.UtcNow - startJsonSerialize).TotalMilliseconds;

    // Deserialize back
    var startDeserialize = DateTime.UtcNow;
    var deserialized = System.Text.Json.JsonSerializer.Deserialize<List<Person>>(json);
    var deserializeTime = (DateTime.UtcNow - startDeserialize).TotalMilliseconds;

    return new
    {
        objectCount = request.ObjectCount,
        objectCreationTimeMs = serializeTime,
        serializationTimeMs = jsonSerializeTime,
        deserializationTimeMs = deserializeTime,
        totalTimeMs = serializeTime + jsonSerializeTime + deserializeTime,
        jsonSizeBytes = json.Length
    };
});

// LINQ vs Collections benchmark
app.MapGet("/api/linq-benchmark/{size:int}", (int size) =>
{
    var data = Enumerable.Range(1, size).ToList();

    // LINQ operations
    var startLinq = DateTime.UtcNow;
    var linqResult = data
        .Where(x => x % 2 == 0)
        .Select(x => x * 2)
        .OrderByDescending(x => x)
        .Take(100)
        .ToList();
    var linqTime = (DateTime.UtcNow - startLinq).TotalMilliseconds;

    // Equivalent operations with for loops
    var startLoop = DateTime.UtcNow;
    var loopResult = new List<int>();
    for (int i = 0; i < data.Count; i++)
    {
        if (data[i] % 2 == 0)
        {
            loopResult.Add(data[i] * 2);
        }
    }
    loopResult.Sort();
    loopResult.Reverse();
    if (loopResult.Count > 100)
    {
        loopResult = loopResult.Take(100).ToList();
    }
    var loopTime = (DateTime.UtcNow - startLoop).TotalMilliseconds;

    // Complex LINQ query
    var startComplexLinq = DateTime.UtcNow;
    var complexResult = data
        .GroupBy(x => x % 10)
        .Select(g => new { Key = g.Key, Sum = g.Sum(), Count = g.Count(), Average = g.Average() })
        .OrderByDescending(x => x.Sum)
        .ToList();
    var complexLinqTime = (DateTime.UtcNow - startComplexLinq).TotalMilliseconds;

    return new
    {
        dataSize = size,
        linqTimeMs = linqTime,
        forLoopTimeMs = loopTime,
        complexLinqTimeMs = complexLinqTime,
        linqSlowerByPercent = ((linqTime - loopTime) / loopTime) * 100,
        resultCount = linqResult.Count
    };
});

// Collection operations benchmark
app.MapGet("/api/collection-benchmark/{size:int}", (int size) =>
{
    // List operations
    var startList = DateTime.UtcNow;
    var list = new List<int>();
    for (int i = 0; i < size; i++) list.Add(i);
    var listAddTime = (DateTime.UtcNow - startList).TotalMilliseconds;

    var startListSearch = DateTime.UtcNow;
    var found = list.Contains(size / 2);
    var listSearchTime = (DateTime.UtcNow - startListSearch).TotalMilliseconds;

    // Array operations
    var startArray = DateTime.UtcNow;
    var array = new int[size];
    for (int i = 0; i < size; i++) array[i] = i;
    var arrayAddTime = (DateTime.UtcNow - startArray).TotalMilliseconds;

    var startArraySearch = DateTime.UtcNow;
    found = array.Contains(size / 2);
    var arraySearchTime = (DateTime.UtcNow - startArraySearch).TotalMilliseconds;

    // HashSet operations
    var startHashSet = DateTime.UtcNow;
    var hashSet = new HashSet<int>();
    for (int i = 0; i < size; i++) hashSet.Add(i);
    var hashSetAddTime = (DateTime.UtcNow - startHashSet).TotalMilliseconds;

    var startHashSetSearch = DateTime.UtcNow;
    found = hashSet.Contains(size / 2);
    var hashSetSearchTime = (DateTime.UtcNow - startHashSetSearch).TotalMilliseconds;

    return new
    {
        dataSize = size,
        list = new { addTimeMs = listAddTime, searchTimeMs = listSearchTime },
        array = new { addTimeMs = arrayAddTime, searchTimeMs = arraySearchTime },
        hashSet = new { addTimeMs = hashSetAddTime, searchTimeMs = hashSetSearchTime }
    };
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

record JsonBenchmarkRequest(int ObjectCount);

class Person
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    public int Age { get; set; }
    public Address Address { get; set; } = new();
}

class Address
{
    public string Street { get; set; } = "";
    public string City { get; set; } = "";
    public string ZipCode { get; set; } = "";
    public string Country { get; set; } = "";
}
