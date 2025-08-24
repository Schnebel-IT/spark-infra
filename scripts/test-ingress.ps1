# PowerShell script for testing ingress functionality on Windows
# This script performs basic ingress validation tests

param(
    [string]$ManagerIP = "10.10.1.1",
    [int]$HttpPort = 30080,
    [int]$HttpsPort = 30443,
    [string]$TestNamespace = "ingress-tests",
    [switch]$Deploy,
    [switch]$Cleanup,
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Cyan"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Show-Usage {
    Write-Host "Usage: .\test-ingress.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Test ingress functionality"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ManagerIP <IP>        Manager IP address (default: $ManagerIP)"
    Write-Host "  -HttpPort <PORT>       HTTP NodePort (default: $HttpPort)"
    Write-Host "  -HttpsPort <PORT>      HTTPS NodePort (default: $HttpsPort)"
    Write-Host "  -TestNamespace <NAME>  Test namespace (default: $TestNamespace)"
    Write-Host "  -Deploy                Deploy test applications first"
    Write-Host "  -Cleanup               Cleanup test resources after testing"
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\test-ingress.ps1 -Deploy"
    Write-Host "  .\test-ingress.ps1 -ManagerIP 192.168.1.100"
    Write-Host "  .\test-ingress.ps1 -Cleanup"
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check kubectl
    try {
        $null = kubectl version --client 2>$null
        Write-Success "kubectl is available"
    }
    catch {
        Write-Error "kubectl is not installed or not in PATH"
        return $false
    }
    
    # Check curl
    try {
        $null = curl --version 2>$null
        Write-Success "curl is available"
    }
    catch {
        Write-Error "curl is not installed or not in PATH"
        return $false
    }
    
    # Check cluster connectivity
    try {
        $null = kubectl cluster-info 2>$null
        Write-Success "Connected to Kubernetes cluster"
    }
    catch {
        Write-Error "Cannot connect to Kubernetes cluster"
        return $false
    }
    
    return $true
}

function Deploy-TestApplications {
    Write-Info "Deploying test applications..."
    
    # Create namespace
    kubectl create namespace $TestNamespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy applications
    kubectl apply -f manifests/ingress-examples/sample-app.yml -n $TestNamespace
    kubectl apply -f manifests/ingress-examples/sample-ingress.yml -n $TestNamespace
    kubectl apply -f manifests/ingress-examples/nextjs-example.yml -n $TestNamespace
    kubectl apply -f manifests/ingress-examples/rest-api-example.yml -n $TestNamespace
    kubectl apply -f manifests/ingress-examples/advanced-ingress-tests.yml -n $TestNamespace
    
    Write-Info "Waiting for deployments to be ready..."
    Start-Sleep -Seconds 30
    
    Write-Success "Test applications deployed"
}

function Test-BasicFunctionality {
    Write-Info "Testing basic ingress functionality..."
    
    $BaseUrl = "http://${ManagerIP}:${HttpPort}"
    $TestsPassed = 0
    $TotalTests = 0
    
    # Test basic routing
    $TotalTests++
    try {
        $Response = curl -s -H "Host: sample.local" $BaseUrl 2>$null
        if ($Response -match "Sample Application") {
            Write-Success "✓ Basic routing works"
            $TestsPassed++
        } else {
            Write-Error "✗ Basic routing failed"
        }
    }
    catch {
        Write-Error "✗ Basic routing failed with exception"
    }
    
    # Test NextJS application
    $TotalTests++
    try {
        $Response = curl -s -H "Host: nextjs.local" $BaseUrl 2>$null
        if ($Response -match "NextJS") {
            Write-Success "✓ NextJS application works"
            $TestsPassed++
        } else {
            Write-Error "✗ NextJS application failed"
        }
    }
    catch {
        Write-Error "✗ NextJS application failed with exception"
    }
    
    # Test REST API
    $TotalTests++
    try {
        $Response = curl -s -H "Host: api.local" "$BaseUrl/api/status" 2>$null
        if ($Response -match "REST API") {
            Write-Success "✓ REST API works"
            $TestsPassed++
        } else {
            Write-Error "✗ REST API failed"
        }
    }
    catch {
        Write-Error "✗ REST API failed with exception"
    }
    
    Write-Info "Basic functionality: $TestsPassed/$TotalTests tests passed"
    return $TestsPassed -eq $TotalTests
}

function Test-PathRouting {
    Write-Info "Testing path-based routing..."
    
    $BaseUrl = "http://${ManagerIP}:${HttpPort}"
    $TestsPassed = 0
    $TotalTests = 0
    
    # Test path rewriting
    $TotalTests++
    try {
        $Response = curl -s -H "Host: paths.local" "$BaseUrl/app/" 2>$null
        if ($Response -match "Advanced Ingress Test") {
            Write-Success "✓ Path rewriting works"
            $TestsPassed++
        } else {
            Write-Error "✗ Path rewriting failed"
        }
    }
    catch {
        Write-Error "✗ Path rewriting failed with exception"
    }
    
    Write-Info "Path routing: $TestsPassed/$TotalTests tests passed"
    return $TestsPassed -eq $TotalTests
}

