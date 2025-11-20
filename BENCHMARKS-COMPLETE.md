# Suite Complete de Benchmarks Windows ✅

Tous les scripts PowerShell ont ete crees avec succes !

## Scripts Disponibles

| Script | Description | Duree | Statut |
|--------|-------------|-------|--------|
| `benchmark_compilation.ps1` | Temps de compilation .NET vs Scala | 5-10 min | ✅ Complet |
| `benchmark_package_size.ps1` | Taille des packages deployes | 2-5 min | ✅ Complet |
| `benchmark_startup.ps1` | Temps de demarrage (cold/warm/hot) | 5-10 min | ✅ Complet |
| `benchmark_runtime.ps1` | Performance runtime & RAM | 10-15 min | ✅ Complet |
| `benchmark_json.ps1` | Serialisation/Deserialisation JSON | 5-10 min | ✅ Complet* |
| `benchmark_linq_collections.ps1` | LINQ & Collections | 5-10 min | ⚠️ Placeholder** |
| `benchmark_throughput.ps1` | Throughput a differents niveaux de concurrence | 10-15 min | ✅ Complet |
| `benchmark_load_test.ps1` | Test de charge progressif (breaking point) | 10-15 min | ✅ Complet |
| `run_all_benchmarks.ps1` | **Lance tous les benchmarks** | 45-60 min | ✅ Complet |

**Legende :**
- ✅ Complet : Fonctionne avec les endpoints existants
- ✅ Complet* : Fonctionne si endpoint `/api/json-benchmark` existe, sinon skip
- ⚠️ Placeholder** : Genere des resultats placeholder en attendant l'implementation des endpoints

## Utilisation

### Methode 1 : Lancer Tous les Benchmarks

```powershell
# Lancer la suite complete
.\benchmarks\scripts\run_all_benchmarks.ps1
```

**Duree totale** : 45-60 minutes

### Methode 2 : Lancer des Benchmarks Individuels

```powershell
# Benchmarks de base (fonctionnent immediatement)
.\benchmarks\scripts\benchmark_compilation.ps1
.\benchmarks\scripts\benchmark_package_size.ps1
.\benchmarks\scripts\benchmark_startup.ps1
.\benchmarks\scripts\benchmark_runtime.ps1

# Benchmarks de throughput (fonctionnent immediatement)
.\benchmarks\scripts\benchmark_throughput.ps1
.\benchmarks\scripts\benchmark_load_test.ps1

# Benchmarks avances (necessitent endpoints specifiques)
.\benchmarks\scripts\benchmark_json.ps1
.\benchmarks\scripts\benchmark_linq_collections.ps1
```

## Fonctionnalites Cles

