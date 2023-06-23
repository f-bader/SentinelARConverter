FROM mcr.microsoft.com/powershell:latest

# Note: The DEBIAN_FRONTEND export avoids warnings when you go on to work with your container.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git \
    && apt install -y powershell

SHELL ["/usr/bin/pwsh", "-c"]
RUN $ErrorActionPreference='Stop'; Install-Module -Name Pester, powershell-yaml ,PSScriptAnalyzer -Force