#requires -version 5
using namespace System.IO
#Build Script for Powershell Modules
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

param (
    #Skip publishing to various destinations (Appveyor,Github,PowershellGallery,etc.)
    [Switch]$SkipPublish,
    #Force publish step even if we are not in master or release. If you are following GitFlow or GitHubFlow you should never need to do this.
    [Switch]$ForcePublish,
    #Additional criteria on when to publish.
    #Show detailed environment variables. WARNING: Running this in a CI like appveyor may expose your secrets to the log! Be careful!
    [Switch]$ShowEnvironmentVariables,
    #Which build files/folders should be excluded from packaging
    #TODO: Reimplement this with root module folder support
    #[String[]]$BuildFilesToExclude = @("Build","Release","Tests",".git*","appveyor.yml","gitversion.yml","*.build.ps1",".vscode",".placeholder"),
    #Where to perform the building of the module. Defaults to "Release" under the project directory. You can specify either a path relative to the project directory, or a literal alternate path.
    [String]$BuildOutputPath = "Release",
    #NuGet API Key for Powershell Gallery Publishing. Defaults to environment variable of the same name
    [String]$NuGetAPIKey = $env:NuGetAPIKey,
    #GitHub User for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubUserName = $env:GitHubUserName,
    #GitHub API Key for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubAPIKey = $env:GitHubAPIKey,
    #Setting this option will only publish to Github as "draft" (hidden) releases for both GA and prerelease, that you then must approve to show to the world
    [Switch]$GitHubPublishAsDraft,
    #Don't detect or bootstrap dependencies
    [Switch]$SkipBootStrap,
    #Force dependency check, useful if a script upgrade has required it. Skip overrides force if both are specified
    [Switch]$ForceBootStrap,
    #What module name to use for a Metabuild. This will probably only work for 'PowerCD'
    [String]$MetaBuild = 'PowerCD'
)

#region HelperFunctions
$lines = '----------------------------------------------------------------'
#endregion HelperFunctions

#Initialize Build Environment
Enter-Build {
    #Move to the Project Directory if we aren't there already. This should never be necessary, just a sanity check
    Set-Location $buildRoot

    ###Detect certain environments

    #Appveyor
    if ($ENV:APPVEYOR) {$IsAppVeyor = $true}
    #Azure DevOps
    if ($ENV:SYSTEM_COLLECTIONID) {$IsAzureDevOps = $true}

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or $IsAppVeyor -or $IsAzureDevOps -or ([Environment]::GetCommandLineArgs() -like '-noni*')) {
        write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow
        $ProgressPreference = "SilentlyContinue"
    }

#region Bootstrap
    $bootstrapCompleteFileName = (Split-Path $buildroot -leaf) + '.buildbootstrap.complete'
    $bootstrapCompleteFilePath = join-path ([IO.Path]::GetTempPath()) $bootstrapCompleteFileName
    if ((Test-Path $bootstrapCompleteFilePath) -and (-not $forcebootstrap)) {
        write-build Green "Build Initialization - 'Bootstrap Complete' file detected at $bootstrapCompleteFilePath, skipping bootstrap and dependencies"
        $SkipBootStrap = $true
    }

    if (-not $SkipBootStrap) {
        #Register Nuget if required
        if (!(get-packageprovider "Nuget" -ForceBootstrap -ErrorAction silentlycontinue)) {
            write-verbose "Nuget Provider Not found. Fetching..."
            Install-PackageProvider Nuget -forcebootstrap -scope currentuser | out-string | write-verbose
            write-verbose "Installed Nuget Provider Info"
            Get-PackageProvider Nuget | format-list | out-string | write-verbose
        }

        #If nuget is pointed to the v3 URI or doesn't exist, downgrade it to v2
        $NugetOrgSource = Get-PackageSource nuget.org -erroraction SilentlyContinue
        $IsNugetOrgV2Source = $NugetOrgSource.location -match 'v2$'
        if (-not $IsNugetOrgV2Source) {
            write-verbose "Detected nuget.org not using v2 api, downgrading to v2 Nuget API for PowerShellGet compatability"

            #Next command will detect this was removed and add this back
            UnRegister-PackageSource -Name nuget.org -ErrorAction SilentlyContinue

            #Add the nuget repository so we can download things like GitVersion
            # TODO: Make this optional code when running interactively
            if (!(Get-PackageSource "nuget.org" -erroraction silentlycontinue)) {
                write-verbose "Registering nuget.org as package source"
                Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted  | out-string | write-verbose
            }
            else {
                $nugetOrgPackageSource = Set-PackageSource -name 'nuget.org' -Trusted
            }
        }

        if (-not (Get-Command -Name 'PSDepend\Invoke-PSDepend' -ErrorAction SilentlyContinue)) {
            #Force required by Azure Devops Pipelines, confirm false not good enough
            Install-module -Name 'PSDepend' -Scope CurrentUser -Repository PSGallery -ErrorAction Stop -Force
        }

        #Install dependencies defined in Requirements.psd1
        Write-Build Green 'Build Initialization - Running PSDepend to Install Dependencies'
        Invoke-PSDepend -Install -Import -Path PSModule.requirements.psd1 -Confirm:$false

        #If we get this far, assume all dependencies worked and drop a flag to not do this again.
        "Delete this file or use -ForceBootstrap parameter to enable bootstrap again." > $bootstrapCompleteFilePath
    }

