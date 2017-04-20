$nugetExeUrl = "https://dist.nuget.org/win-x86-commandline/v4.0.0/nuget.exe"
$nugetExe = "$PSScriptRoot\nuget.exe"
$nugetV3Api = "https://api.nuget.org/v3/index.json"
Get-Date -Format o
$OutputTimeStamp = Get-Date -Format o | foreach {$_ -replace ":", "."}
$outputDir = "$PSScriptRoot\$OutputTimeStamp"

New-Item -ItemType Directory -Path $outputDir | Out-Null

<#
Package restore tests
#>

Function Get-NuGetExe
{
    #Write-Output "Downloading nuget.exe from $nugetExeUrl"
    
    Write-Output "Using modified nuget.exe from script root"

    $start_time = Get-Date

    #Invoke-WebRequest -Uri $nugetExeUrl -OutFile $nugetExe

    #Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Output ""
}

Function New-TestScenario ($packageId, $packageVersion, $disableparallel)
{

    Write-Output "Initiating test scenario for $packageId $packageVersion"

    $testDir = "$PSScriptRoot\TestScenario-$packageId-$packageVersion"
    $packagesDir = Join-Path $testDir "packages"

    If (Test-Path $testDir){
	    Remove-Item $testDir -Force -Recurse | Out-Null
    }
    
    & $nugetExe locals all -clear

    If (Test-Path $packagesDir){
	    Remove-Item $packagesDir -Force -Recurse | Out-Null
    }
    
    New-Item -ItemType Directory -Path $testDir | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testDir "Properties") | Out-Null

    Add-Content -Path (Join-Path $testDir "project.json") -Value (@'
{
    "dependencies": { 
		"
'@ + $packageId + '": "' + $packageVersion + @'
"
    },
    "frameworks": {        
        ".NETFramework,Version=v4.6.1": { }
    },
    "supports": { }
}
'@)

    Add-Content -Path (Join-Path $testDir "App.config") -Value @'
<?xml version="1.0" encoding="utf-8" ?>
<configuration>
    <startup> 
        <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.6.2" />
    </startup>
</configuration>
'@

    Add-Content -Path (Join-Path $testDir "Program.cs") -Value @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NuGetRestoreTest
{
    class Program
    {
        static void Main(string[] args)
        {
        }
    }
}
'@

    Add-Content -Path (Join-Path $testDir "Properties\AssemblyInfo.cs") -Value @'
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("NuGetRestoreTest")]
[assembly: AssemblyDescription("")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("")]
[assembly: AssemblyProduct("NuGetRestoreTest")]
[assembly: AssemblyCopyright("Copyright ©  2017")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]
[assembly: ComVisible(false)]
[assembly: Guid("4d7906ee-0ed7-4d88-8c08-b7ab7406f4b1")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]
'@

    $projectFile = (Join-Path $testDir "NuGetRestoreTest.csproj")
    Add-Content -Path $projectFile -Value @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
    <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProjectGuid>{4D7906EE-0ED7-4D88-8C08-B7AB7406F4B1}</ProjectGuid>
    <OutputType>Exe</OutputType>
    <RootNamespace>NuGetRestoreTest</RootNamespace>
    <AssemblyName>NuGetRestoreTest</AssemblyName>
    <TargetFrameworkVersion>v4.6.2</TargetFrameworkVersion>
    <FileAlignment>512</FileAlignment>
    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
    </PropertyGroup>
    <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
    <PlatformTarget>AnyCPU</PlatformTarget>
    <DebugSymbols>true</DebugSymbols>
    <DebugType>full</DebugType>
    <Optimize>false</Optimize>
    <OutputPath>bin\Debug\</OutputPath>
    <DefineConstants>DEBUG;TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
    </PropertyGroup>
    <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
    <PlatformTarget>AnyCPU</PlatformTarget>
    <DebugType>pdbonly</DebugType>
    <Optimize>true</Optimize>
    <OutputPath>bin\Release\</OutputPath>
    <DefineConstants>TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
    </PropertyGroup>
    <ItemGroup>
    <Reference Include="System" />
    <Reference Include="System.Core" />
    <Reference Include="Microsoft.CSharp" />
    </ItemGroup>
    <ItemGroup>
    <Compile Include="Program.cs" />
    <Compile Include="Properties\AssemblyInfo.cs" />
    </ItemGroup>
    <ItemGroup>
    <None Include="App.config" />
    </ItemGroup>
    <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
