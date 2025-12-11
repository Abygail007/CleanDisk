# 📁 Structure des Logs CleanDisk

## 📂 Organisation

```
Logs/
├── Sessions/           ← Rapports par session (HTML)
├── Clients/            ← Historiques compiles par client (HTML)
├── Certificats/        ← Certificats pour clients (PDF + HTML)
├── Dashboard_CleanDisk.html  ← Dashboard global
└── CleanDiskAudit_*.xml      ← Audits XML bruts
```

---

## 1️⃣ Sessions/

**Contenu** : Rapports HTML de chaque session d'effacement

**Format fichier** : `Rapport_Interne_NOMCLIENT_20241204_143000.html`

**Usage** : Suivi interne detaille de chaque session

**Genere** : Automatiquement apres chaque effacement

**Exemple** :
```
Sessions/
├── Rapport_Interne_ACME_20241204_143000.html
├── Rapport_Interne_ACME_20241202_101500.html
├── Rapport_Interne_BETA_20241201_153000.html
```

---

## 2️⃣ Clients/

**Contenu** : Historiques compiles par client

**Format fichier** : `Historique_NOMCLIENT.html`

**Usage** : Vision complete de tous les effacements d'un client

**Genere** : Automatiquement mis a jour apres chaque session

**Cumulative** : Oui - compile TOUTES les sessions du client

**Exemple** :
```
Clients/
├── Historique_ACME_Corp.html       (contient 5 sessions)
├── Historique_BETA_Industries.html (contient 3 sessions)
├── Historique_Gamma_Solutions.html (contient 2 sessions)
```

**Contenu fichier** :
- Stats globales (total disques, dates premiere/derniere session)
- Liste toutes les sessions
- Details complets de chaque session

---

## 3️⃣ Certificats/

**Contenu** : Certificats officiels pour clients (PDF + HTML fallback)

**Format fichier** : 
- `Certificat_NOMCLIENT_20241204_143000.pdf` (si wkhtmltopdf disponible)
- `Certificat_NOMCLIENT_20241204_143000.html` (fallback)

**Usage** : A remettre au client comme preuve d'effacement

**Genere** : Automatiquement apres chaque session

**Format** : Template LOGICIA officiel

**Contenu** :
- Logo LOGICIA
- Adresse LOGICIA
- Nom client
- Date effacement
- Liste numeros de serie
- Mention ANSSI

**Exemple** :
```
Certificats/
├── Certificat_ACME_Corp_20241204_143000.pdf
├── Certificat_ACME_Corp_20241202_101500.pdf
├── Certificat_BETA_Industries_20241201_153000.pdf
```

---

## 4️⃣ Dashboard_CleanDisk.html

**Contenu** : Tableau de bord global avec statistiques

**Format fichier** : `Dashboard_CleanDisk.html` (fichier unique)

**Usage** : Vision d'ensemble de TOUTE l'activite

**Genere** : Automatiquement mis a jour apres chaque session

**Stats incluses** :
- Nombre total disques effaces
- Nombre clients traites
- Temps moyen par disque
- Taux de succes
- Repartition modes (Fast/Secure/BitLocker)
- Repartition types disques (USB/SATA/NVMe)
- Activite recente (7 derniers jours)

**Affichage** : Dashboard moderne avec graphiques

---

## 5️⃣ CleanDiskAudit_*.xml

**Contenu** : Audits XML bruts de chaque session

**Format fichier** : `CleanDiskAudit_20241204_143000.xml`

**Usage** : Donnees brutes pour traitements automatises

**Genere** : Automatiquement apres chaque session

**Utilise par** :
- Historiques clients (lecture XML pour compiler)
- Dashboard (lecture XML pour stats)

**Exemple** :
```
Logs/
├── CleanDiskAudit_20241204_143000.xml
├── CleanDiskAudit_20241202_101500.xml
├── CleanDiskAudit_20241201_153000.xml
```

---

## 🔄 Workflow Automatique

Apres chaque session, CleanDisk genere automatiquement :

1. ✅ **XML Audit** (`CleanDiskAudit_*.xml`)
2. ✅ **Rapport Session** (`Sessions/Rapport_Interne_*.html`)
3. ✅ **Certificat Client** (`Certificats/Certificat_*.pdf`)
4. ✅ **MAJ Historique Client** (`Clients/Historique_NOMCLIENT.html`)
5. ✅ **MAJ Dashboard** (`Dashboard_CleanDisk.html`)

**Resultat** : 5 fichiers generes/mis a jour automatiquement !

---

## 📊 Exemple Complet

### Scenario : 3 sessions ACME

**Session 1 - 15/11/2024** (10 disques) :
```
✅ CleanDiskAudit_20241115_143000.xml
✅ Sessions/Rapport_Interne_ACME_20241115_143000.html
✅ Certificats/Certificat_ACME_Corp_20241115_143000.pdf
✅ Clients/Historique_ACME_Corp.html (CREE)
✅ Dashboard_CleanDisk.html (MAJ)
```

**Session 2 - 28/11/2024** (2 disques) :
```
✅ CleanDiskAudit_20241128_101500.xml
✅ Sessions/Rapport_Interne_ACME_20241128_101500.html
✅ Certificats/Certificat_ACME_Corp_20241128_101500.pdf
✅ Clients/Historique_ACME_Corp.html (MAJ - ajout session 2)
✅ Dashboard_CleanDisk.html (MAJ)
```

**Session 3 - 04/12/2024** (3 disques) :
```
✅ CleanDiskAudit_20241204_143000.xml
✅ Sessions/Rapport_Interne_ACME_20241204_143000.html
✅ Certificats/Certificat_ACME_Corp_20241204_143000.pdf
✅ Clients/Historique_ACME_Corp.html (MAJ - ajout session 3)
✅ Dashboard_CleanDisk.html (MAJ)
```

**Resultat final** :
- 3 certificats PDF (1 par session)
- 3 rapports session (1 par session)
- 1 historique ACME (avec 3 sessions dedans)
- 1 dashboard (avec stats globales)

---

## 🗑️ Nettoyage

### Fichiers a conserver :
✅ Certificats/ (preuve client)
✅ Clients/ (historiques clients)
✅ Dashboard_CleanDisk.html

### Fichiers a archiver/supprimer periodiquement :
📦 Sessions/ (apres 6 mois)
📦 CleanDiskAudit_*.xml (apres 1 an)

### Commande nettoyage :
```powershell
# Supprimer rapports sessions > 6 mois
Get-ChildItem -Path "Logs\Sessions" -Filter "*.html" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddMonths(-6) } |
    Remove-Item -Force

# Supprimer audits XML > 1 an
Get-ChildItem -Path "Logs" -Filter "CleanDiskAudit_*.xml" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) } |
    Remove-Item -Force
```

---

## ✅ RESUME

| Fichier | Type | Usage | Accumulation |
|---------|------|-------|--------------|
| Sessions/*.html | Session | Interne | 1 par session |
| Clients/*.html | Compilation | Historique | 1 par client (MAJ) |
| Certificats/*.pdf | Certificat | Client | 1 par session |
| Dashboard_CleanDisk.html | Stats | Vue globale | 1 fichier (MAJ) |
| CleanDiskAudit_*.xml | Donnees brutes | Automatisation | 1 par session |

---

**Auteur** : LOGICIA INFORMATIQUE  
**Version** : 0.4  
**Date** : 04/12/2024
