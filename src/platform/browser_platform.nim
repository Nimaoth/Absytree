import std/[strformat, tables, dom, unicode, strutils]
import std/htmlgen as hg
import platform, widgets, custom_logger, rect_utils, input, event, lrucache
import vmath
import chroma as chroma

export platform, widgets

type
  WheelEvent* {.importc.} = ref object of MouseEvent ## see `docs<https://developer.mozilla.org/en-US/docs/Web/API/WheelEvent>`_
    deltaX: float
    deltaY: float
    deltaZ: float
    deltaMode: uint

type
  BrowserPlatform* = ref object of Platform
    content: Element
    boundsStack: seq[Rect]

    onResized*: event.Event[void]

    mFontSize: float
    mLineHeight: float
    mLineDistance: float
    mCharWidth: float

    escapedText: LruCache[string, string]

proc toInput(key: cstring, code: cstring, keyCode: int): int64
proc updateFontSettings*(self: BrowserPlatform)

proc getModifiers*(self: KeyboardEvent): Modifiers =
  if self.altKey:
    result.incl Modifier.Alt
  if self.shiftKey:
    result.incl Modifier.Shift
  if self.ctrlKey:
    result.incl Modifier.Control

proc getModifiers*(self: MouseEvent): Modifiers =
  if self.altKey:
    result.incl Modifier.Alt
  if self.shiftKey:
    result.incl Modifier.Shift
  if self.ctrlKey:
    result.incl Modifier.Control

method init*(self: BrowserPlatform) =
  self.mFontSize = 18
  self.mLineHeight = 20
  self.mLineDistance = 2
  self.mCharWidth = 18

  self.escapedText = newLruCache[string, string](1000)

  self.layoutOptions.getTextBounds = proc(text: string): Vec2 =
    result.x = text.len.float * self.mCharWidth
    result.y = self.totalLineHeight

  window.addEventListener "resize", proc(e: dom.Event) =
    self.onResized.invoke()

  self.content = document.getElementById("view")

  self.content.addEventListener("keydown", proc(e: dom.Event) =
    let ke = e.KeyboardEvent
    let modifiers = ke.getModifiers
    # debugf"keyevent {ke.key}, {ke.code}, {ke.keyCode}"

    var input = toInput(ke.key, ke.code, ke.keyCode)
    # debugf"{inputToString(input)}, {modifiers}"
    self.onKeyPress.invoke (input, modifiers)
  )

  self.content.addEventListener("wheel", proc(e: dom.Event) =
    let we = e.WheelEvent
    let modifiers = we.getModifiers

    # debugf"wheel {we.deltaX}, {we.deltaY}, {we.deltaZ}, {we.deltaMode}, {modifiers}"
    self.onScroll.invoke (vec2(we.clientX.float, we.clientY.float), vec2(we.deltaX, -we.deltaY) * 0.01, modifiers)
  , AddEventListenerOptions(passive: true))

  self.content.addEventListener("mousedown", proc(e: dom.Event) =
    let me = e.MouseEvent
    let modifiers = me.getModifiers

    let mouseButton = case me.button
    of 0: MouseButton.Left
    of 1: MouseButton.Middle
    of 2: MouseButton.Right
    else:
      return

    # debugf"click {we.button}, {modifiers}, {me.clientX}, {me.clientY}"
    self.onMousePress.invoke (mouseButton, modifiers, vec2(me.clientX.float, me.clientY.float))
  )

  self.updateFontSettings()
  self.content.focus()


method deinit*(self: BrowserPlatform) =
  discard

method size*(self: BrowserPlatform): Vec2 = vec2(self.content.clientWidth.float, self.content.clientHeight.float)# * 0.7

# method sizeChanged*(self: BrowserPlatform): bool =
#   let (w, h) = (terminalWidth(), terminalHeight())
#   return self.buffer.width != w or self.buffer.height != h

proc updateFontSettings*(self: BrowserPlatform) =
  let newFontSize: float = ($window.getComputedStyle(self.content).fontSize)[0..^3].parseFloat
  # debugf"updateFontSettings: {newFontSize}"
  if newFontSize != self.mFontSize:
    self.mFontSize = newFontSize
    var d = document.createElement("div")
    d.setAttr("style", "position: absolute; visibility: hidden; height: auto; width: auto;")
    d.innerHTML = "#"
    self.content.appendChild(d)
    debugf"charWidth: {d.clientWidth}, lineHeight: {d.clientHeight}"
    self.mLineHeight = d.clientHeight.float
    self.mCharWidth = d.clientWidth.float
    self.content.removeChild(d)

