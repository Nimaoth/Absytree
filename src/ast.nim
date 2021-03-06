import std/[strformat, bitops, strutils, tables, algorithm, math]
import boxy, opengl, times, windy
import monitors
import sugar
import input, editor, editor_render

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
window.runeInputEnabled = true

proc centerWindowOnMonitor(window: Window, monitor: int) =
  let monitorPos = getMonitorRect(monitor)

  let left = float(monitorPos.left)
  let right = float(monitorPos.right)
  let top = float(monitorPos.top)
  let bottom = float(monitorPos.bottom)

  let windowWidth = float(window.size.x)
  let windowHeight = float(window.size.y)
  let monitorWidth = right - left
  let monitorHeight = bottom - top
  window.pos = ivec2(int32(left + (monitorWidth - windowWidth) / 2),
                     int32(top + (monitorHeight - windowHeight) / 2))

window.centerWindowOnMonitor(2)

makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

var ed = newEditor(window, bxy)

# Load the images.
# bxy.addImage("bg", readImage("examples/data/bg.png"))

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  # bxy.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))

  ed.render()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()

var currentModifiers: Modifiers = {}

window.onFocusChange = proc() =
  currentModifiers = {}

window.onRune = proc(rune: Rune) =
  if rune.int32 in char.low.ord .. char.high.ord:
    case rune.char
    of ' ': return
    else: discard

  ed.handleRune(rune, currentModifiers)

window.onButtonPress = proc(button: Button) =
  # If the key event would also generate a char afterwards then ignore it, except for some special keys
  if isNextMsgChar():
    case button:
    of KeySpace, KeyEnter: discard
    else: return

  case button
  of KeyLeftShift, KeyRightShift: currentModifiers = currentModifiers + {Shift}
  of KeyLeftControl, KeyRightControl: currentModifiers = currentModifiers + {Control}
  of KeyLeftAlt, KeyRightAlt: currentModifiers = currentModifiers + {Alt}
  of KeyLeftSuper, KeyRightSuper: currentModifiers = currentModifiers + {Super}
  else:
    ed.handleKeyPress(button, currentModifiers)

window.onButtonRelease = proc(button: Button) =
  case button
  of KeyLeftShift, KeyRightShift: currentModifiers = currentModifiers - {Shift}
  of KeyLeftControl, KeyRightControl: currentModifiers = currentModifiers - {Control}
  of KeyLeftAlt, KeyRightAlt: currentModifiers = currentModifiers - {Alt}
  of KeyLeftSuper, KeyRightSuper: currentModifiers = currentModifiers - {Super}
  else:
    ed.handleKeyRelease(button, currentModifiers)

while not window.closeRequested:
  pollEvents()
