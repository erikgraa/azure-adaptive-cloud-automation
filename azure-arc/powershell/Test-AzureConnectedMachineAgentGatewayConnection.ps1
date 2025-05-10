 <#
    .DESCRIPTION
    Retrieves whether the Azure Connected Machine Agent is using Azure Arc gateway and if it can be reached.

    .PARAMETER ComputerName
    Specifies one or more machine(s) to check for whether the Azure Arc gateway is being used and whether it can be reached.

    .PARAMETER Credential
    Specifies an administrator credential.

    .PARAMETER Session
    Specifies a PowerShell remoting session.    

    .EXAMPLE
    Test-AzureConnectedMachineAgentGatewayConnection

    .EXAMPLE
    Test-AzureConnectedMachineAgentGatewayConnection -ComputerName 'azl-lab-1.dev.graa' -Credential (Get-Credential)

    .EXAMPLE
    $session = New-PSSession -ComputerName 'azl-lab-1.dev.graa'
    Test-AzureConnectedMachineAgentGatewayConnection -Session $session

    .LINK
    https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview
    
#>

function Test-AzureConnectedMachineAgentGatewayConnection {
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
        $status = Get-AzureConnectedMachineStatus @PSBoundParameters

        if ([string]::IsNullOrEmpty($status.gatewayUrl)) {
          $gatewayUrlTest = $false
          $gatewayConnectivityTest = $false
        }
        else {
          $gatewayUrlTest = $true
          [string]$gatewayUrlNormalized = $status.gatewayUrl.Replace('https://','')
          $gatewayConnectivityTest = Test-NetConnection -Port 443 -ComputerName $gatewayUrlNormalized -InformationLevel Quiet -WarningAction SilentlyContinue
        }

        $hash = [Ordered]@{
          'ComputerName' = $ComputerName
          'TestSucceeded' = $gatewayUrlTest
          'ConnectivityTestSucceeded' = $gatewayConnectivityTest
          'GatewayUrl' = $status.gatewayUrl        
        }

        New-Object -TypeName PSCustomObject -Property $hash
      } 
      catch {
          $PSCmdlet.ThrowTerminatingError($_)
      }
  }

  end {}    
}