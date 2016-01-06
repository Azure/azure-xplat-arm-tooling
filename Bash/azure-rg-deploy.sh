#!/bin/bash -e
while getopts "f:l:e:g:" opt; do
    case $opt in
        f)
            templateFile=$OPTARG
        ;;
        l)
            location=$OPTARG
        ;;
        e)
            parametersFile=$OPTARG
        ;;
        g)
            resourceGroupName=$OPTARG
        ;;
    esac
done
    

[[ $# -eq 0 || -z $templateFile || -z $location ]] && { echo "Usage: $0 <-f template-file> <-l location> [-e parameters-file] [-g resource-group-name]"; exit 1; }

templateName="$( basename "${templateFile%.*}" )"
templateDirectory="$( dirname "$templateFile")"

if [[ -z $parametersFile ]]
then
    parametersFile=${parametersFile:-${templateDirectory}/${templateName}".parameters.json"}
fi

if [[ -z $resourceGroupName ]]
then
    resourceGroupName=${resourceGroupName:-${templateName}}
fi

artifactsSourceFolder=$templateDirectory"/Artifacts"

parameterJson=$( cat "$parametersFile" | jq '.parameters' )

azure config mode arm

# When $artifactsSourceFolder contains files, they will be staged in a storage account.
artifactsCount=$( ls "$artifactsSourceFolder" 2>/dev/null | wc -l )
if [[ ! -z "$artifactsSourceFolder" ]] && [[ -r "$artifactsSourceFolder" ]] && [[ $artifactsCount -gt 0 ]]
then
    subscriptionId=$( azure account show --json | jq -r '.[0].id' )
    artifactsResourceGroupName="ARM_Deploy_Staging"
    artifactsStorageAccountName="armstaging${subscriptionId:0:8}"
    artifactsStorageContainerName=${resourceGroupName}"-stageartifacts"
    artifactsStorageContainerName=$( echo "$artifactsStorageContainerName" | awk '{print tolower($0)}')
    
    azure group create "$artifactsResourceGroupName" "$location"

    set +e
    azure storage account create -l "$location" --type "LRS" -g "$artifactsResourceGroupName" "$artifactsStorageAccountName" 2>/dev/null
    artifactsStorageAccountKey=$( azure storage account keys list -g "$artifactsResourceGroupName" "$artifactsStorageAccountName" --json | jq -r '.storageAccountKeys.key1' )
    azure storage container create --container "$artifactsStorageContainerName" -p Off -a "$artifactsStorageAccountName" -k "$artifactsStorageAccountKey" >/dev/null 2>&1
    set -e

    # Get a 4-hour SAS Token for the artifacts container. Fall back to OSX date syntax if Linux syntax fails.
    set +e
    plusFourHoursUtc=$(date -u -v+4H +%Y-%m-%dT%H:%M:%S%z 2>/dev/null) || plusFourHoursUtc=$(date -u --date "$dte 4 hour" --iso-8601=seconds)
    set -e

    sasToken=$( azure storage container sas create --container "$artifactsStorageContainerName" --permissions r --expiry "$plusFourHoursUtc" -a "$artifactsStorageAccountName" -k "$artifactsStorageAccountKey" --json | jq -r '.sas' )

    blobEndpoint=$( azure storage account show "$artifactsStorageAccountName" -g "$artifactsResourceGroupName" --json | jq -r '.primaryEndpoints.blob' )

    parameterJson=$( echo "$parameterJson"  | jq "{_artifactsLocation: {value: "\"$blobEndpoint$artifactsStorageContainerName"\"}, _artifactsLocationSasToken: {value: \"?"$sasToken"\"}} + ." )

    artifactsSourceFolder=$( echo "$artifactsSourceFolder" | sed 's/\/*$//')
    artifactsSourceFolderLen=$((${#artifactsSourceFolder} + 1))

    for filepath in $( find "$artifactsSourceFolder" -type f )
    do
        relFilePath=${filepath:$artifactsSourceFolderLen}
        azure storage blob upload -f $filepath --container $artifactsStorageContainerName -b $relFilePath -q -a "$artifactsStorageAccountName" -k "$artifactsStorageAccountKey"
    done 
fi

azure group create "$resourceGroupName" "$location"

# Remove line endings from parameter JSON so it can be passed in to the CLI as a single line
parameterJson=$( echo "$parameterJson" | jq -c '.' )

azure group deployment create -g "$resourceGroupName" -n XPlat_CLI_Script -f $templateFile -p "$parameterJson" -v