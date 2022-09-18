import std/[tables, sets, strutils, hashes, options, macros]
import sugar
import system
import print
import fusion/matching
import ast, id, util

{.experimental: "dynamicBindSym".}

var currentIndent* = 0

type
  Fingerprint* = seq[int64]

  ItemId* = tuple[id: Id, typ: int]

  UpdateFunction = proc(item: ItemId): Fingerprint
  Dependency* = tuple[item: ItemId, update: UpdateFunction]

  NodeColor* = enum Grey, Red, Green

  DependencyGraph* = ref object
    verified: Table[Dependency, int]
    changed*: Table[Dependency, int]
    fingerprints: Table[Dependency, Fingerprint]
    dependencies*: Table[Dependency, seq[Dependency]]
    queryNames*: Table[UpdateFunction, string]
    revision*: int

proc hash(value: ItemId): Hash = value.id.hash xor value.typ.hash
proc `==`(a: ItemId, b: ItemId): bool = a.id == b.id and a.typ == b.typ

proc newDependencyGraph*(): DependencyGraph =
  new result
  result.revision = 0
  result.queryNames.add(nil, "")

proc nodeColor*(graph: DependencyGraph, key: Dependency, parentVerified: int = 0): NodeColor =
  if key.update == nil:
    # Input
    let inputChangedRevision = graph.changed.getOrDefault(key, graph.revision)
    if inputChangedRevision > parentVerified:
      return Red
    else:
      return Green

  # Computed data
  let verified = graph.verified.getOrDefault(key, 0)
  if verified != graph.revision:
    return Grey

  let changed = graph.changed.getOrDefault(key, 0)
  if changed == graph.revision:
    return Red

  return Green

proc getDependencies*(graph: DependencyGraph, key: Dependency): seq[Dependency] =
  result = graph.dependencies.getOrDefault(key, @[])
  if result.len == 0 and key.update != nil:
    result.add (key.item, nil)

proc clearEdges*(graph: DependencyGraph, key: Dependency) =
  graph.dependencies[key] = @[]

proc setDependencies*(graph: DependencyGraph, key: Dependency, deps: seq[Dependency]) =
  graph.dependencies[key] = deps

proc fingerprint*(graph: DependencyGraph, key: Dependency): Fingerprint =
  if graph.fingerprints.contains(key):
    return graph.fingerprints[key]

proc markGreen*(graph: DependencyGraph, key: Dependency) =
  graph.verified[key] = graph.revision

proc markRed*(graph: DependencyGraph, key: Dependency, fingerprint: Fingerprint) =
  graph.verified[key] = graph.revision
  graph.changed[key] = graph.revision
  graph.fingerprints[key] = fingerprint

proc `$`*(graph: DependencyGraph): string =
  result = "Dependency Graph\n"
  result.add indent("revision: " & $graph.revision, 1, "| ") & "\n"

  result.add indent("colors:", 1, "| ") & "\n"
  for (key, value) in graph.changed.pairs:
    let color = graph.nodeColor key
    result.add indent(graph.queryNames[key.update] & ":" & $key.item & " -> " & $color, 2, "| ") & "\n"

  result.add indent("verified:", 1, "| ") & "\n"
  for (key, value) in graph.verified.pairs:
    result.add indent(graph.queryNames[key.update] & ":" & $key.item & " -> " & $value, 2, "| ") & "\n"

  result.add indent("changed:", 1, "| ") & "\n"
  for (key, value) in graph.changed.pairs:
    result.add indent(graph.queryNames[key.update] & ":" & $key.item & " -> " & $value, 2, "| ") & "\n"

  result.add indent("fingerprints:", 1, "| ") & "\n"
  for (key, value) in graph.fingerprints.pairs:
    result.add indent(graph.queryNames[key.update] & ":" & $key.item & " -> " & $value, 2, "| ") & "\n"

  result.add indent("dependencies:", 1, "| ") & "\n"
  for (key, value) in graph.dependencies.pairs:
    var deps = "["
    for i, dep in value:
      if i > 0: deps.add ", "
      deps.add graph.queryNames[dep.update] & ":" & $dep.item

    deps.add "]"
    result.add indent(graph.queryNames[key.update] & ":" & $key.item & " -> " & deps, 2, "| ") & "\n"

template query*(name: string) {.pragma.}

