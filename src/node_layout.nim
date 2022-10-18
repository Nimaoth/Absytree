import std/[tables, strformat]
import fusion/matching
import pixie/fonts, bumpy, chroma, vmath, theme
import compiler, ast, util, id

proc measureText*(font: Font, text: string): Vec2 = font.typeset(text).layoutBounds()

proc newFont*(typeface: Typeface, fontSize: float32): Font {.raises: [].} =
  result = newFont(typeface)
  result.size = fontSize

proc getPrecedenceForNode(ctx: Context, node: AstNode): int =
  if node.kind != Call or node.len == 0:
    return 0
  if ctx.computeSymbol(node[0], false).getSome(symbol):
    case symbol.kind
    of skBuiltin:
      return symbol.precedence
    of skAstNode:
      discard

  return 0

type
  VisualLayoutColorConfig = object
    separator: string
    separatorParen: seq[string]
    separatorBrace: seq[string]
    separatorBracket: seq[string]
    empty: string
    keyword: string
    typ: string

  VisualLayoutConfig* = object
    colors*: VisualLayoutColorConfig
    font*: Font
    fontRegular: string
    fontBold*: string
    fontItalic*: string
    fontBoldItalic*: string
    indent*: float32
    revision*: int

proc `==`(a: Font, b: Font): bool =
  if a.isNil: return b.isNil
  if b.isNil: return false
  if a.size != b.size: return false
  if a.lineHeight != b.lineHeight: return false
  if a.textCase != b.textCase: return false
  if a.underline != b.underline: return false
  if a.strikethrough != b.strikethrough: return false
  if a.noKerningAdjustments != b.noKerningAdjustments: return false
  if a.typeface != b.typeface: return false
  if a.paints != b.paints: return false
  return true

template createConfigAccessor(member: untyped, typ: type) =
  proc member*(config: var VisualLayoutConfig): typ = config.member
  proc `member=`*(config: var VisualLayoutConfig, newValue: typ) =
    if config.member != newValue:
      config.revision += 1
    config.member = newValue

createConfigAccessor(colors, VisualLayoutColorConfig)
createConfigAccessor(fontFont, Font)
createConfigAccessor(fontRegular, string)
createConfigAccessor(fontBold, string)
createConfigAccessor(fontItalic, string)
createConfigAccessor(fontBoldItalic, string)
createConfigAccessor(indent, float32)

var config* =  VisualLayoutConfig(
  font: newFont(readTypeface("fonts/DejaVuSansMono.ttf"), 20),
  fontRegular: "fonts/DejaVuSansMono.ttf",
  fontBold: "fonts/DejaVuSansMono-Bold.ttf",
  fontItalic: "fonts/DejaVuSansMono-Oblique.ttf",
  fontBoldItalic: "fonts/DejaVuSansMono-BoldOblique.ttf",
  indent: 15,
  colors: VisualLayoutColorConfig(
    separator: "punctuation",
    separatorParen: @["meta.brace.round", "punctuation", "&editor.foreground"],
    separatorBrace: @["meta.brace.curly", "punctuation", "&editor.foreground"],
    separatorBracket: @["meta.brace.square", "punctuation", "&editor.foreground"],
    empty: "string",
    keyword: "keyword",
    typ: "storage.type",
  ),
)

proc getFont*(config: VisualLayoutConfig, style: set[FontStyle]): string =
  if Italic in style and Bold in style:
    return config.fontBoldItalic
  if Italic in style:
    return config.fontItalic
  if Bold in style or Underline in style:
    return config.fontBold
  return config.fontRegular

proc newTextNode*(text: string, color: string, font: Font, node: AstNode = nil): VisualNode =
  result = VisualNode(text: text, colors: @[color], font: font, node: node)
  result.bounds.wh = font.measureText(text)

proc newTextNode*(text: string, colors: seq[string], font: Font, node: AstNode = nil): VisualNode =
  result = VisualNode(text: text, colors: colors, font: font, node: node)
  result.bounds.wh = font.measureText(text)

proc newFunctionNode*(bounds: Rect, render: VisualNodeRenderFunc): VisualNode =
  result = VisualNode(bounds: bounds, render: render)

