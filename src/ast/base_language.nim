import std/[strformat, sugar]
import platform/[widgets]
import id, ast_ids, util, custom_logger
import types, cells
import print

let typeClass* = newNodeClass(IdType, "Type", isAbstract=true)
let stringTypeClass* = newNodeClass(IdString, "StringType", alias="string", base=typeClass)
let intTypeClass* = newNodeClass(IdInt, "IntType", alias="int", base=typeClass)
let voidTypeClass* = newNodeClass(IdVoid, "VoidType", alias="void", base=typeClass)
let functionTypeClass* = newNodeClass(IdFunctionType, "FunctionType", base=typeClass,
  children=[
    NodeChildDescription(id: IdFunctionTypeReturnType, role: "returnType", class: typeClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdFunctionTypeParameterTypes, role: "parameterTypes", class: typeClass.id, count: ChildCount.ZeroOrMore)])

let namedInterface* = newNodeClass(IdINamed, "INamed", isAbstract=true, isInterface=true,
  properties=[PropertyDescription(id: IdINamedName, role: "name", typ: PropertyType.String)])

let declarationInterface* = newNodeClass(IdIDeclaration, "IDeclaration", isAbstract=true, isInterface=true, base=namedInterface)

let expressionClass* = newNodeClass(IdExpression, "Expression", isAbstract=true)
let binaryExpressionClass* = newNodeClass(IdBinaryExpression, "BinaryExpression", isAbstract=true, base=expressionClass, children=[
    NodeChildDescription(id: IdBinaryExpressionLeft, role: "left", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdBinaryExpressionRight, role: "right", class: expressionClass.id, count: ChildCount.One),
  ])
let unaryExpressionClass* = newNodeClass(IdUnaryExpression, "UnaryExpression", isAbstract=true, base=expressionClass, children=[
    NodeChildDescription(id: IdUnaryExpressionChild, role: "child", class: expressionClass.id, count: ChildCount.One),
  ])

let emptyLineClass* = newNodeClass(IdEmptyLine, "EmptyLine", base=expressionClass)

let addExpressionClass* = newNodeClass(IdAdd, "BinaryAddExpression", alias="+", base=binaryExpressionClass)
let subExpressionClass* = newNodeClass(IdSub, "BinarySubExpression", alias="-", base=binaryExpressionClass)
let mulExpressionClass* = newNodeClass(IdMul, "BinaryMulExpression", alias="*", base=binaryExpressionClass)
let divExpressionClass* = newNodeClass(IdDiv, "BinaryDivExpression", alias="/", base=binaryExpressionClass)
let modExpressionClass* = newNodeClass(IdMod, "BinaryModExpression", alias="%", base=binaryExpressionClass)

let appendStringExpressionClass* = newNodeClass(IdAppendString, "BinaryAppendStringExpression", alias="&", base=binaryExpressionClass)
let lessExpressionClass* = newNodeClass(IdLess, "BinaryLessExpression", alias="<", base=binaryExpressionClass)
let lessEqualExpressionClass* = newNodeClass(IdLessEqual, "BinaryLessEqualExpression", alias="<=", base=binaryExpressionClass)
let greaterExpressionClass* = newNodeClass(IdGreater, "BinaryGreaterExpression", alias=">", base=binaryExpressionClass)
let greaterEqualExpressionClass* = newNodeClass(IdGreaterEqual, "BinaryGreaterEqualExpression", alias=">=", base=binaryExpressionClass)
let equalExpressionClass* = newNodeClass(IdEqual, "BinaryEqualExpression", alias="==", base=binaryExpressionClass)
let notEqualExpressionClass* = newNodeClass(IdNotEqual, "BinaryNotEqualExpression", alias="!=", base=binaryExpressionClass)
let andExpressionClass* = newNodeClass(IdAnd, "BinaryAndExpression", alias="and", base=binaryExpressionClass)
let orExpressionClass* = newNodeClass(IdOr, "BinaryOrExpression", alias="or", base=binaryExpressionClass)
let orderExpressionClass* = newNodeClass(IdOrder, "BinaryOrderExpression", alias="<=>", base=binaryExpressionClass)

let negateExpressionClass* = newNodeClass(IdNegate, "UnaryNegateExpression", alias="-", base=unaryExpressionClass)
let notExpressionClass* = newNodeClass(IdNot, "UnaryNotExpression", alias="!", base=unaryExpressionClass)

