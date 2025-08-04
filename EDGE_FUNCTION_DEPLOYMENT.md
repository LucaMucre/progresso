# Edge Function Deployment - Progresso App

## 🚀 **Schritt 1: RLS Policies anwenden**

1. **Gehe zu deinem Supabase Dashboard**
   - https://supabase.com/dashboard/project/xssuhovxkpgorjxvflwo

2. **Öffne den SQL Editor**
   - Klicke auf "SQL Editor" in der linken Seitenleiste

3. **Führe die SQL-Befehle aus**
   - Kopiere den Inhalt von `supabase_setup.sql`
   - Füge ihn in den SQL Editor ein
   - Klicke auf "Run"

## 🚀 **Schritt 2: Edge Function deployen**

### **Option A: Über Supabase Dashboard**
1. **Gehe zu "Edge Functions"**
   - Klicke auf "Edge Functions" in der linken Seitenleiste

2. **Erstelle eine neue Function**
   - Klicke auf "Create a new function"
   - Name: `calculate-xp`
   - Runtime: `Deno`

3. **Füge den Code ein**
   - Kopiere den Inhalt von `supabase/functions/calculate-xp/index.ts`
   - Füge ihn in den Editor ein
   - Klicke auf "Deploy"

### **Option B: Über CLI (falls Login funktioniert)**
```bash
# Login (falls noch nicht gemacht)
supabase login

# Function deployen
supabase functions deploy calculate-xp
```

## ✅ **Was wird aktiviert:**

### **RLS Policies:**
- ✅ **Datenisolation**: Jeder User sieht nur seine eigenen Daten
- ✅ **Sicherheit**: Verhindert unbefugten Zugriff
- ✅ **Multi-Tenant**: Sichere Mehrbenutzer-Umgebung

### **Storage Policies:**
- ✅ **Avatar-Uploads**: Sichere Avatar-Speicherung
- ✅ **User-spezifische Ordner**: Jeder User hat seinen eigenen Ordner

### **Edge Function:**
- ✅ **Server-seitige XP-Berechnung**: Komplexe Logik auf Supabase-Servern
- ✅ **Streak-Berechnung**: Automatische Streak-Erkennung
- ✅ **Duration-Boni**: +1 XP pro 10 Minuten
- ✅ **Streak-Boni**: +2 XP bei 7+ Tagen Streak

## 🔧 **Nach dem Deployment:**

### **Test der Edge Function:**
```bash
# Test-Aufruf (ersetze USER_ID und ACTION_LOG_ID)
curl -X POST 'https://xssuhovxkpgorjxvflwo.supabase.co/functions/v1/calculate-xp' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"action_log_id": "ACTION_LOG_ID"}'
```

### **Integration in der App:**
Die App verwendet bereits die Edge Function über den `db_service.dart`:
```dart
// Bereits implementiert in db_service.dart
final response = await _db.functions.invoke('calculate-xp', 
  body: {'action_log_id': logId});
```

## 🎯 **Ergebnis:**
- **Sichere Daten**: RLS verhindert Datenlecks
- **Konsistente Berechnungen**: Server-seitige XP-Berechnung
- **Bessere Performance**: Schwere Berechnungen nicht auf Client-Geräten
- **Skalierbar**: Funktioniert auch mit tausenden Usern

Die App ist jetzt **produktionsreif** und **sicher**! 🚀 