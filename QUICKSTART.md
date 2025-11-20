# Guide de Démarrage Rapide

Ce guide vous permet de lancer rapidement les benchmarks pour comparer .NET et Scala Play.

> **📱 Utilisateurs macOS x64** : Pour des instructions détaillées adaptées à macOS (installation de GNU coreutils, gestion des limites, optimisations), consultez le [Guide macOS complet](docs/MACOS_GUIDE.md).

> **💻 Utilisateurs Windows** : Pour des instructions détaillées adaptées à Windows (installation via Chocolatey, scripts PowerShell), consultez le [Guide Windows complet](docs/WINDOWS_GUIDE.md).

## Installation Rapide des Prérequis

### Windows (Installation Automatique) ⚡

**Option 1 : Installation automatique (Recommandé)**

Ouvrez PowerShell en tant qu'**Administrateur** et exécutez :

```powershell
# Depuis la racine du projet
.\install-windows-tools.ps1
```

Ce script installe automatiquement :
- Chocolatey (gestionnaire de paquets)
- .NET 10 SDK
- Java (OpenJDK 17)
- SBT (Scala Build Tool)
- jq (traitement JSON)
- Git

**Option 2 : Installation manuelle**

Consultez le [Guide Windows complet](docs/WINDOWS_GUIDE.md) pour les instructions détaillées.

---

### Ubuntu/Debian

```bash
# Installer .NET 10 SDK (LTS)
wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 10.0
export PATH="$PATH:$HOME/.dotnet"

# Installer SBT (pour Scala)
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
sudo apt-get update
sudo apt-get install -y sbt

# Installer les outils de benchmark
sudo apt-get install -y apache2-utils bc jq curl
```

### macOS

```bash
# Installer Homebrew si nécessaire
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Installer .NET
brew install --cask dotnet-sdk

# Installer SBT
brew install sbt

# Installer les outils de benchmark
brew install apache2-utils jq
```

## Lancer les Benchmarks en 3 Étapes

### Étape 1 : Vérifier les installations

**Linux/macOS :**
```bash
# Vérifier .NET
dotnet --version
# Devrait afficher : 10.0.x

# Vérifier SBT
sbt --version
# Devrait afficher la version de SBT

# Vérifier Apache Bench
ab -V
# Devrait afficher la version d'Apache Bench
```

**Windows PowerShell :**
```powershell
# Vérifier .NET
dotnet --version
# Devrait afficher : 10.0.x

# Vérifier SBT
sbt --version
# Devrait afficher la version de SBT

# Vérifier jq
jq --version
# Devrait afficher la version de jq
```

### Étape 2 : Cloner et préparer le projet

**Linux/macOS :**
```bash
# Si vous avez cloné le repo
cd /chemin/vers/le/projet

# Rendre les scripts exécutables
chmod +x benchmarks/scripts/*.sh
```

**Windows PowerShell :**
```powershell
# Naviguer vers le projet
cd C:\chemin\vers\le\projet

# Les scripts PowerShell sont déjà prêts à l'emploi
```

### Étape 3 : Lancer les benchmarks

**Linux/macOS :**
```bash
# Lancer tous les benchmarks (15-30 minutes)
./benchmarks/scripts/run_all_benchmarks.sh

# OU lancer les benchmarks individuellement

# Compilation uniquement (5-10 min)
./benchmarks/scripts/benchmark_compilation.sh

# Taille des packages uniquement (2-5 min)
./benchmarks/scripts/benchmark_package_size.sh

# Performance runtime uniquement (10-15 min)
./benchmarks/scripts/benchmark_runtime.sh
```

**Windows PowerShell :**
```powershell
# Lancer tous les benchmarks (30-45 minutes)
.\benchmarks\scripts\run_all_benchmarks.ps1

# OU lancer les benchmarks individuellement

# Compilation uniquement (5-10 min)
.\benchmarks\scripts\benchmark_compilation.ps1

# Taille des packages uniquement (2-5 min)
.\benchmarks\scripts\benchmark_package_size.ps1

# Temps de démarrage (5-10 min)
.\benchmarks\scripts\benchmark_startup.ps1

# Performance runtime uniquement (10-15 min)
.\benchmarks\scripts\benchmark_runtime.ps1
```

## Voir les Résultats

Les résultats sont dans `benchmarks/results/` :

```bash
# Voir le rapport complet en Markdown
cat benchmarks/results/comprehensive_report.md

# Ou ouvrir dans un éditeur
code benchmarks/results/comprehensive_report.md
```

## Test Manuel Rapide

### Tester .NET

```bash
# Terminal 1 : Démarrer l'application
cd dotnet-api
dotnet run

# Terminal 2 : Tester les endpoints
curl http://localhost:5000/api/hello
curl http://localhost:5000/api/echo/test
curl -X POST http://localhost:5000/api/data \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":123}'
```

### Tester Scala Play

```bash
# Terminal 1 : Démarrer l'application
cd scala-play-api
sbt run

# Terminal 2 : Tester les endpoints
curl http://localhost:9000/api/hello
curl http://localhost:9000/api/echo/test
curl -X POST http://localhost:9000/api/data \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":123}'
```

## Benchmark Personnalisé

Pour modifier les paramètres de test, éditez `benchmarks/scripts/benchmark_runtime.sh` :

```bash
# Ouvrir le fichier
nano benchmarks/scripts/benchmark_runtime.sh

# Modifier ces valeurs :
WARMUP_REQUESTS=100      # Nombre de requêtes de warmup
BENCH_REQUESTS=1000      # Nombre de requêtes de benchmark
CONCURRENCY=10           # Nombre de connexions simultanées
WARMUP_TIME=5            # Durée du warmup en secondes
```

## Troubleshooting Rapide

### Problème : Port déjà utilisé

```bash
# Trouver et tuer le processus
lsof -i :5000  # Pour .NET
lsof -i :9000  # Pour Scala Play
kill -9 <PID>
```

### Problème : Erreur de compilation .NET

```bash
cd dotnet-api
dotnet clean
rm -rf bin obj
dotnet restore
dotnet build
```

### Problème : Erreur de compilation Scala

```bash
cd scala-play-api
sbt clean
rm -rf target project/target
sbt compile
```

### Problème : ab (Apache Bench) non trouvé

```bash
# Ubuntu/Debian
sudo apt-get install apache2-utils

# macOS
brew install apache2-utils
```

### Problème : jq non trouvé

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

## Options Docker (Alternative)

Si vous préférez utiliser Docker :

### Construire les images

```bash
# .NET
cd dotnet-api
docker build -t dotnet-bench .

# Scala Play
cd scala-play-api
docker build -t scala-bench .
```

### Exécuter

```bash
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

## Résultats Attendus

Après l'exécution complète, vous devriez avoir :

```
benchmarks/results/
├── compilation_results.json        # Temps de compilation
├── package_size_results.json       # Tailles des packages
├── runtime_results.json            # Performance et RAM
├── comprehensive_report.json       # Rapport complet JSON
└── comprehensive_report.md         # Rapport complet Markdown
```

## Prochaines Étapes

1. **Analyser les résultats** : Lire `comprehensive_report.md`
2. **Ajuster les paramètres** : Modifier les scripts de benchmark
3. **Ajouter des tests** : Créer de nouveaux endpoints à comparer
4. **Comparer différentes configs** : Tester avec différents paramètres

## Besoin d'Aide ?

Consultez le [README.md](README.md) principal pour :
- Documentation complète
- Architecture détaillée
- Guide de contribution
- Ressources supplémentaires
