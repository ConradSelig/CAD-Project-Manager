# projman.ps1

param (
    [Parameter(Position=0)]
    [string]$Command,
    [switch]$v,  # Verbose flag
    [switch]$h,  # Help flag
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

# Global variables
$global:Verbose = $v.IsPresent
$global:LogBuffer = @()
$global:Success = $true

# Function to write log messages to console or buffer
function Write-Log {
    param (
        [string]$Message
    )
    $timestampedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    if ($global:Verbose) {
        Write-Host $timestampedMessage
    } else {
        $global:LogBuffer += $timestampedMessage
    }
}

# Function to dump log buffer to error.txt on failure
function Dump-ErrorLog {
    if (-not $global:Verbose -and -not $global:Success) {
        $errorFile = Join-Path -Path (Get-Location) -ChildPath "error.txt"
        $global:LogBuffer | Out-File -FilePath $errorFile
        Write-Host "Project setup failed. Details written to '$errorFile'."
    } elseif (-not $global:Success) {
        Write-Host "Project setup failed."
    } else {
        Write-Host "Project setup complete."
    }
}

# Function to display help
function Show-Help {
    Write-Host "Usage: projman.ps1 [command] [args] [-v] [-h]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  newproject [project name]  Create a new FreeCAD project with Git and LFS."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -v                        Enable verbose output."
    Write-Host "  -h                        Display this help message."
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  projman.ps1 newproject MyProject -v"
    exit 0
}

# Function to create a new project
function New-Project {
    param (
        [string[]]$Arguments
    )

    # Ensure exactly one argument (project name) is provided
    if ($Arguments.Count -ne 1) {
        Write-Log "Error: 'newproject' requires exactly one argument: [project name]"
        $global:Success = $false
        return
    }

    $projectName = $Arguments[0]

    # Step 1: Create project folder
    $projectPath = Join-Path -Path (Get-Location) -ChildPath $projectName
    if (-not (Test-Path $projectPath)) {
        New-Item -Path $projectPath -ItemType Directory | Out-Null
        Write-Log "Project folder '$projectPath' created."
    } else {
        Write-Log "Error: Folder '$projectPath' already exists."
        $global:Success = $false
        return
    }

    # Change to project directory
    Set-Location -Path $projectPath

    # Step 2: Copy Template.FCStd from script directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $templateFile = Join-Path -Path $scriptDir -ChildPath "Template.FCStd"
    $fcstdFile = "$projectName.FCStd"

    if (Test-Path $templateFile) {
        Copy-Item -Path $templateFile -Destination $fcstdFile -Force
        Write-Log "Template.FCStd copied to '$fcstdFile'."
    } else {
        Write-Log "Error: 'Template.FCStd' not found in script directory '$scriptDir'."
        $global:Success = $false
        return
    }

    # Step 3: Initialize Git repository
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git init | Out-Null
        Write-Log "Git repository initialized."
    } else {
        Write-Log "Error: Git is not installed or not in PATH."
        $global:Success = $false
        return
    }

    # Step 4: Create .gitignore for FCBak files
    $gitignoreContent = "*.FCBak"
    $gitignoreFile = ".gitignore"
    Set-Content -Path $gitignoreFile -Value $gitignoreContent
    Write-Log ".gitignore created to ignore '*.FCBak' files."

    # Step 5: Enable Git LFS for .FCStd files
    if (Get-Command git-lfs -ErrorAction SilentlyContinue) {
        git lfs track "*.FCStd" | Out-Null
        Write-Log "Git LFS enabled for '*.FCStd' files."
    } else {
        Write-Log "Error: Git LFS is not installed or not in PATH."
        $global:Success = $false
        return
    }

    # Step 6: Add files to the repo
    git add $fcstdFile | Out-Null
    git add .gitattributes | Out-Null
    git add $gitignoreFile | Out-Null
    Write-Log "Files '$fcstdFile', '.gitattributes', and '.gitignore' added to Git."

    # Step 7: Commit with message "Project Initialization"
    git commit -m "Project Initialization" | Out-Null
    Write-Log "Initial commit created with message 'Project Initialization'."

    # Step 8: Push to GitHub
    try {
        git push origin main -u | Out-Null
        Write-Log "Project pushed to GitHub remote 'origin' on branch 'main'."
    } catch {
        Write-Log "Error: Failed to push to GitHub. Ensure 'origin' is set and accessible."
        Write-Log "Run: git remote add origin <github-url> and try again."
        $global:Success = $false
        return
    }
}

# Main script logic
if ($h) {
    Show-Help
}

if (-not $Command) {
    Write-Log "Error: No command provided. Usage: projman.ps1 [command] [args] [-v] [-h]"
    $global:Success = $false
    Dump-ErrorLog
    exit 1
}

switch ($Command.ToLower()) {
    "newproject" {
        if ($global:Verbose) { Write-Log "Starting new project creation..." }
        New-Project -Arguments $Args
        if ($global:Verbose -and $global:Success) { Write-Log "Project setup complete." }
        Dump-ErrorLog
    }
    default {
        Write-Log "Error: Unknown command '$Command'. Usage: projman.ps1 [command] [args] [-v] [-h]"
        Write-Log "Supported commands: newproject [project name]"
        $global:Success = $false
        Dump-ErrorLog
    }
}