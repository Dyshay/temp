# .NET vs Scala Play - Comparative Benchmark Suite

Ce projet compare les performances entre **.NET 8.0** et **Scala 2.13 avec Play Framework** à travers plusieurs dimensions :

- ⏱️ **Temps de compilation**
- 📦 **Taille des packages**
- 🚀 **Performance d'exécution** (requêtes par seconde, latence)
- 💾 **Utilisation de la RAM**

## Structure du Projet

```
.
├── dotnet-api/              # Application .NET Web API
│   ├── DotNetApi.csproj     # Configuration du projet
│   ├── Program.cs           # Point d'entrée et définition des endpoints
│   ├── appsettings.json     # Configuration de l'application
│   └── Dockerfile           # Image Docker pour .NET
│
├── scala-play-api/          # Application Scala Play Framework
│   ├── build.sbt            # Configuration SBT
│   ├── project/             # Configuration du build
│   ├── conf/                # Configuration et routes
│   │   ├── application.conf
│   │   └── routes
│   ├── app/                 # Code source
│   │   ├── controllers/
│   │   └── models/
│   └── Dockerfile           # Image Docker pour Scala Play
│
├── benchmarks/              # Scripts de benchmark
│   ├── scripts/             # Scripts de test
│   │   ├── benchmark_compilation.sh    # Test de temps de compilation
│   │   ├── benchmark_package_size.sh   # Test de taille des packages
│   │   ├── benchmark_runtime.sh        # Test de performance runtime
│   │   ├── generate_report.sh          # Génération du rapport
│   │   └── run_all_benchmarks.sh       # Script principal
│   └── results/             # Résultats des benchmarks (généré)
│
└── docs/                    # Documentation supplémentaire
```

## Endpoints Implémentés

Les deux applications implémentent les mêmes endpoints pour assurer une comparaison équitable :

### 1. Hello Endpoint
**GET** `/api/hello`
- Retourne un message simple avec timestamp
- Test de base pour les performances

### 2. Echo Endpoint
**GET** `/api/echo/{text}`
- Retourne le texte fourni avec sa longueur
- Test avec paramètre d'URL

### 3. Data Endpoint
**POST** `/api/data`
```json
{
  "name": "test",
  "value": 123
}
```
- Test avec JSON body
- Retourne une réponse structurée avec ID généré

### 4. Compute Endpoint
**GET** `/api/compute/{iterations}`
- Effectue un calcul CPU-intensif
- Test de performance sous charge CPU

### 5. Memory Endpoint
**GET** `/api/memory/{sizeMb}`
- Alloue de la mémoire
- Test de gestion de la RAM

## Prérequis

### Pour exécuter les applications localement :

#### .NET
```bash
# Installer .NET 8.0 SDK
# https://dotnet.microsoft.com/download/dotnet/8.0
```

#### Scala Play
```bash
# Installer SBT (Scala Build Tool)
# https://www.scala-sbt.org/download.html

# Ou sur Ubuntu/Debian:
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
sudo apt-get update
sudo apt-get install sbt
```

### Pour exécuter les benchmarks :

```bash
# Outils requis
sudo apt-get install -y \
    apache2-utils \  # Pour 'ab' (Apache Bench)
    bc \             # Pour les calculs
    jq \             # Pour le traitement JSON
    curl             # Pour les tests de connectivité
```

## Utilisation

### 1. Exécuter les applications individuellement

#### .NET
```bash
cd dotnet-api
dotnet restore
dotnet run
# L'application démarre sur http://localhost:5000
```

#### Scala Play
```bash
cd scala-play-api
sbt run
# L'application démarre sur http://localhost:9000
```

### 2. Exécuter tous les benchmarks

```bash
# Depuis la racine du projet
./benchmarks/scripts/run_all_benchmarks.sh
```

Ce script va :
1. Compiler les deux applications
2. Mesurer les temps de compilation
3. Mesurer les tailles des packages
4. Démarrer chaque application et mesurer les performances
5. Générer un rapport complet

**Durée estimée :** 15-30 minutes

### 3. Exécuter des benchmarks individuels

#### Test de compilation uniquement
```bash
./benchmarks/scripts/benchmark_compilation.sh
```

#### Test de taille de package uniquement
```bash
./benchmarks/scripts/benchmark_package_size.sh
```

#### Test de performance runtime uniquement
```bash
./benchmarks/scripts/benchmark_runtime.sh
```

## Résultats

Après l'exécution des benchmarks, les résultats sont disponibles dans `benchmarks/results/` :

- **compilation_results.json** - Temps de compilation détaillés
- **package_size_results.json** - Tailles des packages
- **runtime_results.json** - Performance d'exécution et RAM
- **comprehensive_report.json** - Tous les résultats combinés
- **comprehensive_report.md** - Rapport lisible en Markdown

