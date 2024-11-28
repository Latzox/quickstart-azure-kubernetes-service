# Quickstart Guide

## Prerequisites

- Azure CLI
- Azure PowerShell
- AKS CLI Tools

```
az aks install-cli
```

## Deploy the AKS cluster

Create the ssh keypair.

```bash
az sshkey create --name "keyName" --resource-group "myRg"
```

Now deploy the bicep template. You can either run it with:

```powershell
New-AzResourceGroupDeployment -ResourceGroupName <resource-group-name> -TemplateFile <path-to-template>
```

Or use the VS Code Bicep extension to deploy it within your UI:

![image.png](</quickstart-azure-kubernetes-service/docs/image (1).png>)

Pick the scope and perform a quick validation and preview with what-if. If everything runs without an error, hit the deploy button. Check the Azure Portal after the successful deployment to see what kind of resources got created.

## Connect to the AKS cluster

Now run the following command to import the aks credentials:

```powershell
Import-AzAksCredential -ResourceGroupName rg-k8s-dev-001 -Name latzok8s
```

Now you can use the kubectl commands to perform actions on your cluster.

```
kubectl get nodes

Output:
NAME                                STATUS   ROLES    AGE   VERSION
aks-agentpool-34339427-vmss000000   Ready    <none>   83m   v1.29.9
```

This will show the amout of nodes you deployed with the bicep template.

## Deploy the demo application

### Build and push Docker image

```bash
cd app/
docker build -t <yourAcrName.azurecr.io>/quickstart-aks-py:latest .
```

To test the python app on your local machine, run:

```bash
docker run -d -p 80:5000 <yourAcrName.azurecr.io>/quickstart-aks-py:latest
```

To push the Docker image, run:

```bash
docker push <yourAcrName.azurecr.io>/quickstart-aks-py:latest
```

### Update AKS yaml definition

```
image: <yourAcrName.azurecr.io>/quickstart-aks-py:latest
```

### Create the Kubernetes deployment

```bash
kubectl apply -f deployment.yaml
```

You should be able to see the pods by running:

```
kubectl get pods

Output:
NAME                        READY   STATUS    RESTARTS   AGE
aks-demo-85d9cfc796-gwmkf   1/1     Running   0          11m
aks-demo-85d9cfc796-m95nc   1/1     Running   0          11m
```

### Expose the app by creating the service

```
kubectl apply -f service.yaml
```

You can see the created service by running:

```
kubectl get service

Output:
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
aks-service   LoadBalancer   10.0.89.248   <pending>     80:30484/TCP   11s
kubernetes    ClusterIP      10.0.0.1      <none>        443/TCP        94m
```

When you're too quick, you'll see a pending external ip. Just wait a moment and try again.

```
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
aks-service   LoadBalancer   10.0.89.248   74.242.203.21   80:30484/TCP   26s
kubernetes    ClusterIP      10.0.0.1      <none>          443/TCP        95m
```

Now you can access the app from the browser.

![image.png](/quickstart-azure-kubernetes-service/docs/image.png)