import std/[os, macros, genasts, strutils, sequtils, sugar, strformat, options, random, tables, sets]
import src/macro_utils, src/util, src/id
import boxy, boxy/textures, pixie, windy, vmath, rect_utils, opengl, timer, lrucache, ui/node
import custom_logger

logger.enableConsoleLogger()
logCategory "test", true

var showPopup1 = true
var showPopup2 = false

var logRoot = false
var logFrameTime = true
var showDrawnNodes = true

var advanceFrame = false
var counter = 0
var testWidth = 10.float32
var invalidateOverlapping* = true

var popup1 = neww (vec2(100, 100), vec2(0, 0), false)
var popup2 = neww (vec2(200, 200), vec2(0, 0), false)

var cursor = (0, 0)
var mainTextChanged = false
var retainMainText = false

const testText = """
macro defineBitFlag*(body: untyped): untyped =
  let flagName = body[0][0].typeName
  let flagsName = (flagName.repr & "s").ident

  result = genAst(body, flagName, flagsName):
    body
    type flagsName* = distinct uint32

    func incl*(flags: var flagsName, flag: flagName) {.inline.} =
      flags = (flags.uint32 or (1.uint32 shl flag.uint32)).flagsName
    func excl*(flags: var flagsName, flag: flagName) {.inline.} =
      flags = (flags.uint32 and not (1.uint32 shl flag.uint32)).flagsName

    func `==`*(a, b: flagsName): bool {.borrow.}

    macro `&`*(flags: static set[flagName]): flagsName =
      var res = 0.flagsName
      for flag in flags:
        res.incl flag
      return genAst(res2 = res.uint32):
        res2.flagsName
""".splitLines(keepEol=false)

const testText2 = """hi, wassup?
lol
uiaeuiaeuiae
uiui uia eu""".splitLines(keepEol=false)

const testText3 = """    glBindFramebuffer(GL_READ_FRAMEBUFFER, framebufferId)
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0)
    glBlitFramebuffer(
      0, 0, framebuffer.width.GLint, framebuffer.height.GLint,
      0, 0, window.size.x.GLint, window.size.y.GLint,
      GL_COLOR_BUFFER_BIT, GL_NEAREST.GLenum)

    window.swapBuffers()""".splitLines(keepEol=false)

proc getFont*(font: string, fontSize: float32): Font =
  let typeface = readTypeface(font)

  result = newFont(typeface)
  result.paint.color = color(1, 1, 1)
  result.size = fontSize

var builder = newNodeBuilder()

var image = newImage(1000, 1000)
var ctx = newContext(image)
ctx.strokeStyle = rgb(255, 0, 0)
ctx.font = "fonts/FiraCode-Regular.ttf"
ctx.fontSize = 17

let font = getFont(ctx.font, ctx.fontSize)
let bounds = font.typeset(repeat("#", 100)).layoutBounds()

builder.charWidth = bounds.x / 100.0
builder.lineHeight = bounds.y - 3
builder.lineGap = 6

var framebufferId: GLuint
var framebuffer: Texture

var window = newWindow("", ivec2(image.width.int32 * 2, image.height.int32), WindowStyle.Decorated, vsync=false)
makeContextCurrent(window)
loadExtensions()
enableAutoGLerrorCheck(false)

var bxy = newBoxy()
bxy.addImage("image", image)

framebuffer = Texture()
framebuffer.width = image.width.int32 * 2
framebuffer.height = image.height.int32
framebuffer.componentType = GL_UNSIGNED_BYTE
framebuffer.format = GL_RGBA
framebuffer.internalFormat = GL_RGBA8
framebuffer.minFilter = minLinear
framebuffer.magFilter = magLinear
bindTextureData(framebuffer, nil)

glGenFramebuffers(1, framebufferId.addr)
glBindFramebuffer(GL_FRAMEBUFFER, framebufferId)
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, framebuffer.textureId, 0)
glBindFramebuffer(GL_FRAMEBUFFER, 0)
bxy.setTargetFramebuffer framebufferId

var drawnNodes: seq[UINode] = @[]

var cachedImages: LruCache[string, string] = newLruCache[string, string](1000, true)

