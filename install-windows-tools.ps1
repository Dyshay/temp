# Script d'installation automatique des outils pour Windows
# Ce script installe tous les outils necessaires pour executer les benchmarks
# A executer avec PowerShell en mode Administrateur

param(
    [switch]$SkipChocolatey,
    [switch]$SkipDotNet,
    [switch]$SkipJava,
    [switch]$SkipSbt,
    [switch]$SkipTools
)

# Verifier si le script est execute en tant qu'administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "ERREUR : Ce script doit etre execute en tant qu'Administrateur" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Pour executer en tant qu'administrateur :" -ForegroundColor Yellow
    Write-Host "1. Clic droit sur PowerShell" -ForegroundColor Yellow
    Write-Host "2. Selectionnez 'Executer en tant qu'administrateur'" -ForegroundColor Yellow
    Write-Host "3. Relancez ce script" -ForegroundColor Yellow
    exit 1
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installation des Outils .NET vs Scala" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Fonction pour verifier si une commande existe
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Fonction pour afficher un message de succes
function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

# Fonction pour afficher un message d'erreur
function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERREUR] $Message" -ForegroundColor Red
}

# Fonction pour afficher un message d'info
function Write-InfoMessage {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

# 1. Installer Chocolatey
if (-not $SkipChocolatey) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Etape 1/5 : Chocolatey (Gestionnaire de Paquets)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    if (Test-Command choco) {
        Write-SuccessMessage "Chocolatey est deja installe"
        choco --version
    }
    else {
        Write-InfoMessage "Installation de Chocolatey..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-SuccessMessage "Chocolatey installe avec succes"

            # Recharger la variable d'environnement PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de Chocolatey : $_"
            Write-Host "Veuillez installer Chocolatey manuellement : https://chocolatey.org/install"
            exit 1
        }
    }
}

# 2. Installer .NET SDK
if (-not $SkipDotNet) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Etape 2/5 : .NET 10 SDK" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    if (Test-Command dotnet) {
        Write-SuccessMessage ".NET SDK est deja installe"
        dotnet --version

        # Verifier si c'est .NET 10
        $dotnetVersion = dotnet --version
        if ($dotnetVersion -like "10.*") {
            Write-SuccessMessage ".NET 10 SDK detecte"
        }
        else {
            Write-InfoMessage "Version actuelle : $dotnetVersion"
            Write-InfoMessage "Installation de .NET 10 SDK..."
            choco install dotnet-sdk -y --version=10.0.0
        }
    }
    else {
        Write-InfoMessage "Installation de .NET 10 SDK..."
        try {
            choco install dotnet-sdk -y
            Write-SuccessMessage ".NET SDK installe avec succes"

            # Recharger PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de .NET SDK"
            Write-Host "Veuillez installer manuellement depuis : https://dotnet.microsoft.com/download"
        }
    }
}

# 3. Installer Java (requis pour Scala)
if (-not $SkipJava) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Etape 3/5 : Java (OpenJDK 17)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    if (Test-Command java) {
        Write-SuccessMessage "Java est deja installe"
        java -version
    }
    else {
        Write-InfoMessage "Installation d'OpenJDK 17..."
        try {
            choco install openjdk17 -y
            Write-SuccessMessage "Java installe avec succes"

            # Recharger PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de Java"
            Write-Host "Veuillez installer manuellement depuis : https://adoptium.net/"
        }
    }
}

# 4. Installer SBT (Scala Build Tool)
if (-not $SkipSbt) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Etape 4/5 : SBT (Scala Build Tool)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    if (Test-Command sbt) {
        Write-SuccessMessage "SBT est deja installe"
        sbt --version
    }
    else {
        Write-InfoMessage "Installation de SBT..."
        try {
            choco install sbt -y
            Write-SuccessMessage "SBT installe avec succes"

            # Recharger PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de SBT"
            Write-Host "Veuillez installer manuellement depuis : https://www.scala-sbt.org/download.html"
        }
    }
}

