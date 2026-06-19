import Foundation

let str1 = "пару минут"
let str2 = "пару минут"

print("str1: \(str1.map { String(format: "%02X", $0.unicodeScalars.first!.value) }.joined(separator: " "))")
print("str2: \(str2.map { String(format: "%02X", $0.unicodeScalars.first!.value) }.joined(separator: " "))")
