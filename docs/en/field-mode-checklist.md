# Field Mode Manual Checklist

- Toggle Field Mode on/off and confirm only HUD, critical status bar placeholder, and flight mode/arm state remain visible.
- Restart the app and confirm Field Mode state persists.
- Set `fieldModeAllowPlan=false`; verify Plan is hidden and cannot be opened.
- Set `fieldModeAllowPlan=true`; verify Plan is visible and can be opened, Analyze remains hidden.
- Attempt to open Plan/Analyze via the tool menu and confirm gating works in Field Mode.
- Open a tool drawer (Settings/Configure) then enable Field Mode; confirm the drawer closes.
- With no vehicle connected, confirm Field Mode still shows only the allowed UI elements.
- Reduce window width to a small size and confirm the Field toggle remains accessible.
- Toggle Field Mode while in Plan view (with allowPlan=true) and verify it switches back to Fly view when allowPlan=false.
