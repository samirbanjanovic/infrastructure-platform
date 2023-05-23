# fetch aks crednetials
az aks get-credentials --resource-group $env:RESOURCE_GROUP --name $env:CLUSTER_NAME --overwrite-existing

kubectl create secret generic `
    $env:AZURE_CLUSTER_IDENTITY_SECRET_NAME `
    --from-literal=clientSecret=$env:AZURE_CLIENT_SECRET `
    --namespace $env:AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE

# Create management cluster
clusterctl init --infrastructure azure