method fontSize*(self: BrowserPlatform): float =
  self.updateFontSettings()
  result = self.mFontSize

method lineDistance*(self: BrowserPlatform): float =
  self.updateFontSettings()
  self.mLineDistance

method lineHeight*(self: BrowserPlatform): float =
  self.updateFontSettings()
  self.mLineHeight

method charWidth*(self: BrowserPlatform): float =
  self.updateFontSettings()
  self.mCharWidth

proc toInput(key: cstring, code: cstring, keyCode: int): int64 =
  case key
  of "Enter": result = INPUT_ENTER
  of "Escape": result = INPUT_ESCAPE
  of "Backspace": result = INPUT_BACKSPACE
  of " ": result = INPUT_SPACE
  of "Delete": result = INPUT_DELETE
  of "Tab": result = INPUT_TAB
  of "ArrowLeft": result = INPUT_LEFT
  of "ArrowRight": result = INPUT_RIGHT
  of "ArrowUp": result = INPUT_UP
  of "ArrowDown": result = INPUT_DOWN
  of "Home": result = INPUT_HOME
  of "End": result = INPUT_END
  of "PageUp": result = INPUT_PAGE_UP
  of "PageDown": result = INPUT_PAGE_DOWN
  else:
    case keyCode
    of 112..123: result = int64(INPUT_F1 + (keyCode - 112))
    else:
      if key.len == 1:
        result =  ($key).runeAt(0).int64

method processEvents*(self: BrowserPlatform): int =
  result = 0

