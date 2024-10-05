import std/[strformat, strutils, os]
import misc/[custom_unicode, custom_logger]
import document, ui/node
import chroma

{.push stacktrace:off.}
{.push linetrace:off.}

logCategory "wigdet-library"

template createHeader*(builder: UINodeBuilder, inRenderHeader: bool, inMode: string,
    inDocument: Document, inHeaderColor: Color, inTextColor: Color, body: untyped): UINode =

  block:
    var leftFunc: proc() {.gcsafe.}
    var rightFunc: proc() {.gcsafe.}

    template onLeft(inBody: untyped) {.used.} =
      leftFunc = proc() {.gcsafe.} =
        inBody

    template onRight(inBody: untyped) {.used.} =
      rightFunc = proc() {.gcsafe.} =
        inBody

    body

    var bar: UINode
    if inRenderHeader:
      builder.panel(&{FillX, SizeToContentY, FillBackground, LayoutHorizontal},
          backgroundColor = inHeaderColor):

        bar = currentNode

        let isDirty = inDocument.lastSavedRevision != inDocument.revision
        let dirtyMarker = if isDirty: "*" else: ""

        let workspaceName = inDocument.workspace.map(wf => " - " & wf.name).get("")
        let modeText = if inMode.len == 0: "-" else: inMode
        let (directory, filename) = inDocument.filename.splitPath
        let text = " $# - $#$# - $#$# " % [modeText, dirtyMarker, filename, directory, workspaceName]
        builder.panel(&{SizeToContentX, SizeToContentY, DrawText}, textColor = inTextColor, text = text)

        if leftFunc.isNotNil:
          leftFunc()

        builder.panel(&{FillX, SizeToContentY, LayoutHorizontalReverse}):
          if rightFunc.isNotNil:
            rightFunc()

    else:
      builder.panel(&{FillX}):
        bar = currentNode

    bar

proc createLines*(builder: UINodeBuilder, previousBaseIndex: int, scrollOffset: float,
    maxLine: int, maxHeight: Option[float], flags: UINodeFlags, backgroundColor: Color,
    handleScroll: proc(delta: float) {.gcsafe.}, handleLine: proc(line: int, y: float, down: bool) {.gcsafe.}): UINode =

  let sizeToContentY = SizeToContentY in flags
  builder.panel(flags):
    result = currentNode

    onScroll:
      handleScroll(delta.y)

    let height = currentNode.bounds.h
    var y = scrollOffset

    # draw lines downwards
    for i in previousBaseIndex..maxLine:
      handleLine(i, y, true)

      y = builder.currentChild.yh
      if not sizeToContentY and builder.currentChild.bounds.y > height:
        break

      if maxHeight.getSome(maxHeight) and builder.currentChild.bounds.y > maxHeight:
        break

    if y < height: # fill remaining space with background color
      builder.panel(&{FillX, FillY, FillBackground}, y = y, backgroundColor = backgroundColor)

    y = scrollOffset

    # draw lines upwards
    for i in countdown(min(previousBaseIndex - 1, maxLine), 0):
      handleLine(i, y, false)

      y = builder.currentChild.y
      if not sizeToContentY and builder.currentChild.bounds.yh < 0:
        break

      if maxHeight.isSome and builder.currentChild.bounds.yh < 0:
        break

    if not sizeToContentY and y > 0: # fill remaining space with background color
      builder.panel(&{FillX, FillBackground}, h = y, backgroundColor = backgroundColor)

proc createLines*(builder: UINodeBuilder, previousBaseIndex: int, scrollOffset: float,
    maxLine: int, sizeToContentX: bool, sizeToContentY: bool, backgroundColor: Color,
    handleScroll: proc(delta: float) {.gcsafe.}, handleLine: proc(line: int, y: float, down: bool) {.gcsafe.}) =
  var flags = 0.UINodeFlags
  if sizeToContentX:
    flags.incl SizeToContentX
  else:
    flags.incl FillX

  if sizeToContentY:
    flags.incl SizeToContentY
  else:
    flags.incl FillY

  discard builder.createLines(previousBaseIndex, scrollOffset, maxLine, float.none, flags,
    backgroundColor, handleScroll, handleLine)

