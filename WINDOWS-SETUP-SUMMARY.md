# Resume : Support Complet Windows ✅

Tout est maintenant pret pour executer les benchmarks sur Windows !

## Ce qui a ete cree

### 1. Script d'Installation Automatique 🚀
**Fichier** : `install-windows-tools.ps1`

Ce script installe automatiquement tous les outils necessaires :
- Chocolatey (gestionnaire de paquets)
- .NET 10 SDK
- Java (OpenJDK 17)
- SBT (Scala Build Tool)
- jq (traitement JSON)
- Git

**Comment l'utiliser** :
```powershell
# Ouvrir PowerShell en tant qu'Administrateur
.\install-windows-tools.ps1
```

### 2. Scripts PowerShell de Benchmark 📊

Tous les scripts bash ont ete convertis en PowerShell :

| Script | Description | Duree |
|--------|-------------|-------|
| `benchmark_compilation.ps1` | Temps de compilation .NET vs Scala | 5-10 min |
| `benchmark_package_size.ps1` | Taille des packages | 2-5 min |
| `benchmark_startup.ps1` | Temps de demarrage (cold/warm/hot) | 5-10 min |
| `benchmark_runtime.ps1` | Performance et utilisation RAM | 10-15 min |
| `run_all_benchmarks.ps1` | **Lance tous les benchmarks** | 30-45 min |

**Comment les utiliser** :
```powershell
# Lance tous les benchmarks
.\benchmarks\scripts\run_all_benchmarks.ps1

# OU individuellement
.\benchmarks\scripts\benchmark_compilation.ps1
.\benchmarks\scripts\benchmark_package_size.ps1
.\benchmarks\scripts\benchmark_startup.ps1
.\benchmarks\scripts\benchmark_runtime.ps1
```

### 3. Documentation Complete 📚

| Document | Description |
|----------|-------------|
| `docs/WINDOWS_GUIDE.md` | Guide complet Windows avec troubleshooting |
| `README-WINDOWS.md` | Guide de demarrage rapide pour Windows |
| `README.md` | Mis a jour avec instructions Windows |
| `QUICKSTART.md` | Mis a jour avec instructions Windows |

## Demarrage Rapide

### Etape 1 : Installation (5-10 minutes)

```powershell
# Ouvrir PowerShell en tant qu'Administrateur
.\install-windows-tools.ps1
```

### Etape 2 : Fermer et Rouvrir PowerShell

C'est important pour recharger les variables d'environnement !

### Etape 3 : Lancer les Benchmarks (30-45 minutes)

```powershell
# Ouvrir une nouvelle fenetre PowerShell (pas besoin d'admin)
cd C:\Users\dyl_c\IdeaProjects\temp
.\benchmarks\scripts\run_all_benchmarks.ps1
```

### Etape 4 : Voir les Resultats

```powershell
# Lire le rapport
Get-Content benchmarks\results\comprehensive_report.md

# OU ouvrir dans notepad
notepad benchmarks\results\comprehensive_report.md
```

## Fonctionnalites des Scripts PowerShell

### Gestion Automatique des Erreurs
- Les scripts detectent si les applications sont deja compilees
- Compilation automatique si necessaire
- Nettoyage automatique avant les tests

### Fallback Intelligent
- Si Apache Bench (ab) n'est pas installe, les scripts utilisent PowerShell comme fallback
- Performance moins precise mais fonctionnel

### Mesures Precises
- Temps de compilation
- Taille des packages
- Temps de demarrage (3 iterations : cold, warm, hot)
- Performance (requetes/seconde, latence)
- Utilisation memoire (idle et sous charge)

## Tests Manuels

### Tester .NET

```powershell
# Terminal 1
cd dotnet-api
dotnet run

# Terminal 2
curl http://localhost:5000/api/hello
curl http://localhost:5000/api/echo/test
```

### Tester Scala Play

```powershell
# Terminal 1
cd scala-play-api
sbt run

# Terminal 2
curl http://localhost:9000/api/hello
curl http://localhost:9000/api/echo/test
```

## Troubleshooting Rapide

### "Scripts desactives sur ce systeme"
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Port deja utilise
```powershell
# Trouver le processus
netstat -ano | findstr :5000

# Tuer le processus
taskkill /PID <PID> /F
```

### .NET ou SBT non trouve
Fermez et rouvrez PowerShell pour recharger le PATH.

## Structure des Resultats

Apres l'execution des benchmarks :

```
benchmarks/results/
├── compilation_results.json       # Temps de compilation detailles
├── package_size_results.json      # Tailles des packages
├── startup_results.json           # Temps de demarrage
├── runtime_results.json           # Performance et RAM
└── comprehensive_report.md        # Rapport complet (si genere)
```

## Differences avec Linux/macOS

Les scripts PowerShell ont ete adaptes pour Windows :
- Utilisation de `Get-Process` au lieu de `ps`
- Chemins avec backslash (`\`) au lieu de slash (`/`)
- `Start-Process` pour lancer les applications en arriere-plan
- `Stop-Process` pour arreter les processus
- Mesure de memoire via `WorkingSet64` au lieu de RSS
- Gestion des fichiers `.bat` pour Scala Play (au lieu de scripts shell)

## Prochaines Etapes

1. **Installer les outils** : `.\install-windows-tools.ps1`
2. **Rouvrir PowerShell** pour recharger PATH
3. **Lancer les benchmarks** : `.\benchmarks\scripts\run_all_benchmarks.ps1`
4. **Analyser les resultats** dans `benchmarks\results\`

## Ressources

- [Guide Windows Complet](docs/WINDOWS_GUIDE.md)
- [Guide de Demarrage Rapide](QUICKSTART.md)
- [README Principal](README.md)
- [README Windows](README-WINDOWS.md)

---

**Note** : Tous les scripts sont fonctionnels et prets a l'emploi.
Pour Apache Bench, les scripts incluent un fallback PowerShell si `ab` n'est pas installe.