template button*(builder: UINodeBuilder, name: string, body: untyped): untyped =
  builder.panel(&{DrawText, DrawBorder, FillBackground, SizeToContentX, SizeToContentY, MouseHover}, text = name):
    currentNode.setTextColor(1, 0, 0)

    if currentNode.some == builder.hoveredNode:
      currentNode.setBackgroundColor(0.6, 0.5, 0.5)
    else:
      currentNode.setBackgroundColor(0.3, 0.2, 0.2)

    onClick Left:
      body

template withText*(builder: UINodeBuilder, str: string, body: untyped): untyped =
  builder.panel(&{DrawText, FillBackground, SizeToContentX, SizeToContentY}, text = str):
    # currentNode.setTextColor(1, 0, 0)
    # currentNode.setBackgroundColor(0, 0, 0)

    body

iterator splitLine(str: string): string =
  if str.len == 0:
    yield ""
  else:
    var start = 0
    var i = 0
    var ws = str[0] in Whitespace
    while i < str.len:
      let currWs = str[i] in Whitespace
      if ws != currWs:
        yield str[start..<i]
        start = i
        ws = currWs
      inc i
    if start < i:
      yield str[start..<i]

proc renderLine(builder: UINodeBuilder, line: string, curs: Option[int], backgroundColor, textColor: Color, sizeToContentX: bool): Option[(UINode, string, Rect)] =
  var flags = &{LayoutHorizontal, FillX, SizeToContentY}
  if sizeToContentX:
    flags.incl SizeToContentX
  # else:
  #   flags.incl FillX

  builder.panel(flags):
    var start = 0
    var lastPartXW: float32 = 0
    for part in line.splitLine:
      defer:
        start += part.len

      builder.withText(part):
        currentNode.backgroundColor = backgroundColor
        currentNode.textColor = textColor

        # cursor
        if curs.getSome(curs) and curs >= start and curs < start + part.len:
          let cursorX = builder.textWidth(curs - start).round
          result = some (currentNode, $part[curs - start], rect(cursorX, 0, builder.charWidth, builder.textHeight))
          # builder.panel(&{FillY, FillBackground}, x = cursorX, w = builder.charWidth, backgroundColor = color(0.7, 0.7, 1, 0.7))
            # onClick:
            #   # echo "clicked cursor ", btn
            #   cursor[1] = rand(0..line.len)

        lastPartXW = currentNode.bounds.xw

    # cursor after latest char
    if curs.getSome(curs) and curs == line.len:
      result = some (currentNode, "", rect(lastPartXW, 0, builder.charWidth, builder.textHeight))
      # builder.panel(&{FillY, FillBackground}, w = builder.charWidth, backgroundColor = color(0.5, 0.5, 1, 1))
        # onClick:
        #   # echo "clicked cursor ", btn
        #   cursor[1] = rand(0..line.len)

    # Fill rest of line with background
    builder.panel(&{FillX, FillY, FillBackground}, backgroundColor = backgroundColor * 2)

proc renderText(builder: UINodeBuilder, lines: openArray[string], first: int, cursor: (int, int), backgroundColor, textColor: Color, sizeToContentX = false, sizeToContentY = true, id = Id.none) =
  var flags = &{MaskContent, OverlappingChildren}
  var flagsInner = &{LayoutVertical}
  if sizeToContentX:
    flags.incl SizeToContentX
    flagsInner.incl SizeToContentX
  else:
    flags.incl FillX
    flagsInner.incl FillX

  if sizeToContentY:
    flags.incl SizeToContentY
    flagsInner.incl SizeToContentY
  else:
    flags.incl FillY
    flagsInner.incl FillY

  builder.panel(flags, userId = id):

    var cursorLocation = (UINode, string, Rect).none

    builder.panel(flagsInner):
      for i, line in lines:
        let column = if cursor[0] == i: cursor[1].some else: int.none
        if builder.renderLine(line, column, backgroundColor, textColor, sizeToContentX).getSome(cl):
          cursorLocation = cl.some

    # let cursorX = builder.textWidth(curs - start).round
    if cursorLocation.getSome(cl):
      var bounds = cl[2].transformRect(cl[0], currentNode) - vec2(1, 0)
      bounds.w += 1
      builder.panel(&{FillBackground}, x = bounds.x, y = bounds.y, w = bounds.w, h = bounds.h, backgroundColor = color(0.7, 0.7, 1)):
        builder.panel(&{DrawText, SizeToContentX, SizeToContentY}, x = 1, y = 0, text = cl[1], textColor = color(0.4, 0.2, 2))