proc updateBaseIndexAndScrollOffset*(height: float, previousBaseIndex: var int, scrollOffset: var float,
    lines: int, totalLineHeight: float, targetLine: Option[int], margin: float = 0.0) =

  if targetLine.getSome(targetLine):
    let targetLineY = (targetLine - previousBaseIndex).float32 * totalLineHeight + scrollOffset

    if targetLineY < margin:
      scrollOffset = margin
      previousBaseIndex = targetLine
    elif targetLineY + totalLineHeight > height - margin:
      scrollOffset = height - margin - totalLineHeight
      previousBaseIndex = targetLine

  previousBaseIndex = previousBaseIndex.clamp(0..lines)

  # Adjust scroll offset and base index so that the first node on screen is the base
  while scrollOffset < 0 and previousBaseIndex + 1 < lines:
    if scrollOffset + totalLineHeight >= height:
      break
    previousBaseIndex += 1
    scrollOffset += totalLineHeight

  # Adjust scroll offset and base index so that the first node on screen is the base
  while scrollOffset > height and previousBaseIndex > 0:
    if scrollOffset - totalLineHeight <= 0:
      break
    previousBaseIndex -= 1
    scrollOffset -= totalLineHeight

proc createAbbreviatedText*(builder: UINodeBuilder, text: string, oversize: int, ellipsis: string,
    color: Color, flags: UINodeFlags = 0.UINodeFlags) =

  let textFlags = &{DrawText, SizeToContentX, SizeToContentY} + flags
  let partRuneLen = text.runeLen.int
  let cutoutStartRune = max(0, ((partRuneLen - oversize) div 2) - (ellipsis.len div 2) + 1)
  let cutoutStart = text.runeOffset cutoutStartRune.RuneIndex
  let cutoutEnd = text.runeOffset (cutoutStart + oversize + ellipsis.len).RuneIndex

  if cutoutStart > 0:
    builder.panel(textFlags, text = text[0..<cutoutStart], textColor = color)

  builder.panel(textFlags, text = ellipsis, textColor = color.darken(0.2))

  if cutoutEnd < text.len:
    builder.panel(textFlags, text = text[cutoutEnd..^1], textColor = color)

proc createTextWithMaxWidth*(builder: UINodeBuilder, text: string, maxWidth: int, ellipsis: string,
    color: Color, flags: UINodeFlags = 0.UINodeFlags): UINode =

  let oversize = text.runeLen.int - maxWidth
  if oversize > 0:
    builder.panel(&{LayoutHorizontal, SizeToContentX, SizeToContentY}):
      result = currentNode
      builder.createAbbreviatedText(text, oversize, ellipsis, color, flags)
  else:
    let textFlags = &{DrawText, SizeToContentX, SizeToContentY} + flags
    builder.panel(textFlags + flags, text = text, textColor = color):
      result = currentNode

proc highlightedText*(builder: UINodeBuilder, text: string, highlightedIndices: openArray[int],
    color: Color, highlightColor: Color, maxWidth: int = int.high): UINode =
  ## Create a text panel wher the characters at the indices in `highlightedIndices` are highlighted
  ## with `highlightColor`.

  const ellipsis = "..."

  let runeLen = text.runeLen.int

  # How much we're over the limit, gets reduced as we replace text with ...
  var oversize = runeLen - maxWidth

  let textFlags = &{DrawText, SizeToContentX, SizeToContentY}

  if highlightedIndices.len > 0:
    builder.panel(&{SizeToContentX, SizeToContentY, LayoutHorizontal}):
      result = currentNode
      var start = 0
      for matchIndex in highlightedIndices:
        if matchIndex >= text.len:
          break

        # Add non highlighted text between last highlight and before next
        if matchIndex > start:
          let partText = text[start..<matchIndex]
          let partOversizeMax = partText.runeLen.int - ellipsis.len
          if oversize > 0 and partOversizeMax > 0:
            let partOversize = min(oversize, partOversizeMax)
            builder.createAbbreviatedText(partText, partOversize, ellipsis, color)
            oversize -= partOversize

          else:
            builder.panel(textFlags, text = partText, textColor = color)

        # Add highlighted text
        builder.panel(textFlags, text = $text.runeAt(matchIndex),
          textColor = highlightColor)

        start = text.nextRuneStart(matchIndex)

      # Add non highlighted part at end of text
      if start < text.len:
        let partText = text[start..^1]
        let partOversizeMax = partText.runeLen.int - ellipsis.len
        if oversize > 0 and partOversizeMax > 0:
          let partOversize = min(oversize, partOversizeMax)
          builder.createAbbreviatedText(partText, partOversize, ellipsis, color)

        else:
          builder.panel(textFlags, text = partText, textColor = color)

  else:
    if oversize > 0:
      builder.panel(&{LayoutHorizontal, SizeToContentX, SizeToContentY}):
        result = currentNode
        builder.createAbbreviatedText(text, oversize, ellipsis, color)

    else:
      builder.panel(textFlags, text = text, textColor = color):
        result = currentNode
