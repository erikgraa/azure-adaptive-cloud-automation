 <#
    .DESCRIPTION
    Retrieves whether the Azure Connected Machine Agent is installed

    .PARAMETER ComputerName
    Specifies one or more machine(s) to check for the Azure Connected Machine Agent.

    .PARAMETER Credential
    Specifies an administrator credential.

    .PARAMETER Session
    Specifies a PowerShell remoting session.    

    .EXAMPLE
    Test-AzureConnectedMachineAgentIsInstalled

    .EXAMPLE
    Test-AzureConnectedMachineAgentIsInstalled -ComputerName 'azl-lab-1.dev.graa' -Credential (Get-Credential)

    .EXAMPLE
    $session = New-PSSession -ComputerName 'azl-lab-1.dev.graa'
    Test-AzureConnectedMachineAgentIsInstalled -Session $session

    .LINK
    https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview
    
#>

function Test-AzureConnectedMachineAgentIsInstalled {
    [CmdletBinding(DefaultParameterSetName = 'LocalSet')]
    param (  
        [Parameter(Mandatory = $false, ParameterSetName = 'CredentialSet')] 
        [String]$ComputerName,

        [Parameter(Mandatory = $false, ParameterSetName = 'CredentialSet')]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential,
    
        [Parameter(Mandatory = $false, ParameterSetName = 'PSSessionSet')]
        [System.Management.Automation.Runspaces.PSSession]$Session
      )
    
      begin {
        $splat = @{}
    
        $scriptBlock = {
            Test-Path -Path "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" -PathType Leaf -ErrorAction SilentlyContinue
          }        
      }
    
      process {
        if ($PSBoundParameters.ContainsKey('ComputerName')) {
          $splat.Add('ComputerName', $ComputerName)
        }
    
        if ($PSCmdlet.ParameterSetName -eq 'CredentialSet') {
          $splat.Add('Credential', $Credential)
        }
    
        if ($PSCmdlet.ParameterSetName -eq 'PSSessionSet') {
          $splat.Add('Session', $Session)
        }

        try {
            $command = Invoke-Command @splat -ScriptBlock $scriptBlock -ErrorAction Stop

            $command
        } 
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    end {}    
}