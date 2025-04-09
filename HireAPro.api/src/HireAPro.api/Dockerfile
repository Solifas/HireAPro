FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["HireAPro.api.csproj", "./"]
RUN dotnet restore

# Copy the rest of the code
COPY . .

# Build and publish
RUN dotnet publish "HireAPro.api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Build runtime image
FROM public.ecr.aws/lambda/dotnet:8
WORKDIR ${LAMBDA_TASK_ROOT}

COPY --from=build /app/publish .

# Set the CMD to your handler
CMD [ "HireAPro.api::HireAPro.api.LambdaEntryPoint::FunctionHandlerAsync" ] 