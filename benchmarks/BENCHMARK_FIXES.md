# Corrections des Benchmarks

## Problèmes Identifiés et Résolus

### 1. Timestamps Variables Causant des Faux "Failed" ✓

**Problème**: Apache Bench comptait les requêtes comme "Failed" car chaque réponse avait un timestamp différent.

**Cause**: Les endpoints retournaient des timestamps qui changeaient à chaque requête:
- `.NET`: `{"message":"Hello from .NET!","timestamp":"2025-11-20T..."}`
- `Scala`: `{"message":"Hello from Scala Play!","timestamp":"2025-11-20T..."}`

**Solution**: Retiré les timestamps des réponses `/api/hello`:
- **dotnet-api/Program.cs:12** - Timestamp retiré
- **scala-play-api/app/controllers/ApiController.scala:13-17** - Timestamp retiré

**Résultat**: Les réponses sont maintenant identiques:
- `.NET`: `{"message":"Hello from .NET!"}`
- `Scala`: `{"message":"Hello from Scala Play!"}`

### 2. Mesure Incorrecte de la RAM pour Scala Play ✓

**Problème**: La mémoire Scala Play affichait 0 KB au lieu de la vraie utilisation.

**Cause**: Le script mesurait la mémoire du processus PowerShell wrapper au lieu du processus Java réel.

**Solution**:
1. Créé `benchmarks/scripts/common_functions.ps1` avec des fonctions pour:
   - `Start-ScalaPlayApp`: Démarre Scala Play et trouve le PID Java
   - `Stop-ScalaPlayApp`: Arrête proprement tous les processus

2. Modifié `benchmark_runtime.ps1:231-276` pour:
   - Utiliser `start-play.ps1` au lieu du fichier `.bat` défectueux
   - Trouver le processus Java enfant après démarrage
   - Mesurer la RAM du processus Java, pas du wrapper PowerShell

**Résultat**: La RAM est maintenant mesurée correctement sur le processus Java.

### 3. Scala Play ne Démarre pas avec .bat sur Windows ✓

**Problème**: Le fichier `.bat` généré par `sbt stage` échoue avec "The input line is too long"

**Cause**: Windows CMD a une limite de 8191 caractères pour les commandes, et le classpath de Scala Play dépasse cette limite.

**Solution**: Créé `scala-play-api/start-play.ps1` qui:
- Lance Java directement depuis le répertoire `target/universal/stage`
- Utilise des chemins relatifs courts pour le classpath
- Passe l'application secret via paramètre JVM

**Résultat**: Scala Play démarre correctement sur Windows.

### 4. Problème IPv6 Causant des Timeouts ✓

**Problème**: Les requêtes vers `localhost` prenaient 2+ secondes à cause du timeout IPv6.

**Cause**: Windows résout `localhost` vers `::1` (IPv6) en premier, et les applications écoutent seulement sur IPv4.

**Solution**: Tous les scripts utilisent maintenant `127.0.0.1` au lieu de `localhost`.

**Fichiers modifiés**:
- `benchmark_startup.ps1:115,151`
- Tous les autres scripts de benchmark

## Scripts Nécessitant Encore des Corrections

Les scripts suivants utilisent encore l'ancien code `.bat` et doivent être mis à jour pour utiliser `common_functions.ps1`:

- [ ] `benchmark_throughput.ps1`
- [ ] `benchmark_load_test.ps1`
- [ ] `benchmark_json.ps1`
- [x] `benchmark_runtime.ps1` - ✓ Corrigé
- [x] `benchmark_startup.ps1` - ✓ Déjà correct (utilise start-play.ps1)

## Comment Utiliser common_functions.ps1

Au début de chaque script de benchmark, ajouter:

```powershell
# Import common functions
. "$ScriptDir\common_functions.ps1"

# Démarrer Scala Play
$scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot
$SCALA_PID = $scalaInfo.PID

# ... faire les benchmarks ...

# Arrêter Scala Play
Stop-ScalaPlayApp -ProcessInfo $scalaInfo
```

## Résultats Attendus Après Corrections

Avec toutes les corrections appliquées:

1. **Failed requests** devrait être à **0** pour les endpoints simples
2. **Utilisation RAM Scala Play** devrait afficher ~100-200 MB (dépend de la charge)
3. **Démarrage Scala Play** devrait fonctionner sur Windows
4. **Benchmarks** devraient s'exécuter sans erreurs

## Applications Doivent Être Rebuild

Pour que les changements de code prennent effet:

```powershell
# .NET
cd dotnet-api
dotnet publish -c Release -o .\publish

# Scala Play
cd scala-play-api
cmd /c sbt stage
```

Ou laissez les scripts de benchmark les rebuilder automatiquement.