</Project>
'@

    filter timestamp {"$(Get-Date -Format o): $_"}

    IF ($disableparallel -eq "Y")
    {

        Write-Output "Invoking nuget restore command: $nugetExe restore $projectFile -Verbosity detailed -OutputDirectory $packagesDir -NoCache -source $nugetV3Api"
        & $nugetExe restore $projectFile -Verbosity detailed -OutputDirectory $packagesDir -NoCache -source $nugetV3Api -msbuildversion 4.0 -disableparallel | timestamp | Tee-Object -Variable restoreCmdOutput

    }

    else

    {
        Write-Output "Invoking nuget restore command: $nugetExe restore $projectFile -Verbosity detailed -OutputDirectory $packagesDir -NoCache -source $nugetV3Api"
        & $nugetExe restore $projectFile -Verbosity detailed -OutputDirectory $packagesDir -NoCache -source $nugetV3Api -msbuildversion 4.0 | timestamp | Tee-Object -Variable restoreCmdOutput
    }

    $logFile = "$outputDir\TestScenario_v2_$disableparallel-$packageId-$packageVersion-log.txt"
    Write-Output "Creating $logFile file"
    If (Test-Path $logFile){
	    Remove-Item $logFile -Force
    }
    Add-Content $logFile $restoreCmdOutput
        
    #If (Test-Path $testDir){
	#    Remove-Item $testDir -Force -Recurse | Out-Null
    #}

    Write-Output "Completed test scenario for $packageId $packageVersion"
    Write-Output ""
    Remove-Item $testDir -Force -Recurse
}


<#
URL tests.
#>

function Get-Sha512Algo()
{
	return [System.Security.Cryptography.SHA512]::Create();
}

function Get-StreamHash([System.Security.Cryptography.HashAlgorithm]$HashAlgo, [System.IO.Stream]$Stream)
{
	$HashAlgo.ComputeHash($Stream);
}

function Get-ArrayHash([System.Security.Cryptography.HashAlgorithm]$HashAlgo, [Byte[]]$Bytes)
{
	$HashAlgo.ComputeHash($Bytes);
}

function Get-HexString([Byte[]]$Bytes)
{
	return ($Bytes | ForEach-Object {$_.ToString("X2")}) -join "";
}

function Get-Base64String([Byte[]]$Bytes)
{
	return [System.Convert]::ToBase64String($Bytes);
}

function Test-Url([string]$Url)
{
	Write-Output "[$((Get-Date).ToUniversalTime().ToString("O"))] $($Url):";
	try
	{
		$mr = Measure-Command { $r = Invoke-WebRequest -Uri $Url };
	}
	catch
	{
		Write-Output "`tFailed to retrieve: $($_.Exception.ToString())";
		return;
	}
	$sp = [System.Net.ServicePointManager]::FindServicePoint($Url);
	Write-Output "`tTime taken      : $($mr.TotalMilliseconds) ms"
	Write-Output "`tRawContentLength: $($r.RawContentLength) bytes";
	if ($r.Content -is [Byte[]])
	{
		Write-Output "`tContent length  : $($r.Content.Length) bytes";
		$hashBytes = Get-StreamHash -HashAlgo (Get-Sha512Algo) -Stream $r.RawContentStream;
#		$hashBytes = Get-ArrayHash -HashAlgo (Get-Sha512Algo) -Bytes $r.Content;
		Write-Output "`tResponse SHA512 : $(Get-HexString -Bytes $hashBytes)";
		Write-Output "`tSHA512 Base64   : $(Get-Base64String -Bytes $hashBytes)";
	}
	if ($sp -ne $null -and $sp.Certificate -ne $null)
	{
		$cert = $sp.Certificate;
		Write-Output "`tCert subject    : $($cert.Subject)";
		Write-Output "`tCert issuer     : $($cert.Issuer)";
		Write-Output "`tCert thumbprint : $($cert.GetCertHashString())";
		Write-Output "`tCert serial No  : $($cert.GetSerialNumberString())";
	}
	else
	{
		Write-Output "`tNo cert info found..."
	}
}


<#
An MTR clone for PowerShell.
#>