proc createPopup(builder: UINodeBuilder, lines: openArray[string], pop: ref tuple[pos: Vec2, offset: Vec2, collapsed: bool], backgroundColor, borderColor, headerColor, textColor: Color) =
  let pos = pop.pos + pop.offset

  var flags = &{LayoutVertical, SizeToContentX, SizeToContentY, MouseHover, MaskContent}
  if pop.collapsed:
    flags.incl SizeToContentY

  builder.panel(flags, x = pos.x, y = pos.y): # draggable overlay
    currentNode.setBorderColor(1, 0, 1)
    currentNode.flags.incl DrawBorder

    let headerWidth = if pop.collapsed: 100.float32.some else: float32.none

    # header
    builder.panel(&{FillX, SizeToContentY, FillBackground, LayoutHorizontal}, w = headerWidth):
      currentNode.setBackgroundColor(0.2, 0.2, 0.2)
      builder.button("X"):
        pop.collapsed = not pop.collapsed

      onClick Left:
        pop.pos += pop.offset
        pop.offset = vec2(0, 0)
        builder.draggedNode = currentNode.some

      onDrag Left:
        pop.offset = builder.mousePos - builder.mousePosClick[Left]

    if not pop.collapsed:
      builder.renderText(lines, 0, (0, 0), backgroundColor=backgroundColor, textColor = textColor, sizeToContentX = true)

      # # background filler
      # builder.panel(&{FillX, FillY, FillBackground}):
      #   currentNode.setBackgroundColor(0, 0, 0)

proc createSlider(builder: UINodeBuilder, value: float32, inBackgroundColor, handleColor: Color, min: float32 = 0, max: float32 = 1, step = float32.none, valueChanged: proc(value: float32) = nil) =
  builder.panel(&{FillX, FillBackground, LayoutHorizontal}, h = builder.textHeight):
    currentNode.backgroundColor = inBackgroundColor

    # let slider = currentNode

    builder.panel(&{SizeToContentY, DrawText}, text = $value, textColor = color(1, 1, 1), w = 100)

    builder.panel(&{FillX, FillY, DrawBorder}, borderColor = handleColor):
      let slider = currentNode

      let x = (slider.w - builder.charWidth) * ((value - min).abs / (max - min).abs).clamp(0, 1)
      builder.panel(&{FillY, FillBackground}, x = x, w = builder.charWidth):
        currentNode.backgroundColor = handleColor

      proc updateValue() =
        let alpha = ((builder.mousePos.x - slider.lx - builder.charWidth * 0.5) / (slider.w - builder.charWidth)).clamp(0, 1)
        var targetValue = if max >= min:
          min + alpha * (max - min)
        else:
          min - alpha * (min - max)

        # var targetValue = (max - min).abs * (builder.mousePos.x - slider.lx - builder.charWidth / 2) / (slider.w - builder.charWidth) + min
        if step.getSome(step):
          targetValue = (targetValue / step).round * step

        if valueChanged.isNotNil:
          valueChanged(targetValue)

      onClick Left:
        builder.draggedNode = currentNode.some
        updateValue()

      onDrag Left:
        updateValue()

proc createCheckbox(builder: UINodeBuilder, value: bool, valueChanged: proc(value: bool) = nil) =
  let margin = builder.textHeight * 0.2
  builder.panel(&{FillBackground}, w = builder.textHeight, h = builder.textHeight, backgroundColor = color(0.5, 0.5, 0.5)):
    if value:
      builder.panel(&{FillBackground}, x = margin, y = margin, w = builder.textHeight - margin * 2, h = builder.textHeight - margin * 2, backgroundColor = color(0.8, 0.8, 0.8))

    onClick Left:
      if valueChanged.isNotNil:
        valueChanged(not value)

var sliderMin = 0.float32
var sliderMax = 100.float32
var sliderStep = 1.float32
var slider = 35.float32

template createLine(builder: UINodeBuilder, body: untyped) =
  builder.panel(&{FillX, SizeToContentY, LayoutHorizontal}):
    body
    builder.panel(&{FillX, FillY, FillBackground}, backgroundColor = color(0, 0, 0))

    # # Fill rest of line with background
    # builder.panel(&{FillX, FillY, FillBackground}):
    #   currentNode.backgroundColor = color(0, 0, 0)

