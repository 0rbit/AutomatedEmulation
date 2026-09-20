
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\sysmon_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting sysmon.ps1")

# Set DNS resolver to google
lwrite("Setting DNS resolver to public DNS")
$myindex = Get-Netadapter -Name "Ethernet" | Select-Object -ExpandProperty IfIndex
  Set-DNSClientServerAddress -InterfaceIndex $myindex -ServerAddresses "8.8.8.8"

# Download Sysmon config xml
$outfile = "C:\terraform\" + "${sysmon_config}"
$awsCli = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
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
      & $awsCli s3 cp "s3://${s3_bucket}/$key" $outfile --region "${region}"
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

if (Test-Path -Path "C:\Terraform\${sysmon_config}") {
  lwrite("sysmon config exists")
} else {
  Download-StagingObject "${sysmon_config}" $outfile
}
# Finished Download of Sysmon config xml


# Download Sysmon zip 
$outfile = "C:\terraform\" + "${sysmon_zip}"
lwrite("Going to download from S3 bucket: ${s3_bucket}")

if (Test-Path -Path "C:\Terraform\${sysmon_zip}") {
  lwrite("sysmon zip exists")
} else {
  Download-StagingObject "${sysmon_zip}" $outfile
}
# Finished Download of Sysmon zip

# Expand the Sysmon zip archive
if (Test-Path -Path "C:\Terraform\${sysmon_zip}") {
  lwrite("Expand the sysmon zip file")
  Expand-Archive -Force -LiteralPath 'C:\terraform\${sysmon_zip}' -DestinationPath 'C:\terraform\Sysmon' 
} else {
  lwrite("Something wrong - sysmon zip file doesn't exist")
}

# Copy the Sysmon configuration for SwiftOnSecurity to destination Sysmon folder
lwrite("Copy the Sysmon configuration for SwiftOnSecurity to destination Sysmon folder")
Copy-Item "C:\terraform\sysmonconfig-export.xml" -Destination "C:\terraform\Sysmon"

# Install Sysmon
lwrite("Install Sysmon")
C:\terraform\Sysmon\sysmon.exe -accepteula -i C:\terraform\Sysmon\sysmonconfig-export.xml 

lwrite("End of sysmon.ps1")
