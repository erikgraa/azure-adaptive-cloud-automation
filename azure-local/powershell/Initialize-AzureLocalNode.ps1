 <#
    .DESCRIPTION
    Onboards one or more Azure Local node(s) to Azure Arc with PowerShell remoting.

    .PARAMETER ComputerName
    Specifies one or more Azure Local node(s).

    .PARAMETER Context
    Specifies the Azure Context.

    .PARAMETER AccessToken
    Specifies the Azure Access Token.

    .PARAMETER Region
    Specifies the Azure Region.

    .PARAMETER ResourceGroup
    Specifies the Azure Resource Group Name.

    .PARAMETER ArcGatewayId
    Specifies an optional Azure Arc gateway resource ID.

    .PARAMETER Credential
    Specifies the local administrator credential to the Azure Local node(s).

    .EXAMPLE
    Connect-AzAccount
    $node = 'azl-lab-1.dev.graa'
    $context = Get-AzContext    
    $accessToken = (Get-AzAccessToken -AsSecureString).Token    
    $region = 'westeurope'
    $resourceGroup = 'resourceGroupName'    
    $arcgatewayId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/resourceGroup/providers/Microsoft.HybridCompute/gateways/arc-gateway'
    $credential = Get-Credential
    Initialize-AzureLocalNode -ComputerName $node -Context $context -AccessToken -Region $region -ResourceGroup $resourceGroup -ArcGatewayId $arcGatewayId -Credential $credential

    .LINK
    https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions
    
#>

function Initialize-AzureLocalNode {
  [CmdletBinding(DefaultParameterSetName = 'AzureContextSet')]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ComputerName,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'AzureContextSet')]    
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext]$Context,

    [Parameter(Mandatory = $true, ParameterSetName = 'AzureContextSet')]
    [ValidateNotNullOrEmpty()]
    [SecureString]$AccessToken,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Region,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String]$ArcGatewayId, 

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential
  )

  begin {
    $splat = @{}

    if ($PSBoundParameters.ContainsKey('PassThru')) {
      $splat.Add('PassThru', $true)
    }

    $scriptBlock = {
      param (
        $subscriptionId,
        $resourceGroup,
        $tenantId,
        $region,
        $armAccessToken,
        $accountId,
        $ArcGatewayId
      )

      $splat = @{}

      if ($ArcGatewayId) {
        $splat.Add('ArcGatewayId', $ArcGatewayId)
      }

      $initializationCmdlet = 'Invoke-AzStackHciArcInitialization'

      if (Get-Command -Name $initializationCmdlet -ErrorAction SilentlyContinue) {
        Invoke-AzStackHciArcInitialization -SubscriptionID $subscriptionId -ResourceGroup $resourceGroup -TenantID $tenantId -Region $region -Cloud 'AzureCloud' -ArmAccessToken $armAccessToken -AccountID $accountId @splat
      }
      else {
        Write-Error ("The cmdlet '{0}' does not exist, make sure to only run initialization on Azure Local nodes that have not yet been onboarded." -f $initializationCmdlet) -ErrorAction Stop
      }
    }    
  }

  process {
    try {
      $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop

      $installed = Test-AzureConnectedMachineAgentIsInstalled -ComputerName $ComputerName -Credential $Credential

      if ($installed -eq $true) {
        Write-Debug 'Azure Arc Agent is installed'

        $status = Get-AzureConnectedMachineStatus -ComputerName $ComputerName -Credential $Credential

        if (($status.status -eq 'Connected') -or ($null -ne $status.subscriptionId -and $null -ne $status.tenantId) ) {
          throw 'Azure Local node is already registered'
        }

        Write-Debug 'Azure Arc Agent is installed, but has not been onboarded'
      }

      # Might be able to suppress and beautify  the output with -AsJob
      Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $Context.Subscription.Id,$ResourceGroup,$Context.Tenant.Id,$Region,(ConvertFrom-SecureString $accessToken -AsPlainText),$Context.Account.Id,$ArcGatewayId        
    }
    catch {
      Write-Error ("Encountered error bootstrapping Azure Local node '{0}' for Azure Arc: {1}" -f $ComputerName, $_)
    }
    finally {
      if ($null -ne $session) {
        $null = Remove-PSSession -Session $session | Out-Null
      }
    } 
  }

  end { }
}