### 1. Gestion Automatique des Erreurs
- Les scripts utilisent `$ErrorActionPreference = "Continue"`
- Gestion gracieuse des erreurs (pas d'arret brutal)
- Messages d'erreur clairs et informatifs

### 2. Detection Automatique des Outils
- Detection automatique d'Apache Bench (ab)
- Fallback vers PowerShell si ab n'est pas disponible
- Messages clairs sur les outils manquants

### 3. Endpoints Optionnels
- `benchmark_json.ps1` : Verifie si `/api/json-benchmark` existe
- `benchmark_linq_collections.ps1` : Genere placeholder si endpoint manquant
- Pas d'echec si endpoints non implementes

### 4. Resultats Structures
Tous les resultats sont sauvegardes en JSON dans `benchmarks\results\` :

```
benchmarks/results/
├── compilation_results.json       # Temps de compilation
├── package_size_results.json      # Tailles des packages
├── startup_results.json           # Temps de demarrage
├── runtime_results.json           # Performance & RAM
├── json_results.json              # JSON serialization
├── linq_collections_results.json  # LINQ & Collections
├── throughput_results.json        # Throughput multi-concurrence
└── load_test_results.json         # Test de charge progressif
```

## Metriques Mesurees

### Compilation (`benchmark_compilation.ps1`)
- Temps de restore/update des dependances
- Temps de build/compile
- Temps de publish/stage
- Temps total

### Package Size (`benchmark_package_size.ps1`)
- Taille totale du package (bytes, MB)
- Nombre de fichiers
- Taille des binaires principaux (DLL/JAR)

### Startup (`benchmark_startup.ps1`)
- Cold start (premier demarrage)
- Warm start (deuxieme demarrage)
- Hot start (troisieme demarrage)
- Moyenne des 3 demarrages

### Runtime (`benchmark_runtime.ps1`)
- Requetes par seconde (RPS)
- Temps de reponse moyen (ms)
- Requetes echouees
- Memoire au repos (idle)
- Memoire sous charge

### Throughput (`benchmark_throughput.ps1`)
Teste avec differents niveaux de concurrence :
- 1, 10, 50, 100, 200 connexions simultanees
- RPS a chaque niveau
- Latence moyenne
- Taux d'erreur

### Load Test (`benchmark_load_test.ps1`)
Test de charge progressif :
- Charge de 10 a 500 connexions simultanees
- Detection du point de rupture (breaking point)
- Taux d'erreur a chaque niveau
- Performance degradation

### JSON (`benchmark_json.ps1`)
Si endpoint disponible :
- Temps de serialisation
- Temps de deserialisation
- Taille JSON generee
- Tests avec 100, 1000, 5000, 10000 objets

## Differences avec les Scripts Bash

Les scripts PowerShell ont ete adaptes pour Windows :

| Aspect | Bash (Linux/macOS) | PowerShell (Windows) |
|--------|-------------------|---------------------|
| Redirection | `2>&1 \| Out-Null` | `*> $null` |
| Chemins | `/` | `\` |
| Mesure temps | `date +%s.%N` | `Measure-Command` |
| Processus | `ps -o rss` | `Get-Process.WorkingSet64` |
| Demarrage app | `&` background | `Start-Process -WindowStyle Hidden` |
| Arret app | `kill $PID` | `Stop-Process -Id $PID` |
| Scala script | `.sh` | `.bat` |

## Troubleshooting

### Apache Bench non trouve
Les scripts `benchmark_throughput.ps1` et `benchmark_load_test.ps1` utilisent Apache Bench pour des resultats precis.

**Solution 1** : Installer Apache Bench
```powershell
# Telecharger depuis https://www.apachelounge.com/download/
# Extraire dans C:\Apache24
# Ajouter C:\Apache24\bin au PATH
```

**Solution 2** : Utiliser wrk comme alternative
```powershell
choco install wrk -y
```

**Fallback** : Les scripts utilisent PowerShell si ab n'est pas disponible (moins precis)

### Endpoints JSON/LINQ non disponibles
Les benchmarks JSON et LINQ necessitent des endpoints specifiques.

**Option 1** : Implementer les endpoints
- Ajouter `/api/json-benchmark` dans dotnet-api et scala-play-api
- Ajouter `/api/linq-benchmark` dans dotnet-api et scala-play-api

**Option 2** : Accepter les placeholders
- Les scripts generent des resultats placeholder si endpoints manquants
- Pas d'echec, juste un avertissement

### Port deja utilise
```powershell
# Trouver le processus
netstat -ano | findstr :5000
netstat -ano | findstr :9000

# Tuer le processus
taskkill /PID <PID> /F
```

## Prochaines Etapes

### 1. Execution Immediate
Les benchmarks suivants fonctionnent immediatement :
```powershell
.\benchmarks\scripts\run_all_benchmarks.ps1
```

### 2. Optimisation (Optionnel)
Pour de meilleurs resultats :
- Installer Apache Bench
- Fermer les applications gourmandes
- Desactiver temporairement Windows Defender

### 3. Extension (Optionnel)
Pour benchmarks avances :
- Implementer `/api/json-benchmark` endpoint
- Implementer `/api/linq-benchmark` endpoint
- Relancer les benchmarks

## Commandes Rapides

```powershell
# Lancer tous les benchmarks
.\benchmarks\scripts\run_all_benchmarks.ps1

# Voir les resultats
Get-Content benchmarks\results\compilation_results.json | ConvertFrom-Json
Get-Content benchmarks\results\runtime_results.json | ConvertFrom-Json

# Lister tous les resultats
dir benchmarks\results\*.json

# Ouvrir les resultats dans notepad
notepad benchmarks\results\runtime_results.json
```

## Ressources

- [Guide Windows Complet](docs/WINDOWS_GUIDE.md)
- [Guide de Demarrage Rapide](QUICKSTART.md)
- [README Windows](README-WINDOWS.md)
- [README Principal](README.md)

---

**Note** : Tous les scripts sont prets a l'emploi. Les benchmarks de base (compilation, package size, startup, runtime, throughput, load test) fonctionnent immediatement. Les benchmarks JSON et LINQ generent des placeholders si les endpoints ne sont pas encore implementes.

**Status** : ✅ Configuration Windows Complete - Pret pour les benchmarks !