method renderWidget(self: WWidget, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string {.base.} = discard

method render*(self: BrowserPlatform, widget: WWidget, frameIndex: int) =
  self.boundsStack.add rect(vec2(), self.size)
  defer: discard self.boundsStack.pop()

  self.redrawEverything = true
  var result = widget.renderWidget(self, self.redrawEverything, frameIndex)
  self.content.innerHTML = result.cstring

method renderWidget(self: WPanel, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string =
  if self.lastHierarchyChange < frameIndex and self.lastBoundsChange < frameIndex and self.lastInvalidation < frameIndex and not forceRedraw:
    return

  # if self.drawBorder:
  #   renderer.setForegroundColor(self.getForegroundColor)
  #   renderer.buffer.drawRect(self.lastBounds.x.int, self.lastBounds.y.int, self.lastBounds.xw.int, self.lastBounds.yh.int)

  # if self.maskContent:
  #   renderer.pushMask(self.lastBounds)
  # defer:
  #   if self.maskContent:
  #     renderer.popMask()

  let relBounds = self.lastBounds - renderer.boundsStack[renderer.boundsStack.high].xy
  renderer.boundsStack.add self.lastBounds
  defer: discard renderer.boundsStack.pop()

  result = ""
  for c in self.children:
    result.add c.renderWidget(renderer, forceRedraw or self.fillBackground, frameIndex)

  let backgroundColor = if self.fillBackground:
    fmt"background: {self.backgroundColor.toHtmlHex};"
  else:
    ""

  result = hg.`div`(
    style = fmt"left: {relBounds.x.int}px; top: {relBounds.y.int}px; width: {relBounds.w.int}px; height: {relBounds.h.int}px; {backgroundColor}",
    class = "widget",
    result
  )

method renderWidget(self: WStack, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string =
  if self.lastHierarchyChange < frameIndex and self.lastBoundsChange < frameIndex and self.lastInvalidation < frameIndex and not forceRedraw:
    return

  # if self.fillBackground:
  # debugf"renderWidget {self.lastBounds}, {self.lastHierarchyChange}, {self.lastBoundsChange}"

  # if self.drawBorder:
  #   renderer.buffer.drawRect(self.lastBounds.x.int, self.lastBounds.y.int, self.lastBounds.xw.int, self.lastBounds.yh.int)

  let relBounds = self.lastBounds - renderer.boundsStack[renderer.boundsStack.high].xy
  renderer.boundsStack.add self.lastBounds
  defer: discard renderer.boundsStack.pop()

  result = ""
  for c in self.children:
    result.add c.renderWidget(renderer, forceRedraw or self.fillBackground, frameIndex)

  let backgroundColor = if self.fillBackground:
    fmt"background: {self.backgroundColor.toHtmlHex};"
  else:
    ""

  result = hg.`div`(
    style = fmt"left: {relBounds.x.int}px; top: {relBounds.y.int}px; width: {relBounds.w.int}px; height: {relBounds.h.int}px; {backgroundColor}",
    class = "widget",
    result
  )

method renderWidget(self: WVerticalList, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string =
  if self.lastHierarchyChange < frameIndex and self.lastBoundsChange < frameIndex and self.lastInvalidation < frameIndex and not forceRedraw:
    return

  # if self.fillBackground:
  # debugf"renderWidget {self.lastBounds}, {self.lastHierarchyChange}, {self.lastBoundsChange}"

  let relBounds = self.lastBounds - renderer.boundsStack[renderer.boundsStack.high].xy
  renderer.boundsStack.add self.lastBounds
  defer: discard renderer.boundsStack.pop()

  result = ""
  for c in self.children:
    result.add c.renderWidget(renderer, forceRedraw or self.fillBackground, frameIndex)

  let backgroundColor = if self.fillBackground:
    fmt"background: {self.backgroundColor.toHtmlHex};"
  else:
    ""

  result = hg.`div`(
    style = fmt"left: {relBounds.x.int}px; top: {relBounds.y.int}px; width: {relBounds.w.int}px; height: {relBounds.h.int}px; {backgroundColor}",
    class = "widget",
    result
  )

method renderWidget(self: WHorizontalList, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string =
  if self.lastHierarchyChange < frameIndex and self.lastBoundsChange < frameIndex and self.lastInvalidation < frameIndex and not forceRedraw:
    return

  # if self.fillBackground:
  # debugf"renderWidget {self.lastBounds}, {self.lastHierarchyChange}, {self.lastBoundsChange}"

  let relBounds = self.lastBounds - renderer.boundsStack[renderer.boundsStack.high].xy
  renderer.boundsStack.add self.lastBounds
  defer: discard renderer.boundsStack.pop()

  result = ""
  for c in self.children:
    result.add c.renderWidget(renderer, forceRedraw or self.fillBackground, frameIndex)

  let backgroundColor = if self.fillBackground:
    fmt"background: {self.backgroundColor.toHtmlHex};"
  else:
    ""

  result = hg.`div`(
    style = fmt"left: {relBounds.x.int}px; top: {relBounds.y.int}px; width: {relBounds.w.int}px; height: {relBounds.h.int}px; {backgroundColor}",
    class = "widget",
    result
  )

method renderWidget(self: WText, renderer: BrowserPlatform, forceRedraw: bool, frameIndex: int): string =
  if self.lastHierarchyChange < frameIndex and self.lastBoundsChange < frameIndex and self.lastInvalidation < frameIndex and not forceRedraw:
    return

  let relBounds = self.lastBounds - renderer.boundsStack[renderer.boundsStack.high].xy

  let backgroundColor = if self.fillBackground:
    fmt"background: {self.backgroundColor.toHtmlHex};"
  else:
    ""

  let color = self.foregroundColor.toHtmlHex

  let text = if renderer.escapedText.contains(self.text):
    renderer.escapedText[self.text]
  else:
    # var p = document.createElement("pre".cstring)
    # p.setAttribute("style", "white-space: pre-wrap;")
    # p.appendChild document.createTextNode(self.text.replace(" ", "&nbsp;").cstring)
    # p.innerText = self.text.cstring
    # let escapedText = $p.innerHTML
    let escapedText = self.text.multiReplace(("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"), ("'", "&#039;"))
    renderer.escapedText[self.text] = escapedText
    escapedText

  result = hg.span(
    style = fmt"left: {relBounds.x.int}px; top: {relBounds.y.int}px; width: {relBounds.w.int}px; height: {relBounds.h.int}px; overflow: visible; color: {color}; {backgroundColor}",
    class = "widget",
    text
  )

  self.lastRenderedText = self.text