### Exemple de rapport

Le rapport comprend :

#### Résumé Exécutif
- Comparaison rapide des temps de compilation
- Comparaison des tailles de packages
- Comparaison des performances (req/s)
- Comparaison de l'utilisation mémoire

#### Résultats Détaillés
- Tables comparatives pour chaque métrique
- Résultats par endpoint
- Statistiques de performance sous charge

#### Conclusion
- Analyse des points forts de chaque technologie
- Recommandations basées sur les cas d'usage

## Configuration des Benchmarks

Les paramètres de test peuvent être modifiés dans `benchmarks/scripts/benchmark_runtime.sh` :

```bash
WARMUP_REQUESTS=100      # Requêtes de warmup
BENCH_REQUESTS=1000      # Requêtes de benchmark
CONCURRENCY=10           # Connexions simultanées
WARMUP_TIME=5            # Temps de warmup (secondes)
```

## Utilisation avec Docker

### Construire les images

```bash
# .NET
cd dotnet-api
docker build -t dotnet-benchmark .

# Scala Play
cd scala-play-api
docker build -t scala-play-benchmark .
```

### Exécuter les conteneurs

```bash
# .NET
docker run -p 5000:5000 dotnet-benchmark

# Scala Play
docker run -p 9000:9000 scala-play-benchmark
```

## Métriques Mesurées

### 1. Temps de Compilation
- **Restore/Update** : Téléchargement des dépendances
- **Build/Compile** : Compilation du code source
- **Publish/Stage** : Packaging de l'application
- **Total** : Temps total de build

### 2. Taille des Packages
- **Taille totale** : Taille du package déployable
- **Nombre de fichiers** : Nombre de fichiers dans le package
- **Taille des binaires principaux** : DLL/.NET ou JAR/Scala

### 3. Performance Runtime
- **Requests per Second (RPS)** : Débit
- **Mean Time** : Temps de réponse moyen
- **Failed Requests** : Nombre d'échecs

### 4. Utilisation Mémoire
- **Memory Idle** : RAM au repos
- **Memory Under Load** : RAM sous charge

## Points de Comparaison

### .NET
**Avantages :**
- Compilation généralement plus rapide
- Packages souvent plus petits
- Excellente performance native
- Écosystème mature pour Windows

**Considérations :**
- Principalement orienté Microsoft/Windows
- Moins de paradigmes fonctionnels natifs

### Scala Play
**Avantages :**
- Programmation fonctionnelle puissante
- Accès à l'écosystème JVM
- Type-safety avancée
- Excellent pour les applications réactives

**Considérations :**
- Compilation peut être plus lente
- Packages JVM potentiellement plus volumineux
- Courbe d'apprentissage plus élevée

## Tests Manuels

Vous pouvez tester les endpoints manuellement avec curl :

```bash
# Test simple
curl http://localhost:5000/api/hello  # .NET
curl http://localhost:9000/api/hello  # Scala Play

# Test avec paramètre
curl http://localhost:5000/api/echo/test

# Test POST avec JSON
curl -X POST http://localhost:5000/api/data \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":123}'

# Test compute
curl http://localhost:5000/api/compute/10000

# Test memory (alloue 10MB)
curl http://localhost:5000/api/memory/10
```

## Contribution

Pour ajouter de nouveaux benchmarks ou améliorer les existants :

1. Ajoutez de nouveaux endpoints dans les deux applications
2. Créez un nouveau script de benchmark dans `benchmarks/scripts/`
3. Mettez à jour `run_all_benchmarks.sh` pour inclure votre test
4. Mettez à jour `generate_report.sh` pour inclure vos résultats

## Troubleshooting

### Port déjà utilisé
```bash
# Vérifier les processus sur le port
lsof -i :5000
lsof -i :9000

# Tuer le processus si nécessaire
kill -9 <PID>
```

### Erreur de permission
```bash
# Rendre les scripts exécutables
chmod +x benchmarks/scripts/*.sh
```

### Manque de dépendances
```bash
# Installer toutes les dépendances nécessaires
sudo apt-get update
sudo apt-get install -y apache2-utils bc jq curl
```

### Erreur de compilation Scala
```bash
# Nettoyer le cache SBT
cd scala-play-api
sbt clean
rm -rf target project/target
```

## Licence

Ce projet est fourni à des fins éducatives et de comparaison.

## Ressources

- [Documentation .NET](https://docs.microsoft.com/dotnet/)
- [Documentation Play Framework](https://www.playframework.com/documentation)
- [Apache Bench Guide](https://httpd.apache.org/docs/2.4/programs/ab.html)
