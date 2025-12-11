# Profils Clients

Ce dossier contient les profils clients sauvegardes automatiquement.

## Format

Chaque profil est un fichier JSON avec :
- Societe
- Site
- Ville
- Technicien
- DateCreation

## Utilisation

1. Les profils sont sauvegardes **automatiquement** apres chaque effacement
2. Cliquez sur **"Charger un profil existant"** (Etape 2) pour reutiliser un profil
3. Tapez le nom de la societe pour charger ses informations

## Gestion

- Les profils s'accumulent automatiquement
- Vous pouvez supprimer manuellement les profils obsoletes
- Pas de limite de nombre

## Exemple de fichier

```json
{
  "Societe": "ACME Corp",
  "Site": "Siege social",
  "Ville": "Paris",
  "Technicien": "Jean Dupont",
  "DateCreation": "2024-12-04 16:30:00"
}
```