Function script:Set-Variables ($Target)
{
[int]$PingCycles = 5 #Default to 10 pings per hop; minimum of 5, maximum of 100
[int]$BufLen = 32 #Default to 32 bytes of data in the ICMP packet, maximum of 1000 bytes
[IPAddress]$DNSServer = $Null
[String]$Filename = "Traceroute_$Target"

$PerTraceArr = @()
$script:ASNOwnerArr = @()
$ASNOwnerObj = New-Object PSObject
$ASNOwnerObj | Add-Member NoteProperty "ASN"("AS0")
$ASNOwnerObj | Add-Member NoteProperty "ASN Owner"("EvilCorp")
$ASNOwnerArr += $ASNOwnerObj #Add some values so the array isn't empty when first checked.
$script:i = 0
$script:x = 0
$script:z = 0
$script:WHOIS = ".origin.asn.cymru.com"
$script:ASNWHOIS = ".asn.cymru.com"
} #End Set-Variables

Function script:Set-WindowSize {
$Window = $Host.UI.RawUI
  If ($Window.BufferSize.Width -lt 175 -OR $Window.WindowSize.Width -lt 175) {
    $NewSize = $Window.BufferSize
    $NewSize.Height = 3000
    $NewSize.Width = 175
    $Window.BufferSize = $NewSize

    #$NewSize = $Window.WindowSize
    #$NewSize.Height = 50
    #$NewSize.Width = 175
    #$Window.WindowSize = $NewSize
  }
} #End Set-WindowSize

Function script:Get-Traceroute {
  $script:TraceResults = Test-NetConnection $Target -InformationLevel Detailed -TraceRoute | Select -ExpandProperty TraceRoute
} #End Get-Traceroute

Function script:Resolve-ASN {
  $HopASN = $null #Reset to null each time
  $HopASNRecord = $null #Reset to null each time
  If ($Hop -notlike "TimedOut" -AND $Hop -notmatch "^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\..*") { #Don't waste a lookup on RFC1918 IPs
    $HopSplit = $Hop.Split('.')
    $HopRev = $HopSplit[3] + '.' + $HopSplit[2] + '.' + $HopSplit[1] + '.' + $HopSplit[0]
    $HopASNRecord = Resolve-DnsName -Server $DNSServer -Type TXT -Name $HopRev$WHOIS -ErrorAction SilentlyContinue | Select Strings
  }
  Else {
    $HopASNRecord = $null
  }

  If ($HopASNRecord.Strings -AND $HopASNRecord.Strings.GetType().IsArray){ #Check for array;
    $HopASN = "AS"+$HopASNRecord.Strings[0].Split('|').Trim()[0]
    Write-Verbose "Object found $HopASN"
  }

  ElseIf ($HopASNRecord.Strings -AND $HopASNRecord.Strings.GetType().FullName -like "System.String"){ #Check for string; normal case.
    $HopASN = "AS"+$HopASNRecord.Strings[0].Split('|').Trim()[0]
    Write-Verbose "String found $HopASN"
  }

  Else {
    $HopASN = "-"
  }
} #End Resolve-ASN

Function script:Resolve-ASNOwner {
  If ($HopASN -notlike "-") {  
  $IndexNo = $ASNOwnerArr.ASN.IndexOf($HopASN)
  Write-Verbose "Current object: $ASNOwnerObj"
  
    If (!($ASNOwnerArr.ASN.Contains($HopASN)) -OR ($ASNOwnerArr."ASN Owner"[$IndexNo].Contains('-'))){ #Keep "ASNOwnerArr.ASN" in double quotes so it will be treated as a string and not an object
      Write-Verbose "ASN $HopASN not previously resolved; performing lookup" #Check the previous lookups before running this unnecessarily
      $HopASNOwner = Resolve-DnsName -Server $DNSServer -Type TXT -Name $HopASN$ASNWHOIS -ErrorAction SilentlyContinue | Select Strings

	  If ($HopASNOwner.Strings -AND $HopASNOwner.Strings.GetType().IsArray){ #Check for array;
        $HopASNOwner = $HopASNOwner.Strings[0].Split('|').Trim()[4].Split('-')[0]
        Write-Verbose "Object found $HopASNOwner"
      }
	  ElseIf ($HopASNRecord.Strings -AND $HopASNRecord.Strings.GetType().FullName -like "System.String"){ #Check for string; normal case.
        $HopASNOwner = $HopASNOwner.Strings[0].Split('|').Trim()[4].Split('-')[0]
        Write-Verbose "String found $HopASNOwner"
	  }
	  Else {
        $HopASNOwner = "-"
	  }
	  $ASNOwnerObj | Add-Member NoteProperty "ASN"($HopASN) -Force
	  $ASNOwnerObj | Add-Member NoteProperty "ASN Owner"($HopASNOwner) -Force
	  $ASNOwnerArr += $ASNOwnerObj #Add our new value to the cache
    }
    Else { #We get to use a cached entry and save Team Cymru some lookups
      Write-Verbose "ASN Owner found in cache"
	  $HopASNOwner = $ASNOwnerArr[$IndexNo]."ASN Owner"
    }
  }
  Else {
    $HopASNOwner = "-"
    Write-Verbose "ASN Owner lookup not performed - RFC1918 IP found or hop TimedOut"
  }
} #End Resolve-ASNOwner

