$deletedAccounts = Get-AzResource -ResourceId /subscriptions/@lab.CloudSubscription.Id/providers/Microsoft.CognitiveServices/deletedAccounts -ApiVersion 2021-04-30
foreach ($deletedAccount in $deletedAccounts) {
    Remove-AzResource -Confirm:$false -ResourceId $deletedAccount.ResourceId -ApiVersion 2021-04-30 -Force
}