var lastTextArea = newId()
proc buildUINodes(builder: UINodeBuilder) =
  var rootFlags = &{FillX, FillY, OverlappingChildren, MaskContent}
  # if not invalidateOverlapping:
  #   rootFlags.incl FillBackground

  builder.panel(rootFlags, backgroundColor = color(0, 0, 0)): # fullscreen overlay

    builder.panel(&{FillX, FillY, LayoutVertical}): # main panel

      builder.createLine: builder.createSlider(sliderMin, color(0.5, 0.3, 0.3), color(0.9, 0.6, 0.6), min = -200, max = 200, step = 0.1.float32.some, (value: float32) => (sliderMin = value))
      builder.createLine: builder.createSlider(sliderMax, color(0.3, 0.5, 0.3), color(0.6, 0.9, 0.6), min = -200, max = 200, step = 0.1.float32.some, (v: float32) => (sliderMax = v))
      builder.createLine: builder.createSlider(sliderStep, color(0.3, 0.3, 0.5), color(0.6, 0.6, 0.9), min = 0.1, max = 10, step = 0.1.float32.some, (v: float32) => (sliderStep = v))
      builder.createLine: builder.createSlider(slider, color(0.3, 0.5, 0.3), color(0.6, 0.9, 0.6), min = sliderMin, max = sliderMax, step = sliderStep.some, (v: float32) => (slider = v))
      builder.createLine: builder.createCheckbox(showPopup1, (v: bool) => (showPopup1 = v))
      builder.createLine: builder.createCheckbox(showPopup2, (v: bool) => (showPopup2 = v))

      if not showPopup2:
        builder.createLine: builder.createCheckbox(showPopup2, (v: bool) => (showPopup2 = v))

      builder.panel(&{LayoutHorizontal, FillX, SizeToContentY}): # first row
        builder.button("press me"):
          if btn == MouseButton.Left:
            inc counter
        builder.withText($counter):
          currentNode.textColor = color(1, 1, 1)
          currentNode.backgroundColor = color(0, 0, 0)
        builder.withText(" * "):
          currentNode.textColor = color(1, 1, 1)
          currentNode.backgroundColor = color(0, 0, 0)
        builder.withText($counter):
          currentNode.textColor = color(1, 1, 1)
          currentNode.backgroundColor = color(0, 0, 0)
        builder.withText(" = "):
          currentNode.textColor = color(1, 1, 1)
          currentNode.backgroundColor = color(0, 0, 0)
        builder.withText($(counter * counter)):
          currentNode.textColor = color(1, 1, 1)
          currentNode.backgroundColor = color(0, 0, 0)
        builder.panel(&{FillX, FillY, FillBackground}):
          currentNode.backgroundColor = color(0, 0, 0)

      builder.panel(&{LayoutHorizontal, FillX, SizeToContentY}): # second row
        builder.button("-"):
          if btn == MouseButton.Left:
            testWidth = testWidth / 1.5
        builder.button("+"):
          if btn == MouseButton.Left:
            testWidth = testWidth * 1.5
        builder.panel(&{FillBackground, FillY}, w = testWidth):
          currentNode.setBackgroundColor(0, 1, 0)
        builder.panel(&{FillBackground, FillY}, w = 50):
          currentNode.setBackgroundColor(1, 0, 0)
        builder.panel(&{FillX, FillY, FillBackground}):
          currentNode.setBackgroundColor(0, 0, 1)

      # text area
      if not retainMainText or mainTextChanged or not builder.retain(lastTextArea):
        builder.renderText(testText, 0, cursor, backgroundColor = color(0.1, 0.1, 0.1), textColor = color(0.9, 0.9, 0.9), sizeToContentX = false, id = lastTextArea.some)

      # background filler
      builder.panel(&{FillX, FillY, FillBackground}):
        currentNode.setBackgroundColor(0, 0, 1)

    if showPopup1:
      builder.createPopup(testText2, popup1, backgroundColor = color(0.3, 0.1, 0.1), textColor = color(0.9, 0.5, 0.5), headerColor = color(0.4, 0.2, 0.2), borderColor = color(1, 0.1, 0.1))
    if showPopup2:
      builder.createPopup(testText3, popup2, backgroundColor = color(0.1, 0.3, 0.1), textColor = color(0.5, 0.9, 0.5), headerColor = color(0.2, 0.4, 0.2), borderColor = color(0.1, 1, 0.1))