#endregion Bootstrap

    #Configure some easy to use build environment variables
    Set-BuildEnvironment -BuildOutput $BuildOutputPath -Force

    $BuildProjectPath = join-path $env:BHBuildOutput $env:BHProjectName

    #Detect if this is a Metabuild of the PowerCD Tools
    if ($env:BHProjectName -eq $MetaBuild) {$IsMetaBuild = $true} else {$IsMetaBuild = $false}



    #If the branch name is master-test, run the build like we are in "master"
    if ($env:BHBranchName -eq 'master-test') {
        write-build Magenta "Build Initialization - Detected master-test branch, running as if we were master"
        $SCRIPT:BranchName = "master"
    } else {
        $SCRIPT:BranchName = $env:BHBranchName
    }

    <# TODO: Remove this code since the deploy activity was separated out
    #If this is an Appveyor PR, note a special branch name
    if ($isAppveyor -and $ENV:APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH) {
        $SCRIPT:BranchName = "PR$($env:APPVEYOR_PULL_REQUEST_NUMBER)/$($env:BHBranchName)//$($env:APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH)"
        Write-Build Green "Build Initialization - Appveyor Pull Request Detected. Using Branch Name $($SCRIPT:BranchName)"
    }
    #>

    Write-Build Green "Build Initialization - Current Branch Name: $BranchName"
    Write-Build Green "Build Initialization - Project Build Path: $BuildProjectPath"

    $PassThruParams = @{}
    if ($CI -and ($BranchName -ne 'master')) {
        write-build Green "Build Initialization - Not in Master branch, Verbose Build Logging Enabled"
        $SCRIPT:VerbosePreference = "Continue"
    } else {
        $SCRIPT:VerbosePreference = "SilentlyContinue"
        $PassThruParams.Verbose = $false
    }
    if ($VerbosePreference -eq "Continue") {
        $PassThruParams.Verbose = $true
    }
    function Write-VerboseHeader ([String]$Message) {
        #Simple function to add lines around a header
        write-verbose ""
        write-verbose $lines
        write-verbose $Message
        write-verbose $lines
    }

    #Move to the Project Directory if we aren't there already. This should never be necessary, just a sanity check
    Set-Location $buildRoot

    #Force TLS 1.2 for all HTTPS transactions
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    write-verboseheader "Build Environment Prepared! Environment Information:"
    Get-BuildEnvironment | format-list | out-string | write-verbose
    if ($ShowEnvironmentVariables) {
        write-verboseheader "Current Environment Variables"
        get-childitem env: | out-string | write-verbose

        write-verboseheader "Powershell Variables"
        Get-Variable | select-object name, value, visibility | format-table -autosize | out-string | write-verbose
    }
}

task Clean {
    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        remove-item (join-path $buildOutputPath '*') -Recurse
    }
    New-Item -Type Directory $BuildProjectPath @PassThruParams | out-null
    #Unmount any modules named the same as our module
    Remove-Module $env:BHProjectName -erroraction silentlycontinue
}

