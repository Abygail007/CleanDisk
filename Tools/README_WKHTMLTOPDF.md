# 📄 wkhtmltopdf - Conversion HTML vers PDF

## ❓ C'est quoi ?

**wkhtmltopdf** est un outil qui convertit vos certificats HTML en PDF professionnel.

**IMPORTANT** : Sans wkhtmltopdf, CleanDisk genere uniquement des fichiers HTML.
Avec wkhtmltopdf, CleanDisk genere des **PDF professionnels** !

---

## 📥 INSTALLATION

### Etape 1 : Telecharger

🔗 **Lien officiel** : https://wkhtmltopdf.org/downloads.html

**Version recommandee** : `wkhtmltopdf 0.12.6 (with patched qt)`

**Pour Windows 64-bit** : 
- Fichier : `wkhtmltox-0.12.6-1.msvc2015-win64.exe`
- Taille : ~50 MB

### Etape 2 : Installer

1. Double-cliquez sur le fichier .exe telecharge
2. Suivez l'assistant d'installation
3. **Par defaut** : Installe dans `C:\Program Files\wkhtmltopdf\`

### Etape 3 : Copier dans CleanDisk

1. Allez dans `C:\Program Files\wkhtmltopdf\bin\`
2. Copiez le fichier `wkhtmltopdf.exe`
3. Collez-le dans `CleanDisk\Tools\wkhtmltopdf.exe`

**Chemin final** : `CleanDisk\Tools\wkhtmltopdf.exe`

---

## ✅ Verification

Ouvrez PowerShell et testez :

```powershell
cd C:\CleanDisk
.\Tools\wkhtmltopdf.exe --version
```

**Resultat attendu** :
```
wkhtmltopdf 0.12.6 (with patched qt)
```

Si vous voyez ce message : **C'EST BON !** ✅

---

## 🚀 Utilisation dans CleanDisk

**Automatique** : CleanDisk detecte automatiquement wkhtmltopdf.

**Si present** :
```
✅ Genere certificat PDF professionnel
✅ Qualite identique au HTML
✅ Pret a imprimer
```

**Si absent** :
```
⚠️ Genere certificat HTML uniquement
⚠️ Message avertissement dans les logs
⚠️ Lien telechargement affiche
```

---

## 📁 Structure finale

```
CleanDisk/
├── Tools/
│   ├── wkhtmltopdf.exe         ← METTRE ICI
│   └── README_WKHTMLTOPDF.md   ← Ce fichier
├── Logs/
│   └── Certificats/
│       ├── Certificat_Client_*.pdf   ← Generes avec wkhtmltopdf
│       └── Certificat_Client_*.html  ← Fallback si pas wkhtmltopdf
└── ...
```

---

## ❓ FAQ

### Q : wkhtmltopdf est obligatoire ?
**R** : Non, mais **FORTEMENT RECOMMANDE** pour PDF professionnels.

### Q : Ca marche sans ?
**R** : Oui, mais certificats en HTML uniquement (pas PDF).

### Q : Je peux utiliser autre chose ?
**R** : Non, CleanDisk est optimise pour wkhtmltopdf uniquement.

### Q : C'est gratuit ?
**R** : Oui, 100% gratuit et open-source.

### Q : C'est sur ?
**R** : Oui, projet open-source reconnu depuis 2008.

### Q : Quelle taille ?
**R** : ~50 MB (fichier .exe seul : ~12 MB)

---

## 🔗 Liens Utiles

**Site officiel** : https://wkhtmltopdf.org/

**GitHub** : https://github.com/wkhtmltopdf/wkhtmltopdf

**Documentation** : https://wkhtmltopdf.org/usage/wkhtmltopdf.txt

---

## 🐛 Problemes ?

### Erreur "fichier introuvable"
→ Verifier chemin : `CleanDisk\Tools\wkhtmltopdf.exe`

### PDF non genere
→ Verifier version : `wkhtmltopdf.exe --version`
→ Reinstaller si necessaire

### Message "Access denied"
→ Executer CleanDisk en administrateur

---

**Auteur** : LOGICIA INFORMATIQUE  
**Version** : 0.4  
**Date** : 04/12/2024
