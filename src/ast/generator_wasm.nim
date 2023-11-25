import std/[macros, genasts]
import std/[options, tables]
import fusion/matching
import id, model, ast_ids, custom_logger, util, base_language, model_state
import scripting/[wasm_builder]

logCategory "base-language-wasm"

type
  LocalVariableStorage* = enum Local, Stack
  LocalVariable* = object
    case kind*: LocalVariableStorage
    of Local: localIdx*: WasmLocalIdx
    of Stack: stackOffset*: int32

  DestinationStorage* = enum Stack, Memory, Discard, LValue
  Destination* = object
    case kind*: DestinationStorage
    of Stack: discard
    of Memory:
      offset*: uint32
      align*: uint32
    of Discard: discard
    of LValue: discard

  BaseLanguageWasmCompiler* = ref object
    builder*: WasmBuilder

    ctx*: ModelComputationContextBase

    wasmFuncs: Table[NodeId, WasmFuncIdx]

    functionsToCompile: seq[(AstNode, WasmFuncIdx)]
    localIndices: Table[NodeId, LocalVariable]
    globalIndices: Table[NodeId, WasmGlobalIdx]
    labelIndices: Table[NodeId, int] # Not the actual index

    exprStack*: seq[WasmExpr]
    currentExpr*: WasmExpr
    currentLocals: seq[tuple[typ: WasmValueType, id: string]]
    currentParamCount: int32
    currentStackLocals: seq[int32]
    currentStackLocalsSize: int32

    generators: Table[ClassId, proc(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination)]

    # imported
    printI32: WasmFuncIdx
    printString: WasmFuncIdx
    printLine: WasmFuncIdx
    intToString: WasmFuncIdx

    # implemented inline
    buildString: WasmFuncIdx
    strlen: WasmFuncIdx
    allocFunc: WasmFuncIdx

    stackBase: WasmGlobalIdx
    stackEnd: WasmGlobalIdx
    stackPointer: WasmGlobalIdx

    currentBasePointer: WasmLocalIdx

    memoryBase: WasmGlobalIdx
    tableBase: WasmGlobalIdx
    heapBase: WasmGlobalIdx
    heapSize: WasmGlobalIdx

    globalData: seq[uint8]

proc compileFunction*(self: BaseLanguageWasmCompiler, node: AstNode, funcIdx: WasmFuncIdx)
proc getOrCreateWasmFunc*(self: BaseLanguageWasmCompiler, node: AstNode, exportName: Option[string] = string.none): WasmFuncIdx
proc compileRemainingFunctions*(self: BaseLanguageWasmCompiler)