task Version {
    #Fetch GitVersion if required from NuGet
    $GitVersionPackageName = 'gitversion.commandline'
    $GitVersionPackageMinVersion = '4.0.0'
    $PackageParams = @{
        Name = $GitVersionPackageName
        MinimumVersion = $GitVersionPackageMinVersion
    }

    if ($IsAppVeyor -and $IsLinux) {
        #Appveyor Ubuntu can't run the EXE for some dumb reason as of 2018/11/27, fetch it as a global tool instead
        #Fetch Gitversion as a .net Global Tool
        $dotnetCMD = (get-command dotnet -CommandType Application -errorAction stop | select -first 1).source
        $gitversionEXE = (get-command dotnet-gitversion -CommandType Application -errorAction silentlycontinue | select -first 1).source
        if ($dotnetCMD -and -not $gitversionEXE) {
            write-build Green "Task $task - Installing dotnet-gitversion"
            #Skip First Run Setup (takes too long for no benefit)
            $ENV:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = $true
            Invoke-Expression "$dotnetCMD tool install --global GitVersion.Tool --version 4.0.1-beta1-47"
        }
        $gitversionEXE = (get-command dotnet-gitversion -CommandType Application -errorAction stop | select -first 1).source
    } else {
        #Fetch Gitversion as a NuGet Package
        $GitVersionPackage = Get-Package @PackageParams -erroraction SilentlyContinue
        if (!($GitVersionPackage)) {
            write-verbose "Package $GitVersionPackageName Not Found Locally, Installing..."

            #Fetch GitVersion
            $GitVersionPackage = Install-Package @PackageParams -scope currentuser -source 'nuget.org' -force -erroraction stop
        }
        $GitVersionEXE = [Path]::Combine(((Get-Package $GitVersionPackageName).source | split-path -Parent),'tools','GitVersion.exe')
    }

    #If this commit has a tag on it, temporarily remove it so GitVersion calculates properly
    #Fixes a bug with GitVersion where tagged commits don't increment on non-master builds.
    $currentTag = git tag --points-at HEAD

    if ($currentTag) {
        write-build DarkYellow "Task $($task.name) - Git Tag $currentTag detected. Temporarily removing for GitVersion calculation."
        git tag -d $currentTag
    }

    #Strip prerelease tags, GitVersion can't handle them with Mainline deployment with version 4.0
    #TODO: Restore these for local repositories, otherwise they just come down with git pulls
    git tag --list v*-* | % {git tag -d $PSItem}


    try {
        #Calculate the GitVersion
        write-verbose "Executing GitVersion to determine version info"

        if ($isLinux -and -not $isAppveyor) {
            #TODO: Find a more platform-independent way of changing GitVersion executable permissions (Mono.Posix library maybe?)
            chmod +x $GitVersionEXE
        }

        $GitVersionOutput = Invoke-Expression "$GitVersionEXE /nofetch"

        #Since GitVersion doesn't return error exit codes, we look for error text in the output in the output
        if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe in $buildRoot"}
        $SCRIPT:GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop
    } catch {
        write-build Red $GitVersionOutput
        write-error "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is above..."
    } finally {
        #Restore the tag if it was present
        if ($currentTag) {
            write-build DarkYellow "Task $($task.name) - Restoring tag $currentTag."
            git tag $currentTag -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        }
    }


    if (-not $GitVersionOutput) {throw "GitVersion returned no output. Are you sure it ran successfully?"}
    if ($PassThruParams.Verbose) {
        write-verboseheader "GitVersion Results"
        $GitVersionInfo | format-list | out-string | write-verbose
    }

    $SCRIPT:ProjectBuildVersion = [Version]$GitVersionInfo.MajorMinorPatch

    #GA release detection
    if ($BranchName -eq 'master') {
        $Script:IsGARelease = $true
        $Script:ProjectVersion = $ProjectBuildVersion
    } else {
        #The regex strips all hypens but the first one. This shouldn't be necessary per NuGet spec but Update-ModuleManifest fails on it.
        $SCRIPT:ProjectPreReleaseVersion = $GitVersionInfo.nugetversion -replace '(?<=-.*)[-]'
        $SCRIPT:ProjectVersion = $ProjectPreReleaseVersion
        $SCRIPT:ProjectPreReleaseTag = $SCRIPT:ProjectPreReleaseVersion.split('-')[1]
    }

    write-build Green "Task $($task.name)` - Calculated Project Version: $ProjectVersion"

    #Tag the release if this is a GA build
    if ($BranchName -match '^(master|releases?[/-])') {
        write-build Green "Task $($task.name)` - In Master/Release branch, adding release tag v$ProjectVersion to this build"

        $SCRIPT:isTagRelease = $true
        if ($BranchName -eq 'master') {
            write-build Green "Task $($task.name)` - In Master branch, marking for General Availability publish"
            [Switch]$SCRIPT:IsGARelease = $true
        }
    }

    #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
}

