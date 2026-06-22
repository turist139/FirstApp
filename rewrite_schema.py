import re

models_to_copy = [
    "FocusSession.swift",
    "UserProgress.swift",
    "BreakActivity.swift",
    "MindfulnessSession.swift",
    "DetoxLog.swift",
    "PastStreak.swift",
    "DetoxProfile.swift"
]

v1_models = []
v2_models = []

for filename in models_to_copy:
    with open(f"MyFocus/Models/{filename}", "r") as f:
        content = f.read()
    
    # Extract just the class definitions
    # Find all @Model classes
    matches = re.finditer(r'@Model\s*final\s*class\s+(\w+)\s*\{([^}]*)\}', content, re.MULTILINE)
    
    for match in matches:
        class_name = match.group(1)
        body = match.group(2)
        
        # for v1, if it's DetoxLog, remove endDate
        if class_name == "DetoxLog":
            v1_body = re.sub(r'\s*var endDate:\s*Date\?.*?\n', '\n', body)
            v1_body = re.sub(r'endDate:\s*Date\?\s*=\s*nil,?', '', v1_body)
            v1_body = re.sub(r'self\.endDate\s*=\s*endDate\n', '', v1_body)
            v1_models.append(f"    @Model final class {class_name} {{{v1_body}}}")
            v2_models.append(f"    @Model final class {class_name} {{{body}}}")
        else:
            v1_models.append(f"    @Model final class {class_name} {{{body}}}")
            v2_models.append(f"    @Model final class {class_name} {{{body}}}")

with open("MyFocus/Models/SchemaVersions.swift", "w") as f:
    f.write("import Foundation\nimport SwiftData\n\n")
    
    # V1
    f.write("enum MyFocusSchemaV1: VersionedSchema {\n")
    f.write("    static var versionIdentifier = Schema.Version(1, 0, 0)\n")
    f.write("    static var models: [any PersistentModel.Type] {\n")
    f.write("        [FocusSession.self, UserProgress.self, BreakActivity.self, MindfulnessSession.self, DetoxLog.self, PastStreak.self, DetoxProfile.self]\n")
    f.write("    }\n")
    for m in v1_models:
        f.write(m + "\n")
    f.write("}\n\n")
    
    # V2
    f.write("enum MyFocusSchemaV2: VersionedSchema {\n")
    f.write("    static var versionIdentifier = Schema.Version(2, 0, 0)\n")
    f.write("    static var models: [any PersistentModel.Type] {\n")
    f.write("        [FocusSession.self, UserProgress.self, BreakActivity.self, MindfulnessSession.self, DetoxLog.self, PastStreak.self, DetoxProfile.self]\n")
    f.write("    }\n")
    for m in v2_models:
        f.write(m + "\n")
    f.write("}\n\n")
    
    # Migration Plan
    f.write("""
enum MyFocusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MyFocusSchemaV1.self, MyFocusSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: MyFocusSchemaV1.self,
        toVersion: MyFocusSchemaV2.self
    )
}
""")
