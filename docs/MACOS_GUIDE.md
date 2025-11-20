# Guide pour macOS (x64)

Ce guide explique comment exécuter les benchmarks sur **macOS x64** avec les ajustements nécessaires.

## Problèmes de Compatibilité

macOS utilise des commandes BSD qui diffèrent des commandes GNU Linux utilisées dans les scripts. Voici les principaux problèmes :

### 1. Date avec nanosecondes
**Problème** : `date +%s.%N` (nanosecondes) n'existe pas sur macOS BSD
**Impact** : Mesures de temps moins précises

### 2. Du (disk usage)
**Problème** : `du -sb` (size in bytes) n'existe pas sur macOS
**Impact** : Mesure de taille de packages

### 3. Apache Bench
**Note** : Disponible nativement sur macOS (pas besoin d'installation supplémentaire)

## Solution Recommandée : Installer GNU Coreutils

La meilleure solution est d'installer les versions GNU des commandes :

```bash
# Installer GNU coreutils via Homebrew
brew install coreutils

# Les commandes GNU seront préfixées par 'g'
# Ex: gdate, gdu, etc.
```

## Installation Complète pour macOS x64

### Étape 1 : Installer Homebrew (si nécessaire)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Étape 2 : Installer toutes les dépendances

```bash
# .NET 10 SDK
brew install --cask dotnet-sdk

# Vérifier l'installation
dotnet --version
# Devrait afficher : 10.0.x

# Scala Build Tool
brew install sbt

# Vérifier l'installation
sbt --version

# GNU Coreutils (pour compatibilité des scripts)
brew install coreutils

# Utilitaires de benchmark
brew install jq

# bc (calculatrice pour scripts bash)
brew install bc
```

### Étape 3 : Créer des alias pour les commandes GNU

Ajoutez ceci à votre `~/.zshrc` ou `~/.bash_profile` :

```bash
# Alias pour utiliser les commandes GNU sans préfixe 'g'
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# Ou créer des alias individuels
alias date='gdate'
alias du='gdu'
```

Puis rechargez votre shell :

```bash
# Pour zsh (défaut sur macOS moderne)
source ~/.zshrc

# Ou pour bash
source ~/.bash_profile
```

### Étape 4 : Vérifier les installations

```bash
# Vérifier que date supporte les nanosecondes
date +%s.%N
# Devrait afficher un timestamp avec décimales

# Vérifier du
du -sb . 2>/dev/null && echo "✓ du fonctionne" || echo "✗ Utiliser gdu"

# Vérifier Apache Bench
ab -V
# Devrait afficher la version

# Vérifier jq
jq --version

# Vérifier bc
echo "1 + 1" | bc
# Devrait afficher : 2
```

## Architecture x64 vs ARM (Apple Silicon)

### Si vous êtes sur Apple Silicon (M1/M2/M3)

**Note** : Vous avez mentionné x64, mais si vous avez un Mac avec Apple Silicon :

```bash
# Vérifier votre architecture
uname -m
# x86_64 = Intel (x64)
# arm64 = Apple Silicon

# Pour Apple Silicon, .NET 10 a un support natif ARM64
# Les benchmarks fonctionneront mieux en mode natif
```

### Rosetta 2 (si nécessaire)

Si certains composants nécessitent x64 :

```bash
# Installer Rosetta 2
softwareupdate --install-rosetta
```

## Lancer les Benchmarks

Une fois tout installé :

```bash
# Cloner le projet
cd /chemin/vers/le/projet

# Rendre les scripts exécutables (si nécessaire)
chmod +x benchmarks/scripts/*.sh

# Lancer la suite complète
./benchmarks/scripts/run_all_benchmarks.sh
```

## Tests Rapides

### Test .NET uniquement

```bash
cd dotnet-api
dotnet restore
dotnet run
# Devrait démarrer sur http://localhost:5000

# Dans un autre terminal
curl http://localhost:5000/api/hello
```

### Test Scala Play uniquement

```bash
cd scala-play-api
sbt run
# Devrait démarrer sur http://localhost:9000

# Dans un autre terminal
curl http://localhost:9000/api/hello
```

## Problèmes Connus sur macOS

### 1. Port déjà utilisé

```bash
# Trouver le processus utilisant le port
lsof -i :5000
lsof -i :9000

# Tuer le processus
kill -9 <PID>
```

### 2. Limite de fichiers ouverts

macOS a une limite basse par défaut :

```bash
# Vérifier la limite actuelle
ulimit -n

# Augmenter temporairement (pour la session courante)
ulimit -n 10000

# Ou de façon permanente, ajouter à ~/.zshrc :
echo "ulimit -n 10000" >> ~/.zshrc
```

### 3. Performances avec Docker

Si vous utilisez Docker sur Mac :

```bash
# Docker Desktop pour Mac peut être plus lent
# Préférez exécuter les applications nativement pour les benchmarks

# Allouer plus de ressources à Docker Desktop :
# Docker Desktop > Settings > Resources
# - CPUs: 4+
# - Memory: 8GB+
```

### 4. Antivirus / Firewall

```bash
# Le firewall macOS peut bloquer les connexions
# Autoriser les connexions entrantes pour dotnet et java

# Système > Sécurité et confidentialité > Pare-feu
```

### 5. SBT très lent au premier lancement

```bash
# SBT télécharge beaucoup de dépendances la première fois
# Patience ! Cela peut prendre 10-15 minutes

# Précharger les dépendances :
cd scala-play-api
sbt update
```

## Optimisations macOS

### Pour de meilleures performances

```bash
# 1. Fermer les applications inutiles
# 2. Désactiver Time Machine pendant les tests
# 3. Désactiver Spotlight pendant les tests

# Désactiver Spotlight temporairement :
sudo mdutil -a -i off

# Réactiver après :
sudo mdutil -a -i on
```

### Monitoring des performances

```bash
# Utiliser Activity Monitor
open -a "Activity Monitor"

# Ou en ligne de commande
top -o cpu

# Pour voir l'utilisation réseau
nettop
```

## Variables d'Environnement

### .NET

```bash
# Désactiver la télémétrie (optionnel)
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Optimiser pour les benchmarks
export DOTNET_TieredCompilation=true
export DOTNET_ReadyToRun=1
```

### Java/Scala

```bash
# Augmenter la mémoire JVM
export JAVA_OPTS="-Xmx4g -Xms2g"

# Ajuster pour votre machine
export SBT_OPTS="-Xmx4g -Xss2M"
```

## Résultats Attendus sur macOS

Les performances peuvent varier selon :
- **Processeur** : Intel i5/i7/i9 ou AMD
- **RAM** : 8GB minimum, 16GB+ recommandé
- **SSD** : Impact sur les temps de compilation
- **macOS Version** : 12+ recommandé

### Benchmarks de référence (MacBook Pro 2020, i7, 16GB)

Ordres de grandeur attendus :

```
Compilation :
- .NET : 5-10 secondes
- Scala : 30-60 secondes

Throughput :
- .NET : 20,000-40,000 req/sec
- Scala : 15,000-35,000 req/sec

Startup :
- .NET : 0.5-1.5 secondes
- Scala : 3-8 secondes
```

## Aide et Support

### Logs et Débogage

```bash
# Activer le mode verbose pour les scripts
bash -x ./benchmarks/scripts/benchmark_compilation.sh

# Capturer les erreurs
./benchmarks/scripts/run_all_benchmarks.sh 2>&1 | tee benchmark.log
```

### Ressources

- [.NET sur macOS](https://learn.microsoft.com/en-us/dotnet/core/install/macos)
- [Homebrew](https://brew.sh/)
- [GNU Coreutils](https://www.gnu.org/software/coreutils/)
- [SBT Documentation](https://www.scala-sbt.org/download.html)

## Checklist Avant de Lancer les Benchmarks

- [ ] .NET 10 SDK installé et fonctionnel
- [ ] SBT installé et fonctionnel
- [ ] GNU Coreutils installé (gdate, gdu)
- [ ] Alias configurés dans .zshrc/.bash_profile
- [ ] jq et bc installés
- [ ] ulimit augmenté (10000+)
- [ ] Applications inutiles fermées
- [ ] Espace disque suffisant (5GB+)
- [ ] Connexion internet stable (pour télécharger dépendances)

## Exécution

Une fois la checklist complétée :

```bash
# Test rapide (5 minutes)
./benchmarks/scripts/benchmark_compilation.sh

# Suite complète (30-45 minutes)
./benchmarks/scripts/run_all_benchmarks.sh

# Tests de throughput (20-30 minutes)
./benchmarks/scripts/run_throughput_suite.sh
```

Bonne chance avec vos benchmarks ! 🚀
