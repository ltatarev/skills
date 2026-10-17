// Compare two PNGs of the same size and print how many pixels differ.
// Usage: swift pxdiff.swift before.png after.png
// It samples every second column and ignores a colour change under 0.06.

import AppKit

let args = CommandLine.arguments
func load(_ path: String) -> NSBitmapImageRep {
  NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
}
let a = load(args[1])
let b = load(args[2])
var minY = Int.max
var maxY = -1
var count = 0
for y in 0..<a.pixelsHigh {
  for x in stride(from: 0, to: a.pixelsWide, by: 2) {
    let p = a.colorAt(x: x, y: y)!
    let q = b.colorAt(x: x, y: y)!
    let delta = abs(p.redComponent - q.redComponent)
      + abs(p.greenComponent - q.greenComponent)
      + abs(p.blueComponent - q.blueComponent)
    if delta > 0.06 {
      count += 1
      minY = min(minY, y)
      maxY = max(maxY, y)
    }
  }
}
print(count == 0 ? "differing px: 0" : "differing px: \(count) rows \(minY) - \(maxY)")
