# Microsoft Azure Cross-Platform Tooling Samples for Windows, Mac and Linux
A set of templates, snippets, and scripts that demonstrate creating and deploying Azure Resource Management Templates in cross-platform environments.

See [Authoring Azure Resource Manager Templates](https://azure.microsoft.com/en-us/documentation/articles/resource-group-authoring-templates/) for more information on how to author Azure Resource Group Templates. 

## Prerequisites

### Windows
* [Azure PowerShell](https://www.microsoft.com/web/handlers/webpi.ashx?command=getinstallerredirect&appid=WindowsAzurePowershellGet)
* [Visual Studio Code](https://code.visualstudio.com/Download)

#### OSX/Linux
* [jq](http://stedolan.github.io/jq/)
* [Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install)
* [Visual Studio Code](https://code.visualstudio.com/Download)

## Configure Visual Studio Code to Use the JSON Snippets
* Copy the contents of **VSCode\armsnippets.json** to the clipboard
* In Visual Studio Code, navigate to `File > Preferences > User Snippets > JSON`.
* Append (paste) the contents of **VSCode\armsnippets.json** into your user snippets file before the final **"}"**.
* Save and close the user snippets file.

## Edit Sample Templates using Visual Studio Code
* Launch Visual Studio Code.
* Navigate to `File > Open Folder` and select either the Bash or PowerShell folder as appropriate.
* Open **\*VirtualMachineSample.json** and put the insertion point after the first **"["** following **"resources:"**.
* Type `"arm"` and you'll see a list of available resource snippets. Choose one and it'll be inserted at the current cursor location. Freshly inserted snippets have tokens you can type in values for, and you can tab through the different tokens. 
* As you're editing the properties on objects in your template, IntelliSense dropdowns will appear to suggest available values. You can also select a value and hit `Ctrl+Space` to see the list of options.
* Descriptions for properties are displayed as you edit the property or mouse over them (if a description is defined in the schema).
* If you have any schema validation issues in your template you'll see squiggles in the editor. You can view the list of errors and warnings by hitting `Ctrl+Shift+M` or clicking the glyphs in the lower left status bar.

## Deploy Sample Templates from the Command Line

### Windows
* Open a PowerShell command prompt and run `Login-AzureRmAccount` to login.
* If the account has access to multiple subscriptions, use `Select-AzureRmSubscription -SubscriptionId <Subscription Id>` to switch to the one you want use.
* Update the values in the **PowerShell\WindowsVirtualMachineSample.parameters.json** file.
* Run the PowerShell script: `.\PowerShell\Deploy-AzureRmResourceGroup.ps1 -TemplateFile .\PowerShell\WindowsVirtualMachineSample.json -Location <Azure Region>`.

#### OSX/Linux
* Open a terminal window and run `azure login` to login.
* If the account has access to multiple subscriptions, use `azure account set <subscriptionNameOrId>` to switch to the one you want to use.
* Update the values in the **Bash/LinuxVirtualMachineSample.parameters.json** file.
* Run the bash Script: `Bash/azure-rg-deploy.sh -f Bash/LinuxVirtualMachineSample.json -l <Azure Region>`.

## Feedback
If you have any feedback on this example, please file an issue in the [Issues](https://github.com/Azure/azure-xplat-arm-tooling/issues) section of this project.