#Copy all powershell module "artifacts" to Build Release Path
task CopyFilesToBuildDir {

    #Make sure we are in the project location in case something changed
    Set-Location $buildRoot

    #Detect the .psm1 file and copy all files to the root directory, excluding build files unless this is PowerCD
    $PSModuleManifestDirectory = (split-path $env:BHPSModuleManifest -parent)
    if ($PSModuleManifestDirectory -eq $buildRoot) {
        <# TODO: Root-folder level module with buildFilesToExclude
        copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $BuildReleasePath @PassThruParams
        #>
        throw "Placing module files in the root project folder is current not supported by this script. Please put them in a subfolder with the name of your module"
    } else {
        Copy-Item -Container -Recurse -Path $PSModuleManifestDirectory\* -Destination $BuildReleasePath
    }
    if ($isMetaBuild) {
        #If this is a meta-build of PowerCD, include certain additional files that are normally excluded.
        #This is so we can use the same build file for both PowerCD and templates deployed from PowerCD.
        #TODO: Put this in its own build script so that this code doesn't carry over to the template
        $PowerCDFilesToCopy = Get-Childitem $buildRoot -Force -Recurse |
            where fullname -notlike "$PSModuleManifestDirectory*" |
            where fullname -notlike "$env:BHBuildOutput*" |
            where fullname -notlike (join-path $buildRoot 'LICENSE') |
            where fullname -notlike (join-path $buildRoot 'README.MD') |
            where fullname -notlike (join-path $buildRoot '.git') |
            where fullname -notlike ([Path]::Combine($buildRoot,'.git','*')) |
            where fullname -notlike (join-path $buildroot "Tests\$($env:BHProjectName)*.Tests.ps1")

        #Copy-Item doesn't preserve paths with piped files even with -Container parameter, this is a workaround
        $PowerCDFilesToCopy | Resolve-Path -Relative | foreach {
            $RelativeDestination = [Path]::Combine($BuildReleasePath,'PlasterTemplates\Default',$PSItem)
            Copy-Item $PSItem -Destination $RelativeDestination -Force
        }

        Copy-Item $buildRoot\PowerCD\PowerCD.psm1 $BuildReleasePath\PlasterTemplates\Default\Module.psm1
    }
}

#Update the Metadata of the module with the latest version information.
task UpdateMetadata Version,CopyFilesToBuildDir,{
    #TODO: Split manifest and plaster versioning into discrete tasks
    [Version]$UpdateModuleManifestVersion = (get-command update-metadata -erroractionsilentlycontinue).version
    if ($UpdateModuleManifestVersion -lt '1.6') {throw "PowershellGet module must be version 1.6 or higher to support prerelease versioning"}

    # Set the Module Version to the calculated Project Build version. Cannot use update-modulemanifest for this because it will complain the version isn't correct (ironic)
    Update-Metadata -Path $buildReleaseManifest -PropertyName ModuleVersion -Value $ProjectBuildVersion

    #Update Plaster Manifest Version if this is a PowerCD Build
    if ($isMetaBuild) {
        $PlasterManifestPath = join-path $buildReleasePath "PlasterTemplates\Default\plasterManifest.xml"
        $PlasterManifest = [xml](Get-Content -raw $PlasterManifestPath)
        $PlasterManifest.plasterManifest.metadata.version = $ProjectBuildVersion.tostring()
        $PlasterManifest.save($PlasterManifestPath)

        #Update-ModuleManifest corrupts the Plaster Extension, doing this instead.
        Update-Metadata -Path $buildReleaseManifest -PropertyName Extensions -Value @(
            @{
                Module = "Plaster"
                MinimumVersion = "1.0.1"
                Details = @{
                    TemplatePaths = "PlasterTemplates\Default"
                }
            }
        )
    }

    # This is needed for proper discovery by get-command and Powershell Gallery
    $moduleFunctionsToExport = (Get-ChildItem (join-path "$BuildReleasePath" "Public") -Filter *.ps1).basename
    if (-not $moduleFunctionsToExport) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
    } else {

        Update-Metadata -Path $BuildReleaseManifest -PropertyName FunctionsToExport -Value $moduleFunctionsToExport
    }

    if ($IsGARelease) {
        #Blank out the prerelease tag to make this a GA build in Powershell Gallery
        $ProjectPreReleaseTag = ''
    } else {
        "This is a prerelease build and not meant for deployment!" > (Join-Path $BuildReleasePath "PRERELEASE-$ProjectVersion")
    }

    #Set the prerelease version in the Manifest File
    Update-Metadata -Path $BuildReleaseManifest -PropertyName PreRelease -Value $ProjectPreReleaseTag

    if ($isTagRelease) {
        #Set an email address for the tag commit to work if it isn't already present
        if (-not (git config user.email)) {
            git config user.email "buildtag@$env:ComputerName"
        }

        #Tag the release. This keeps Gitversion performant, as well as provides a master audit trail
        if (-not (git tag -l "v$ProjectVersion")) {
            git tag "v$ProjectVersion" -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        } else {
            write-warning "Tag $ProjectVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen."
        }
    }

    # Add Release Notes from current version
    # TODO: Generate Release Notes from GitHub
    #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ReleaseNotes -Value ("$($env:APPVEYOR_REPO_COMMIT_MESSAGE): $($env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)")
}

