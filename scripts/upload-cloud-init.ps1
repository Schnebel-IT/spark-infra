# Upload cloud-init files to Proxmox
# PowerShell script for Windows

param(
    [switch]$Force,
    [switch]$Help
)

# Color functions
function Write-Info($message) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] WARNING: $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $message" -ForegroundColor Red
}

function Show-Usage {
    Write-Host @"
Usage: .\upload-cloud-init.ps1 [OPTIONS]

Upload cloud-init user-data files to Proxmox snippets storage

OPTIONS:
    -Force              Overwrite existing files
    -Help               Show this help message

EXAMPLES:
    .\upload-cloud-init.ps1                # Upload all cloud-init files
    .\upload-cloud-init.ps1 -Force         # Force overwrite existing files

REQUIREMENTS:
    - SSH client (OpenSSH or PuTTY)
    - SCP client
    - Access to Proxmox server

"@
}

if ($Help) {
    Show-Usage
    exit 0
}

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"
$TerraformVars = Join-Path $TerraformDir "terraform.tfvars"

Write-Info "Starting cloud-init upload process"
Write-Info "Project root: $ProjectRoot"

# Check if terraform.tfvars exists
if (-not (Test-Path $TerraformVars)) {
    Write-Error "terraform.tfvars not found in $TerraformDir"
    exit 1
}

# Extract Proxmox connection details
Write-Info "Reading Proxmox connection details..."

$ProxmoxApiUrl = (Select-String -Path $TerraformVars -Pattern '^proxmox_api_url\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$ProxmoxUser = (Select-String -Path $TerraformVars -Pattern '^proxmox_user\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$ProxmoxPassword = (Select-String -Path $TerraformVars -Pattern '^proxmox_password\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$ProxmoxNode = (Select-String -Path $TerraformVars -Pattern '^proxmox_node\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value

if (-not $ProxmoxApiUrl -or -not $ProxmoxUser -or -not $ProxmoxPassword -or -not $ProxmoxNode) {
    Write-Error "Could not extract Proxmox connection details from terraform.tfvars"
    exit 1
}

# Extract host from API URL
$ProxmoxHost = $ProxmoxApiUrl -replace 'https://', '' -replace ':8006/api2/json', ''

Write-Info "Proxmox Host: $ProxmoxHost"
Write-Info "Proxmox User: $ProxmoxUser"
Write-Info "Proxmox Node: $ProxmoxNode"

# Function to upload a file
function Upload-File {
    param(
        [string]$LocalFile,
        [string]$RemoteFile,
        [bool]$ForceUpload
    )
    
    if (-not (Test-Path $LocalFile)) {
        Write-Error "Local file not found: $LocalFile"
        return $false
    }
    
    Write-Info "Uploading: $LocalFile -> $RemoteFile"
    
    # Check if SCP is available
    $scpCommand = Get-Command scp -ErrorAction SilentlyContinue
    if (-not $scpCommand) {
        Write-Error "SCP command not found. Please install OpenSSH client."
        return $false
    }
    
    # Upload the file using SCP
    try {
        $scpArgs = @(
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=NUL",
            $LocalFile,
            "root@${ProxmoxHost}:/var/lib/vz/snippets/$RemoteFile"
        )
        
        & scp @scpArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Uploaded: $RemoteFile"
            
            # Set proper permissions
            $sshArgs = @(
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=NUL",
                "root@$ProxmoxHost",
                "chmod 644 /var/lib/vz/snippets/$RemoteFile"
            )
            
            & ssh @sshArgs
            
            return $true
        } else {
            Write-Error "Failed to upload: $RemoteFile"
            return $false
        }
    } catch {
        Write-Error "Error uploading file: $_"
        return $false
    }
}

# Upload all cloud-init files
Write-Info "Uploading all cloud-init files to Proxmox..."

$CloudInitDir = Join-Path $TerraformDir "cloud-init"
$UploadCount = 0
$ErrorCount = 0

# Files to upload
$FilesToUpload = @(
    @{ Local = "user-data-k8s-manager.yml"; Remote = "user-data-k8s-manager.yml" },
    @{ Local = "user-data-k8s-node-1.yml"; Remote = "user-data-k8s-node-1.yml" },
    @{ Local = "user-data-k8s-node-2.yml"; Remote = "user-data-k8s-node-2.yml" },
    @{ Local = "user-data-k8s-node-3.yml"; Remote = "user-data-k8s-node-3.yml" }
)

foreach ($File in $FilesToUpload) {
    $LocalPath = Join-Path $CloudInitDir $File.Local
    
    if (Test-Path $LocalPath) {
        if (Upload-File -LocalFile $LocalPath -RemoteFile $File.Remote -ForceUpload $Force) {
            $UploadCount++
        } else {
            $ErrorCount++
        }
    } else {
        Write-Warning "$($File.Local) not found. Run 'terraform plan' first."
        $ErrorCount++
    }
}

# Summary
Write-Info "Upload Summary:"
Write-Info "- Successfully uploaded: $UploadCount files"
if ($ErrorCount -gt 0) {
    Write-Warning "- Errors/Skipped: $ErrorCount files"
}

if ($UploadCount -gt 0) {
    Write-Success "Cloud-init files uploaded successfully!"
    Write-Info "You can now run 'terraform apply' to create VMs with the updated configuration"
} else {
    Write-Error "No files were uploaded successfully"
    exit 1
}