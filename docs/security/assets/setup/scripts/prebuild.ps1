Register-AzResourceProvider -ProviderNamespace "Microsoft.Compute"
Register-AzProviderFeature -FeatureName "AutomaticSKUPreview" -ProviderNamespace "Microsoft.ContainerService"

while ($true) {
    $status = Get-AzResourceProvider -ProviderNamespace "Microsoft.Compute"
    Write-Output "$($status[0].ProviderNamespace) is still $($status[0].RegistrationState) in $($status[0].Locations)"
    if ($status[0].RegistrationState -eq "Registered") {
        break
    }
    Start-Sleep -Seconds 5
}

while ($true) {
    $status = Get-AzProviderFeature -FeatureName "AutomaticSKUPreview" -ProviderNamespace "Microsoft.ContainerService"
    Write-Output "$($status.FeatureName) is still $($status.RegistrationState)"
    if ($status.RegistrationState -eq "Registered") {
        break
    }
    Start-Sleep -Seconds 5
}

Register-AzResourceProvider -ProviderNamespace "Microsoft.PolicyInsights"