proc newBaseLanguageWasmCompiler*(ctx: ModelComputationContextBase): BaseLanguageWasmCompiler =
  new result
  result.builder = newWasmBuilder()
  result.ctx = ctx

  result.builder.mems.add(WasmMem(typ: WasmMemoryType(limits: WasmLimits(min: 255))))

  result.builder.addExport("memory", 0.WasmMemIdx)

  result.printI32 = result.builder.addImport("env", "print_i32", result.builder.addType([I32], []))
  result.printString = result.builder.addImport("env", "print_string", result.builder.addType([I32], []))
  result.printLine = result.builder.addImport("env", "print_line", result.builder.addType([], []))
  result.intToString = result.builder.addImport("env", "intToString", result.builder.addType([I32], [I32]))
  result.stackBase = result.builder.addGlobal(I32, mut=true, 0, id="__stack_base")
  result.stackEnd = result.builder.addGlobal(I32, mut=true, 0, id="__stack_end")
  result.stackPointer = result.builder.addGlobal(I32, mut=true, 65536, id="__stack_pointer")
  result.memoryBase = result.builder.addGlobal(I32, mut=false, 0, id="__memory_base")
  result.tableBase = result.builder.addGlobal(I32, mut=false, 0, id="__table_base")
  result.heapBase = result.builder.addGlobal(I32, mut=false, 0, id="__heap_base")
  result.heapSize = result.builder.addGlobal(I32, mut=true, 0, id="__heap_size")

  # todo: add proper allocator. For now just a bump allocator without freeing
  result.allocFunc = result.builder.addFunction([I32], [I32], [], exportName="my_alloc".some, body=WasmExpr(instr: @[
    WasmInstr(kind: GlobalGet, globalIdx: result.heapBase),
    WasmInstr(kind: GlobalGet, globalIdx: result.heapSize),
    WasmInstr(kind: I32Add),
    WasmInstr(kind: GlobalGet, globalIdx: result.heapSize),
    WasmInstr(kind: LocalGet, localIdx: 0.WasmLocalIdx),
    WasmInstr(kind: I32Add),
    WasmInstr(kind: GlobalSet, globalIdx: result.heapSize),
  ]))

  discard result.builder.addFunction([I32], [], [], exportName="my_dealloc".some, body=WasmExpr(instr: @[
      WasmInstr(kind: Nop),
  ]))

  # strlen
  block:
    let param = 0.WasmLocalIdx
    let current = 1.WasmLocalIdx
    result.strlen = result.builder.addFunction([I32], [I32], [
        (I32, "current"),
      ], body=WasmExpr(instr: @[

      # a.length
      WasmInstr(kind: LocalGet, localIdx: param),
      WasmInstr(kind: LocalSet, localIdx: current),

      WasmInstr(kind: Block, blockType: WasmBlockType(kind: ValType), blockInstr: @[
        WasmInstr(kind: Loop, loopType: WasmBlockType(kind: ValType), loopInstr: @[
          WasmInstr(kind: LocalGet, localIdx: current),
          WasmInstr(kind: I32Load8U),
          WasmInstr(kind: I32Eqz),
          WasmInstr(kind: BrIf, brLabelIdx: 1.WasmLabelIdx),

          WasmInstr(kind: LocalGet, localIdx: current),
          WasmInstr(kind: I32Const, i32Const: 1),
          WasmInstr(kind: I32Add),
          WasmInstr(kind: LocalSet, localIdx: current),
          WasmInstr(kind: Br, brLabelIdx: 0.WasmLabelIdx),
        ]),
      ]),

      WasmInstr(kind: LocalGet, localIdx: current),
      WasmInstr(kind: LocalGet, localIdx: param),
      WasmInstr(kind: I32Sub),
    ]))

  # build
  block:
    let paramA = 0.WasmLocalIdx
    let paramB = 1.WasmLocalIdx
    let lengthA = 2.WasmLocalIdx
    let lengthB = 3.WasmLocalIdx
    let resultLength = 4.WasmLocalIdx
    let resultAddress = 5.WasmLocalIdx
    result.buildString = result.builder.addFunction([I64, I64], [I64], [
        (I32, "lengthA"),
        (I32, "lengthB"),
        (I32, "resultLength"),
        (I32, "resultAddress")
      ], body=WasmExpr(instr: @[

      # params: a: string, b: string
      # a.length
      WasmInstr(kind: LocalGet, localIdx: paramA),
      WasmInstr(kind: I64Const, i64Const: 32),
      WasmInstr(kind: I64ShrU),
      WasmInstr(kind: I32WrapI64),
      WasmInstr(kind: LocalTee, localIdx: lengthA),

      # b.length
      WasmInstr(kind: LocalGet, localIdx: paramB),
      WasmInstr(kind: I64Const, i64Const: 32),
      WasmInstr(kind: I64ShrU),
      WasmInstr(kind: I32WrapI64),
      WasmInstr(kind: LocalTee, localIdx: lengthB),

      # resultLength = a.length + b.length
      WasmInstr(kind: I32Add),
      WasmInstr(kind: LocalTee, localIdx: resultLength),

      # result = alloc(resultLength)
      WasmInstr(kind: I32Const, i32Const: 1),
      WasmInstr(kind: I32Add),
      WasmInstr(kind: Call, callFuncIdx: result.allocFunc),
      WasmInstr(kind: LocalTee, localIdx: resultAddress),

      # memcpy(resultAddress, a, a.length)
      WasmInstr(kind: LocalGet, localIdx: paramA),
      WasmInstr(kind: I32WrapI64),
      WasmInstr(kind: LocalGet, localIdx: lengthA),
      WasmInstr(kind: MemoryCopy),

      # memcpy(resultAddress + a.length, b, b.length)
      WasmInstr(kind: LocalGet, localIdx: resultAddress),
      WasmInstr(kind: LocalGet, localIdx: lengthA),
      WasmInstr(kind: I32Add),

      WasmInstr(kind: LocalGet, localIdx: paramB),
      WasmInstr(kind: I32WrapI64),
      WasmInstr(kind: LocalGet, localIdx: lengthB),
      WasmInstr(kind: MemoryCopy),

      # *(resultAddress + resultLength) = 0
      WasmInstr(kind: LocalGet, localIdx: resultAddress),
      WasmInstr(kind: LocalGet, localIdx: resultLength),
      WasmInstr(kind: I32Add),
      WasmInstr(kind: I32Const, i32Const: 0),
      WasmInstr(kind: I32Store),

      # result = ptr or (resultLength << 32)
      WasmInstr(kind: LocalGet, localIdx: resultAddress),
      WasmInstr(kind: I64ExtendI32U),
      WasmINstr(kind: LocalGet, localIdx: resultLength),
      WasmInstr(kind: I64ExtendI32U),
      WasmInstr(kind: I64Const, i64Const: 32),
      WasmInstr(kind: I64Shl),
      WasmInstr(kind: I64Or),
    ]))

