with open("MyFocusWidgets/StreakWidget.swift", "r") as f:
    content = f.read()

# Fix 1: missing profileName in container fail fallback
err1 = "return StreakEntry(date: Date(), streakDays: 0, activeHours: 0, paletteName: paletteName, hasCheckedInToday: false)"
fix1 = "return StreakEntry(date: Date(), streakDays: 0, activeHours: 0, paletteName: paletteName, hasCheckedInToday: false, profileName: \"Трекинг\")"
content = content.replace(err1, fix1)

# Fix 2: activeProfile?.colorPalette does not exist
err2 = "paletteName: activeProfile?.colorPalette ?? paletteName,"
fix2 = "paletteName: paletteName,"
content = content.replace(err2, fix2)

with open("MyFocusWidgets/StreakWidget.swift", "w") as f:
    f.write(content)