proc createReplacement(input: NodeLayoutInput, node: AstNode, layout: var NodeLayout, line: var VisualNode): bool =
  if input.replacements.contains(node.id):
    layout.nodeToVisualNode[node.id] = line.add input.replacements[node.id].clone
    return true
  if input.replacements.contains(node.reff):
    layout.nodeToVisualNode[node.id] = line.add input.replacements[node.reff].clone
    return true
  return false

proc getColorForSymbol*(ctx: Context, sym: Symbol): seq[string] =
  let typ = ctx.computeSymbolType(sym, false)
  case typ.kind
  of tError: return @["invalid"]
  of tType: return @["storage.type"]
  of tFunction:
    if sym.kind == skBuiltin:
      case sym.operatorNotation
      of Prefix, Infix, Postfix: return @["keyword.operator"]
      else: return @["variable.function", "variable"]
    return @["variable.function", "variable"]
  elif sym.kind == skAstNode:
    if sym.node.kind == ConstDecl: return @["variable.other.constant", "variable"]
    elif sym.node.kind == VarDecl or sym.node.kind == LetDecl:
      if sym.node.parent.kind == Params: return @["variable.parameter", "variable"]
      else: return @["variable"]
    else: return @["variable.other", "variable"]

  return @["variable.other", "variable"]

