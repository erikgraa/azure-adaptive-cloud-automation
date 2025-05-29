 <#
    .DESCRIPTION
    Enables Azure Local nested deployment workaround for ECC RAM on VMware vSphere virtual hardware.

    .SYNOPSIS
    Enables Azure Local nested deployment workaround for ECC RAM on VMware vSphere virtual hardware.

    .PARAMETER Session
    Specifies one or more PSSession(s).

    .PARAMETER Wait
    Specifies to wait until finished enabling workaround.

    .EXAMPLE
    $session = New-PSSession -ComputerName 'azure-local.fqdn' -Credential (Get-Credential)
    Enable-AzureLocalNestedMemoryWorkaround -Session $session -Wait

    .LINK
    https://blog.graa.dev/AzureLocal-NestedDeploymentTips
    
#>

function Enable-AzureLocalNestedMemoryWorkaround {
    [CmdletBinding()]
    param (
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [System.Management.Automation.Runspaces.PSSession[]]$Session,

      [Parameter(Mandatory = $false)]
      [Switch]$Wait
    )

    begin {
        $sessionHash = @{}

        foreach ($_session in $session) {
            if ($_session.Availability -ne 'Available') {
                Write-Error -Message 'Session for computer {0} is not available' -f $_session.ComputerName -RecommendedAction 'Create a new session' -ErrorAction Stop
            }
        }        

        $finished = $false        

        $scriptBlock = {
            $i = 0

            do {
                try {
                    $xml = Get-ChildItem -Path C:\NugetStore -Recurse -File -ErrorAction Stop | Where-Object { $_.FullName -match 'EnvironmentChecker.Deploy' -and $_.Name -eq 'role.xml' }

                    Copy-Item -Path $xml.FullName -Destination ('{0}.bkp' -f $xml.FullName)
                
                    $content = Get-Content -Path $xml.FullName -Raw

                    $pattern = 'RolePath="Cloud\\Infrastructure\\EnvironmentValidator" InterfaceType="ValidateHardware"'
                    $changeLine = 'RolePath="Cloud\Infrastructure\EnvironmentValidator" InterfaceType="ValidateSBEHealth"'

                    if ($content -match $pattern) {
                        $content = $content -replace $pattern, $changeLine
                        $content | Set-Content -Path $xml.FullName

                        Write-Verbose 'Replaced ValidateHardware with ValidateSBEHealth for ECC RAM workaround'
                    }
                    else {
                      Write-Verbose 'Workaround already in place'
                    }

                    break
                }
                catch {
                    if ($i % 60 -eq 0) {
                      Write-Output 'The role.xml file for EnvironmentChecker does not exist yet'
                    }

                    Start-Sleep -Seconds 5

                    $i++
                }
            } while ($true)
        }

        $splat = @{}
 
        $splat.Add('AsJob', $true)
    }

    process {
        foreach ($_session in $session) {
            $job = Invoke-Command -Session $_session -ScriptBlock $scriptBlock @splat
            $sessionHash.Add($_session.ComputerName, $job)
        }


        if ($PSBoundParameters.ContainsKey('Wait')) {
            $finished = @()

            do {
                foreach ($_session in $sessionHash.GetEnumerator()) {
                    $job = Get-Job -Name $_session.value.name

                    if ($job.State -eq 'Completed' -and -not($finished.Contains($_session.Key))) {
                        $finished += $_session.Key
                        Write-Verbose ('Azure Local node {0} has workaround in place' -f $_session.Key)
                    }
                }

                Start-Sleep -Seconds 5

                Write-Verbose ('{0} out of {1} nodes have the workaround in place' -f $finished.Count, $Session.Count)
            }
            while(-not($finished.Count -eq $Session.Count))
        }
    }

    end { }
}