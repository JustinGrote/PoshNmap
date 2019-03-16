@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    Pester                          = @{
        Version     = '4.4.2'
        Parameters  = @{
            SkipPublisherCheck = $true
        }
    }
    PowershellGet                   = @{
        Version     = '2.0.3'
        Parameters  = @{
            SkipPublisherCheck = $true
        }
    }
    BuildHelpers                    = '2.0.1'
    'powershell-yaml'               = '0.3.7'
    'Microsoft.Powershell.Archive'  = '1.2.2.0'
    PSScriptAnalyzer                = '1.17.1'
    Plaster                         = '1.1.3'
}