#Pester Testing
task Pester {
    #Find the latest module
    try {
        $moduleManifestCandidatePath = join-path (join-path $BuildProjectPath '*') '*.psd1'
        $moduleManifestCandidates = Get-Item $moduleManifestCandidatePath -ErrorAction stop
        $moduleManifestPath = ($moduleManifestCandidates | Select-Object -last 1).fullname
        $moduleDirectory = Split-Path $moduleManifestPath
    } catch {
        throw "Did not detect any module manifests in $BuildProjectPath. Did you run 'Invoke-Build Build' first?"
    }

    write-verboseheader "Starting Pester Tests..."
    write-build Green "Task $($task.name)` -  Testing $moduleDirectory"

    $PesterResultFile = join-path $env:BHBuildOutput "$env:BHProjectName-TestResults_PS$PSVersion`_$TimeStamp.xml"

    $PesterParams = @{
        Script = @{Path = "Tests"; Parameters = @{ModulePath = (split-path $moduleManifestPath)}}
        OutputFile = $PesterResultFile
        OutputFormat = "NunitXML"
        PassThru = $true
        OutVariable = 'TestResults'
    }

    #If we are in vscode, add the VSCodeMarkers
    if ($host.name -match 'Visual Studio Code') {
        write-verbose "Detected Visual Studio Code, adding test markers"
        $PesterParams.PesterOption = (new-pesteroption -IncludeVSCodeMarker)
    }

    Invoke-Pester @PesterParams | Out-Null

    # In Appveyor? Upload our test results!
    If ($ENV:APPVEYOR) {
        $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        write-verbose "Detected we are running in AppVeyor! Uploading Pester Results to $UploadURL"
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $PesterResultFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        $testFailedMessage = "Failed '$($TestResults.FailedCount)' tests, build failed"
        Write-Error $testFailedMessage
        if ($isAzureDevOps) {
            Write-Host "##vso[task.logissue type=error;]$testFailedMessage"
        }
        $SCRIPT:SkipPublish = $true
    }
    "`n"
}

task PackageZip {
    $ZipArchivePath = (join-path $env:BHBuildOutput "$env:BHProjectName-$ProjectVersion.zip")
    write-build Green "Task $($task.name)` - Writing Finished Module to $ZipArchivePath"
    #Package the Powershell Module
    Compress-Archive -Path $BuildProjectPath -DestinationPath $ZipArchivePath -Force @PassThruParams
}

