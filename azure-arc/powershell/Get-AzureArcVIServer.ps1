<#
    .SYNOPSIS
    Retrivess an Azure Arc-enabled VMware vCenter server.

    .DESCRIPTION
    Retrivess an Azure Arc-enabled VMware vCenter server.

    .PARAMETER Name
    Specifies the Azure Arc-enabled VMware vCenter server.

    .PARAMETER ResourceGroup
    Specifies the Azure Resource Group Name.    

    .PARAMETER SubscriptionId
    Optionally specifies the Azure Subscription ID.

    .PARAMETER ApiVersion
    Optionally specifies the API version.

    .EXAMPLE
    Get-AzureArcVIServer -Server 'vcsa.fqdn'

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://learn.microsoft.com/en-us/rest/api/azure-arc-vmware/v-centers/get
#>

function Get-AzureArcVIServer {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ResourceGroup,        

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('2023-12-01')]
        [String]$ApiVersion = '2023-12-01'
    )

    begin { 
        try {
            $token = Get-AzAccessToken -AsSecureString

            $headers = @{
                'Authorization' = ('Bearer {0}' -f ($token.Token | ConvertFrom-SecureString -AsPlainText))
                'Accept' = 'application/json'
            }

            if (-not($PSBoundParameters.ContainsKey('SubscriptionId'))) {
                $SubscriptionId = Get-AzSubscription | Select-Object -ExpandProperty SubscriptionId
            }
        }
        catch {
            Write-Error -Message 'Not connected to Azure' -RecommendedAction 'Please connect to Azure using the Connect-AzAccount cmdlet.' -ErrorAction Stop
        }

        try {
            $null = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
        }
        catch {
            throw $_
        }
    }

    process {
        try {
            $uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.ConnectedVMwarevSphere/vcenters/?api-version={2}' -f $SubscriptionId, $ResourceGroup, $ApiVersion)

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers       

            $response = $response.Value

            if ($PSBoundParameters.ContainsKey('Name')) {
                $response = $response | Where-Object { $_.Name -eq $Name }
            }

            $response
        }
        catch {
            throw ('Error encountered calling Azure REST API to retrieve Azure Arc-enabled VMware vSphere: {0}' -f $_)
        }
    }

    end {
        if ($null -ne $token) {
            Clear-Variable -Name token -Force -ErrorAction SilentlyContinue
            Clear-Variable -Name headers -Force -ErrorAction SilentlyContinue
        }
    }
}