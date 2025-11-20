# Scripts de Benchmark à Mettre à Jour

## Scripts Déjà Corrigés ✓

1. **benchmark_runtime.ps1** - ✓ Utilise `common_functions.ps1`
2. **benchmark_startup.ps1** - ✓ Utilise `start-play.ps1` directement
3. **benchmark_linq_collections.ps1** - ✓ Utilise `common_functions.ps1`
4. **benchmark_json.ps1** - ✓ Vient d'être corrigé

## Scripts Restants à Corriger

### 1. benchmark_throughput.ps1

**Changements nécessaires:**
- Ajouter `# Import common functions` et `. "$ScriptDir\common_functions.ps1"` après la ligne 9
- Remplacer le code de démarrage Scala Play (lignes ~172-178) par:
  ```powershell
  $scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot
  $SCALA_PID = $scalaInfo.PID
  ```
- Remplacer `Stop-Process -Id $SCALA_PID` par:
  ```powershell
  Stop-ScalaPlayApp -ProcessInfo $scalaInfo
  ```

### 2. benchmark_load_test.ps1

**Changements nécessaires:**
- Ajouter `# Import common functions` et `. "$ScriptDir\common_functions.ps1"` après la ligne 9
- Remplacer le code de démarrage Scala Play par:
  ```powershell
  $scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot
  $SCALA_PID = $scalaInfo.PID
  ```
- Remplacer tous les `Stop-Process -Id $SCALA_PID` par:
  ```powershell
  Stop-ScalaPlayApp -ProcessInfo $scalaInfo
  ```

## Problème de RAM dans benchmark_runtime.ps1

Le script `benchmark_runtime.ps1` a déjà été mis à jour pour utiliser `common_functions.ps1`, mais il y a toujours 0 MB pour Scala Play.

**Cause**: Le script ne rebuild pas Scala Play après les changements, donc il utilise encore l'ancien `.bat` qui ne fonctionne pas.

**Solution**: Forcer le rebuild de Scala Play:
```powershell
cd scala-play-api
Remove-Item -Recurse -Force .\target\universal\stage -ErrorAction SilentlyContinue
cmd /c sbt stage
```

Ou laisser le script le faire automatiquement lors de la prochaine exécution.

## Pattern de Remplacement

Pour tous les scripts, chercher:

```powershell
# OLD CODE
$scalaStartScript = Get-ChildItem -Path ".\target\universal\stage\bin" -Filter "*.bat" | Select-Object -First 1
if (-not $scalaStartScript) {
    throw "Scala Play start script not found"
}
$scalaProcess = Start-Process -FilePath $scalaStartScript.FullName -PassThru -WindowStyle Hidden
$SCALA_PID = $scalaProcess.Id
```

Remplacer par:

```powershell
# NEW CODE
$scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot
$SCALA_PID = $scalaInfo.PID
```

Et chercher:

```powershell
# OLD CODE
Stop-Process -Id $SCALA_PID -Force -ErrorAction SilentlyContinue
```

Remplacer par:

```powershell
# NEW CODE
Stop-ScalaPlayApp -ProcessInfo $scalaInfo
```

## Vérification Rapide

Pour vérifier quels scripts utilisent encore l'ancien code:

```powershell
cd benchmarks\scripts
Select-String -Pattern "\.bat" -Path *.ps1 | Select-Object Filename, LineNumber, Line
```

Ceux qui affichent des résultats doivent être mis à jour.
