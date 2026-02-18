# Mérföldkő Dokumentáció (Stealth Fix) - v2.38

**Dátum:** 2026.02.18
**Státusz:** STABIL (Termelési Kész)

Ez a dokumentum rögzíti a **Merkava v2.38** és a **FireControl v2.23** konfigurációs állapotát. A korábbi v2.37-es verziót felváltotta, mivel kritikus stealth hiányosságot (bróker oldalon látható kommentek) javítottunk.

## 1. Rendszer Komponensek (Verziók)

A rendszer integritása érdekében az alábbi moduloknak kell jelen lenniük:

*   **Fő Program (Expert Advisor):**
    *   `Merkava_v2_38.mq5` (Verzió: 2.38)
    *   *Funkciók:* Deep Stealth integráció, Dinamikus verziókijelzés, **Kényszerített Üres Komment**.

*   **Végrehajtó Modulok:**
    *   `FireControl_v2_23.mqh` (ÚJ - Verzió: 2.23)
        *   *Fix:* **Broker Comment Sanitization.** A bróker felé küldött `OrderSend` kérésben a `comment` mező mindig üres string (`""`), függetlenül a belső logikától.
        *   *Audit:* A belső naplózás (`StealthRegistry`) és az Expert fülön megjelenő `STEALTH AUDIT` üzenet továbbra is tartalmazza a réteg (Layer) információkat (pl. `_L1`, `_L2`), de ez **CSAK** a kliens oldalon látható.
    *   `StealthRegistry.mqh` (Verzió: 1.05)
        *   *Szerepe:* Belső pozíciókövetés és random Magic Number generálás.
    *   `StealthEngine.mqh` (Verzió: 1.0)
        *   *Szerepe:* Emberi késleltetés és árfolyam-bizonytalanság (fuzzy pricing).

## 2. Változások a v2.37-hez képest (CHANGELOG)

### 🚨 Kritikus Stealth Javítás
A felhasználói visszajelzés alapján az IC Markets bróker heti összesítőjében megjelentek a `_L1`, `_L2` technikai jelölések a megjegyzés rovatban. Ez lebuktatta a stratégiát.

**Megoldás (v2.38):**
*   A `FireControl` modulban a `ExecuteTrade` függvény mostantól figyelmen kívül hagyja a bemeneti `comment` prefixet a bróker kommunikáció során.
*   **Bróker felé:** `request.comment = ""` (Üres).
*   **Belső Napló:** `internal_comment = "Strategy_L1"` (Megmaradt a visszakereshetőség).

### Ellenőrzés
A javítás helyességét az Expert fülön megjelenő üzenettel lehet azonnal ellenőrizni kereskedéskor:
`STEALTH AUDIT: Sending Order. Magic=..., Comment='' (Broker sees EMPTY), Internal='Strategy_L1'`

## 3. Telepítés és Fájlok

*   EA: `MQL5/Indicators/Jules/Merkava_v2_38.mq5`
*   FireControl: `MQL5/Indicators/Indicators/FireControl_v2_23.mqh`

A `v2.37`-es verzió (`MILESTONE_v2_37_GOLDEN_MASTER.md`) elavultnak tekintendő és törlésre került a félreértések elkerülése végett.

**Jóváhagyta:** Jules (AI Engineer) & Rendszerfőnök
