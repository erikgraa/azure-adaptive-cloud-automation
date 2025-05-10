 <#
    .DESCRIPTION
    Retrieves Azure Connected Machine Agent metadata and connection status.

    .PARAMETER ComputerName
    Specifies one or more machine(s) with the Azure Connected Machine Agent.

    .PARAMETER Credential
    Specifies an administrator credential.

    .PARAMETER Session
    Specifies a PowerShell remoting session.    

    .EXAMPLE
    Get-AzureConnectedMachineStatus

    .EXAMPLE
    Get-AzureConnectedMachineStatus -ComputerName 'azl-lab-1.dev.graa' -Credential (Get-Credential)

    .EXAMPLE
    $session = New-PSSession -ComputerName 'azl-lab-1.dev.graa'
    Get-AzureConnectedMachineStatus -Session $session

    .LINK
    https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview
    
#>

function Get-AzureConnectedMachineStatus {
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
          $path = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'
          & $path show -j
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
        $agent = Test-AzureConnectedMachineAgentIsInstalled @PSBoundParameters

        if ($agent -eq $false) {
          throw 'Azure Connected Machine Agent is not installed'
        }
        else {        
          $command = Invoke-Command @splat -ScriptBlock $scriptBlock -ErrorAction Stop

          $command | ConvertFrom-Json
        }
      } 
      catch {
          $PSCmdlet.ThrowTerminatingError($_)
      }
  }

  end {}    
}