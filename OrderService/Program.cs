using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();
builder.Services.AddControllers().AddDapr();

var app = builder.Build();

app.MapGet("/healthz", () => Results.Ok("ok"));
app.MapSubscribeHandler();

app.MapPost("/orders", ([FromBody] Product p, ILoggerFactory lf) =>
{
    var logger = lf.CreateLogger("OrderService");
    logger.LogInformation("Received product {Id} - {Name} at {UtcNow}", p.Id, p.Name, DateTime.UtcNow);
    return Results.Ok();
})
.WithTopic(app.Configuration["PubSubName"] ?? "sb-pubsub", "products");

app.Run("http://0.0.0.0:8080");
public record Product(string Id, string Name, decimal Price);
