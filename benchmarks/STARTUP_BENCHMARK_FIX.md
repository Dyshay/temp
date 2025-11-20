# Startup Benchmark - Fix Applied

## Problème Résolu

Le benchmark de startup time tournait dans le vide car les ports 5000 et 9000 étaient bloqués par des processus résiduels (dotnet/java) de tests précédents.

## Solution Implémentée

Le script `benchmark_startup.ps1` a été modifié pour **nettoyer automatiquement** les processus et ports **AVANT** de commencer les tests.

### Modifications Apportées

1. **Vérification des privilèges** (ligne 17-28)
   - Détecte si le script est exécuté en tant qu'Administrateur
   - Affiche un avertissement si les privilèges sont insuffisants

2. **Fonction de nettoyage par nom** (ligne 30-48)
   - `Stop-ProcessByName`: Tue tous les processus dotnet et java
   - Utilisée pour un nettoyage complet avant les tests

3. **Nettoyage initial automatique** (ligne 162-192)
   - Tue tous les processus dotnet et java existants
   - Vérifie que les ports 5000 et 9000 sont libres
   - Affiche des messages clairs en cas de problème
   - **Échoue explicitement** si les ports ne peuvent pas être libérés

4. **Nettoyage avant chaque test**
   - Chaque fonction `Test-DotNetStartup` et `Test-ScalaStartup` nettoie son port avant de démarrer
   - Nettoyage également après chaque test pour éviter les conflits

## Comment Utiliser

### Option 1: Exécuter directement (recommandé)

Ouvrez PowerShell **en tant qu'Administrateur** et exécutez:

```powershell
cd C:\Users\dyl_c\IdeaProjects\temp\benchmarks\scripts
.\benchmark_startup.ps1
```

### Option 2: Via le script complet

```powershell
# En tant qu'Administrateur
cd C:\Users\dyl_c\IdeaProjects\temp\benchmarks\scripts
.\run_all_benchmarks.ps1
```

Le script `run_all_benchmarks.ps1` affiche maintenant un message avant Step 3/8 expliquant que des privilèges administrateur sont nécessaires.

## Messages d'Erreur Possibles

### "ERROR: Cannot free port 5000. Please run as Administrator."

**Cause**: Le script ne peut pas tuer les processus bloquant les ports sans droits administrateur.

**Solution**:
1. Fermez PowerShell
2. Ouvrez PowerShell en tant qu'Administrateur (Windows + X → "Terminal (Admin)")
3. Re-exécutez le script

### "WARNING: Not running as Administrator"

**Impact**: Le script va essayer de nettoyer les ports, mais pourrait échouer si des processus protégés les utilisent.

**Solution préventive**: Exécutez toujours les benchmarks en tant qu'Administrateur.

## Avantages de Cette Approche

1. **Autonome**: Le benchmark nettoie automatiquement avant de commencer
2. **Détection précoce**: Vérifie et signale les problèmes immédiatement
3. **Messages clairs**: Indique exactement quel est le problème et comment le résoudre
4. **Robuste**: Nettoie à plusieurs niveaux (par nom de processus ET par port)
5. **Pas de script séparé**: Plus besoin d'exécuter un script de nettoyage manuel

## Fichiers Modifiés

- `benchmarks/scripts/benchmark_startup.ps1` - Nettoyage automatique intégré
- `benchmarks/scripts/run_all_benchmarks.ps1` - Message d'information ajouté

## Fichiers Utilitaires Créés (optionnels)

- `benchmarks/scripts/kill_ports.ps1` - Script manuel pour nettoyer les ports
- `fix_and_run_benchmark.ps1` - Script alternatif à la racine du projet

Ces fichiers ne sont plus nécessaires mais peuvent être utiles pour un nettoyage manuel si besoin.