Function script:Resolve-DNS {
$HopNameArr = $null
$script:HopName = New-Object psobject
  If ($Hop -notlike "TimedOut" -and $Hop -notlike "0.0.0.0") {
    $z++ #Increment the count for the progress bar
    $script:HopNameArr = Resolve-DnsName -Server $DNSServer -Type PTR $Hop -ErrorAction SilentlyContinue | Select NameHost
    Write-Verbose "Hop = $Hop"

    If ($HopNameArr.NameHost -AND $HopNameArr.NameHost.GetType().IsArray) { #Check for array first; sometimes resolvers are stupid and return NS records with the PTR in an array.
      $script:HopName | Add-Member -MemberType NoteProperty -Name NameHost -Value $HopNameArr.NameHost[0] #If Resolve-DNS brings back an array containing NS records, select just the PTR
      Write-Verbose "Object found $HopName"
    }

    ElseIf ($HopNameArr.NameHost -AND $HopNameArr.NameHost.GetType().FullName -like "System.String") { #Normal case. One PTR record. Will break up an array of multiple PTRs separated with a comma.
      $script:HopName | Add-Member -MemberType NoteProperty -Name NameHost -Value $HopNameArr.NameHost.Split(',')[0].Trim() #In the case of multiple PTRs select the first one
      Write-Verbose "String found $HopName"
    }

    ElseIf ($HopNameArr.NameHost -like $null) { #Check for null last because when an array is returned with PTR and NS records, it contains null values.
      $script:HopName | Add-Member -MemberType NoteProperty -Name NameHost -Value $Hop #If there's no PTR record, set name equal to IP
      Write-Verbose "HopNameArr apparently empty for $HopName"
    }
    Write-Progress -Activity "Resolving PTR Record" -Status "Looking up $Hop, Hop #$z of $($TraceResults.length)" -PercentComplete ($z / $($TraceResults.length)*100)
  }
  Else {
    $z++
    $script:HopName | Add-Member -MemberType NoteProperty -Name NameHost -Value $Hop #If the hop times out, set name equal to TimedOut
    Write-Verbose "Hop = $Hop"
  }
} #End Resolve-DNS

Function script:Get-PerHopRTT {
  $PerHopRTTArr = @() #Store all RTT values per hop
  $SAPSObj = $null #Clear the array each cycle
  $SendICMP = New-Object System.Net.NetworkInformation.Ping
  $i++ #Advance the count
  $x = 0 #Reset x for the next hop count. X tracks packet loss percentage.
  $BufferData = "a" * $BufLen #Send the UTF-8 letter "a"
  $ByteArr = [Text.Encoding]::UTF8.GetBytes($BufferData)
  If ($Hop -notlike "TimedOut" -and $Hop -notlike "0.0.0.0") { #Normal case, attempt to ping hop
    For ($y = 1; $y -le $PingCycles; $y++){
     $HopResults = $SendICMP.Send($Hop,1000,$ByteArr) #Send the packet with a 1 second timeout
     $HopRTT = $HopResults.RoundtripTime
     $PerHopRTTArr += $HopRTT #Add RTT to HopRTT array
      If ($HopRTT -eq 0) {
        $x = $x + 1
      }
    Write-Progress -Activity "Testing Packet Loss to Hop #$z of $($TraceResults.length)" -Status "Sending ICMP Packet $y of $PingCycles to $Hop - Result: $HopRTT ms" -PercentComplete ($y / $PingCycles*100)
    } #End for loop
    $PerHopRTTArr = $PerHopRTTArr | Where-Object {$_ -gt 0} #Remove zeros from the array
    $HopRTTMin = "{0:N0}" -f ($PerHopRTTArr | Measure-Object -Minimum).Minimum
    $HopRTTMax = "{0:N0}" -f ($PerHopRTTArr | Measure-Object -Maximum).Maximum
    $HopRTTAvg = "{0:N0}" -f ($PerHopRTTArr | Measure-Object -Average).Average
    $HopLoss = "{0:N1}" -f (($x / $PingCycles) * 100) + "`%"
    $HopText = [string]$HopRTT + "ms"
    If ($HopLoss -like "*100*") { #100% loss, but name resolves
      $HopResults = $null
      $HopRTT = $null
      $HopText = $null
      $HopRTTAvg = "-"
      $HopRTTMin = "-"
      $HopRTTMax = "-"
      }
  } #End main ping loop
  Else { #Hop TimedOut - no ping attempted
    $HopResults = $null
    $HopRTT = $null
    $HopText = $null
    $HopLoss = "100.0%"
    $HopRTTAvg = "-"
    $HopRTTMin = "-"
    $HopRTTMax = "-"
    } #End TimedOut condition
  $script:SAPSObj = [PSCustomObject]@{
  "Hop" = $i
  "Hop Name" = $HopName.NameHost
  "ASN" = $HopASN
  "ASN Owner" = $HopASNOwner
  "`% Loss" = $HopLoss
  "Hop IP" = $Hop
  "Avg RTT" = $HopRTTAvg
  "Min RTT" = $HopRTTMin
  "Max RTT" = $HopRTTMax
  }
  $PerTraceArr += $SAPSObj #Add the object to the array
} #End Get-PerHopRTT


