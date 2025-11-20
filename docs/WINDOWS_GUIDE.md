# Guide d'Installation et d'Exécution pour Windows

Ce guide vous permet d'installer et d'exécuter tous les benchmarks sur Windows 10/11.

## Installation Rapide ⚡

**Méthode recommandée** : Utilisez le script d'installation automatique !

Ouvrez PowerShell en tant qu'**Administrateur** et exécutez depuis la racine du projet :

```powershell
.\install-windows-tools.ps1
```

Ce script installe automatiquement tous les outils nécessaires. Pour une installation manuelle, consultez les sections ci-dessous.

---

## Table des Matières

1. [Prérequis](#prérequis)
2. [Installation des Outils](#installation-des-outils)
3. [Configuration de l'Environnement](#configuration-de-lenvironnement)
4. [Exécution des Benchmarks](#exécution-des-benchmarks)
5. [Troubleshooting](#troubleshooting)

## Prérequis

- Windows 10 ou Windows 11
- PowerShell 5.1 ou supérieur (inclus par défaut)
- Droits administrateur pour l'installation des outils

## Installation des Outils

### 1. Installer Chocolatey (Gestionnaire de Paquets)

Ouvrez PowerShell en tant qu'**Administrateur** et exécutez :

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### 2. Installer .NET 10 SDK

```powershell
# Via Chocolatey
choco install dotnet-sdk -y

# OU télécharger manuellement depuis :
# https://dotnet.microsoft.com/download/dotnet/10.0
```

Vérifiez l'installation :

```powershell
dotnet --version
# Devrait afficher : 10.0.x
```

### 3. Installer Java (pour Scala)

Scala nécessite Java 11 ou supérieur :

```powershell
# Installer OpenJDK 17
choco install openjdk17 -y
```

Vérifiez l'installation :

```powershell
java -version
# Devrait afficher : openjdk version "17.x.x"
```

### 4. Installer SBT (Scala Build Tool)

```powershell
# Via Chocolatey
choco install sbt -y
```

Vérifiez l'installation :

```powershell
sbt --version
# Devrait afficher la version de SBT
```

### 5. Installer les Outils de Benchmark

#### Apache Bench (ab)

Option 1 - Via les binaires précompilés :

```powershell
# Télécharger Apache Lounge (contient Apache Bench)
# https://www.apachelounge.com/download/

# Extraire dans C:\Apache24
# Ajouter C:\Apache24\bin au PATH système
```

Option 2 - Utiliser une alternative Windows :

```powershell
# Installer wrk (alternative à Apache Bench)
choco install wrk -y
```

#### jq (Traitement JSON)

```powershell
choco install jq -y
```

Vérifiez l'installation :

```powershell
jq --version
# Devrait afficher : jq-x.x
```

#### curl (Requêtes HTTP)

curl est déjà inclus dans Windows 10/11. Vérifiez :

```powershell
curl --version
```

### 6. Installer Git (si nécessaire)

```powershell
choco install git -y
```

## Configuration de l'Environnement

### 1. Vérifier que tous les outils sont installés

Ouvrez une **nouvelle** fenêtre PowerShell (pas en mode administrateur) et exécutez :

```powershell
# Vérifier .NET
dotnet --version

# Vérifier Java
java -version

# Vérifier SBT
sbt --version

# Vérifier jq
jq --version

# Vérifier curl
curl --version

# Vérifier ab (Apache Bench)
ab -V
# OU si vous utilisez wrk :
wrk --version
```

### 2. Configurer l'Exécution des Scripts PowerShell

Par défaut, Windows bloque l'exécution de scripts PowerShell. Pour autoriser l'exécution :

```powershell
# Ouvrir PowerShell en Administrateur
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### 3. Cloner ou Préparer le Projet

```powershell
# Si vous avez cloné le repo
cd C:\Users\VotreNom\IdeaProjects\temp

# Vérifier la structure
dir
```

## Exécution des Benchmarks

### Méthode 1 : Exécuter Tous les Benchmarks

Depuis la racine du projet, exécutez :

```powershell
# Exécuter la suite complète (30-45 minutes)
.\benchmarks\scripts\run_all_benchmarks.ps1
```

### Méthode 2 : Exécuter les Benchmarks Individuellement

#### Test de Compilation

```powershell
.\benchmarks\scripts\benchmark_compilation.ps1
```

#### Test de Taille des Packages

```powershell
.\benchmarks\scripts\benchmark_package_size.ps1
```

#### Test de Temps de Démarrage

```powershell
.\benchmarks\scripts\benchmark_startup.ps1
```

#### Test de Performance Runtime

```powershell
.\benchmarks\scripts\benchmark_runtime.ps1
```

#### Test JSON

```powershell
.\benchmarks\scripts\benchmark_json.ps1
```

#### Test LINQ & Collections

```powershell
.\benchmarks\scripts\benchmark_linq_collections.ps1
```

### Méthode 3 : Tests Manuels

#### Tester .NET

Terminal 1 :
```powershell
cd dotnet-api
dotnet run
```

Terminal 2 :
```powershell
# Test simple
curl http://localhost:5000/api/hello

# Test avec paramètre
curl http://localhost:5000/api/echo/test

# Test POST avec JSON
curl -X POST http://localhost:5000/api/data `
  -H "Content-Type: application/json" `
  -d '{"name":"test","value":123}'
```

#### Tester Scala Play

Terminal 1 :
```powershell
cd scala-play-api
sbt run
```

Terminal 2 :
```powershell
# Test simple
curl http://localhost:9000/api/hello

# Test avec paramètre
curl http://localhost:9000/api/echo/test

# Test POST avec JSON
curl -X POST http://localhost:9000/api/data `
  -H "Content-Type: application/json" `
  -d '{"name":"test","value":123}'
```

## Voir les Résultats

Les résultats sont sauvegardés dans `benchmarks\results\` :

```powershell
# Voir tous les résultats
dir benchmarks\results\

# Lire le rapport complet
Get-Content benchmarks\results\comprehensive_report.md

# OU ouvrir dans notepad
notepad benchmarks\results\comprehensive_report.md

# OU ouvrir dans VS Code
code benchmarks\results\comprehensive_report.md
```

## Troubleshooting

### Problème : "Scripts désactivés sur ce système"

**Solution :**
```powershell
# Ouvrir PowerShell en Administrateur
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Problème : "dotnet n'est pas reconnu"

**Solution :**
```powershell
# Vérifier que .NET est installé
choco list --local-only | Select-String dotnet

# Si pas installé, installer
choco install dotnet-sdk -y

# Fermer et rouvrir PowerShell
```

### Problème : "Port déjà utilisé"

**Solution :**
```powershell
# Trouver le processus utilisant le port 5000 (.NET)
netstat -ano | findstr :5000

# Tuer le processus (remplacer PID par le numéro trouvé)
taskkill /PID <PID> /F

# Pour le port 9000 (Scala Play)
netstat -ano | findstr :9000
taskkill /PID <PID> /F
```

### Problème : "ab n'est pas reconnu"

**Solution :**
```powershell
# Option 1 : Télécharger Apache Lounge
# https://www.apachelounge.com/download/
# Extraire dans C:\Apache24
# Ajouter C:\Apache24\bin au PATH

# Option 2 : Utiliser wrk comme alternative
choco install wrk -y

# Les scripts PowerShell peuvent utiliser les deux
```

### Problème : "jq n'est pas reconnu"

**Solution :**
```powershell
choco install jq -y
# Fermer et rouvrir PowerShell
```

### Problème : Erreur de Compilation .NET

**Solution :**
```powershell
cd dotnet-api
dotnet clean
Remove-Item -Recurse -Force bin, obj -ErrorAction SilentlyContinue
dotnet restore
dotnet build
```

### Problème : Erreur de Compilation Scala

**Solution :**
```powershell
cd scala-play-api
sbt clean
Remove-Item -Recurse -Force target, project\target -ErrorAction SilentlyContinue
sbt compile
```

### Problème : "Out of Memory" pendant les tests

**Solution :**
```powershell
# Augmenter la mémoire pour SBT
$env:SBT_OPTS = "-Xmx2G -XX:MaxMetaspaceSize=512M"
sbt run
```

### Problème : Erreur SSL/TLS avec curl

**Solution :**
```powershell
# Utiliser -k pour ignorer les erreurs SSL en dev
curl -k http://localhost:5000/api/hello
```

## Utilisation avec Docker (Alternative)

Si vous préférez utiliser Docker sur Windows :

### 1. Installer Docker Desktop

```powershell
choco install docker-desktop -y
```

### 2. Construire les Images

```powershell
# .NET
cd dotnet-api
docker build -t dotnet-bench .

# Scala Play
cd scala-play-api
docker build -t scala-bench .
```

### 3. Exécuter les Conteneurs

```powershell
# .NET
docker run -d -p 5000:5000 --name dotnet-app dotnet-bench

# Scala Play
docker run -d -p 9000:9000 --name scala-app scala-bench

# Tester
curl http://localhost:5000/api/hello
curl http://localhost:9000/api/hello

# Arrêter
docker stop dotnet-app scala-app
docker rm dotnet-app scala-app
```

## Optimisations Windows

### 1. Désactiver Windows Defender temporairement

Pour des benchmarks plus précis, vous pouvez désactiver temporairement l'antivirus :

```powershell
# Ouvrir PowerShell en Administrateur
Set-MpPreference -DisableRealtimeMonitoring $true

# IMPORTANT : Réactiver après les tests
Set-MpPreference -DisableRealtimeMonitoring $false
```

### 2. Augmenter la Priorité du Processus

```powershell
# Dans le script de benchmark, vous pouvez augmenter la priorité
$process = Get-Process -Name "dotnet"
$process.PriorityClass = "High"
```

### 3. Fermer les Applications Inutiles

Pour des résultats plus fiables, fermez les applications gourmandes (navigateurs, IDEs, etc.) avant de lancer les benchmarks.

## Raccourcis Utiles

Créez des alias PowerShell pour gagner du temps :

```powershell
# Ajouter à votre profil PowerShell
notepad $PROFILE

# Ajouter ces lignes :
function Run-AllBenchmarks { .\benchmarks\scripts\run_all_benchmarks.ps1 }
function Run-DotNet { cd dotnet-api; dotnet run }
function Run-Scala { cd scala-play-api; sbt run }

Set-Alias -Name bench -Value Run-AllBenchmarks
Set-Alias -Name dotnet-start -Value Run-DotNet
Set-Alias -Name scala-start -Value Run-Scala
```

Puis utilisez simplement :
```powershell
bench          # Lance tous les benchmarks
dotnet-start   # Démarre l'API .NET
scala-start    # Démarre l'API Scala Play
```

## Prochaines Étapes

1. **Analyser les résultats** : Consultez `benchmarks\results\comprehensive_report.md`
2. **Personnaliser les tests** : Modifiez les paramètres dans les scripts PowerShell
3. **Ajouter des tests** : Créez de nouveaux endpoints et benchmarks
4. **Comparer les configurations** : Testez avec différents paramètres

## Ressources Supplémentaires

- [Documentation .NET](https://docs.microsoft.com/dotnet/)
- [Documentation Play Framework](https://www.playframework.com/documentation)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Chocolatey Packages](https://community.chocolatey.org/packages)
- [Apache Lounge](https://www.apachelounge.com/download/)

## Support

Pour toute question ou problème :
- Consultez le [README.md](../README.md) principal
- Vérifiez les [issues GitHub](https://github.com/votre-repo/issues)
- Consultez le guide de [démarrage rapide](../QUICKSTART.md)