proc strokeRect*(boxy: Boxy, rect: Rect, color: Color, thickness: float = 1, offset: float = 0) =
  let rect = rect.grow(vec2(thickness * offset, thickness * offset))
  boxy.drawRect(rect.splitV(thickness.relative)[0].shrink(vec2(0, thickness)), color)
  boxy.drawRect(rect.splitVInv(thickness.relative)[1].shrink(vec2(0, thickness)), color)
  boxy.drawRect(rect.splitH(thickness.relative)[0], color)
  boxy.drawRect(rect.splitHInv(thickness.relative)[1], color)

proc drawNode(builder: UINodeBuilder, node: UINode, offset: Vec2 = vec2(0, 0), force: bool = false) =
  var nodePos = offset
  nodePos.x += node.x
  nodePos.y += node.y

  var force = force

  if invalidateOverlapping and not force and node.lastChange < builder.frameIndex:
    return

  if node.flags.any &{FillBackground, DrawBorder, DrawText}:
    drawnNodes.add node
  # drawnNodes.add node

  if node.flags.any &{FillBackground, DrawText}:
    force = true

  debug "draw ", node.dump

  node.lx = nodePos.x
  node.ly = nodePos.y
  node.lw = node.w
  node.lh = node.h
  let bounds = rect(nodePos.x, nodePos.y, node.w, node.h)

  if FillBackground in node.flags:
    bxy.drawRect(bounds, node.backgroundColor)

  # Mask the rest of the rendering is this function to the contentBounds
  if MaskContent in node.flags:
    bxy.pushLayer()
  defer:
    if MaskContent in node.flags:
      bxy.pushLayer()
      bxy.drawRect(bounds, color(1, 0, 0, 1))
      bxy.popLayer(blendMode = MaskBlend)
      bxy.popLayer()

  if DrawText in node.flags:
    let key = node.text
    var imageId: string
    if cachedImages.contains(key):
      imageId = cachedImages[key]
    else:
      imageId = $newId()
      cachedImages[key] = imageId

      # let font = renderer.getFont(renderer.ctx.fontSize * (1 + self.fontSizeIncreasePercent), self.style.fontStyle)

      const wrap = false
      let wrapBounds = if wrap: vec2(node.w, node.h) else: vec2(0, 0)
      let arrangement = font.typeset(node.text, bounds=wrapBounds)
      var bounds = arrangement.layoutBounds()
      if bounds.x == 0:
        bounds.x = 1
      if bounds.y == 0:
        bounds.y = builder.textHeight
      # const textExtraHeight = 10.0
      # bounds.y += textExtraHeight

      var image = newImage(bounds.x.int, bounds.y.int)
      image.fillText(arrangement)
      bxy.addImage(imageId, image, false)

    let pos = vec2(nodePos.x.floor, nodePos.y.floor)
    bxy.drawImage(imageId, pos, node.textColor)

  for _, c in node.children:
    builder.drawNode(c, nodePos, force)

  if DrawBorder in node.flags:
    bxy.strokeRect(bounds, node.borderColor)

proc randomColor(node: UINode, a: float32): Color =
  let h = node.id.hash
  result.r = (((h shr 0) and 0xff).float32 / 255.0).sqrt
  result.g = (((h shr 8) and 0xff).float32 / 255.0).sqrt
  result.b = (((h shr 16) and 0xff).float32 / 255.0).sqrt
  result.a = a

proc renderNewFrame(builder: UINodeBuilder) =
  block:
    # let buildTime = startTimer()
    builder.beginFrame(vec2(image.width.float32, image.height.float32))
    builder.buildUINodes()
    builder.endFrame()
    # echo "[build] ", buildTime.elapsed.ms, "ms"

    if logRoot:
      echo builder.root.dump(true)

    drawnNodes.setLen 0

    let drawTime = startTimer()
    builder.drawNode(builder.root)
    # echo "[draw] ", drawTime.elapsed.ms, "ms (", drawnNodes.len, " nodes)"

    if showDrawnNodes:
      bxy.pushLayer()
      defer:
        bxy.pushLayer()
        bxy.drawRect(rect(image.width.float32, 0, image.width.float32, image.height.float32), color(1, 0, 0, 1))
        bxy.popLayer(blendMode = MaskBlend)
        bxy.popLayer()

      bxy.drawRect(rect(image.width.float32, 0, image.width.float32, image.height.float32), color(0, 0, 0))

      for node in drawnNodes:
        let c = node.randomColor(0.3)
        bxy.drawRect(rect(node.lx + image.width.float32, node.ly, node.lw, node.lh), c)

        if DrawBorder in node.flags:
          bxy.strokeRect(rect(node.lx + image.width.float32, node.ly, node.lw, node.lh), color(c.r, c.g, c.b, 0.5), 5, offset = 0.5)

