tfstate='mytfstatestore'
tfstaterg='tfstate-rg'
location='australiaeast'

# Install AZ CLI
if ! command -v az >/dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Authenticate using service principal on CI
az login
az account set --subscription $1

# Create TF state store resource group
if [ $(az group exists --name $tfstaterg) = false ]; then
    az group create --name $tfstaterg --location $location >/dev/null
fi

# Create TF state store
if [ $(az storage account list --query '[].name' -o json | jq 'index( "$tfstate" )') ]; then
    az storage account create -n $tfstate -g $tfstaterg -l $location --sku Standard_LRS >/dev/null
    az storage container create -n tfstate --account-name $tfstate >/dev/null
fi

# For TF backend store
export ARM_ACCESS_KEY=$(az storage account keys list -n $tfstate --query [0].value -o tsv)

case $2 in
"init")
    ansible-playbook deploy.yaml -e env=$3 -e operation=init
    ;;
"destroy")
    ansible-playbook deploy.yaml -e env=$3 -e operation=destroy
    ;;
"create")
    ansible-playbook deploy.yaml -e env=$3 -e operation=create
    ;;
"create-plan" | *)
    ansible-playbook deploy.yaml -e env=$3 -e operation=create-plan
    if [ ! -f "/tf/plan.tfplan" ]; then
        (
            cd tf
            terraform show plan.tfplan
        )
    fi
    ;;
esac