task PreDeploymentChecks Test,{
    #Do not proceed if the most recent Pester test is not passing.
    $CurrentErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Stop"
        $MostRecentPesterTestResult = [xml]((Get-Content -raw (get-item "$env:BHBuildOutput/*-TestResults*.xml" | Sort-Object lastwritetime | Select-Object -last 1)))
        $MostRecentPesterTestResult = $MostRecentPesterTestResult."test-results"
        if (
            $MostRecentPesterTestResult -isnot [System.XML.XMLElement] -or
            $MostRecentPesterTestResult.errors -gt 0 -or
            $MostRecentPesterTestResult.failures -gt 0
        ) {throw "Fail!"}
    } catch {
        throw "Pester tests failed, or unable to detect a clean passing Pester Test nunit xml file in the $BuildOutput directory. Refusing to publish/deploy until all tests pass."
    }
    finally {
        $ErrorActionPreference = $CurrentErrorActionPreference
    }

    if (($BranchName -match '^(master$|vNext$|releases?[-/])') -or $ForcePublish) {
        if (-not (Get-Item $BuildReleasePath/*.psd1 -erroraction silentlycontinue)) {throw "No Powershell Module Found in $BuildReleasePath. Skipping deployment. Did you remember to build it first with {Invoke-Build Build}?"}
    } else {
        write-build Magenta "Task $($task.name) - We are not in master or release branch, skipping publish. If you wish to publish anyways such as for testing, run {InvokeBuild Publish -ForcePublish:$true}"
        $script:SkipPublish=$true
        continue
    }

    #If this branch is on the same commit as master but isn't master, don't deploy, since master already exists.
    if ($branchname -ne 'master' -and (git rev-parse origin/master) -and (git rev-parse $BranchName) -eq (git rev-parse origin/master)) {
        write-build Magenta "Task $($task.name) - This branch is on the same commit as the origin master. Skipping Publish as you should publish from master instead. This is normal if you just merged and reset vNext. Please commit a change and rebuild."
        $script:SkipPublish=$true
        continue
    }
}

task PublishGitHubRelease -if {-not $SkipPublish} Package,Test,{
    #Determine if GitHub is in use
    [uri]$gitOriginURI = & git remote get-url --push origin

    if ($gitOriginURI.host -eq 'github.com') {
        if (-not $GitHubUserName) {
            $GitHubUserName = $gitOriginURI.Segments[1] -replace '/$',''
        }
        [uri]$GitHubPublishURI = $gitOriginURI -replace '^https://github.com/(\w+)/(\w+).git','https://api.github.com/repos/$1/$2/releases'
        write-build Green "Using GitHub Releases URL: $GitHubPublishURI with user $GitHubUserName"
    } else {
        write-build DarkYellow "This project did not detect a GitHub repository as its git origin, skipping GitHub Release preparation"
        $SkipGitHubRelease = $true
    }

    if ($SkipPublish) {[switch]$SkipGitHubRelease = $true}
    if ($AppVeyor -and -not $GitHubAPIKey) {
        write-build DarkYellow "Task $($task.name) - Couldn't find GitHubAPIKey in the Appveyor secure environment variables. Did you save your Github API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }

    if (-not $GitHubAPIKey) {
        if (get-command 'get-storedcredential') {
            write-build Green "Detected Github API key in Windows Credential Manager, using that for GitHub Release"
            $WinCredMgrGitAPIKey = get-storedcredential -target 'LegacyGeneric:target=git:https://github.com' -erroraction silentlycontinue
            if ($WinCredMgrGitAPIKey) {
                $GitHubAPIKey = $winCredMgrGitAPIKey.GetNetworkCredential().Password
            }
        } else {
            #TODO: Add Linux credential support, preferably thorugh making a module called PoshAuth or something
            write-build DarkYellow "Task $($task.name) - GitHubAPIKey was not found as an environment variable or in the Windows Credential Manager. Please store it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
            $SkipGitHubRelease = $true
        }

    }
    if (-not $GitHubUserName) {
        write-build DarkYellow "Task $($task.name) - GitHubUserName was not found as an environment variable or inferred from the repository. Please specify it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }

    #Checkpoint
    if ($SkipGitHubRelease) {
        write-build Magenta "Task $($task.name) - Skipping Publish to GitHub Releases"
        continue
    }
    #Inspiration from https://www.herebedragons.io/powershell-create-github-release-with-artifact

    #Create the release
    #Currently all releases are draft on publish and must be manually made public on the website or via the API
    $releaseData = @{
        tag_name = [string]::Format("v{0}", $ProjectVersion);
        target_commitish = "master";
        name = [string]::Format("v{0}", $ProjectVersion);
        body = $env:BHCommitMessage;
        draft = $false;
        prerelease = $true;
    }

    #Only master builds are considered GA
    if ($BranchName -eq 'master') {
        $releasedata.prerelease = $false
    }

    if ($GitHubPublishAsDraft) {$releasedata.draft = $true}

    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($GitHubApiKey + ":x-oauth-basic"))
    $releaseParams = @{
        Uri = $GitHubPublishURI
        Method = 'POST'
        Headers = @{
            Authorization = $auth
        }
        ContentType = 'application/json'
        Body = (ConvertTo-Json $releaseData -Compress)
    }

    try {
        #Invoke-Restmethod on WindowsPowershell always throws a terminating error regardless of erroraction setting, hence the catch. PSCore fixes this.
        $result = Invoke-RestMethod @releaseParams -ErrorVariable GitHubReleaseError
    } catch [System.Net.WebException] {
        #Git Hub Error Processing
        $gitHubErrorInfo = $PSItem.tostring() | convertfrom-json
        if ($gitHubErrorInfo) {
            write-build Red "Error Received from $($releaseparams.uri.host): $($GitHubErrorInfo.Message)"
            switch ($GitHubErrorInfo.message) {
                "Validation Failed" {
                    $gitHubErrorInfo.errors | foreach {
                        write-build Red "Task $($task.name) - Resource: $($PSItem.resource) - Field: $($PSItem.field) - Issue: $($PSItem.code)"

                        #Additional suggestion if release exists
                        if ($PSItem.field -eq 'tag_name' -and $PSItem.resource -eq 'Release' -and $PSItem.code -eq 'already_exists') {
                            write-build DarkYellow "Task $($task.name) - NOTE: This usually means you've already published once for this commit. This is common if you try to publish again on the same commit. For safety, we will not overwrite releases with same version number. Please make a new commit (empty is fine) to bump the version number, or delete this particular release on Github and retry (NOT RECOMMENDED). You can also mark it as a draft release with the -GitHubPublishAsDraft, multiple drafts per version are allowed"
                        }
                    }
                }
            }
            if ($PSItem.documentation_url) {write-build Red "More info at $($PSItem.documentation_url)"}
        } else {throw}
    }

    if ($GitHubReleaseError) {
        #Dont bother uploading if the release failed
        throw $GitHubErrorInfo
    }

    $uploadUriBase = $result.upload_url -creplace '\{\?name,label\}'  # Strip the , "?name=$artifact" part

    $uploadParams = @{
        Method = 'POST';
            Headers = @{
                Authorization = $auth;
            }
        ContentType = 'application/zip';
    }
    foreach ($artifactItem in $artifactPaths) {
        $uploadparams.URI = $uploadUriBase + "?name=$(split-path $artifactItem -leaf)"
        $uploadparams.Infile = $artifactItem
        $result = Invoke-RestMethod @uploadParams -erroraction stop
    }
}

task PublishPSGallery -if {-not $SkipPublish} Version,Test,{
    if ($SkipPublish) {[switch]$SkipPSGallery = $true}

    #If this is a prerelease build, get the latest version of PowershellGet and PackageManagement if required
    if ($BranchName -ne 'master' -and ((get-command find-package).version -lt [version]"1.1.7.2" -or (get-command find-script).version -lt [version]"1.6.6")) {
        write-build DarkYellow "Task $($task.name) - This is a prerelease module that requires a newer version of PackageManagement and PowershellGet than what you have installed in order to publish. Fetching from Powershell Gallery..."

        Install-Module -Name PowershellGet,PackageManagement -Scope CurrentUser -AllowClobber -force -confirm:$false
        Get-Module PowershellGet,PackageManagement | Remove-Module -force
        import-Module PowershellGet -MinimumVersion 1.6 -force
        Import-Module PackageManagement -MinimumVersion 1.1.7.0 -force
        Import-PackageProvider (Get-Module PowershellGet | where Version -gt 1.6 | % Path) -Force | Out-Null
    }

    #TODO: Break this out into a function
    #We test it here instead of Build requirements because this isn't a "hard" requirement, you can still build locally while not meeting this requirement.
    $packageMgmtVersion = (get-command find-package).version
    if ($packageMgmtVersion -lt [version]"1.1.7.2") {
        write-build DarkYellow "Task $($task.name) - WARNING: You have PackageManagement version $packageMgmtVersion which is less than the recommended v1.1.7.2 or later running in your session. Uploading prerelease builds to the powershell gallery may fail. Please install with {Install-Module PackageManagement -MinimumVersion 1.1.7.2}, close your powershell session, and retry publishing"
    }
    if ((get-command find-script).version -lt [version]"1.6.6") {
        write-build DarkYellow "Task $($task.name) - WARNING: WARNING: You have PowershellGet version $packageMgmtVersion which is less than the recommended v1.6.6 or later running in your session. Uploading prerelease builds to the powershell gallery may fail. Please install with {Install-Module PowershellGet -MinimumVersion 1.6.6}, close your powershell session, and retry publishing"
    }

    if ($AppVeyor -and -not $NuGetAPIKey) {
        write-build DarkYellow "Task $($task.name) - Couldn't find NuGetAPIKey in the Appveyor secure environment variables. Did you save your NuGet/Powershell Gallery API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://www.appveyor.com/docs/build-configuration/"
        $SkipPSGallery = $true
    }
    if (-not $NuGetAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow "Task $($task.name) - NuGetAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build publish -NuGetAPIKey "MyAPIKeyString"}. Have you registered for a Powershell Gallery API key yet? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item"
        $SkipPSGallery = $true
    }

    if ($SkipPSGallery) {
        Write-Build Magenta "Task $($task.name) - Skipping Powershell Gallery Publish"
        continue
    } else {
        $publishParams = @{
                Path = $buildReleasePath
                NuGetApiKey = $NuGetAPIKey
                Repository = 'PSGallery'
        }
        try {
            Publish-Module @publishParams @PassThruParams -ErrorAction Stop
        }
        #WriteErrorException appears to be a bug in the Linux Publish-Module cmdlet
        catch [InvalidOperationException],[Microsoft.PowerShell.Commands.WriteErrorException] {
            #Downgrade a conflict to a warning, as this is common with multiple build matrices.
            #TODO: Validate build matrices succeded before attempting and only do on one worker
            if ($psItem.exception.message -match 'cannot be published as the current version .* is already available in the repository|already exists and cannot be modified') {
                write-warning $PSItem.exception.message
            } else {
                write-build Red "Task $($task.name) - Powershell Gallery Publish Failed"
                throw $PSItem.Exception
            }
        }
        catch {
            write-build Red "Task $($task.name) - Powershell Gallery Publish Failed"
            throw $PSItem.Exception
        }
    }
}

task PackageNuGet Test,{
    #Creates a temporary repository and registers it, uses publish-module which results in a nuget package
    try {
        $SCRIPT:tempRepositoryName = "$($env:BHProjectName)-build-$(get-date -format 'yyyyMMdd-hhmmss')"
        Register-PSRepository -Name $tempRepositoryName -SourceLocation $env:BHBuildOutput
        If (Get-Item -ErrorAction SilentlyContinue (join-path $env:BHBuildOutput "$($env:BHProjectName)*.nupkg")) {
            Write-Build Green "Nuget Package for $($env:BHProjectName) already generated. Skipping..."
        } else {
            Publish-Module -Repository $tempRepositoryName -Path $BuildProjectPath -Force
        }
    }
    catch {Write-Error $PSItem}
    finally {
        Unregister-PSRepository $tempRepositoryName
    }
}

task InstallPSModule PackageNuGet,{
    try {
        register-psrepository -Name $tempRepositoryName -SourceLocation $env:BHBuildOutput -InstallationPolicy Trusted
        Install-Module -Name $env:BHProjectName -Repository $tempRepositoryName -Scope CurrentUser -Force
    } catch {write-error $PSItem}
    finally {
        unregister-psrepository $tempRepositoryName
    }
}

### SuperTasks
# These are the only supported items to run directly from Invoke-Build
task Build Clean,Version,CopyFilesToBuildDir,UpdateMetadata
task Test Version,Pester
task Package Version,PreDeploymentChecks,PackageZip,PackageNuGet
task Publish Version,PreDeploymentChecks,PublishPSGallery,PublishGitHubRelease
task Install Version,PreDeploymentChecks,InstallPSModule

#Default Task - Build and Test
task . Clean,Build,Test,Package