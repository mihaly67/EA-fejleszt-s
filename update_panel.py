import re

with open('MQL5/Indicators/Indicators/PanelControl_v2_23.mqh', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace header names
content = content.replace("PanelControl_v2_21.mqh", "PanelControl_v2_23.mqh")
content = content.replace("PANELCONTROL_V2_21_MQH", "PANELCONTROL_V2_23_MQH")

# Fix button definitions
replacement = """
       int btn_h = 24; // Standardized button height
       int cy_step = btn_h + 5;

       // --- Visual Toggle Button ---
       cy += 30; // Small gap after Min Dist
       ObjectCreate(0, ObjBtnVisual, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnVisual, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnVisual, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnVisual, OBJPROP_FONTSIZE, 8);

       // --- Mode Toggle Button (Breakout/Limit) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnMode, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnMode, OBJPROP_FONTSIZE, 8);

       // --- Entry Toggle Button (Pending/Market) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnEntry, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnEntry, OBJPROP_YSIZE, btn_h);
       ObjectSetInteger(0, ObjBtnEntry, OBJPROP_FONTSIZE, 8);

       // --- Fire TRAP Button (Legacy) ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE TRAP");
       ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed); ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);

       // --- Cease Fire ---
       cy += cy_step;
       ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, col_w-20); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, btn_h);
       ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
       ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange); ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);


       // === RIGHT COLUMN (New Directional Controls) ===
       cy = y + 40;
"""

pattern = r"""\s*int btn_h = 24;.*?cy = y \+ 40;"""

# Replace the specific block
content = re.sub(pattern, replacement, content, flags=re.DOTALL)


with open('MQL5/Indicators/Indicators/PanelControl_v2_23.mqh', 'w', encoding='utf-8') as f:
    f.write(content)
