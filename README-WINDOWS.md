# Démarrage Rapide Windows 💻

Ce document vous guide pour exécuter tous les benchmarks sur Windows.

## Installation en 2 Minutes ⚡

### 1. Installer les Outils (Automatique)

Ouvrez **PowerShell en tant qu'Administrateur** :

```powershell
# Depuis la racine du projet
.\install-windows-tools.ps1
```

Ce script installe automatiquement :
- ✓ Chocolatey (gestionnaire de paquets)
- ✓ .NET 10 SDK
- ✓ Java (OpenJDK 17)
- ✓ SBT (Scala Build Tool)
- ✓ jq (traitement JSON)
- ✓ Git

⏱️ **Durée** : 5-10 minutes

### 2. Lancer les Benchmarks

Fermez et **rouvrez une nouvelle fenêtre PowerShell** (pas besoin d'admin), puis :

```powershell
# Lancer tous les benchmarks
.\benchmarks\scripts\run_all_benchmarks.ps1
```

⏱️ **Durée** : 30-45 minutes

## Voir les Résultats

```powershell
# Lire le rapport complet
Get-Content benchmarks\results\comprehensive_report.md

# OU ouvrir dans notepad
notepad benchmarks\results\comprehensive_report.md

# OU ouvrir dans VS Code
code benchmarks\results\comprehensive_report.md
```

## Benchmarks Individuels

Vous pouvez aussi exécuter les benchmarks séparément :

```powershell
# Compilation uniquement (5-10 min)
.\benchmarks\scripts\benchmark_compilation.ps1

# Taille des packages (2-5 min)
.\benchmarks\scripts\benchmark_package_size.ps1

# Temps de démarrage (5-10 min)
.\benchmarks\scripts\benchmark_startup.ps1

# Performance runtime (10-15 min)
.\benchmarks\scripts\benchmark_runtime.ps1
```

## Tester les Applications Manuellement

### .NET API

Terminal 1 :
```powershell
cd dotnet-api
dotnet run
```

Terminal 2 :
```powershell
# Test simple
curl http://localhost:5000/api/hello

# Test POST avec JSON
curl -X POST http://localhost:5000/api/data `
  -H "Content-Type: application/json" `
  -d '{"name":"test","value":123}'
```

### Scala Play API

Terminal 1 :
```powershell
cd scala-play-api
sbt run
```

Terminal 2 :
```powershell
# Test simple
curl http://localhost:9000/api/hello

# Test POST avec JSON
curl -X POST http://localhost:9000/api/data `
  -H "Content-Type: application/json" `
  -d '{"name":"test","value":123}'
```

## Problèmes Courants

### "Scripts désactivés sur ce système"

```powershell
# Ouvrir PowerShell en Administrateur
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Port déjà utilisé

```powershell
# Trouver le processus sur le port 5000
netstat -ano | findstr :5000

# Tuer le processus (remplacer PID)
taskkill /PID <PID> /F
```

### Erreur .NET ou SBT non trouvé

Fermez et rouvrez PowerShell pour recharger le PATH.

## Documentation Complète

Pour plus de détails :
- 📘 [Guide Windows complet](docs/WINDOWS_GUIDE.md)
- 📘 [Guide de démarrage rapide](QUICKSTART.md)
- 📘 [README principal](README.md)

## Structure des Résultats

Après les benchmarks, vous trouverez dans `benchmarks\results\` :

```
benchmarks\results\
├── compilation_results.json       # Temps de compilation
├── package_size_results.json      # Tailles des packages
├── startup_results.json           # Temps de démarrage
├── runtime_results.json           # Performance et RAM
└── comprehensive_report.md        # Rapport complet
```

## Support

- Questions ? Consultez [docs/WINDOWS_GUIDE.md](docs/WINDOWS_GUIDE.md)
- Problèmes ? Vérifiez la section Troubleshooting dans le guide Windows

---

**Conseil** : Pour de meilleurs résultats de benchmarking, fermez les applications gourmandes (navigateurs, IDEs) avant de lancer les tests.
