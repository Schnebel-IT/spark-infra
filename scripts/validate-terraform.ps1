# Terraform Infrastructure Validation Script (PowerShell)
# This script validates the Terraform infrastructure deployment

param(
    [int]$Timeout = 300  # 5 minutes timeout for VM readiness
)

# Configuration
$TerraformDir = "terraform"
$ErrorActionPreference = "Stop"

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"

Write-Host "Starting Terraform infrastructure validation..." -ForegroundColor $Yellow

# Function to print status
function Print-Status {
    param([bool]$Success, [string]$Message)
    
    if ($Success) {
        Write-Host "✓ $Message" -ForegroundColor $Green
    } else {
        Write-Host "✗ $Message" -ForegroundColor $Red
        throw "Validation failed: $Message"
    }
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    
    $exists = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $exists) {
        Write-Host "Error: $Command is not installed" -ForegroundColor $Red
        exit 1
    }
}

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor $Yellow
Test-Command "terraform"

# Change to terraform directory
Push-Location $TerraformDir

try {
    # Validate Terraform configuration
    Write-Host "Validating Terraform configuration..." -ForegroundColor $Yellow
    $validateResult = terraform validate
    if ($LASTEXITCODE -eq 0) {
        Print-Status $true "Terraform configuration is valid"
    } else {
        Print-Status $false "Terraform configuration validation failed"
    }

    # Check Terraform state
    Write-Host "Checking Terraform state..." -ForegroundColor $Yellow
    if (-not (Test-Path "terraform.tfstate")) {
        Write-Host "Error: terraform.tfstate not found. Run 'terraform apply' first." -ForegroundColor $Red
        exit 1
    }

    # Get outputs
    Write-Host "Retrieving Terraform outputs..." -ForegroundColor $Yellow
    $managerIp = terraform output -raw manager_ip 2>$null
    $nodeIpsJson = terraform output -json node_ips 2>$null
    
    if ([string]::IsNullOrEmpty($managerIp)) {
        Write-Host "Error: Could not retrieve manager IP from Terraform outputs" -ForegroundColor $Red
        exit 1
    }
    
    $nodeIps = $nodeIpsJson | ConvertFrom-Json
    
    Print-Status $true "Retrieved infrastructure information"
    Write-Host "  Manager IP: $managerIp"
    Write-Host "  Node IPs: $($nodeIps -join ', ')"

    # Test network connectivity
    Write-Host "Testing network connectivity..." -ForegroundColor $Yellow

    # Test manager connectivity
    $pingResult = Test-Connection -ComputerName $managerIp -Count 3 -Quiet
    Print-Status $pingResult "Manager ($managerIp) is reachable"

    # Test node connectivity
    foreach ($ip in $nodeIps) {
        $pingResult = Test-Connection -ComputerName $ip -Count 3 -Quiet
        Print-Status $pingResult "Node ($ip) is reachable"
    }

    # Test SSH connectivity (if available)
    Write-Host "Testing SSH connectivity..." -ForegroundColor $Yellow
    
    # Function to wait for SSH
    function Wait-ForSSH {
        param([string]$IP, [int]$TimeoutSeconds)
        
        $elapsed = 0
        while ($elapsed -lt $TimeoutSeconds) {
            try {
                # Try to establish SSH connection (requires SSH client)
                $sshTest = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "ubuntu@$IP" 'exit' 2>$null
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            } catch {
                # SSH might not be available on Windows
            }
            Start-Sleep 10
            $elapsed += 10
        }
        return $false
    }

    # Test SSH if available
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        # Test manager SSH
        $sshResult = Wait-ForSSH $managerIp $Timeout
        Print-Status $sshResult "SSH connection to manager ($managerIp) is working"

        # Test node SSH
        foreach ($ip in $nodeIps) {
            $sshResult = Wait-ForSSH $ip $Timeout
            Print-Status $sshResult "SSH connection to node ($ip) is working"
        }
    } else {
        Write-Host "SSH client not available, skipping SSH connectivity tests" -ForegroundColor $Yellow
    }

    Write-Host "Terraform infrastructure validation completed successfully!" -ForegroundColor $Green
    Write-Host "Next steps:" -ForegroundColor $Yellow
    Write-Host "1. Run Ansible playbooks to install Kubernetes"
    Write-Host "2. Configure kubectl access"
    Write-Host "3. Deploy applications"

} finally {
    Pop-Location
}