let printExpressionClass* = newNodeClass(IdPrint, "PrintExpression", alias="print", base=expressionClass,
  children=[
    NodeChildDescription(id: IdPrintArguments, role: "arguments", class: expressionClass.id, count: ChildCount.ZeroOrMore)])

let buildExpressionClass* = newNodeClass(IdBuildString, "BuildExpression", alias="build", base=expressionClass,
  children=[
    NodeChildDescription(id: IdBuildArguments, role: "arguments", class: expressionClass.id, count: ChildCount.ZeroOrMore)])

let emptyClass* = newNodeClass(IdEmpty, "Empty", base=expressionClass)
let nodeReferenceClass* = newNodeClass(IdNodeReference, "NodeReference", alias="ref", base=expressionClass, references=[NodeReferenceDescription(id: IdNodeReferenceTarget, role: "target", class: declarationInterface.id)])
let numberLiteralClass* = newNodeClass(IdIntegerLiteral, "IntegerLiteral", alias="number literal", base=expressionClass, properties=[PropertyDescription(id: IdIntegerLiteralValue, role: "value", typ: PropertyType.Int)])
let stringLiteralClass* = newNodeClass(IdStringLiteral, "StringLiteral", alias="''", base=expressionClass, properties=[PropertyDescription(id: IdStringLiteralValue, role: "value", typ: PropertyType.String)])
let boolLiteralClass* = newNodeClass(IdBoolLiteral, "BoolLiteral", alias="bool", base=expressionClass, properties=[PropertyDescription(id: IdBoolLiteralValue, role: "value", typ: PropertyType.Bool)])

let constDeclClass* = newNodeClass(IdConstDecl, "ConstDecl", alias="const", base=expressionClass, interfaces=[declarationInterface],
  children=[
    NodeChildDescription(id: IdConstDeclType, role: "type", class: typeClass.id, count: ChildCount.ZeroOrOne),
    NodeChildDescription(id: IdConstDeclValue, role: "value", class: expressionClass.id, count: ChildCount.One)])

let letDeclClass* = newNodeClass(IdLetDecl, "LetDecl", alias="let", base=expressionClass, interfaces=[declarationInterface],
  children=[
    NodeChildDescription(id: IdLetDeclType, role: "type", class: typeClass.id, count: ChildCount.ZeroOrOne),
    NodeChildDescription(id: IdLetDeclValue, role: "value", class: expressionClass.id, count: ChildCount.ZeroOrOne)])

let varDeclClass* = newNodeClass(IdVarDecl, "VarDecl", alias="var", base=expressionClass, interfaces=[declarationInterface],
  children=[
    NodeChildDescription(id: IdVarDeclType, role: "type", class: typeClass.id, count: ChildCount.ZeroOrOne),
    NodeChildDescription(id: IdVarDeclValue, role: "value", class: expressionClass.id, count: ChildCount.ZeroOrOne)])

let nodeListClass* = newNodeClass(IdNodeList, "NodeList",
  children=[
    NodeChildDescription(id: IdNodeListChildren, role: "children", class: expressionClass.id, count: ChildCount.ZeroOrMore)])

let blockClass* = newNodeClass(IdBlock, "Block", alias="{", base=expressionClass,
  children=[
    NodeChildDescription(id: IdBlockChildren, role: "children", class: expressionClass.id, count: ChildCount.ZeroOrMore)])

let callClass* = newNodeClass(IdCall, "Call", base=expressionClass,
  children=[
    NodeChildDescription(id: IdCallFunction, role: "function", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdCallArguments, role: "arguments", class: expressionClass.id, count: ChildCount.ZeroOrMore)])

let ifClass* = newNodeClass(IdIfExpression, "IfExpression", alias="if", base=expressionClass, children=[
    NodeChildDescription(id: IdIfExpressionCondition, role: "condition", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdIfExpressionThenCase, role: "thenCase", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdIfExpressionElseCase, role: "elseCase", class: expressionClass.id, count: ChildCount.ZeroOrOne),
  ])

let whileClass* = newNodeClass(IdWhileExpression, "WhileExpression", alias="while", base=expressionClass, children=[
    NodeChildDescription(id: IdWhileExpressionCondition, role: "condition", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdWhileExpressionBody, role: "body", class: expressionClass.id, count: ChildCount.One),
  ])