macro CreateContext*(contextName: untyped, body: untyped): untyped =
  result = nnkStmtList.newTree()

  # Helper functions to access information about declarations
  proc queryFunctionName(query: NimNode): NimNode =
    if query[0].kind == nnkPostfix:
      return query[0][1]
    return query[0]
  proc queryName(query: NimNode): string =
    return query[4][0][1].strVal
  proc queryArgType(query: NimNode): NimNode = query[3][2][1]
  proc queryValueType(query: NimNode): NimNode = query[3][0]
  proc inputName(input: NimNode): NimNode = input[1]

  proc isQuery(arg: NimNode): bool =
    if arg.len < 5: return false
    let pragmas = arg[4]
    if pragmas.kind != nnkPragma or pragmas.len < 1: return false
    for pragma in pragmas:
      if pragma.kind != nnkCall or pragma.len != 2: continue
      if pragma[0].strVal == "query":
        return true
    return false

  proc isInputDefinition(arg: NimNode): bool =
    if arg.kind != nnkCommand or arg.len < 2: return false
    if arg[0].strVal != "input": return false
    return true

  proc isDataDefinition(arg: NimNode): bool =
    if arg.kind != nnkCommand or arg.len < 2: return false
    if arg[0].strVal != "data": return false
    return true

  proc isCustomMemberDefinition(arg: NimNode): bool =
    return arg.kind == nnkVarSection

  proc customMemberName(arg: NimNode): NimNode =
    if arg[0].kind == nnkPostfix:
      return arg[0][1]
    return arg[0]

  # for arg in body:
  #   if not isCustomMemberDefinition arg:
  #     continue
  #   echo "customMember: ", arg.treeRepr

  # List of members of the final Context type
  # depGraph: DependencyGraph
  # dependencyStack: seq[seq[Key]]
  let memberList = nnkRecList.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("depGraph"),
      quote do: DependencyGraph,
      newEmptyNode()
    ),
    nnkIdentDefs.newTree(
      newIdentNode("dependencyStack"),
      quote do: seq[seq[Dependency]],
      newEmptyNode()
    ),
    nnkIdentDefs.newTree(nnkPostfix.newTree(ident"*", newIdentNode("enableLogging")), bindSym"bool", newEmptyNode()),
  )

  # Add member for each input
  # items: Table[ItemId, Input]
  for input in body:
    if not isInputDefinition input: continue

    let name = inputName input

    memberList.add nnkIdentDefs.newTree(
      ident("items" & name.strVal),
      quote do: Table[ItemId, `name`],
      newEmptyNode()
    )

  # Add member declarations for custom members
  for customMembers in body:
    if not isCustomMemberDefinition customMembers: continue

    for member in customMembers:
      memberList.add nnkIdentDefs.newTree(member[0], member[1], newEmptyNode())

  # Add member for each data
  # data: Table[Data, int]
  for data in body:
    if not isDataDefinition data: continue

    let name = inputName data
    let items = ident "items" & name.strVal

    memberList.add nnkIdentDefs.newTree(
      items,
      quote do: Table[ItemId, `name`],
      newEmptyNode()
    )

  # Add two members for each query
  # queryCache: Table[QueryInput, QueryOutput]
  # update: proc(item: ItemId): Fingerprint
  for query in body:
    if not isQuery query: continue

    let name = queryName query
    let key = queryArgType query
    let value = queryValueType query

    memberList.add nnkIdentDefs.newTree(
      ident("queryCache" & name),
      quote do: Table[`key`, `value`],
      newEmptyNode()
    )
    memberList.add nnkIdentDefs.newTree(
      ident("update" & name),
      nnkPar.newTree(
        nnkProcTy.newTree(
          nnkFormalParams.newTree(
            bindSym"Fingerprint",
            nnkIdentDefs.newTree(genSym(nskParam), bindSym"ItemId", newEmptyNode())
          ),
          newEmptyNode()
        )
      ),
      newEmptyNode()
    )

  # Create Context type
  # type Context* = ref object
  #   memberList...
  result.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(ident"*", contextName),
      newEmptyNode(),
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          memberList
        )
      )
    )
  )

  # Add all statements in the input body of this macro as is to the output
  for query in body:
    if not isQuery(query):
      continue
    result.add query

  # Create newContext function for initializing a new context
  # proc newContext(): Context = ...
  var ctx = genSym(nskVar, "ctx")
  let newContextFnName = ident "new" & contextName.strVal
  var newContextFn = quote do:
    proc `newContextFnName`*(): `contextName` =
      var `ctx`: `contextName`
      new `ctx`
      `ctx`.depGraph = newDependencyGraph()
      `ctx`.dependencyStack = @[]

  # Add initialization code to the newContext function for each query
  # ctx.update = proc(arg: QueryInput): Fingerprint = ...
  var queryInitializers: seq[NimNode] = @[]
  for query in body:
    if not isQuery query: continue

    let name = queryName query
    let key = queryArgType query
    let value = queryValueType query

    let updateName = ident "update" & name
    let queryCache = ident "queryCache" & name
    let queryFunction = queryFunctionName query
    let items = ident "items" & key.strVal

    queryInitializers.add quote do:
      `ctx`.`updateName` = proc (item: ItemId): Fingerprint =
        let arg = `ctx`.`items`[item]
        let value: `value` = `queryFunction`(`ctx`, arg)
        `ctx`.`queryCache`[arg] = value
        return value.fingerprint
      `ctx`.depGraph.queryNames[`ctx`.`updateName`] = `name`

  ## Add initializers for custom members
  for customMembers in body:
    if not isCustomMemberDefinition customMembers: continue

    for member in customMembers:
      if member[2].kind == nnkEmpty: continue
      let name = customMemberName member
      let initValue = member[2]
      queryInitializers.add quote do:
        `ctx`.`name` = `initValue`

  # Add the per query data initializers to the body of the newContext function
  for queryInitializer in queryInitializers:
    newContextFn[6].add queryInitializer
  newContextFn[6].add quote do: return `ctx`
  result.add newContextFn

  # Create $ for each query
  var queryCachesToString = nnkStmtList.newTree()
  let toStringCtx = genSym(nskParam)
  let toStringResult = genSym(nskVar)
  for input in body:
    if not (isInputDefinition(input) or isDataDefinition(input)): continue

    let name = inputName(input).strVal
    let items = ident "items" & name

    queryCachesToString.add quote do:
      `toStringResult`.add repeat("| ", 1) & "Items: " & `name` & "\n"
      for (key, value) in `toStringCtx`.`items`.pairs:
        `toStringResult`.add repeat("| ", 2) & $key & " -> " & $value & "\n"

  for query in body:
    if not isQuery query: continue

    let name = queryName query
    let queryCache = ident "queryCache" & name

    queryCachesToString.add quote do:
      `toStringResult`.add repeat("| ", 1) & "Cache: " & `name` & "\n"
      for (key, value) in `toStringCtx`.`queryCache`.pairs:
        `toStringResult`.add repeat("| ", 2) & $key & " -> " & $value & "\n"

  # Create $ implementation for Context
  result.add quote do:
    proc toString*(`toStringCtx`: `contextName`): string =
      var `toStringResult` = "Context\n"

      `queryCachesToString`

      `toStringResult`.add indent($`toStringCtx`.depGraph, 1, "| ")

      return `toStringResult`

  # proc recordDependency(ctx: Context, item: ItemId, update: UpdateFunction)
  result.add quote do:
    proc recordDependency*(ctx: `contextName`, item: ItemId, update: UpdateFunction = nil) =
      if ctx.dependencyStack.len > 0:
        ctx.dependencyStack[ctx.dependencyStack.high].add (item, update)

  # Add newData function for each data
  for data in body:
    if not isDataDefinition data: continue

    let name = inputName data
    let items = ident "items" & name.strVal
    let functionName = ident "new" & name.strVal

    result.add quote do:
      proc `functionName`*(ctx: `contextName`, data: `name`): `name` =
        let item = data.getItem
        let key: Dependency = (item, nil)
        if ctx.depGraph.changed.contains(key):
          ctx.depGraph.changed[key] = ctx.depGraph.revision
        else:
          ctx.depGraph.changed.add(key, ctx.depGraph.revision)
        ctx.`items`.add(item, data)
        return data

  # proc force(ctx: Context, key: Dependency)
  result.add quote do:
    proc force(ctx: `contextName`, key: Dependency) =
      inc currentIndent, if ctx.enableLogging: 1 else: 0
      defer: dec currentIndent, if ctx.enableLogging: 1 else: 0
      if ctx.enableLogging: echo repeat("| ", currentIndent - 1), "force ", key.item

      ctx.depGraph.clearEdges(key)
      ctx.dependencyStack.add(@[])
      ctx.recordDependency(key.item)

      let fingerprint = key.update(key.item)

      ctx.depGraph.setDependencies(key, ctx.dependencyStack.pop)

      let prevFingerprint = ctx.depGraph.fingerprint(key)

      if fingerprint == prevFingerprint:
        if ctx.enableLogging: echo repeat("| ", currentIndent), "mark green"
        ctx.depGraph.markGreen(key)
      else:
        if ctx.enableLogging: echo repeat("| ", currentIndent), "mark red"
        ctx.depGraph.markRed(key, fingerprint)

  # proc tryMarkGreen(ctx: Context, key: Dependency): bool
  result.add quote do:
    proc tryMarkGreen(ctx: `contextName`, key: Dependency): bool =
      inc currentIndent, if ctx.enableLogging: 1 else: 0
      defer: dec currentIndent, if ctx.enableLogging: 1 else: 0
      if ctx.enableLogging: echo repeat("| ", currentIndent - 1), "tryMarkGreen ", ctx.depGraph.queryNames[key.update] & ":" & $key.item, ", deps: ", ctx.depGraph.getDependencies(key)

      let verified = ctx.depGraph.verified.getOrDefault(key, 0)

      for i, dep in ctx.depGraph.getDependencies(key):
        if dep.item.id == null:
          if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency got deleted -> red, failed"
          return false
        case ctx.depGraph.nodeColor(dep, verified)
        of Green:
          if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency ", ctx.depGraph.queryNames[dep.update] & ":" & $dep.item, " is green, skip"
          discard
        of Red:
          if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency ", ctx.depGraph.queryNames[dep.update] & ":" & $dep.item, " is red, failed"
          return false
        of Grey:
          if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency ", ctx.depGraph.queryNames[dep.update] & ":" & $dep.item, " is grey"
          if not ctx.tryMarkGreen(dep):
            if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency ", ctx.depGraph.queryNames[dep.update] & ":" & $dep.item, ", mark green failed"
            ctx.force(dep)

            if ctx.depGraph.nodeColor(dep, verified) == Red:
              if ctx.enableLogging: echo repeat("| ", currentIndent), "Dependency ", ctx.depGraph.queryNames[dep.update] & ":" & $dep.item, ", value changed"
              return false

      if ctx.enableLogging: echo repeat("| ", currentIndent), "mark green"
      ctx.depGraph.markGreen(key)

      return true

  # Add compute function for every query
  # proc compute(ctx: Context, item: QueryInput): QueryOutput
  for query in body:
    if not isQuery query: continue

    let name = queryName query
    let key = queryArgType query
    let value = queryValueType query

    let updateName = ident "update" & name
    let computeName = ident "compute" & name
    let queryCache = ident "queryCache" & name

    let nameString = name

    result.add quote do:
      proc `computeName`*(ctx: `contextName`, input: `key`): `value` =
        let item = getItem input
        let key = (item, ctx.`updateName`)

        ctx.recordDependency(item, ctx.`updateName`)

        let color = ctx.depGraph.nodeColor(key)

        inc currentIndent, if ctx.enableLogging: 1 else: 0
        defer: dec currentIndent, if ctx.enableLogging: 1 else: 0
        if ctx.enableLogging: echo repeat("| ", currentIndent - 1), "compute", `nameString`, " ", color, ", ", item

        if color == Green:
          if not ctx.`queryCache`.contains(input):
            if ctx.enableLogging: echo repeat("| ", currentIndent), "green, not in cache"
            ctx.force(key)
            if ctx.enableLogging: echo repeat("| ", currentIndent), "result: ", $ctx.`queryCache`[input]
          else:
            if ctx.enableLogging: echo repeat("| ", currentIndent), "green, in cache, result: ", $ctx.`queryCache`[input]
          return ctx.`queryCache`[input]

        if color == Grey:
          if not ctx.`queryCache`.contains(input):
            if ctx.enableLogging: echo repeat("| ", currentIndent), "grey, not in cache"
            ctx.force(key)
            if ctx.enableLogging: echo repeat("| ", currentIndent), "result: ", $ctx.`queryCache`[input]
            return ctx.`queryCache`[input]

          if ctx.enableLogging: echo repeat("| ", currentIndent), "grey, in cache"
          if ctx.tryMarkGreen(key):
            if ctx.enableLogging: echo repeat("| ", currentIndent), "green, result: ", $ctx.`queryCache`[input]
            return ctx.`queryCache`[input]
          else:
            if ctx.enableLogging: echo repeat("| ", currentIndent), "failed to mark green"
            ctx.force(key)
            if ctx.enableLogging: echo repeat("| ", currentIndent), "result: ", $ctx.`queryCache`[input]
            return ctx.`queryCache`[input]

        assert color == Red
        if ctx.enableLogging: echo repeat("| ", currentIndent), "red, in cache, result: ", $ctx.`queryCache`[input]
        return ctx.`queryCache`[input]

  echo result.repr