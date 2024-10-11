# Reverse Proxy Setup in Minikube

This guide will walk you through setting up a reverse proxy in Minikube that can route requests to different services based on subdomains.

## Prerequisites

- Minikube installed
- kubectl installed
- Docker installed
- Go installed (for building the reverse proxy)

## Steps

### 1. Start Minikube

```bash
minikube start
```

### 2. Build and Deploy Reverse Proxy

First, build the Go backend and add it to Minikube:

```bash
# Switch to Minikube's Docker daemon
eval $(minikube docker-env)

# Build the Docker image
docker build -t reverse-proxy:latest .

# Apply the Kubernetes deployment and service
kubectl apply -f reverse-proxy-deployment.yaml
```

### 3. Port Forward and Test

Port forward the reverse proxy service to localhost:8000:

```bash
kubectl port-forward service/reverse-proxy-service 8000:8000
```

In a new terminal, confirm you can access it:

```bash
curl http://localhost:8000
```

You should see "Reverse Proxy Server Running".

### 4. Add New Services

Use the `add-service.ps1` script to add new services. Here are some examples:

#### Add a local image with a single port:

```powershell
.\add-service.ps1 -ServiceName myapp -ServiceImage "C:\path\to\your\Dockerfile" -Ports 8080
```

This command will:
1. Build the Docker image from the specified Dockerfile
2. Load the image into Minikube
3. Deploy the service with the name "myapp" and expose port 8080

#### Add a DockerHub image with multiple ports:

```powershell
.\add-service.ps1 -ServiceName nginx -ServiceImage nginx:latest -Ports 80,443 -DefaultPort 80
```

This command will:
1. Pull the nginx:latest image from DockerHub
2. Deploy the service with the name "nginx"
3. Expose ports 80 and 443
4. Set port 80 as the default port (accessible via port 80 externally)

### 5. Access Services via Subdomain

To access a service, use the format `service-name.localhost:8000`. For example:

```bash
curl -H "Host: myapp.localhost" http://localhost:8000
curl -H "Host: nginx.localhost" http://localhost:8000
```

For browser access, add entries to your hosts file:

```
127.0.0.1 myapp.localhost
127.0.0.1 nginx.localhost
```

Then you can access services in your browser using URLs like:
- http://myapp.localhost:8000
- http://nginx.localhost:8000

## Troubleshooting

- If services are not accessible, check their status with `kubectl get pods` and `kubectl get services`.
- View reverse proxy logs with `kubectl logs deployment/reverse-proxy`.
- Ensure your reverse proxy code correctly handles the subdomains and routes to the appropriate services.

## Note

This setup is for development purposes. For production, consider using a proper Ingress controller and DNS setup.


