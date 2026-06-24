# MQL5 PanelControl - Objektum (Gomb/Címke) Létrehozásának Kötelező Lépései (Cheat Sheet)

Bármikor, amikor egy új UI elemet (gombot, címkét, beviteli mezőt) adunk a `PanelControl` (vagy bármely MQL5 UI) osztályhoz, a MetaTrader objektumkezelése megköveteli az alábbi **szigorú, 6 lépésből álló sorrendet**. Bármelyik lépés kihagyása esetén az objektum nem jelenik meg, vagy rejtett (hibás) marad.

## 1. Deklaráció (Class Private)
Deklarálni kell egy string változót az objektum nevének tárolására a class törzsében.
```mql5
private:
    string ObjBtnMyNewButton;
```

## 2. Név Inicializálása (Init Metódusban) - KRITIKUS!
**Ha ez elmarad, az ObjectCreate névtelen stringként fut le és csendben elbukik! Az objektum sosem jelenik meg a charton és az objektumlistában sem!**
```mql5
void Init(...) {
    ObjBtnMyNewButton = m_prefix + "MyNewButton"; // <-- Ez a név kerül az Object List-be (Ctrl+B)
}
```

## 3. Létrehozás (Create Metódusban)
Gondoskodni kell az alapértelmezett paraméterek, méretek, Y-koordináta, háttérszín, és szöveg azonnali beállításáról, mielőtt a chart először frissülne.
```mql5
void Create() {
    cy += cy_step; // Dinamikus pozíció növelés Y tengelyen
    ObjectCreate(0, ObjBtnMyNewButton, OBJ_BUTTON, 0, 0, 0); // Létrehozás

    // Alapvető attribútumok
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_YDISTANCE, cy);
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_XSIZE, col_w - 20);
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_YSIZE, btn_h);

    // Vizuális Init - HA EZ NINCS, ÁTLÁTSZÓ/SZÖVEG NÉLKÜLI LEHET AZ ELSŐ PILLANATBAN!
    ObjectSetString(0, ObjBtnMyNewButton, OBJPROP_TEXT, "MY NEW BUTTON");
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_BGCOLOR, clrDarkCyan);
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_FONTSIZE, 8);
}
```

## 4. Eseménykezelés (OnEvent Metódusban)
Ha a gomb interaktív, az `id == CHARTEVENT_OBJECT_CLICK` ágban le kell kezelni.
```mql5
ENUM_PANEL_EVENT OnEvent(...) {
    if(sparam == ObjBtnMyNewButton) {
        // Vizuális 'lenyomás' hatás
        ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
        ChartRedraw();
        Sleep(100);
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        ChartRedraw();

        return EVENT_MY_CUSTOM_EVENT;
    }
}
```

## 5. Állapot Frissítés (UpdateButtons / UpdateUI Metódusban)
Ha az objektum (pl. toggle gomb) színe vagy szövege állapotfüggő, azokat itt kell dinamikusan beállítani.
```mql5
void UpdateButtons() {
    if(m_state_active) {
        ObjectSetString(0, ObjBtnMyNewButton, OBJPROP_TEXT, "STATE: ON");
        ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_BGCOLOR, clrGreen);
    } else {
        ObjectSetString(0, ObjBtnMyNewButton, OBJPROP_TEXT, "STATE: OFF");
        ObjectSetInteger(0, ObjBtnMyNewButton, OBJPROP_BGCOLOR, clrRed);
    }
}
```

## 6. Takarítás (Destroy Metódusban)
Az EA törlésekor/újraindulásakor ki kell takarítani az objektumot. Ha bent marad, "Object already exists" hibákat dobhat a MetaTrader.
```mql5
void Destroy() {
    ObjectDelete(0, ObjBtnMyNewButton);
}
```