function ZipFiles( $zipfilename, $sourcedir )
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
        $zipfilename, $compressionLevel, $false)
}


function url_tests()
{
    Write-Output "nuget locals disabled.....Testing cert `n **************************************" | Tee-Object -File $outputDir\url_tests.txt
    Test-Url "https://www.nuget.org/api/v2/package/Newtonsoft.Json/4.0.1" | Tee-Object -File $outputDir\url_tests.txt -Append
    Test-Url "https://api.nuget.org/packages/newtonsoft.json.4.0.1.nupkg" | Tee-Object -File $outputDir\url_tests.txt -Append

    Write-Output "Testing search `n **************************************" | Tee-Object -File $outputDir\url_tests.txt -Append
    1..10 | ForEach-Object { Test-Url "https://api-v2v3search-0.nuget.org/query?q=NuGetConnectivityTest" } | Tee-Object -File $outputDir\url_tests.txt -Append

    Write-Output "Testing guid search `n **************************************" | Tee-Object -File $outputDir\url_tests.txt -Append
    $guid = (New-Guid).ToString();
    1..10 | ForEach-Object { Test-Url "https://api-v2v3search-0.nuget.org/query?q=$guid" } | Tee-Object -File $outputDir\url_tests.txt -Append

    Write-Output "Testing package URL connectivity `n **************************************" | Tee-Object -File $outputDir\url_tests.txt -Append
    1..10 | ForEach-Object { Test-Url "https://www.nuget.org/packages/NuGetConnectivityTest/1.0.0-pre" } | Tee-Object -File $outputDir\url_tests.txt -Append

    Write-Output "Testing registration blob connectivity `n **************************************" | Tee-Object -File $outputDir\url_tests.txt -Append
    1..10 | ForEach-Object { Test-Url "https://api.nuget.org/v3/registration1-gz/entityframework/index.json" } | Tee-Object -File $outputDir\url_tests.txt -Append
}


function tracert_test()
{
    . Set-Variables "api.nuget.org"
    . Get-Traceroute
    ForEach ($Hop in $TraceResults) {
      . Resolve-ASN
      . Resolve-ASNOwner
      . Resolve-DNS
      . Get-PerHopRTT
    }

    $PerTraceArr | Format-Table -Autosize
    $PerTraceArr | Format-Table -Autosize | Out-File $outputDir\$Filename.txt -encoding UTF8

    . Set-Variables "nuget.org"
    . Get-Traceroute
    ForEach ($Hop in $TraceResults) {
      . Resolve-ASN
      . Resolve-ASNOwner
      . Resolve-DNS
      . Get-PerHopRTT
    }

    $PerTraceArr | Format-Table -Autosize
    $PerTraceArr | Format-Table -Autosize | Out-File $outputDir\$Filename.txt -encoding UTF8

}




Get-NuGetExe
#dxdiag /x $outputDir\dxdiag.xml
New-TestScenario "Newtonsoft.Json" "10.0.2" "N"
New-TestScenario "NUnit" "3.6.1" "N"
New-TestScenario "Newtonsoft.Json" "10.0.2" "Y"
New-TestScenario "NUnit" "3.6.1" "Y"
#url_tests
#ZipFiles "$PSScriptRoot\output.zip" "$outputDir"
