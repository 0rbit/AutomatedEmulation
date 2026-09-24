<powershell>
# Beginning of bootstrap script
# This script bootstraps the Windows system and runs
# extra scripts downloaded from the s3 bucket

$stagingdir = "C:\terraform"

if (-not (Test-Path -Path $stagingdir)) {
    New-Item -ItemType Directory -Path $stagingdir
    Write-Host "Directory created: $stagingdir"
} else {
    Write-Host "Directory already exists: $stagingdir"
}

# Set logfile and function for writing logfile
$logfile = "C:\Terraform\bootstrap_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}

lwrite("Starting bootstrap powershell script")

# add a local user and add them to Administrators
$admin_username = "${admin_username}"
$admin_password = "${admin_password}"
$op = Get-LocalUser | Where-Object {$_.Name -eq $admin_username}
if ( -not $op ) {
  $secure_string = ConvertTo-SecureString $admin_password -AsPlainText -Force
  New-LocalUser $admin_username -Password $secure_string
  Add-LocalGroupMember -Group "Administrators" -Member $admin_username
  lwrite("User created and added to the Administrators group: $admin_username")
} else {
  lwrite("User already exists: $admin_username")
}

# Set hostname
lwrite("Checking to rename computer to ${hostname}")

$current = $env:COMPUTERNAME

if ($current -ne "${hostname}") {
    Rename-Computer -NewName "${hostname}" -Force
    lwrite("Renaming computer and reboot")
    Restart-Computer -Force
} else {
    lwrite("Hostname already set correctly")
}

lwrite("Installing AWS CLI for private S3 downloads")
$awsCli = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
if (-not (Test-Path $awsCli)) {
  $msi = "C:\terraform\AWSCLIV2.msi"
  Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi
  Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn"
}
$env:Path = "C:\Program Files\Amazon\AWSCLIV2;" + $env:Path
$env:AWS_DEFAULT_REGION = "${region}"

function Download-StagingObject {
  Param ([string]$key, [string]$outfile)
  $MaxAttempts = 5
  $Attempt = 0
  lwrite("Downloading s3://${s3_bucket}/$key to $outfile")
  while ($Attempt -lt $MaxAttempts) {
    $Attempt += 1
    lwrite("Attempt: $Attempt")
    try {
      & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "s3://${s3_bucket}/$key" $outfile --region "${region}"
      if ($LASTEXITCODE -eq 0) {
        lwrite("Successful")
        return
      }
      lwrite("aws s3 cp failed with exit code $LASTEXITCODE. Retrying...")
    } catch {
      lwrite("An unexpected error occurred:")
      lwrite($_.Exception.Message)
    }
    Start-Sleep -Seconds 2
  }
  lwrite("Reached maximum number of attempts. Continuing...")
}

lwrite("Going to download from S3 bucket: ${s3_bucket}")
$scriptFilenames = "${script_files}".split(",")
foreach ($filename in $scriptFilenames) {
  lwrite("Processing script: $filename")
  $outfile = "C:\terraform\" + "$filename"
  Download-StagingObject $filename $outfile

  # Run the script
  lwrite("Running $outfile")
  & $outfile
}

</powershell>
<persist>true</persist>
