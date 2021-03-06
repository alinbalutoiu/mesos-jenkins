$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TD_AGENT = "td-agent-3.1.1-0-x64.msi"
$url = "http://packages.treasuredata.com.s3.amazonaws.com/3/windows/$TD_AGENT"
$MSI_PATH = Join-Path $here $TD_AGENT
$fluentPath = "$env:SystemDrive\opt\td-agent\embedded\bin"
$env:Path = "$fluentPath;" + $env:Path.Replace("$fluentPath;", "")

function Get-Fluentd () {
    Write-Host "Downloading fluentd/td-agent..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $MSI_PATH)
}

function Install-Fluentd () {
    Write-Host "Installing fluentd..."
    
    [System.IO.FileSystemInfo] $file = Get-Item $MSI_PATH
    [String] $DataStamp = get-date -Format yyyyMMddTHHmmss
    [String] $logFile = '{0}-{1}.log' -f $file.FullName, $DataStamp
    
    $MSIArguments = @(
        "/i"                         # Install
        ('"{0}"' -f $file.fullname)  # MSI path
        "/qn"                        # No UI
        "/norestart"                 # No computer restart
        "/L*v"                       # Log everything including verbose
        $logFile                     # Log file name
    )
    
    $process = Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        throw "ERROR: Failed to install Fluentd. Error code: " + $process.ExitCode + " See details in log: $logfile"
    }
}

function Register-FluentdService () {
    Write-Host "Registering fluentd service..."
    fluentd --reg-winsvc i
    if ($LASTEXITCODE) {
        Throw "Failed to register fluentd Windows service. ExitCode = $LASTEXITCODE"
    }

    fluentd --reg-winsvc-fluentdopt "-c $env:SystemDrive/opt/td-agent/etc/td-agent/td-agent.conf -o $env:SystemDrive/opt/td-agent/td-agent.log"
    if ($LASTEXITCODE) {
        Throw "Failed to set options for fluentd Windows service. ExitCode = $LASTEXITCODE"
    }
}

function Start-FluentdService () {
    Write-Host "Starting fluentd service..."
    Start-Service fluentdwinsvc
}

try {
    Get-Fluentd
    Install-Fluentd
    Register-FluentdService
    Start-FluentdService
}
catch {
    Write-Output $_.ToString()
    Write-Output $_.ScriptStackTrace
    exit 1
}
exit 0