proc toMouseButton(button: Button): MouseButton =
  result = case button:
    of MouseLeft: MouseButton.Left
    of MouseMiddle: MouseButton.Middle
    of MouseRight: MouseButton.Right
    of DoubleClick: MouseButton.DoubleClick
    of TripleClick: MouseButton.TripleClick
    else: MouseButton.Unknown

window.onMouseMove = proc() =
  var mouseButtons: set[MouseButton]
  for button in set[Button](window.buttonDown):
    mouseButtons.incl button.toMouseButton

  advanceFrame = builder.handleMouseMoved(window.mousePos.vec2, mouseButtons) or advanceFrame

window.onButtonRelease = proc(button: Button) =
  case button
  of MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5, DoubleClick, TripleClick, QuadrupleClick:
    builder.handleMouseReleased(button.toMouseButton, window.mousePos.vec2)
    return
  else:
    return

  advanceFrame = true

window.onButtonPress = proc(button: Button) =
  case button
  of MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5, DoubleClick, TripleClick, QuadrupleClick:
    builder.handleMousePressed(button.toMouseButton, window.mousePos.vec2)

  of Button.KeyX:
    window.closeRequested = true
    return
  of Button.KeyV:
    invalidateOverlapping = not invalidateOverlapping
  of Button.KeyL:
    showDrawnNodes = not showDrawnNodes
  of Button.KeyW:
    retainMainText = not retainMainText
  of Button.KeyU:
    logRoot = not logRoot
  of Button.KeyI:
    logFrameTime = not logFrameTime
  of Button.KeyA:
    logInvalidationRects = not logInvalidationRects
  of Button.KeyE:
    logPanel = not logPanel

  of Button.Key1:
    showPopup1 = not showPopup1

  of Button.Key2:
    showPopup2 = not showPopup2

  of Button.KeyUp:
    cursor[0] = max(0, cursor[0] - 1)
    cursor[1] = cursor[1].clamp(0, testText[cursor[0]].len)
    mainTextChanged = true
  of Button.KeyDown:
    cursor[0] = min(testText.high, cursor[0] + 1)
    cursor[1] = cursor[1].clamp(0, testText[cursor[0]].len)
    mainTextChanged = true

  of Button.KeyLeft:
    cursor[1] = max(0, cursor[1] - 1)
    mainTextChanged = true
  of Button.KeyRight:
    cursor[1] = min(testText[cursor[0]].len, cursor[1] + 1)
    mainTextChanged = true

  of Button.KeyHome:
    cursor[1] = 0
    mainTextChanged = true
  of Button.KeyEnd:
    cursor[1] = testText[cursor[0]].len
    mainTextChanged = true

  else:
    discard

  advanceFrame = true

advanceFrame = true
mainTextChanged = true
while not window.closeRequested:
  let frameTimer = startTimer()

  pollEvents()

  bxy.beginFrame(window.size, clearFrame=false)

  for image in cachedImages.removedKeys:
    bxy.removeImage(image)
  cachedImages.clearRemovedKeys()

  let tAdvanceFrame = startTimer()
  if advanceFrame:
    builder.renderNewFrame()
  let msAdvanceFrame = tAdvanceFrame.elapsed.ms

  bxy.endFrame()

  if advanceFrame:
    if logFrameTime:
      echo fmt"[frame] {drawnNodes.len} {frameTimer.elapsed.ms}, advance: {msAdvanceFrame}"

    glBindFramebuffer(GL_READ_FRAMEBUFFER, framebufferId)
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0)
    glBlitFramebuffer(
      0, 0, framebuffer.width.GLint, framebuffer.height.GLint,
      0, 0, window.size.x.GLint, window.size.y.GLint,
      GL_COLOR_BUFFER_BIT, GL_NEAREST.GLenum)

    window.swapBuffers()

  else:
    sleep(3)

  advanceFrame = false
  mainTextChanged = false

window.close()