function Test-HttpsFunctionality {
    Write-Info "Testing HTTPS functionality..."
    
    $HttpsUrl = "https://${ManagerIP}:${HttpsPort}"
    $TestsPassed = 0
    $TotalTests = 0
    
    # Test HTTPS basic
    $TotalTests++
    try {
        $Response = curl -s -k -H "Host: sample.local" $HttpsUrl 2>$null
        if ($Response -match "Sample Application") {
            Write-Success "✓ HTTPS routing works"
            $TestsPassed++
        } else {
            Write-Warning "✗ HTTPS routing failed (may be expected without certificates)"
        }
    }
    catch {
        Write-Warning "✗ HTTPS routing failed with exception (may be expected)"
    }
    
    Write-Info "HTTPS functionality: $TestsPassed/$TotalTests tests passed"
    return $TestsPassed -gt 0
}

function Test-ErrorHandling {
    Write-Info "Testing error handling..."
    
    $BaseUrl = "http://${ManagerIP}:${HttpPort}"
    $TestsPassed = 0
    $TotalTests = 0
    
    # Test 404 for non-existent host
    $TotalTests++
    try {
        $StatusCode = curl -s -o $null -w "%{http_code}" -H "Host: nonexistent.local" $BaseUrl 2>$null
        if ($StatusCode -eq "404") {
            Write-Success "✓ 404 for non-existent host"
            $TestsPassed++
        } else {
            Write-Error "✗ Expected 404 for non-existent host, got $StatusCode"
        }
    }
    catch {
        Write-Error "✗ Error handling test failed with exception"
    }
    
    Write-Info "Error handling: $TestsPassed/$TotalTests tests passed"
    return $TestsPassed -eq $TotalTests
}

function Show-TestInstructions {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor $Blue
    Write-Host "         MANUAL TEST COMMANDS" -ForegroundColor $Blue
    Write-Host "==========================================" -ForegroundColor $Blue
    Write-Host ""
    Write-Host "Basic Tests:" -ForegroundColor $Green
    Write-Host "  curl -H `"Host: sample.local`" http://${ManagerIP}:${HttpPort}"
    Write-Host "  curl -H `"Host: nextjs.local`" http://${ManagerIP}:${HttpPort}"
    Write-Host "  curl -H `"Host: api.local`" http://${ManagerIP}:${HttpPort}/api/status"
    Write-Host ""
    Write-Host "Advanced Tests:" -ForegroundColor $Green
    Write-Host "  curl -H `"Host: advanced.local`" http://${ManagerIP}:${HttpPort}"
    Write-Host "  curl -H `"Host: advanced.local`" http://${ManagerIP}:${HttpPort}/health"
    Write-Host "  curl -H `"Host: paths.local`" http://${ManagerIP}:${HttpPort}/app/"
    Write-Host ""
    Write-Host "HTTPS Tests:" -ForegroundColor $Green
    Write-Host "  curl -k -H `"Host: sample.local`" https://${ManagerIP}:${HttpsPort}"
    Write-Host ""
    Write-Host "Kubernetes Commands:" -ForegroundColor $Yellow
    Write-Host "  kubectl get pods -n $TestNamespace"
    Write-Host "  kubectl get ingress -n $TestNamespace"
    Write-Host "  kubectl get services -n $TestNamespace"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor $Blue
}

function Cleanup-TestResources {
    Write-Info "Cleaning up test resources..."
    
    try {
        kubectl delete namespace $TestNamespace --ignore-not-found=true --timeout=60s
        Write-Success "Test resources cleaned up"
    }
    catch {
        Write-Warning "Failed to cleanup some resources"
    }
}

function Main {
    if ($Help) {
        Show-Usage
        return
    }
    
    Write-Info "Starting ingress functionality tests..."
    Write-Info "Manager IP: $ManagerIP"
    Write-Info "HTTP Port: $HttpPort"
    Write-Info "HTTPS Port: $HttpsPort"
    Write-Info "Test Namespace: $TestNamespace"
    Write-Host ""
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Error "Prerequisites not met. Exiting."
        return
    }
    
    # Deploy applications if requested
    if ($Deploy) {
        Deploy-TestApplications
        Write-Info "Waiting for applications to be ready..."
        Start-Sleep -Seconds 30
    }
    
    # Run tests
    $AllTestsPassed = $true
    
    if (-not (Test-BasicFunctionality)) {
        $AllTestsPassed = $false
    }
    
    if (-not (Test-PathRouting)) {
        $AllTestsPassed = $false
    }
    
    if (-not (Test-HttpsFunctionality)) {
        # HTTPS failures are not critical
    }
    
    if (-not (Test-ErrorHandling)) {
        $AllTestsPassed = $false
    }
    
    # Show manual test instructions
    Show-TestInstructions
    
    # Cleanup if requested
    if ($Cleanup) {
        Cleanup-TestResources
    }
    
    # Final result
    Write-Host ""
    if ($AllTestsPassed) {
        Write-Success "All critical ingress tests passed! ✓"
    } else {
        Write-Error "Some ingress tests failed! ✗"
    }
    
    Write-Host ""
    Write-Info "Test completed."
}

# Run main function
Main