proc compileToBinary*(self: BaseLanguageWasmCompiler, node: AstNode): seq[uint8] =
  let functionName = $node.id
  discard self.getOrCreateWasmFunc(node, exportName=functionName.some)
  self.compileRemainingFunctions()

  let activeDataOffset = wasmPageSize # todo: after stack
  let activeDataSize = self.globalData.len.int32
  discard self.builder.addActiveData(0.WasmMemIdx, activeDataOffset, self.globalData)

  let heapBase = align(activeDataOffset + activeDataSize, wasmPageSize)
  self.builder.globals[self.heapBase.int].init = WasmInstr(kind: I32Const, i32Const: heapBase)

  debugf"{self.builder}"

  let binary = self.builder.generateBinary()
  return binary

proc compileRemainingFunctions*(self: BaseLanguageWasmCompiler) =
  while self.functionsToCompile.len > 0:
    let function = self.functionsToCompile.pop
    self.compileFunction(function[0], function[1])

proc genNode*(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  if self.generators.contains(node.class):
    let generator = self.generators[node.class]
    generator(self, node, dest)
  else:
    let class = node.nodeClass
    log(lvlWarn, fmt"genNode: Node class not implemented: {class.name}")

proc toWasmValueType*(typ: AstNode): Option[WasmValueType] =
  if typ.class == IdInt:
    return WasmValueType.I32.some # int32
  if typ.class == IdPointerType:
    return WasmValueType.I32.some # pointer
  if typ.class == IdString:
    return WasmValueType.I64.some # (len << 32) | ptr
  if typ.class == IdFunctionType:
    return WasmValueType.I32.some # table index
  return WasmValueType.none

proc getTypeAttributes*(self: BaseLanguageWasmCompiler, typ: AstNode): tuple[size: int32, align: int32] =
  if typ.class == IdInt:
    return (4, 4)
  if typ.class == IdPointerType:
    return (4, 4)
  if typ.class == IdString:
    return (8, 4)
  if typ.class == IdFunctionType:
    return (0, 1)
  if typ.class == IdVoid:
    return (0, 1)
  if typ.class == IdStructDefinition:
    for _, memberNode in typ.children(IdStructDefinitionMembers):
      let memberType = self.ctx.computeType(memberNode)
      let (memberSize, memberAlign) = self.getTypeAttributes(memberType)
      assert memberAlign <= 4

      result.size = align(result.size, memberAlign)
      result.size += memberSize
      result.align = max(result.align, memberAlign)
    return
  return (0, 1)

proc shouldPassAsOutParamater*(self: BaseLanguageWasmCompiler, typ: AstNode): bool =
  let (size, _) = self.getTypeAttributes(typ)
  if size > 8:
    return true
  if typ.class == IdStructDefinition:
    return true
  return false

proc getOrCreateWasmFunc*(self: BaseLanguageWasmCompiler, node: AstNode, exportName: Option[string] = string.none): WasmFuncIdx =
  if not self.wasmFuncs.contains(node.id):
    var inputs, outputs: seq[WasmValueType]

    for _, c in node.children(IdFunctionDefinitionReturnType):
      let typ = self.ctx.getValue(c)
      if self.shouldPassAsOutParamater(typ):
        inputs.add WasmValueType.I32
      elif typ.class != IdVoid:
        outputs.add typ.toWasmValueType.get

    for _, c in node.children(IdFunctionDefinitionParameters):
      let typ = self.ctx.computeType(c)
      if typ.class == IdType:
        continue
      inputs.add typ.toWasmValueType.get

    let funcIdx = self.builder.addFunction(inputs, outputs, exportName=exportName)
    self.wasmFuncs[node.id] = funcIdx
    self.functionsToCompile.add (node, funcIdx)

  return self.wasmFuncs[node.id]

proc getTypeMemInstructions*(self: BaseLanguageWasmCompiler, typ: AstNode): tuple[load: WasmInstrKind, store: WasmInstrKind] =
  if typ.class == IdInt:
    return (I32Load, I32Store)
  if typ.class == IdPointerType:
    return (I32Load, I32Store)
  if typ.class == IdString:
    return (I64Load, I64Store)
  log lvlError, fmt"getTypeMemInstructions: Type not implemented: {`$`(typ, true)}"
  assert false
  return (Nop, Nop)

proc createLocal*(self: BaseLanguageWasmCompiler, id: NodeId, typ: AstNode, name: string): WasmLocalIdx =
  if typ.toWasmValueType.getSome(wasmType):
    result = (self.currentLocals.len + self.currentParamCount).WasmLocalIdx
    self.currentLocals.add((wasmType, name))
    self.localIndices[id] = LocalVariable(kind: Local, localIdx: result)

proc createStackLocal*(self: BaseLanguageWasmCompiler, id: NodeId, typ: AstNode): int32 =
  let (size, alignment) = self.getTypeAttributes(typ)

  self.currentStackLocalsSize = self.currentStackLocalsSize.align(alignment)
  result = self.currentStackLocalsSize

  self.currentStackLocals.add(self.currentStackLocalsSize)
  # debugf"createStackLocal size {size}, alignment {alignment}, offset {self.currentStackLocalsSize}"

  self.localIndices[id] = LocalVariable(kind: Stack, stackOffset: self.currentStackLocalsSize)

  self.currentStackLocalsSize += size

proc getTempLocal*(self: BaseLanguageWasmCompiler, typ: AstNode): WasmLocalIdx =
  if self.localIndices.contains(typ.id):
    return self.localIndices[typ.id].localIdx

  return self.createLocal(typ.id, typ, fmt"__temp_{typ.id}")

proc addStringData*(self: BaseLanguageWasmCompiler, value: string): int32 =
  let offset = self.globalData.len.int32
  self.globalData.add(value.toOpenArrayByte(0, value.high))
  self.globalData.add(0)

  result = offset + wasmPageSize

macro instr*(self: WasmExpr, op: WasmInstrKind, args: varargs[untyped]): untyped =
  result = genAst(self, op):
    self.instr.add WasmInstr(kind: op)
  for arg in args:
    result[1].add arg

macro instr*(self: BaseLanguageWasmCompiler, op: WasmInstrKind, args: varargs[untyped]): untyped =
  result = genAst(self, op):
    self.currentExpr.instr.add WasmInstr(kind: op)
  for arg in args:
    result[1].add arg

proc genDup*(self: BaseLanguageWasmCompiler, typ: AstNode) =
  let tempIdx = self.getTempLocal(typ)
  self.instr(LocalTee, localIdx: tempIdx)
  self.instr(LocalGet, localIdx: tempIdx)

proc storeInstr*(self: BaseLanguageWasmCompiler, op: WasmInstrKind, offset: uint32, align: uint32) =
  # debugf"storeInstr {op}, offset {offset}, align {align}"
  assert op in {I32Store, I64Store, F32Store, F64Store, I32Store8, I64Store8, I32Store16, I64Store16, I64Store32}
  var instr = WasmInstr(kind: op)
  instr.memArg = WasmMemArg(offset: offset, align: align)
  self.currentExpr.instr.add instr

proc loadInstr*(self: BaseLanguageWasmCompiler, op: WasmInstrKind, offset: uint32, align: uint32) =
  # debugf"loadInstr {op}, offset {offset}, align {align}"
  assert op in {I32Load, I64Load, F32Load, F64Load, I32Load8U, I32Load8S, I64Load8U, I64Load8S, I32Load16U, I32Load16S, I64Load16U, I64Load16S, I64Load32U, I64Load32S}
  var instr = WasmInstr(kind: op)
  instr.memArg = WasmMemArg(offset: offset, align: align)
  self.currentExpr.instr.add instr

proc generateEpiloque*(self: BaseLanguageWasmCompiler) =
  self.instr(LocalGet, localIdx: self.currentBasePointer)
  self.instr(GlobalSet, globalIdx: self.stackPointer)

proc compileFunction*(self: BaseLanguageWasmCompiler, node: AstNode, funcIdx: WasmFuncIdx) =
  let body = node.children(IdFunctionDefinitionBody)
  if body.len != 1:
    return

  assert self.exprStack.len == 0
  self.currentExpr = WasmExpr()
  self.currentLocals.setLen 0
  self.currentParamCount = 0.int32

  let returnType = node.firstChild(IdFunctionDefinitionReturnType).mapIt(self.ctx.getValue(it)).get(voidTypeInstance)
  let passReturnAsOutParam = self.shouldPassAsOutParamater(returnType)

  if passReturnAsOutParam:
    self.localIndices[IdFunctionDefinitionReturnType.NodeId] = LocalVariable(kind: Local, localIdx: self.currentParamCount.WasmLocalIdx)
    inc self.currentParamCount

  for i, param in node.children(IdFunctionDefinitionParameters):
    let paramType = self.ctx.computeType(param)
    if paramType.class == IdType:
      continue

    self.localIndices[param.id] = LocalVariable(kind: Local, localIdx: self.currentParamCount.WasmLocalIdx)
    inc self.currentParamCount

  self.currentBasePointer = (self.currentLocals.len + self.currentParamCount).WasmLocalIdx
  self.currentLocals.add((I32, "__base_pointer")) # base pointer

  let stackSizeInstrIndex = block: # prologue
    self.instr(GlobalGet, globalIdx: self.stackPointer)
    self.instr(I32Const, i32Const: 0) # size, patched at end when we know the size of locals
    let i = self.currentExpr.instr.high
    self.instr(I32Sub)
    self.instr(LocalTee, localIdx: self.currentBasePointer)
    self.instr(GlobalSet, globalIdx: self.stackPointer)
    i

  let destination = if returnType.class == IdVoid:
    Destination(kind: Discard)
  elif passReturnAsOutParam:
    self.instr(LocalGet, localIdx: 0.WasmLocalIdx) # load return value address from first parameter
    Destination(kind: Memory, offset: 0, align: 0)
  else:
    Destination(kind: Stack)

  self.genNode(body[0], destination)

  let requiredStackSize: int32 = self.currentStackLocalsSize
  self.currentExpr.instr[stackSizeInstrIndex].i32Const = requiredStackSize

  self.generateEpiloque()

  self.builder.setBody(funcIdx, self.currentLocals, self.currentExpr)

proc genDrop*(self: BaseLanguageWasmCompiler, node: AstNode) =
  self.instr(Drop)
  # todo: size of node, stack

proc genStoreDestination*(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  case dest
  of Stack(): discard
  of Memory(offset: @offset, align: @align):
    let typ = self.ctx.computeType(node)
    let instr = self.getTypeMemInstructions(typ).store
    self.storeInstr(instr, offset, align)
  of Discard():
    self.genDrop(node)

proc genNodeChildren*(self: BaseLanguageWasmCompiler, node: AstNode, role: RoleId, dest: Destination) =
  let count = node.childCount(role)
  for i, c in node.children(role):
    let childDest = if i == count - 1:
      dest
    else:
      Destination(kind: Discard)

    self.genNode(c, childDest)

###################### Node Generators ##############################

template genNested*(self: BaseLanguageWasmCompiler, body: untyped): untyped =
  self.exprStack.add self.currentExpr
  self.currentExpr = WasmExpr()

  try:
    body
  finally:
    let bodyExpr = self.currentExpr
    self.currentExpr = self.exprStack.pop
    self.instr(Loop, loopType: typ, loopInstr: move bodyExpr.instr)

template genBlock*(self: BaseLanguageWasmCompiler, typ: WasmBlockType, body: untyped): untyped =
  self.exprStack.add self.currentExpr
  self.currentExpr = WasmExpr()

  try:
    body
  finally:
    let bodyExpr = self.currentExpr
    self.currentExpr = self.exprStack.pop
    self.instr(Block, blockType: typ, blockInstr: move bodyExpr.instr)

template genLoop*(self: BaseLanguageWasmCompiler, typ: WasmBlockType, body: untyped): untyped =
  self.exprStack.add self.currentExpr
  self.currentExpr = WasmExpr()

  try:
    body
  finally:
    let bodyExpr = self.currentExpr
    self.currentExpr = self.exprStack.pop
    self.instr(Loop, loopType: typ, loopInstr: move bodyExpr.instr)

proc genBranchLabel*(self: BaseLanguageWasmCompiler, node: AstNode, offset: int) =
  assert self.labelIndices.contains(node.id)
  let index = self.labelIndices[node.id]
  let actualIndex = WasmLabelIdx(self.exprStack.high - index - offset)
  self.instr(Br, brLabelIdx: actualIndex)

proc genCopyToDestination*(self: BaseLanguageWasmCompiler, node: AstNode, dest: Destination) =
  case dest
  of Stack():
    let typ = self.ctx.computeType(node)
    let instr = self.getTypeMemInstructions(typ).load
    self.loadInstr(instr, 0, 0)

  of Memory():
    let typ = self.ctx.computeType(node)
    let (sourceSize, sourceAlign) = self.getTypeAttributes(typ)
    self.instr(I32Const, i32Const: sourceSize)
    self.instr(MemoryCopy)

  of Discard():
    self.instr(Drop)

  of LValue():
    discard