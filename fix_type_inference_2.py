with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

bad_closure = "let logs = failLogs.sorted { $0.date > $1.date }"
good_closure = "let logs: [DetoxLog] = failLogs.sorted { (a: DetoxLog, b: DetoxLog) -> Bool in a.date > b.date }"

content = content.replace(bad_closure, good_closure)

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
