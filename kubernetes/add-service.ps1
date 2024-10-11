param (
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    [Parameter(Mandatory=$true)]
    [string]$ServiceImage,
    [Parameter(Mandatory=$true)]
    [string]$Ports,
    [Parameter(Mandatory=$false)]
    [int]$DefaultPort = 0
)

function Build-And-Load-Local-Image {
    param (
        [string]$DockerfilePath,
        [string]$ImageName
    )
    
    docker build -t $ImageName (Split-Path -Parent $DockerfilePath)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker image"
        exit 1
    }
    
    minikube image load $ImageName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to load image into Minikube"
        exit 1
    }
}

# Check if service already exists
$existingService = kubectl get service "${ServiceName}-service" -o name --ignore-not-found
if ($existingService) {
    Write-Error "A service with the name '${ServiceName}' already exists. Please choose a different name."
    exit 1
}

# Check if ServiceImage is a local path or DockerHub image
if (Test-Path $ServiceImage) {
    # It's a local Dockerfile
    Build-And-Load-Local-Image -DockerfilePath $ServiceImage -ImageName $ServiceName
    $ServiceImage = $ServiceName
    $ImagePullPolicy = "Never"
} else {
    # It's a DockerHub image
    $ImagePullPolicy = "IfNotPresent"
}

# Parse ports
$portList = $Ports -split ','

# If DefaultPort is not provided, use the first port in the list
if ($DefaultPort -eq 0) {
    $DefaultPort = [int]$portList[0]
}

$containerPorts = ""
$servicePorts = ""

foreach ($port in $portList) {
    $containerPorts += "        - containerPort: $port`n"
    if ([int]$port -eq $DefaultPort) {
        $servicePorts += "    - port: 80`n      targetPort: $port`n"
    }
    $servicePorts += "    - port: $port`n      targetPort: $port`n"
}

$serviceYaml = (Get-Content "service-template.yaml") -replace "SERVICE_NAME", $ServiceName `
                                                     -replace "SERVICE_IMAGE", $ServiceImage `
                                                     -replace "IMAGE_PULL_POLICY", $ImagePullPolicy `
                                                     -replace "CONTAINER_PORTS", $containerPorts.TrimEnd() `
                                                     -replace "SERVICE_PORTS", $servicePorts.TrimEnd()

$serviceYaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to apply service deployment"
    exit 1
}

$hpaYaml = (Get-Content "hpa-template.yaml") -replace "SERVICE_NAME", $ServiceName
$hpaYaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to apply HPA"
    exit 1
}

Write-Host "Service $ServiceName added successfully with autoscaling!"
Write-Host "The service is internally configured to use ports: $Ports"
Write-Host "It is externally accessible on port 80 (mapped to $DefaultPort) and on its original ports"

# Verify the created service
Write-Host "Verifying created service:"
kubectl get service "${ServiceName}-service" -o yaml
