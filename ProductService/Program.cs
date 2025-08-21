using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();

var app = builder.Build();

app.MapGet("/healthz", () => Results.Ok("ok"));

app.MapPost("/products", async ([FromBody] Product product, DaprClient dapr, IConfiguration cfg, ILoggerFactory lf) =>
{
    var logger = lf.CreateLogger("ProductService");
    var pubsub = cfg["PubSubName"] ?? "sb-pubsub";
    await dapr.PublishEventAsync(pubsub, "products", product);
    logger.LogInformation("Published product {Id} - {Name}", product.Id, product.Name);
    return Results.Accepted(value: product);
});

app.Run("http://0.0.0.0:8080");
public record Product(string Id, string Name, decimal Price);
