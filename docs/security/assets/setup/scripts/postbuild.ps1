New-AzRoleAssignment -SignInName '@lab.CloudPortalCredential(Admin).Username' -RoleDefinitionName 'Azure Kubernetes Service RBAC Cluster Admin' -Scope '@lab.CloudResourceTemplate(AKSAutomatic).Outputs[aksId]'
New-AzRoleAssignment -SignInName '@lab.CloudPortalCredential(Admin).Username' -RoleDefinitionName 'Grafana Admin' -Scope '@lab.CloudResourceTemplate(AKSAutomatic).Outputs[grafanaId]'

Register-AzResourceProvider -ProviderNamespace "Microsoft.KeyVault"
Register-AzResourceProvider -ProviderNamespace "Microsoft.AppConfiguration"
Register-AzResourceProvider -ProviderNamespace "Microsoft.ServiceLinker"
Register-AzResourceProvider -ProviderNamespace "Microsoft.ContainerRegistry"
Register-AzResourceProvider -ProviderNamespace "Microsoft.KubernetesConfiguration"
Register-AzResourceProvider -ProviderNamespace "Microsoft.CognitiveServices"
Register-AzProviderFeature -FeatureName "EnableImageIntegrityPreview" -ProviderNamespace "Microsoft.ContainerService"
Register-AzProviderFeature -FeatureName "AKS-AzurePolicyExternalData" -ProviderNamespace "Microsoft.ContainerService"
