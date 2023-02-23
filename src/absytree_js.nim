
import custom_logger

logger.enableConsoleLogger()

import std/[strformat, dom]
import util, editor, timer, platform/widget_builders, platform/platform, platform/browser_platform, text_document, event, theme
from scripting_api import Backend

# Initialize renderer
var rend: BrowserPlatform = new BrowserPlatform
rend.init()

var initializedEditor = false
var ed = newEditor(Backend.Browser, rend)
const themeString = staticRead("../themes/Night Owl-Light-color-theme copy.json")
if theme.loadFromString(themeString).getSome(theme):
  ed.theme = theme

ed.setLayout("fibonacci")

# ed.createView(newTextDocument("absytree_browser.html", file1))
# ed.createView(newTextDocument("absytree_js.nim", file2))
# ed.openFile("absytree_browser.html")
# ed.openFile("src/absytree_js.nim")
# ed.openFile("absytree_config.nims")

var frameTime = 0.0
var frameIndex = 0

var hasRequestedRerender = false
proc requestRender(redrawEverything = false) =
  if not initializedEditor:
    return
  if hasRequestedRerender:
    return

  discard window.requestAnimationFrame proc(time: float) =
    # echo "requestAnimationFrame ", time

    hasRequestedRerender = false
    defer: inc frameIndex

    var layoutTime, updateTime, renderTime: float
    block:
      ed.frameTimer = startTimer()

      let updateTimer = startTimer()
      ed.updateWidgetTree(frameIndex)
      updateTime = updateTimer.elapsed.ms

      let layoutTimer = startTimer()
      ed.layoutWidgetTree(rend.size, frameIndex)
      layoutTime = layoutTimer.elapsed.ms

      let renderTimer = startTimer()
      rend.render(ed.widget, frameIndex)
      renderTime = renderTimer.elapsed.ms

      frameTime = ed.frameTimer.elapsed.ms

    if frameTime > 10:
      logger.log(lvlInfo, fmt"Frame: {frameTime:>5.2}ms (u: {updateTime:>5.2}ms, l: {layoutTime:>5.2}ms, r: {renderTime:>5.2}ms)")

discard rend.onKeyPress.subscribe proc(event: auto): void = requestRender()
discard rend.onKeyRelease.subscribe proc(event: auto): void = requestRender()
discard rend.onRune.subscribe proc(event: auto): void = requestRender()
discard rend.onMousePress.subscribe proc(event: auto): void = requestRender()
discard rend.onMouseRelease.subscribe proc(event: auto): void = requestRender()
discard rend.onMouseMove.subscribe proc(event: auto): void = requestRender()
discard rend.onScroll.subscribe proc(event: auto): void = requestRender()
discard rend.onCloseRequested.subscribe proc(_: auto) = requestRender()
discard rend.onResized.subscribe proc(redrawEverything: bool) = requestRender(redrawEverything)

block:
  ed.setHandleInputs "editor.text", true
  scriptSetOptionString "editor.text.cursor.movement.", "both"
  scriptSetOptionBool "editor.text.cursor.wide.", false

  ed.addCommandScript "editor", "<A-h>", "load-current-config"
  ed.addCommandScript "editor", "<A-g>", "sourceCurrentDocument"

initializedEditor = true
requestRender()
