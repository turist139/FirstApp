import re

with open("MyFocus/App/MyFocusApp.swift", "r") as f:
    content = f.read()

# For each @Model class in MyFocusSchemaV1, insert init() {} before the closing brace
def replacer(match):
    body = match.group(2)
    # only insert if inside MyFocusSchemaV1
    if "enum MyFocusSchemaV1" not in content[:match.start()]:
        return match.group(0)
    
    # insert init() {}
    new_body = body.rstrip() + "\n        init() {}\n    "
    return match.group(1) + new_body + "}"

new_content = re.sub(r'(@Model final class \w+ \{)([^}]*)\}', replacer, content)

with open("MyFocus/App/MyFocusApp.swift", "w") as f:
    f.write(new_content)
