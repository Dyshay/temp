# Guide des Tests de Throughput (Req/Sec)

Ce guide explique comment utiliser la suite de benchmarks de throughput pour mesurer les performances en requêtes par seconde (req/sec) de .NET vs Scala Play.

## Vue d'Ensemble

La suite de tests de throughput comprend trois composants principaux :

1. **Test Multi-Concurrence** : Mesure les performances à différents niveaux de charge
2. **Test de Charge Progressive** : Trouve le point de rupture et la charge maximale soutenable
3. **Analyse Détaillée** : Génère un rapport complet avec recommandations

## Scripts Disponibles

### 1. Suite Complète de Throughput

Pour exécuter tous les tests de throughput :

```bash
./benchmarks/scripts/run_throughput_suite.sh
```

**Durée** : 20-30 minutes
**Résultats** :
- `throughput_results.json` : Résultats détaillés par concurrence
- `load_test_results.json` : Résultats du test de charge progressive
- `throughput_analysis.md` : Rapport d'analyse complet

### 2. Tests Individuels

#### Test Multi-Concurrence

```bash
./benchmarks/scripts/benchmark_throughput.sh
```

Teste avec les niveaux de concurrence : **1, 10, 50, 100, 200**

**Endpoints testés** :
- `/api/hello` : Requête simple GET
- `/api/echo/benchmark` : GET avec paramètre
- `/api/compute/1000` : Calcul CPU léger
- `/api/compute/10000` : Calcul CPU intensif

**Métriques mesurées** :
- Requêtes par seconde (RPS)
- Latence moyenne
- Latence percentiles (P50, P75, P90, P95, P99)
- Taux d'échec
- Taux de transfert

#### Test de Charge Progressive

```bash
./benchmarks/scripts/benchmark_load_test.sh
```

Augmente progressivement la charge par paliers de **50 connexions** jusqu'à **500** ou jusqu'à ce que le taux d'erreur dépasse **5%**.

**Chaque palier** :
- Durée : 10 secondes
- Métriques : RPS, requêtes complétées, échecs, taux d'erreur

**Objectif** : Déterminer la capacité maximale soutenable

#### Analyse des Résultats

```bash
./benchmarks/scripts/analyze_throughput.sh
```

Génère un rapport Markdown détaillé avec :
- Comparaisons tabulaires
- Analyse des latences
- Performance par endpoint
- Recommandations

## Interprétation des Résultats

### Requêtes Par Seconde (RPS)

Plus le nombre est élevé, mieux c'est. C'est la métrique principale de throughput.

**Exemple de sortie** :
```
.NET Peak Throughput: 45000 req/sec
Scala Play Peak Throughput: 38000 req/sec
```

### Latence

La latence mesure le temps de réponse. Plus elle est basse, mieux c'est.

**Métriques importantes** :
- **P50 (médiane)** : 50% des requêtes sont plus rapides
- **P95** : 95% des requêtes sont plus rapides (important pour SLA)
- **P99** : 99% des requêtes sont plus rapides (cas extrêmes)

**Exemple** :
```
P50: 2ms    → Très bon
P95: 15ms   → Acceptable
P99: 45ms   → À surveiller
```

### Taux d'Erreur

Pourcentage de requêtes échouées. Devrait être **< 1%** en conditions normales.

Si > 5%, le système est surchargé.

### Charge Maximale Soutenable

C'est le RPS maximum maintenu avec un taux d'erreur < 1%.

**Exemple** :
```
.NET : 42000 req/sec à 150 connexions concurrentes
Scala : 36000 req/sec à 200 connexions concurrentes
```

## Configuration Avancée

### Modifier les Niveaux de Concurrence

Éditez `benchmark_throughput.sh` :

```bash
# Ligne 16
CONCURRENCY_LEVELS=(1 10 50 100 200 500 1000)
```

### Modifier la Durée des Tests

Éditez `benchmark_load_test.sh` :

```bash
# Ligne 13
DURATION_PER_STEP=30  # 30 secondes par palier
```

### Modifier le Nombre de Requêtes

Éditez `benchmark_throughput.sh` :

```bash
# Ligne 17
REQUESTS_PER_TEST=50000  # Plus de requêtes = plus précis
```

### Ajouter des Endpoints

Éditez `benchmark_throughput.sh`, section des endpoints :

```bash
declare -A ENDPOINTS
ENDPOINTS=(
    ["hello"]="/api/hello"
    ["echo"]="/api/echo/benchmark"
    ["compute_light"]="/api/compute/1000"
    ["compute_heavy"]="/api/compute/10000"
    ["custom"]="/api/mon-endpoint"  # Ajoutez ici
)
```

## Bonnes Pratiques

### 1. Environnement de Test

**Recommandations** :
- Testez sur une machine dédiée (pas de développement en parallèle)
- Fermez les applications inutiles
- Utilisez une connexion réseau stable
- Préférez un environnement Linux pour de meilleurs résultats

