########################################################
# This is a script for building all Steeltoe Libraries #
########################################################
Param(
    [Parameter(Mandatory=$true)]
    [string]$Steeltoe_Version_To_Build,
    [switch]$BuildDebug
 )

# Validate/set initial parameters
$env:STEELTOE_VERSION = $Steeltoe_Version_To_Build.Split("-")[0]
# Steeltoe version should be 5+ characters and include 2 periods
If ($env:STEELTOE_VERSION.length -lt 5 -or ($env:STEELTOE_VERSION.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count -ne 2) {
    Write-Error "Please use a version format of 1.2.3"
    return -1
}
If ($Steeltoe_Version_To_Build.Split("-")[1]) {
    $env:STEELTOE_VERSION_SUFFIX = $Steeltoe_Version_To_Build.Split("-")[1]
    $env:STEELTOE_DASH_VERSION_SUFFIX = "-$env:STEELTOE_VERSION_SUFFIX"
}
Else {
    $env:STEELTOE_VERSION_SUFFIX = ""
    $env:STEELTOE_DASH_VERSION_SUFFIX = ""
}

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

Write-Host "Steeltoe version:" $env:STEELTOE_VERSION
Write-Host "Steeltoe version suffix:" $(If($env:STEELTOE_VERSION_SUFFIX) { $env:STEELTOE_VERSION_SUFFIX } Else { "N/A" })

If (-Not $BuildDebug) {
    Write-Warning "Build type not set. Defaulting to config:Release branch:master"
    $env:BUILD_TYPE = "Release"
    $env:BranchFilter = "--single-branch -b master"
}
Else {
    Write-Host "Debug build specified, we'll use default branches as a side effect"
    $env:BUILD_TYPE = $BuildType
    $env:BUILD_TYPE = "Debug"
    $env:BranchFilter = ""
}
If (-Not $env:SteeltoeRepositoryList) {
    Write-Information "Steeltoe repository list not set in Environment, using complete list"
    $s = "SteeltoeOSS"
    $p = "pivotal-cf"
    $env:SteeltoeRepositoryList = "$s/Common $s/Configuration $p/spring-cloud-dotnet-configuration $s/logging $s/connectors " + 
                                        "$s/discovery $p/spring-cloud-dotnet-discovery $s/security $s/management $s/circuitbreaker"
}
Else {
    Write-Information "Using repository list from environment: $env:SteeltoeRepositoryList"
}

# start the clock
$TotalTime = New-Object -TypeName System.Diagnostics.Stopwatch
$TotalTime.Start()

# setup a local folder NuGet feed for use during the build
mkdir artifacts -Force
nuget sources add -Name artifacts -Source "$(Get-Location)\artifacts"
nuget sources add -Name SteeltoeStaging -Source https://www.myget.org/F/steeltoestaging/api/v3/index.json

# ensure the workspace is clean
Remove-Item workspace -Force -Recurse -ErrorAction SilentlyContinue
[int]$env:TestErrors = 0
$env:ProcessTimes = ""

mkdir workspace -Force
Set-Location workspace

ForEach ($_ in $env:SteeltoeRepositoryList.Split(' ')) {
    $ProjectTime = New-Object -TypeName System.Diagnostics.Stopwatch
    $ProjectTime.Start()
    # build the clone command as a string to then execute so the branch filter works
    $cloneString = "git clone -q $env:BranchFilter https://github.com/$_.git"
    Write-Host "Cloning repository with this command: " $cloneString
    Invoke-Expression $cloneString

    Set-Location $_.Split("/")[1]
    Copy-Item config/versions.props versions.props
    # modify versions.props (xml) to update all steeltoe references (except SteeltoeVersion and SteeltoeVersionSuffix)
    $xmlContent = [XML](Get-Content("versions.props"))
    $xmlContent.SelectNodes("//Project/PropertyGroup/*[starts-with(local-name(), 'Steeltoe')]") | 
      Where-Object {$_.name -ne "SteeltoeVersion" -and $_.name -ne "SteeltoeVersionSuffix"} | 
      ForEach-Object {
        Write-Host "Original value of"$_.Name"is"$_.InnerXml
        $_.InnerXml = $env:STEELTOE_VERSION + $env:STEELTOE_DASH_VERSION_SUFFIX
        Write-Host "Updated value of"$_.Name"is"$_.InnerXml
    }
    $xmlContent.OuterXml | Out-File "versions.props"

    dotnet build --configuration $env:BUILD_TYPE
    If ($LastExitCode -ne 0) {
        Write-Error "Build Failure in $_"
        return -1
    }

    If ($env:RunUnitTests) {
        Set-Location test
        # run tests in each project in the test folder where the folder is named .test
        # this filter will skip integration tests that generally assume another thing (like config server) is running
        Get-ChildItem -Directory -Filter "*.Test" | ForEach-Object {
            Set-Location $_.Name
            dotnet xunit -verbose
            $env:TestErrors = $env:TestErrors + $lastexitcode
            if ($lastexitcode) {
                Write-Error "Test failures encountered in $_"
            }
            Set-Location ..
        }
        Set-Location ..
    }

        # build packages
        Set-Location src
        Get-ChildItem -Directory | ForEach-Object {
            Set-Location $_.Name
            dotnet pack --no-build --configuration $env:BUILD_TYPE /p:Version=$env:STEELTOE_VERSION$env:STEELTOE_DASH_VERSION_SUFFIX --output ../../../../artifacts
            Set-Location ..
        }
        Set-Location ..
    Set-Location ..
    $ProjectTime.Stop()
    Write-Host "Process time for $_ :" $ProjectTime.Elapsed.ToString()
    $env:ProcessTimes += $_ + ":" + $ProjectTime.Elapsed.ToString() + ";"
}
Set-Location ..

# cleanup
nuget sources remove -Name artifacts

# display processing times
Write-Host "Package build process times:"
ForEach ($_ in $env:ProcessTimes.Split(';')) { 
    Write-Host $_ 
}

$TotalTime.Stop()
Write-Host "Total process time:" $TotalTime.Elapsed.ToString()