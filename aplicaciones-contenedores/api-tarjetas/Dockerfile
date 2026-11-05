FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY api-tarjetas/ApiTarjetas.csproj ./
RUN dotnet restore ApiTarjetas.csproj
COPY api-tarjetas/. ./
RUN dotnet publish ApiTarjetas.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
RUN apt-get update \
	&& apt-get install -y --no-install-recommends --only-upgrade apt libapt-pkg6.0 \
	&& rm -rf /var/lib/apt/lists/*
RUN useradd --system --uid 10001 --create-home appuser
COPY --from=build --chown=appuser:appuser /app/publish/ ./
USER appuser

EXPOSE 8085
ENV PORT=8085
ENTRYPOINT ["dotnet", "ApiTarjetas.dll"]