let parameterDeclClass* = newNodeClass(IdParameterDecl, "ParameterDecl", alias="param", base=expressionClass, interfaces=[declarationInterface],
  children=[
    NodeChildDescription(id: IdParameterDeclType, role: "type", class: typeClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdParameterDeclValue, role: "value", class: expressionClass.id, count: ChildCount.ZeroOrOne)])

let functionDefinitionClass* = newNodeClass(IdFunctionDefinition, "FunctionDefinition", alias="fn", base=expressionClass,
  children=[
    NodeChildDescription(id: IdFunctionDefinitionParameters, role: "parameters", class: parameterDeclClass.id, count: ChildCount.ZeroOrMore),
    NodeChildDescription(id: IdFunctionDefinitionReturnType, role: "returnType", class: typeClass.id, count: ChildCount.ZeroOrOne),
    NodeChildDescription(id: IdFunctionDefinitionBody, role: "body", class: expressionClass.id, count: ChildCount.One)])

let assignmentClass* = newNodeClass(IdAssignment, "Assignment", alias="=", base=expressionClass, children=[
    NodeChildDescription(id: IdAssignmentTarget, role: "target", class: expressionClass.id, count: ChildCount.One),
    NodeChildDescription(id: IdAssignmentValue, role: "value", class: expressionClass.id, count: ChildCount.One),
  ])

var builder = newCellBuilder()

builder.addBuilderFor emptyLineClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = ConstantCell(id: newId(), node: node)
  return cell

builder.addBuilderFor emptyClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = ConstantCell(id: newId(), node: node)
  return cell

builder.addBuilderFor numberLiteralClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = PropertyCell(id: newId(), node: node, property: IdIntegerLiteralValue, themeForegroundColors: @["constant.numeric"])
  return cell

builder.addBuilderFor boolLiteralClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = PropertyCell(id: newId(), node: node, property: IdBoolLiteralValue, themeForegroundColors: @["constant.numeric"])
  return cell

builder.addBuilderFor stringLiteralClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.add ConstantCell(node: node, text: "'", style: CellStyle(noSpaceRight: true), disableEditing: true, deleteImmediately: true, themeForegroundColors: @["punctuation.definition.string", "punctuation", "&editor.foreground"])
  cell.add PropertyCell(node: node, property: IdStringLiteralValue, themeForegroundColors: @["string"])
  cell.add ConstantCell(node: node, text: "'", style: CellStyle(noSpaceLeft: true), disableEditing: true, deleteImmediately: true, themeForegroundColors: @["punctuation.definition.string", "punctuation", "&editor.foreground"])
  return cell

proc buildDefaultPlaceholder(builder: CellBuilder, node: AstNode, role: Id): Cell =
  return PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")

proc buildChildren(builder: CellBuilder, node: AstNode, role: Id, layout: WPanelLayoutKind,
    isVisible: proc(node: AstNode): bool = nil,
    separatorFunc: proc(builder: CellBuilder): Cell = nil,
    placeholderFunc: proc(builder: CellBuilder, node: AstNode, role: Id): Cell = buildDefaultPlaceholder): Cell =

  let children = node.children(role)
  if children.len > 1 or (children.len == 0 and placeholderFunc.isNil):
    var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: layout))
    for i, c in node.children(role):
      if i > 0 and separatorFunc.isNotNil:
        cell.add separatorFunc(builder)
      cell.add builder.buildCell(c)
    result = cell
  elif children.len == 1:
    result = builder.buildCell(children[0])
  else:
    result = placeholderFunc(builder, node, role)
  result.isVisible = isVisible

template buildChildrenT(b: CellBuilder, n: AstNode, r: Id, layout: WPanelLayoutKind, body: untyped): Cell =
  var isVisibleFunc: proc(node: AstNode): bool = nil
  var separatorFunc: proc(builder: CellBuilder): Cell = nil
  var placeholderFunc: proc(builder: CellBuilder, node: AstNode, role: Id): Cell = nil

  var builder {.inject.} = b
  var node {.inject.} = n
  var role {.inject.} = r

  template separator(bod: untyped): untyped =
    separatorFunc = proc(builder {.inject.}: CellBuilder): Cell =
      return bod

  template placeholder(bod: untyped): untyped =
    placeholderFunc = proc(builder {.inject.}: CellBuilder, node {.inject.}: AstNode, role {.inject.}: Id): Cell =
      return bod

  template placeholder(text: string): untyped =
    placeholderFunc = proc(builder {.inject.}: CellBuilder, node {.inject.}: AstNode, role {.inject.}: Id): Cell =
      return PlaceholderCell(id: newId(), node: node, role: role, shadowText: text)

  template visible(bod: untyped): untyped =
    isVisibleFunc = proc(node {.inject.}: AstNode): bool =
      return bod

  placeholder("...")

  body

  builder.buildChildren(node, role, layout, isVisibleFunc, separatorFunc, placeholderFunc)

