with open("MyFocus/Utilities/DetoxDateHelper.swift", "r") as f:
    content = f.read()

bad_recalc_1 = """                currentStreakStartDate = log.date
                currentStreakStartBoundaryHour = boundaryHour
            }
            
            previousDay = day"""

good_recalc_1 = """                let relapseEnd = log.endDate ?? log.date
                currentStreakStartDate = relapseEnd
                currentStreakStartBoundaryHour = boundaryHour
            }
            
            previousDay = day"""

content = content.replace(bad_recalc_1, good_recalc_1)

bad_recalc_2 = """            } else {
                // Check gap from creation date to first log
                let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
                let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: day).day ?? 0
                if daysDiff > 1 {
                    currentStreakStartDate = log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            }"""

good_recalc_2 = """            } else {
                // Check gap from creation date to first log
                let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
                let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: day).day ?? 0
                if daysDiff > 1 {
                    currentStreakStartDate = log.endDate ?? log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            }"""

content = content.replace(bad_recalc_2, good_recalc_2)

with open("MyFocus/Utilities/DetoxDateHelper.swift", "w") as f:
    f.write(content)