proc createLayoutLineForNode(ctx: Context, input: NodeLayoutInput, node: AstNode, result: var NodeLayout, line: var VisualNode) =
  let renderInline = node.kind in {While, If, NodeList} and node.parent.kind in {Call}

  var prevLine = line
  let first = prevLine.children.len
  defer:
    if first < prevLine.children.len:
      result.nodeToVisualNode[node.id] = VisualNodeRange(parent: prevLine, first: first, last: prevLine.children.len)

  var oldLine = line
  var containerLine = VisualNode(node: node, parent: line)
  if renderInline:
    line = VisualNode(parent: containerLine)

  defer:
    if renderInline:
      containerLine.addLine line
      result.nodeToVisualNode[node.id] = oldLine.add(containerLine)
      line = oldLine

  # force computation of type so that errors diagnostics can be generated
  discard ctx.computeType(node, false)

  case node
  of Empty():
    if not input.createReplacement(node, result, line):
      result.nodeToVisualNode[node.id] = line.add VisualNode(colors: @[config.colors.empty], node: node, bounds: rect(vec2(), vec2(config.font.size * 0.5, config.font.size)))

  of NumberLiteral():
    if not input.createReplacement(node, result, line):
      result.nodeToVisualNode[node.id] = line.add newTextNode(node.text, "constant.numeric", config.font, node)

  of StringLiteral():
    discard line.add newTextNode("\"", @["punctuation.definition.string", config.colors.separator, "&editor.foreground"], config.font)
    if not input.createReplacement(node, result, line):
      discard line.add newTextNode(node.text, "string", config.font, node)
    discard line.add newTextNode("\"", @["punctuation.definition.string", config.colors.separator, "&editor.foreground"], config.font)

  of Identifier():
    if not input.createReplacement(node, result, line):
      if ctx.computeSymbol(node, false).getSome(sym):
        result.nodeToVisualNode[node.id] = line.add newTextNode(sym.name, ctx.getColorForSymbol(sym), config.font, node)
      else:
        result.nodeToVisualNode[node.id] = line.add newTextNode($node.reff, "variable", config.font, node)

  of ConstDecl():
    if not input.createReplacement(node, result, line):
      let color = if ctx.computeSymbol(node, false).getSome(sym): ctx.getColorForSymbol(sym)
      else: @["entity.name.constant"]

      if ctx.computeSymbol(node, false).getSome(sym):
        discard line.add newTextNode(sym.name, color, config.font, node)
      else:
        discard line.add newTextNode($node.id, color, config.font, node)

    let typ = ctx.computeType(node, false)
    if typ.kind == tFunction:
      discard line.add newTextNode(" :: ", @[config.colors.separator, "&editor.foreground"], config.font)
    else:
      discard line.add newTextNode(" : ", @[config.colors.separator, "&editor.foreground"], config.font)
      discard line.add newTextNode($typ, config.colors.typ, config.font)
      discard line.add newTextNode(" : ", @[config.colors.separator, "&editor.foreground"], config.font)

    if node.len > 0:
      ctx.createLayoutLineForNode(input, node[0], result, line)

      let value = ctx.computeValue(node, false)
      case value.kind
      of vkAstFunction, vkBuiltinFunction, vkVoid: discard
      else:
        case node[0].kind
        of StringLiteral, NumberLiteral: discard
        else:
          discard line.add newTextNode(" = ", @[config.colors.separator, "&editor.foreground"], config.font)
          discard line.add newTextNode($value, "string", config.font)

  of LetDecl():
    if not input.createReplacement(node, result, line):
      let color = if ctx.computeSymbol(node, false).getSome(sym): ctx.getColorForSymbol(sym)
      else: @["variable"]

      discard line.add newTextNode(node.text, color, config.font, node)

    discard line.add newTextNode(" : ", @[config.colors.separator, "&editor.foreground"], config.font)

    if node.len > 0:
      if node[0].kind == Empty and node[0].text.len == 0 and not input.replacements.contains(node[0].id):
        let typ = ctx.computeType(node, false)
        result.nodeToVisualNode[node[0].id] = line.add newTextNode($typ, config.colors.typ, config.font, node[0])
      else:
        ctx.createLayoutLineForNode(input, node[0], result, line)

    if node.len > 1:
      discard line.add newTextNode(" = ", @[config.colors.separator, "&editor.foreground"], config.font)
      ctx.createLayoutLineForNode(input, node[1], result, line)

  of VarDecl():
    if not input.createReplacement(node, result, line):
      let color = if ctx.computeSymbol(node, false).getSome(sym): ctx.getColorForSymbol(sym)
      else: @["variable"]

      discard line.add newTextNode(node.text, color, config.font, node)

    discard line.add newTextNode(" : mut ", @[config.colors.separator, "&editor.foreground"], config.font)

    if node.len > 0:
      if node[0].kind == Empty and node[0].text.len == 0 and not input.replacements.contains(node[0].id):
        let typ = ctx.computeType(node, false)
        result.nodeToVisualNode[node[0].id] = line.add newTextNode($typ, config.colors.typ, config.font, node[0])
      else:
        ctx.createLayoutLineForNode(input, node[0], result, line)

    if node.len > 1:
      discard line.add newTextNode(" = ", @[config.colors.separator, "&editor.foreground"], config.font)
      ctx.createLayoutLineForNode(input, node[1], result, line)

  of FunctionDefinition():
    discard line.add newTextNode("fn", config.colors.keyword, config.font)
    discard line.add newTextNode("(", config.colors.separatorParen, config.font)

    if node.len > 0:
      var parent = line
      let first = parent.len
      for i, param in node[0].children:
        if i > 0:
          discard line.add newTextNode(", ", @[config.colors.separator, "&editor.foreground"], config.font)

        ctx.createLayoutLineForNode(input, param, result, line)

      if node[0].len == 0:
        result.nodeToVisualNode[node[0].id] = line.add newTextNode(" ", config.colors.empty, config.font, node[0])
      else:
        result.nodeToVisualNode[node[0].id] = VisualNodeRange(parent: parent, first: first, last: parent.len)


    discard line.add newTextNode(") ", config.colors.separatorParen, config.font)

    if node.len > 1:
      ctx.createLayoutLineForNode(input, node[1], result, line)

    discard line.add newTextNode(" = ", @[config.colors.separator, "&editor.foreground"], config.font)

    if node.len > 2:
      ctx.createLayoutLineForNode(input, node[2], result, line)

  of If():
    var parent = line.parent
    let prevIndent = line.indent

    let first = parent.children.len
    defer:
      if first < parent.children.len:
        result.nodeToVisualNode[node.id] = VisualNodeRange(parent: parent, first: first, last: parent.children.len)

    var i = 0
    while i + 1 < node.len:
      defer: i += 2

      if i == 0:
        discard line.add newTextNode("if ", config.colors.keyword, config.font)
      else:
        parent.addLine(line)
        line = VisualNode(parent: parent, bounds: rect(prevIndent, 0, 0, 0), indent: prevIndent)
        discard line.add newTextNode("elif ", config.colors.keyword, config.font)

      ctx.createLayoutLineForNode(input, node[i], result, line)
      discard line.add newTextNode(": ", @[config.colors.separator, "&editor.foreground"], config.font)

      ctx.createLayoutLineForNode(input, node[i + 1], result, line)

    if node.len mod 2 == 1:
      parent.addLine(line)
      line = VisualNode(parent: parent, bounds: rect(prevIndent, 0, 0, 0), indent: prevIndent)
      discard line.add newTextNode("else: ", config.colors.keyword, config.font)
      ctx.createLayoutLineForNode(input, node.last, result, line)

    parent.addLine(line)
    line = VisualNode(parent: parent, bounds: rect(prevIndent, 0, 0, 0), indent: prevIndent)

  of While():
    discard line.add newTextNode("while ", config.colors.keyword, config.font)

    if node.len >= 1:
      ctx.createLayoutLineForNode(input, node[0], result, line)

    discard line.add newTextNode(": ", @[config.colors.separator, "&editor.foreground"], config.font)

    if node.len >= 2:
      ctx.createLayoutLineForNode(input, node[1], result, line)

  of NodeList():
    var parent = line.parent
    let first = parent.children.len + 1
    defer:
      if first < parent.children.len:
        result.nodeToVisualNode[node.id] = VisualNodeRange(parent: parent, first: first, last: parent.children.len)

    let prevIndent = line.indent
    for child in node.children:
      parent.addLine(line)
      line = VisualNode(parent: parent, bounds: rect(prevIndent, 0, config.indent, 0), indent: prevIndent + config.indent, node: child)
      ctx.createLayoutLineForNode(input, child, result, line)

    parent.addLine(line)
    line = VisualNode(parent: parent, bounds: rect(prevIndent, 0, 0, 0), indent: prevIndent)

  of Assignment():
    if node.len > 0:
      ctx.createLayoutLineForNode(input, node[0], result, line)
    discard line.add newTextNode(" = ", @[config.colors.separator, "&editor.foreground"], config.font)
    if node.len > 0:
      ctx.createLayoutLineForNode(input, node[1], result, line)

  of Call():
    if node.len == 0:
      result.nodeToVisualNode[node.id] = line.add newTextNode("<empty function call>", config.colors.empty, config.font, node)
      return

    let operatorNotation = if ctx.computeSymbol(node[0], false).getSome(sym) and sym.kind == skBuiltin:
      let arity = case sym.operatorNotation
      of Infix: 2
      of Prefix, Postfix: 1
      else: -1

      if node.len == arity + 1:
        sym.operatorNotation
      else:
        Regular
    else:
      Regular

    case operatorNotation
    of Infix:
      let parentPrecedence = ctx.getPrecedenceForNode node.parent
      let precedence = ctx.getPrecedenceForNode node
      let renderParens = precedence < parentPrecedence

      if renderParens:
        discard line.add newTextNode("(", config.colors.separatorParen, config.font)

      ctx.createLayoutLineForNode(input, node[1], result, line)
      discard line.add newTextNode(" ", config.colors.separator, config.font)
      ctx.createLayoutLineForNode(input, node[0], result, line)
      discard line.add newTextNode(" ", config.colors.separator, config.font)
      ctx.createLayoutLineForNode(input, node[2], result, line)

      if renderParens:
        discard line.add newTextNode(")", config.colors.separatorParen, config.font)

    of Prefix:
      ctx.createLayoutLineForNode(input, node[0], result, line)
      ctx.createLayoutLineForNode(input, node[1], result, line)
    of Postfix:
      ctx.createLayoutLineForNode(input, node[1], result, line)
      ctx.createLayoutLineForNode(input, node[0], result, line)

    else:
      if node.len > 0:
        ctx.createLayoutLineForNode(input, node[0], result, line)

      discard line.add newTextNode("(", config.colors.separatorParen, config.font)

      for i in 1..<node.len:
        if i > 1:
          discard line.add newTextNode(", ", @[config.colors.separator, "&editor.foreground"], config.font)
        ctx.createLayoutLineForNode(input, node[i], result, line)

      discard line.add newTextNode(")", config.colors.separatorParen, config.font)

  else:
    echo "createLayoutLineForNode not implemented for ", node.kind

proc computeNodeLayoutImpl2*(ctx: Context, input: NodeLayoutInput): NodeLayout =
  # echo fmt"computeNodeLayoutImpl2 {input.node}"
  let node = input.node
  result = NodeLayout(root: VisualNode(), nodeToVisualNode: initTable[Id, VisualNodeRange]())
  var line = VisualNode(node: node, parent: result.root)
  ctx.createLayoutLineForNode(input, node, result, line)
  line.parent.addLine(line)