# 5. Installer les outils de benchmark
if (-not $SkipTools) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Etape 5/5 : Outils de Benchmark" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # jq (pour le traitement JSON)
    if (Test-Command jq) {
        Write-SuccessMessage "jq est deja installe"
    }
    else {
        Write-InfoMessage "Installation de jq..."
        try {
            choco install jq -y
            Write-SuccessMessage "jq installe avec succes"
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de jq"
        }
    }

    # Git (si pas deja installe)
    if (Test-Command git) {
        Write-SuccessMessage "Git est deja installe"
    }
    else {
        Write-InfoMessage "Installation de Git..."
        try {
            choco install git -y
            Write-SuccessMessage "Git installe avec succes"
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de Git"
        }
    }

    # Apache Bench (ab)
    Write-Host ""
    Write-InfoMessage "Apache Bench (ab) pour les tests de charge..."
    Write-Host "  Note: Apache Bench n'est pas disponible via Chocolatey" -ForegroundColor Yellow
    Write-Host "  Les scripts PowerShell incluent un fallback en cas d'absence" -ForegroundColor Yellow
    Write-Host "  Pour de meilleurs resultats, telechargez Apache Lounge:" -ForegroundColor Yellow
    Write-Host "  -> https://www.apachelounge.com/download/" -ForegroundColor Cyan
    Write-Host "  -> Extraire dans C:\Apache24" -ForegroundColor Cyan
    Write-Host "  -> Ajouter C:\Apache24\bin au PATH systeme" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Alternative: Installer wrk" -ForegroundColor Yellow
    $installWrk = Read-Host "  Voulez-vous installer wrk comme alternative? (O/N)"
    if ($installWrk -eq "O" -or $installWrk -eq "o" -or $installWrk -eq "Y" -or $installWrk -eq "y") {
        try {
            choco install wrk -y
            Write-SuccessMessage "wrk installe avec succes"
        }
        catch {
            Write-ErrorMessage "Erreur lors de l'installation de wrk"
        }
    }
}

# Recharger PATH final
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Resume final
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Resume de l'Installation" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$tools = @(
    @{Name="Chocolatey"; Command="choco"},
    @{Name=".NET SDK"; Command="dotnet"},
    @{Name="Java"; Command="java"},
    @{Name="SBT"; Command="sbt"},
    @{Name="jq"; Command="jq"},
    @{Name="Git"; Command="git"},
    @{Name="curl"; Command="curl"}
)

foreach ($tool in $tools) {
    if (Test-Command $tool.Command) {
        Write-SuccessMessage "$($tool.Name) : Installe"
    }
    else {
        Write-ErrorMessage "$($tool.Name) : Non installe"
    }
}

# Apache Bench
if (Test-Command ab) {
    Write-SuccessMessage "Apache Bench : Installe"
}
elseif (Test-Command wrk) {
    Write-SuccessMessage "wrk (alternative a Apache Bench) : Installe"
}
else {
    Write-Host "[ATTENTION] Apache Bench / wrk : Non installe (optionnel)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installation Terminee!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines etapes :" -ForegroundColor Green
Write-Host "1. Fermez cette fenetre PowerShell" -ForegroundColor Yellow
Write-Host "2. Ouvrez une NOUVELLE fenetre PowerShell (pour recharger PATH)" -ForegroundColor Yellow
Write-Host "3. Naviguez vers le dossier du projet" -ForegroundColor Yellow
Write-Host "4. Executez : .\benchmarks\scripts\run_all_benchmarks.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pour un guide complet, consultez : docs\WINDOWS_GUIDE.md" -ForegroundColor Cyan
Write-Host ""

# Proposer de configurer l'ExecutionPolicy
Write-Host "Configuration finale..." -ForegroundColor Cyan
$configurePolicy = Read-Host "Autoriser l'execution de scripts PowerShell? (Requis pour les benchmarks) (O/N)"
if ($configurePolicy -eq "O" -or $configurePolicy -eq "o" -or $configurePolicy -eq "Y" -or $configurePolicy -eq "y") {
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-SuccessMessage "Politique d'execution configuree avec succes"
    }
    catch {
        Write-ErrorMessage "Erreur lors de la configuration de la politique d'execution"
        Write-Host "Executez manuellement : Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
