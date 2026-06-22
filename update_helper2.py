import re

with open("MyFocus/Utilities/DetoxDateHelper.swift", "r") as f:
    content = f.read()

content = content.replace("PastStreak", "StreakHistoryItem")
content = content.replace("PastRelapse", "RelapseHistoryItem")

with open("MyFocus/Utilities/DetoxDateHelper.swift", "w") as f:
    f.write(content)