builder.addBuilderFor nodeListClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Vertical))
  cell.nodeFactory = proc(): AstNode =
    return newAstNode(emptyLineClass)
  cell.fillChildren = proc() =
    # echo "fill collection node list"
    cell.add builder.buildChildren(node, IdNodeListChildren, Vertical)
    # for c in node.children(IdNodeListChildren):
    #   cell.add builder.buildCell(c)
  return cell

builder.addBuilderFor blockClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Vertical), style: CellStyle(indentChildren: true))
  cell.nodeFactory = proc(): AstNode =
    return newAstNode(emptyLineClass)
  cell.fillChildren = proc() =
    # echo "fill collection block"
    cell.add builder.buildChildren(node, IdBlockChildren, Vertical)
    # for c in node.children(IdBlockChildren):
    #   cell.add builder.buildCell(c)
    # if cell.children.len == 0:
    #   cell.add ConstantCell(node: node, text: "<...>", themeForegroundColors: @["&editor.foreground"], disableEditing: true)
  return cell

builder.addBuilderFor constDeclClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    proc isVisible(node: AstNode): bool = node.hasChild(IdConstDeclType)

    # echo "fill collection const decl"
    cell.add ConstantCell(node: node, text: "const", themeForegroundColors: @["keyword"], disableEditing: true)
    cell.add PropertyCell(node: node, property: IdINamedName)
    cell.add ConstantCell(node: node, text: ":", isVisible: isVisible, style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add builder.buildChildren(node, IdConstDeclType, Horizontal, isVisible = isVisible)
    cell.add ConstantCell(node: node, text: "=", themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add block:
      buildChildrenT(builder, node, IdConstDeclValue, WPanelLayoutKind.Horizontal):
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")
  return cell

builder.addBuilderFor letDeclClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    proc isVisible(node: AstNode): bool = node.hasChild(IdLetDeclType)

    # echo "fill collection let decl"
    cell.add ConstantCell(node: node, text: "let", themeForegroundColors: @["keyword"], disableEditing: true)
    cell.add PropertyCell(node: node, property: IdINamedName)
    cell.add ConstantCell(node: node, text: ":", isVisible: isVisible, style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add builder.buildChildren(node, IdLetDeclType, Horizontal, isVisible = isVisible)
    cell.add ConstantCell(node: node, text: "=", themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add block:
      buildChildrenT(builder, node, IdLetDeclValue, WPanelLayoutKind.Horizontal):
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")
  return cell

builder.addBuilderFor varDeclClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    proc isTypeVisible(node: AstNode): bool = node.hasChild(IdVarDeclType)
    proc isValueVisible(node: AstNode): bool = node.hasChild(IdVarDeclValue)

    # echo "fill collection var decl"
    cell.add ConstantCell(node: node, text: "var", themeForegroundColors: @["keyword"], disableEditing: true)
    cell.add PropertyCell(node: node, property: IdINamedName)
    cell.add ConstantCell(node: node, text: ":", isVisible: isTypeVisible, style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add builder.buildChildren(node, IdVarDeclType, Horizontal, isVisible = isTypeVisible)
    cell.add ConstantCell(node: node, text: "=", isVisible: isValueVisible, themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add block:
      buildChildrenT(builder, node, IdVarDeclValue, WPanelLayoutKind.Horizontal):
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")
  return cell

builder.addBuilderFor assignmentClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection assignment"
    cell.add builder.buildChildren(node, IdAssignmentTarget, Horizontal)
    cell.add ConstantCell(node: node, text: "=", themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add builder.buildChildren(node, IdAssignmentValue, Horizontal)
  return cell

builder.addBuilderFor parameterDeclClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    proc isVisible(node: AstNode): bool = node.hasChild(IdParameterDeclValue)

    # echo "fill collection parameter decl"
    cell.add PropertyCell(node: node, property: IdINamedName)
    cell.add ConstantCell(node: node, text: ":", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      builder.buildChildrenT(node, IdParameterDeclType, Horizontal):
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")

    cell.add ConstantCell(node: node, text: "=", isVisible: isVisible, themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      buildChildrenT(builder, node, IdParameterDeclValue, WPanelLayoutKind.Horizontal):
        visible: isVisible(node)
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "...")
  return cell

builder.addBuilderFor functionDefinitionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection func def"
    cell.add ConstantCell(node: node, text: "fn", themeForegroundColors: @["keyword"], disableEditing: true)
    cell.add ConstantCell(node: node, text: "(", style: CellStyle(noSpaceLeft: true, noSpaceRight: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      buildChildrenT(builder, node, IdFunctionDefinitionParameters, WPanelLayoutKind.Horizontal):
        separator: ConstantCell(node: node, text: ",", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
        placeholder: "..."

    cell.add ConstantCell(node: node, text: "):", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      builder.buildChildrenT(node, IdFunctionDefinitionReturnType, Horizontal):
        placeholder: "..."

    cell.add ConstantCell(node: node, text: "=", themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      builder.buildChildrenT(node, IdFunctionDefinitionBody, Vertical):
        placeholder: "..."

  return cell

builder.addBuilderFor callClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection call"

    cell.add builder.buildChildren(node, IdCallFunction, Horizontal)

    cell.add ConstantCell(node: node, text: "(", style: CellStyle(noSpaceLeft: true, noSpaceRight: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      buildChildrenT(builder, node, IdCallArguments, WPanelLayoutKind.Horizontal):
        separator: ConstantCell(node: node, text: ",", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "")

    cell.add ConstantCell(node: node, text: ")", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

  return cell

builder.addBuilderFor ifClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection if"

    cell.add ConstantCell(node: node, text: "if", themeForegroundColors: @["keyword"], disableEditing: true)

    cell.add builder.buildChildren(node, IdIfExpressionCondition, Horizontal)
    # for c in node.children(IdIfExpressionCondition):
    #   cell.add builder.buildCell(c)

    cell.add ConstantCell(node: node, text: ":", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add builder.buildChildren(node, IdIfExpressionThenCase, Horizontal)
    # for c in node.children(IdIfExpressionThenCase):
    #   var cc = builder.buildCell(c)
    #   cell.add cc

    for i, c in node.children(IdIfExpressionElseCase):
      if i == 0:
        cell.add ConstantCell(node: node, text: "else", style: CellStyle(onNewLine: true), themeForegroundColors: @["keyword"], disableEditing: true)
        cell.add ConstantCell(node: node, text: ":", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
      cell.add builder.buildCell(c)

  return cell

builder.addBuilderFor whileClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection while"

    cell.add ConstantCell(node: node, text: "while", themeForegroundColors: @["keyword"], disableEditing: true)

    cell.add builder.buildChildren(node, IdWhileExpressionCondition, Horizontal)
    # for c in node.children(IdWhileExpressionCondition):
    #   cell.add builder.buildCell(c)

    cell.add ConstantCell(node: node, text: ":", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add builder.buildChildren(node, IdWhileExpressionBody, Horizontal)
    # for c in node.children(IdWhileExpressionBody):
    #   cell.add builder.buildCell(c)

  return cell

builder.addBuilderFor nodeReferenceClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = NodeReferenceCell(id: newId(), node: node, reference: IdNodeReferenceTarget, property: IdINamedName, disableEditing: true)
  if node.resolveReference(IdNodeReferenceTarget).getSome(targetNode):
    cell.child = PropertyCell(id: newId(), node: targetNode, property: IdINamedName, themeForegroundColors: @["variable", "&editor.foreground"])
  return cell

builder.addBuilderFor expressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = ConstantCell(id: newId(), node: node, shadowText: "<expr>", themeBackgroundColors: @["&inputValidation.errorBackground", "&debugConsole.errorForeground"])
  return cell

builder.addBuilderFor binaryExpressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection binary"
    cell.add builder.buildChildren(node, IdBinaryExpressionLeft, Horizontal)
    # for c in node.children(IdBinaryExpressionLeft):
    #   cell.add builder.buildCell(c)
    cell.add AliasCell(node: node)
    cell.add builder.buildChildren(node, IdBinaryExpressionRight, Horizontal)
    # for c in node.children(IdBinaryExpressionRight):
    #   cell.add builder.buildCell(c)
  return cell

builder.addBuilderFor divExpressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Vertical), inline: true)
  cell.fillChildren = proc() =
    # echo "fill collection binary"
    cell.add builder.buildChildren(node, IdBinaryExpressionLeft, Horizontal)
    # for c in node.children(IdBinaryExpressionLeft):
    #   cell.add builder.buildCell(c)
    cell.add ConstantCell(node: node, text: "------", themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
    cell.add builder.buildChildren(node, IdBinaryExpressionRight, Horizontal)
    # for c in node.children(IdBinaryExpressionRight):
    #   cell.add builder.buildCell(c)
  return cell

builder.addBuilderFor unaryExpressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection binary"
    cell.add AliasCell(node: node, style: CellStyle(noSpaceRight: true))
    cell.add builder.buildChildren(node, IdUnaryExpressionChild, Horizontal)
    # for c in node.children(IdUnaryExpressionChild):
    #   cell.add builder.buildCell(c)
  return cell

builder.addBuilderFor stringTypeClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = AliasCell(id: newId(), node: node, themeForegroundColors: @["storage.type", "&editor.foreground"], disableEditing: true)
  return cell

builder.addBuilderFor voidTypeClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = AliasCell(id: newId(), node: node, themeForegroundColors: @["storage.type", "&editor.foreground"], disableEditing: true)
  return cell

builder.addBuilderFor intTypeClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = AliasCell(id: newId(), node: node, themeForegroundColors: @["storage.type", "&editor.foreground"], disableEditing: true)
  return cell

builder.addBuilderFor printExpressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection call"

    cell.add AliasCell(node: node)
    cell.add ConstantCell(node: node, text: "(", style: CellStyle(noSpaceLeft: true, noSpaceRight: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      buildChildrenT(builder, node, IdPrintArguments, WPanelLayoutKind.Horizontal):
        separator: ConstantCell(node: node, text: ",", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "")

    cell.add ConstantCell(node: node, text: ")", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

  return cell

builder.addBuilderFor buildExpressionClass.id, idNone(), proc(builder: CellBuilder, node: AstNode): Cell =
  var cell = CollectionCell(id: newId(), node: node, layout: WPanelLayout(kind: Horizontal))
  cell.fillChildren = proc() =
    # echo "fill collection call"

    cell.add AliasCell(node: node)
    cell.add ConstantCell(node: node, text: "(", style: CellStyle(noSpaceLeft: true, noSpaceRight: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

    cell.add block:
      buildChildrenT(builder, node, IdBuildArguments, WPanelLayoutKind.Horizontal):
        separator: ConstantCell(node: node, text: ",", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)
        placeholder: PlaceholderCell(id: newId(), node: node, role: role, shadowText: "")

    cell.add ConstantCell(node: node, text: ")", style: CellStyle(noSpaceLeft: true), themeForegroundColors: @["punctuation", "&editor.foreground"], disableEditing: true)

  return cell

let baseLanguage* = newLanguage(IdBaseLanguage, @[
  namedInterface, declarationInterface,

  typeClass, stringTypeClass, intTypeClass, voidTypeClass, functionTypeClass,

  expressionClass, binaryExpressionClass, unaryExpressionClass, emptyLineClass,
  numberLiteralClass, stringLiteralClass, boolLiteralClass, nodeReferenceClass, emptyClass, constDeclClass, letDeclClass, varDeclClass, nodeListClass, blockClass, callClass, ifClass, whileClass,
  parameterDeclClass, functionDefinitionClass, assignmentClass,
  addExpressionClass, subExpressionClass, mulExpressionClass, divExpressionClass, modExpressionClass,
  lessExpressionClass, lessEqualExpressionClass, greaterExpressionClass, greaterEqualExpressionClass, equalExpressionClass, notEqualExpressionClass, andExpressionClass, orExpressionClass, orderExpressionClass,
  negateExpressionClass, notExpressionClass,
  appendStringExpressionClass, printExpressionClass, buildExpressionClass,
], builder)

print baseLanguage
