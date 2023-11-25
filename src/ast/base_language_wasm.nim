import std/[macros, genasts]
import std/[options, tables]
import fusion/matching
import id, model, ast_ids, custom_logger, util, base_language, model_state
import generator_wasm
import scripting/[wasm_builder]

logCategory "base-language-wasm"

proc genNodeBlock(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let typ = self.ctx.computeType(node)
  let tempIdx = if dest.kind == Memory:
    let tempIdx = self.getTempLocal(intTypeInstance)
    self.instr(LocalSet, localIdx: tempIdx)
    tempIdx.some
  else:
    WasmLocalIdx.none

  self.genBlock(WasmBlockType(kind: ValType, typ: self.toWasmValueType(typ))):
    if tempIdx.getSome(tempIdx):
      self.instr(LocalGet, localIdx: tempIdx)

    self.genNodeChildren(node, IdBlockChildren, dest)

proc genNodeBinaryExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeChildren(node, IdBinaryExpressionLeft, dest)
  self.genNodeChildren(node, IdBinaryExpressionRight, dest)

proc genNodeBinaryAddExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32Add)
  self.genStoreDestination(node, dest)

proc genNodeBinarySubExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32Sub)
  self.genStoreDestination(node, dest)

proc genNodeBinaryMulExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32Mul)
  self.genStoreDestination(node, dest)

proc genNodeBinaryDivExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32DivS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryModExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32RemS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryLessExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32LtS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryLessEqualExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32LeS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryGreaterExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32GtS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryGreaterEqualExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32GeS)
  self.genStoreDestination(node, dest)

proc genNodeBinaryEqualExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32Eq)
  self.genStoreDestination(node, dest)

proc genNodeBinaryNotEqualExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.genNodeBinaryExpression(node, Destination(kind: Stack))
  self.instr(I32Ne)
  self.genStoreDestination(node, dest)

proc genNodeUnaryNegateExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.instr(I32Const, i32Const: 0)
  self.genNodeChildren(node, IdUnaryExpressionChild, Destination(kind: Stack))
  self.instr(I32Sub)
  self.genStoreDestination(node, dest)

proc genNodeUnaryNotExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  self.instr(I32Const, i32Const: 1)
  self.genNodeChildren(node, IdUnaryExpressionChild, Destination(kind: Stack))
  self.instr(I32Sub)
  self.genStoreDestination(node, dest)

