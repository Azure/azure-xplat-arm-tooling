Configuration Main
{
    Param ( [string] $nodeName )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $nodeName
    {
        WindowsFeature WebServerRole
        {
            Name = "Web-Server"
            Ensure = "Present"
        }
    }
}