### 2. Interprétation

**Facteurs à considérer** :
- Les résultats varient selon le hardware
- Le premier test peut être plus lent (JIT compilation)
- Les résultats absolus comptent moins que les comparaisons relatives
- Testez plusieurs fois pour vérifier la cohérence

### 3. Optimisation

**Si les performances ne sont pas satisfaisantes** :

**.NET** :
```bash
# Augmenter les threads du pool
export DOTNET_ThreadPool_MinThreads=100
export DOTNET_ThreadPool_MaxThreads=500
```

**Scala Play** :
```conf
# application.conf
play.server.akka {
  default-dispatcher {
    fork-join-executor {
      parallelism-min = 8
      parallelism-max = 64
    }
  }
}
```

### 4. Validation

**Vérifiez que** :
- Les applications répondent correctement : `curl http://localhost:5000/api/hello`
- Pas d'erreurs dans les logs
- La mémoire ne sature pas
- Le CPU n'est pas à 100% en permanence

## Analyse du Rapport

Le rapport `throughput_analysis.md` contient :

### Section 1 : Configuration
Les paramètres utilisés pour les tests

### Section 2 : Comparaison des Pics
Tableau comparatif du throughput maximal

### Section 3 : Résultats par Endpoint
Détails pour chaque endpoint testé :
- Performance à chaque niveau de concurrence
- Évolution de la latence

### Section 4 : Test de Charge Progressive
Comment le système se comporte sous charge croissante :
- Point de rupture
- Capacité maximale

### Section 5 : Recommandations
Suggestions basées sur les résultats

## Exemples de Scénarios

### Scénario 1 : API REST Simple

**Objectif** : Comparer les performances pour un CRUD simple

**Commande** :
```bash
./benchmarks/scripts/benchmark_throughput.sh
```

**À regarder** :
- RPS sur l'endpoint `hello`
- Latence P95 à 100 connexions

### Scénario 2 : Calcul Intensif

**Objectif** : Voir quelle plateforme gère mieux le CPU

**À regarder** :
- RPS sur `compute_heavy`
- Différence entre `compute_light` et `compute_heavy`

### Scénario 3 : Trouver la Limite

**Objectif** : Déterminer la capacité maximale

**Commande** :
```bash
./benchmarks/scripts/benchmark_load_test.sh
```

**À regarder** :
- Peak sustainable RPS
- Concurrence optimale
- Quand le taux d'erreur commence à monter

### Scénario 4 : Comparaison Complète

**Objectif** : Rapport exhaustif

**Commande** :
```bash
./benchmarks/scripts/run_throughput_suite.sh
```

**Résultat** : Rapport complet avec tous les scénarios

## Dépannage

### Problème : RPS très bas

**Causes possibles** :
- Applications non optimisées (mode Debug au lieu de Release)
- Ressources système limitées
- Throttling réseau

**Solution** :
```bash
# Vérifier le build
cd dotnet-api
dotnet build -c Release

# Vérifier les ressources
htop  # CPU/RAM disponibles
```

### Problème : Taux d'erreur élevé

**Causes** :
- Charge trop élevée pour le système
- Timeouts trop courts
- Limites de fichiers ouverts

**Solution** :
```bash
# Augmenter les limites
ulimit -n 10000

# Réduire la concurrence dans les tests
```

### Problème : Résultats incohérents

**Causes** :
- Garbage collection JVM
- Manque de warmup
- Autres processus en arrière-plan

**Solution** :
```bash
# Augmenter le warmup
# Dans benchmark_throughput.sh, ligne 18
WARMUP_REQUESTS=1000  # au lieu de 500
```

### Problème : Applications qui crashent

**Causes** :
- Mémoire insuffisante
- Trop de connexions
- Stack overflow

**Solution** :
```bash
# Augmenter la mémoire JVM pour Scala
export JAVA_OPTS="-Xmx4g -Xms2g"

# Pour .NET, vérifier les logs
```

## Comparaison avec Production

**Important** : Les résultats de benchmark ne reflètent pas toujours la production.

**Facteurs de production** :
- Base de données
- Latence réseau
- Authentification
- Logging
- Monitoring
- Cache

**Recommandation** : Utilisez ces benchmarks pour des **comparaisons relatives** entre .NET et Scala Play, pas pour des prédictions absolues de production.

## Ressources

- [Apache Bench Documentation](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [.NET Performance Tips](https://docs.microsoft.com/en-us/aspnet/core/performance/performance-best-practices)
- [Play Framework Performance](https://www.playframework.com/documentation/latest/ThreadPools)
- [Understanding Latency Percentiles](https://www.elastic.co/blog/averages-can-dangerous-use-percentile)

---

*Pour des questions ou des améliorations, consultez le README principal.*