proc genNodeIntegerLiteral(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let value = node.property(IdIntegerLiteralValue).get
  self.instr(I32Const, i32Const: value.intValue.int32)
  self.genStoreDestination(node, dest)

proc genNodeBoolLiteral(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let value = node.property(IdBoolLiteralValue).get
  self.instr(I32Const, i32Const: value.boolValue.int32)
  self.genStoreDestination(node, dest)

proc genNodeStringLiteral(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let value = node.property(IdStringLiteralValue).get
  let address = self.addStringData(value.stringValue)
  self.instr(I32Const, i32Const: address)
  self.instr(I64ExtendI32U)
  self.instr(I64Const, i64Const: value.stringValue.len.int64 shl 32)
  self.instr(I64Or)
  self.genStoreDestination(node, dest)

proc genNodeIfExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  var ifStack: seq[WasmExpr]

  let thenCases = node.children(IdIfExpressionThenCase)
  let elseCase = node.children(IdIfExpressionElseCase)

  let typ = self.ctx.computeType(node)
  let wasmType = self.toWasmValueType(typ)

  for k, c in thenCases:
    # condition
    self.genNodeChildren(c, IdThenCaseCondition, Destination(kind: Stack))

    # then case
    self.exprStack.add self.currentExpr
    self.currentExpr = WasmExpr()

    self.genNodeChildren(c, IdThenCaseBody, dest)

    ifStack.add self.currentExpr
    self.currentExpr = WasmExpr()

  for i, c in elseCase:
    if i > 0 and wasmType.isSome: self.genDrop(c)
    self.genNode(c, dest)
    if wasmType.isNone: self.genDrop(c)

  for i in countdown(ifStack.high, 0):
    let elseCase = self.currentExpr
    self.currentExpr = self.exprStack.pop
    self.instr(If, ifType: WasmBlockType(kind: ValType, typ: wasmType), ifThenInstr: move ifStack[i].instr, ifElseInstr: move elseCase.instr)

proc genNodeWhileExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let typ = WasmValueType.none

  # outer block for break
  self.genBlock WasmBlockType(kind: ValType, typ: typ):
    self.labelIndices[node.id] = self.exprStack.high

    # generate body in loop block
    self.genLoop WasmBlockType(kind: ValType, typ: typ):

      # generate condition
      self.genNodeChildren(node, IdWhileExpressionCondition, Destination(kind: Stack))

      # break block if condition is false
      self.instr(I32Eqz)
      self.instr(BrIf, brLabelIdx: 1.WasmLabelIdx)

      self.genNodeChildren(node, IdWhileExpressionBody, Destination(kind: Discard))

      # continue loop
      self.instr(Br, brLabelIdx: 0.WasmLabelIdx)

proc genNodeConstDecl(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  # let index = self.createLocal(node.id, nil)

  # let values = node.children(IdConstDeclValue)
  # assert values.len > 0
  # self.genNode(values[0], dest)

  # self.instr(LocalTee, localIdx: index)

  assert dest.kind == Discard

proc genNodeLetDecl(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let typ = self.ctx.computeType(node)
  let offset = self.createStackLocal(node.id, typ)

  if node.firstChild(IdLetDeclValue).getSome(value):
    self.instr(LocalGet, localIdx: self.currentBasePointer)
    self.genNode(value, Destination(kind: Memory, offset: offset.uint32, align: 0))

  # self.instr(LocalTee, localIdx: index)

  assert dest.kind == Discard

proc genNodeVarDecl(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let typ = self.ctx.computeType(node)
  let offset = self.createStackLocal(node.id, typ)
  # let index = self.createLocal(node.id, nil)

  if node.firstChild(IdVarDeclValue).getSome(value):
    self.instr(LocalGet, localIdx: self.currentBasePointer)
    self.genNode(value, Destination(kind: Memory, offset: offset.uint32, align: 0))

  # self.instr(LocalTee, localIdx: index)

  assert dest.kind == Discard

proc genNodeBreakExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  var parent = node.parent
  while parent.isNotNil and parent.class != IdWhileExpression:
    parent = parent.parent

  if parent.isNil:
    log lvlError, fmt"Break outside of loop"
    return

  self.genBranchLabel(parent, 0)

proc genNodeContinueExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  var parent = node.parent
  while parent.isNotNil and parent.class != IdWhileExpression:
    parent = parent.parent

  if parent.isNil:
    log lvlError, fmt"Break outside of loop"
    return

  self.genBranchLabel(parent, 1)

proc genNodeReturnExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  discard

proc genNodeNodeReference(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let id = node.reference(IdNodeReferenceTarget)
  if node.resolveReference(IdNodeReferenceTarget).getSome(target) and target.class == IdConstDecl:
    self.genNodeChildren(target, IdConstDeclValue, dest)

  else:
    if not self.localIndices.contains(id):
      log lvlError, fmt"Variable not found found in locals: {id}, from here {node}"
      return

    let typ = self.ctx.computeType(node)
    let (size, align, _) = self.getTypeAttributes(typ)

    case dest
    of Stack():
      case self.localIndices[id]:
      of Local(localIdx: @index):
        self.instr(LocalGet, localIdx: index)
      of Stack(stackOffset: @offset):
        self.instr(LocalGet, localIdx: self.currentBasePointer)
        let memInstr = self.getTypeMemInstructions(typ)
        self.loadInstr(memInstr.load, offset.uint32, 0)

    of Memory(offset: @offset, align: @align):
      case self.localIndices[id]:
      of Local(localIdx: @index):
        self.instr(LocalGet, localIdx: index)
        let memInstr = self.getTypeMemInstructions(typ)
        self.storeInstr(memInstr.store, offset, align)

      of Stack(stackOffset: @offset):
        self.instr(LocalGet, localIdx: self.currentBasePointer)
        if offset > 0:
          self.instr(I32Const, i32Const: offset)
          self.instr(I32Add)
        self.instr(I32Const, i32Const: size)
        self.instr(MemoryCopy)

    of Discard():
      discard

    of LValue():
      case self.localIndices[id]:
      of Local(localIdx: @index):
        log lvlError, fmt"Can't get lvalue of local: {id}, from here {node}"
      of Stack(stackOffset: @offset):
        self.instr(LocalGet, localIdx: self.currentBasePointer)
        if offset > 0:
          self.instr(I32Const, i32Const: offset)
          self.instr(I32Add)

proc genAssignmentExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let targetNode = node.firstChild(IdAssignmentTarget).getOr:
    log lvlError, fmt"No assignment target for: {node}"
    return

  let id = if targetNode.class == IdNodeReference:
    targetNode.reference(IdNodeReferenceTarget).some
  else:
    NodeId.none

  var valueDest = Destination(kind: Stack)

  if id.isSome:
    if not self.localIndices.contains(id.get):
      log lvlError, fmt"Variable not found found in locals: {id.get}"
      return

    case self.localIndices[id.get]
    of Local(localIdx: @index):
      discard
    of Stack(stackOffset: @offset):
      self.instr(LocalGet, localIdx: self.currentBasePointer)
      valueDest = Destination(kind: Memory, offset: offset.uint32, align: 0)
  else:
    self.genNode(targetNode, Destination(kind: LValue))
    valueDest = Destination(kind: Memory, offset: 0, align: 0)

  self.genNodeChildren(node, IdAssignmentValue, valueDest)

  if id.isSome:
    case self.localIndices[id.get]
    of Local(localIdx: @index):
      self.instr(LocalSet, localIdx: index)
    of Stack():
      discard

  assert dest.kind == Discard

proc genNodePrintExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  for i, c in node.children(IdPrintArguments):
    self.genNode(c, Destination(kind: Stack))

    let typ = self.ctx.computeType(c)
    if typ.class == IdInt:
      self.instr(Call, callFuncIdx: self.printI32)
    elif typ.class == IdPointerType:
      self.instr(Call, callFuncIdx: self.printI32)
    elif typ.class == IdString:
      self.instr(I32WrapI64)
      self.instr(Call, callFuncIdx: self.printString)
    else:
      log lvlError, fmt"genNodePrintExpression: Type not implemented: {`$`(typ, true)}"

  self.instr(Call, callFuncIdx: self.printLine)

proc genToString(self: BaseLanguageWasmCompiler, typ: AstNode) =
  if typ.class == IdInt:
    let tempIdx = self.getTempLocal(typ)
    self.instr(Call, callFuncIdx: self.intToString)
    self.instr(LocalTee, localIdx: tempIdx)
    self.instr(I64ExtendI32U)
    self.instr(LocalGet, localIdx: tempIdx)
    self.instr(Call, callFuncIdx: self.strlen)
    self.instr(I64ExtendI32U)
    self.instr(I64Const, i64Const: 32)
    self.instr(I64Shl)
    self.instr(I64Or)
  else:
    self.instr(Drop)
    self.instr(I64Const, i64Const: 0)

proc genNodeBuildExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  for i, c in node.children(IdBuildArguments):
    self.genNode(c, Destination(kind: Stack))

    let typ = self.ctx.computeType(c)
    if typ.class != IdString:
      self.genToString(typ)

    if i > 0:
      self.instr(Call, callFuncIdx: self.buildString)

  self.genStoreDestination(node, dest)

proc genNodeCallExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  for i, c in node.children(IdCallArguments):
    self.genNode(c, Destination(kind: Stack))

  let funcExprNode = node.firstChild(IdCallFunction).getOr:
    log lvlError, fmt"No function specified for call {node}"
    return

  let returnType = self.ctx.computeType(node)
  let passReturnAsOutParam = self.shouldPassAsOutParamater(returnType)

  if passReturnAsOutParam:
    case dest
    of Stack(): return # todo error
    of Memory(offset: @offset):
      if offset > 0:
        self.instr(I32Const, i32Const: offset.int32)
    of Discard(): discard
    of LValue(): return # todo error

  if funcExprNode.class == IdNodeReference:
    let funcDeclNode = funcExprNode.resolveReference(IdNodeReferenceTarget).getOr:
      log lvlError, fmt"Function not found: {funcExprNode}"
      return

    if funcDeclNode.class == IdConstDecl:
      let funcDefNode = funcDeclNode.firstChild(IdConstDeclValue).getOr:
        log lvlError, fmt"No value: {funcDeclNode} in call {node}"
        return

      var name = funcDeclNode.property(IdINamedName).get.stringValue
      if funcDefNode.isGeneric(self.ctx):
        # generic call
        let concreteFunction = self.ctx.instantiateFunction(funcDefNode, node.children(IdCallArguments))
        let funcIdx = self.getOrCreateWasmFunc(concreteFunction, (name & $concreteFunction.id).some)
        self.instr(Call, callFuncIdx: funcIdx)

      else:
        # static call
        let funcIdx = self.getOrCreateWasmFunc(funcDefNode, name.some)
        self.instr(Call, callFuncIdx: funcIdx)

    else: # not a const decl, so call indirect
      self.genNode(funcExprNode, Destination(kind: Stack))
      const tableIdx = 0.WasmTableIdx
      let typeIdx = 0.WasmTypeIdx
      self.instr(CallIndirect, callIndirectTableIdx: tableIdx, callIndirectTypeIdx: typeIdx)

  else: # not a node reference
    self.genNode(funcExprNode, Destination(kind: Stack))
    const tableIdx = 0.WasmTableIdx
    let typeIdx = 0.WasmTypeIdx
    self.instr(CallIndirect, callIndirectTableIdx: tableIdx, callIndirectTypeIdx: typeIdx)

  let typ = self.ctx.computeType(node)
  if typ.class != IdVoid and not passReturnAsOutParam: # todo: should handlediscard here aswell even if passReturnAsOutParam
    self.genStoreDestination(node, dest)

proc genNodeStructMemberAccessExpression(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =

  let member = node.resolveReference(IdStructMemberAccessMember).getOr:
    log lvlError, fmt"Member not found: {node}"
    return

  let valueNode = node.firstChild(IdStructMemberAccessValue).getOr:
    log lvlError, fmt"No value: {node}"
    return

  let typ = self.ctx.computeType(valueNode)

  var offset = 0.int32
  var size = 0.int32
  var align = 0.int32

  for _, memberDefinition in typ.children(IdStructDefinitionMembers):
    let memberType = self.ctx.computeType(memberDefinition)
    let (memberSize, memberAlign, _) = self.getTypeAttributes(memberType)
    offset = align(offset, memberAlign)

    let originalMemberId = if memberDefinition.hasReference(IdStructTypeGenericMember):
      memberDefinition.reference(IdStructTypeGenericMember)
    else:
      memberDefinition.id

    if member.id == originalMemberId:
      size = memberSize
      align = memberAlign
      break
    offset += memberSize

  case dest
  of Memory(offset: @offset, align: @align):
    if offset > 0:
      self.instr(I32Const, i32Const: offset.int32)
      self.instr(I32Add)

  self.genNode(valueNode, Destination(kind: LValue))

  case dest
  of Stack():
    let typ = self.ctx.computeType(member)
    let instr = self.getTypeMemInstructions(typ).load
    self.loadInstr(instr, offset.uint32, 0)

  of Memory():
    if offset > 0:
      self.instr(I32Const, i32Const: offset.int32)
      self.instr(I32Add)
    self.instr(I32Const, i32Const: size)
    self.instr(MemoryCopy)

  of Discard():
    self.instr(Drop)

  of LValue():
    if offset > 0:
      self.instr(I32Const, i32Const: offset)
      self.instr(I32Add)

proc genNodeAddressOf(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let valueNode = node.firstChild(IdAddressOfValue).getOr:
    log lvlError, fmt"No value: {node}"
    return

  self.genNode(valueNode, Destination(kind: LValue))
  self.genStoreDestination(node, dest)

proc genCopyToDestination(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  case dest
  of Stack():
    let typ = self.ctx.computeType(node)
    let instr = self.getTypeMemInstructions(typ).load
    self.loadInstr(instr, 0, 0)

  of Memory():
    let typ = self.ctx.computeType(node)
    let (sourceSize, sourceAlign, _) = self.getTypeAttributes(typ)
    self.instr(I32Const, i32Const: sourceSize)
    self.instr(MemoryCopy)

  of Discard():
    self.instr(Drop)

  of LValue():
    discard

proc genNodeDeref(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let valueNode = node.firstChild(IdDerefValue).getOr:
    log lvlError, fmt"No value: {node}"
    return

  self.genNode(valueNode, Destination(kind: Stack))
  self.genCopyToDestination(node, dest)

proc genNodeArrayAccess(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let valueNode = node.firstChild(IdArrayAccessValue).getOr:
    log lvlError, fmt"No value: {node}"
    return

  let indexNode = node.firstChild(IdArrayAccessIndex).getOr:
    log lvlError, fmt"No index: {node}"
    return

  let typ = self.ctx.computeType(node)
  let (size, _, _) = self.getTypeAttributes(typ)

  self.genNode(valueNode, Destination(kind: Stack))
  self.genNode(indexNode, Destination(kind: Stack))
  self.instr(I32Const, i32Const: size)
  self.instr(I32Mul)
  self.instr(I32Add)

  self.genCopyToDestination(node, dest)

proc genNodeAllocate(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  let typeNode = node.firstChild(IdAllocateType).getOr:
    log lvlError, fmt"No type: {node}"
    return

  let typ = self.ctx.getValue(typeNode)
  let (size, align, _) = self.getTypeAttributes(typ)

  self.instr(I32Const, i32Const: size)

  if node.firstChild(IdAllocateCount).getSome(countNode):
    self.genNode(countNode, Destination(kind: Stack))
    self.instr(I32Mul)

  self.instr(Call, callFuncIdx: self.allocFunc)
  self.genStoreDestination(node, dest)

proc computeStructTypeAttributes(self: BaseLanguageWasmCompiler, typ: AstNode): TypeAttributes =
  result.passReturnAsOutParam = true
  for _, memberNode in typ.children(IdStructDefinitionMembers):
    let memberType = self.ctx.computeType(memberNode)
    let (memberSize, memberAlign, _) = self.getTypeAttributes(memberType)
    assert memberAlign <= 4

    result.size = align(result.size, memberAlign)
    result.size += memberSize
    result.align = max(result.align, memberAlign)
  return

proc addBaseLanguageGenerators*(self: BaseLanguageWasmCompiler) =
  self.generators[IdBlock] = genNodeBlock
  self.generators[IdAdd] = genNodeBinaryAddExpression
  self.generators[IdSub] = genNodeBinarySubExpression
  self.generators[IdMul] = genNodeBinaryMulExpression
  self.generators[IdDiv] = genNodeBinaryDivExpression
  self.generators[IdMod] = genNodeBinaryModExpression
  self.generators[IdLess] = genNodeBinaryLessExpression
  self.generators[IdLessEqual] = genNodeBinaryLessEqualExpression
  self.generators[IdGreater] = genNodeBinaryGreaterExpression
  self.generators[IdGreaterEqual] = genNodeBinaryGreaterEqualExpression
  self.generators[IdEqual] = genNodeBinaryEqualExpression
  self.generators[IdNotEqual] = genNodeBinaryNotEqualExpression
  self.generators[IdNegate] = genNodeUnaryNegateExpression
  self.generators[IdNot] = genNodeUnaryNotExpression
  self.generators[IdIntegerLiteral] = genNodeIntegerLiteral
  self.generators[IdBoolLiteral] = genNodeBoolLiteral
  self.generators[IdStringLiteral] = genNodeStringLiteral
  self.generators[IdIfExpression] = genNodeIfExpression
  self.generators[IdWhileExpression] = genNodeWhileExpression
  self.generators[IdConstDecl] = genNodeConstDecl
  self.generators[IdLetDecl] = genNodeLetDecl
  self.generators[IdVarDecl] = genNodeVarDecl
  self.generators[IdNodeReference] = genNodeNodeReference
  self.generators[IdAssignment] = genAssignmentExpression
  self.generators[IdBreakExpression] = genNodeBreakExpression
  self.generators[IdContinueExpression] = genNodeContinueExpression
  self.generators[IdPrint] = genNodePrintExpression
  self.generators[IdBuildString] = genNodeBuildExpression
  self.generators[IdCall] = genNodeCallExpression
  self.generators[IdStructMemberAccess] = genNodeStructMemberAccessExpression
  self.generators[IdAddressOf] = genNodeAddressOf
  self.generators[IdDeref] = genNodeDeref
  self.generators[IdArrayAccess] = genNodeArrayAccess
  self.generators[IdAllocate] = genNodeAllocate

  self.wasmValueTypes[IdInt] = WasmValueType.I32 # int32
  self.wasmValueTypes[IdPointerType] = WasmValueType.I32 # pointer
  self.wasmValueTypes[IdString] = WasmValueType.I64 # (len << 32) | ptr
  self.wasmValueTypes[IdFunctionType] = WasmValueType.I32 # table index

  self.typeAttributes[IdInt] = (4'i32, 4'i32, false)
  self.typeAttributes[IdPointerType] = (4'i32, 4'i32, false)
  self.typeAttributes[IdString] = (8'i32, 4'i32, false)
  self.typeAttributes[IdFunctionType] = (0'i32, 1'i32, false)
  self.typeAttributes[IdVoid] = (0'i32, 1'i32, false)
  self.typeAttributeComputers[IdStructDefinition] = proc(typ: AstNode): TypeAttributes = self.computeStructTypeAttributes(typ)
