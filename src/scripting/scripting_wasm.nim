import std/[macros, macrocache, genasts, json, strutils, os]
import misc/[custom_logger, custom_async, util]
import platform/filesystem
import scripting_base, document_editor, expose, vfs

import wasm

when not defined(js):
  import wasm3, wasm3/wasmconversions

export scripting_base, wasm

logCategory "scripting-wasm"

type
  ScriptContextWasm* = ref object of ScriptContext
    modules: seq[WasmModule]

    editorModeChangedCallbacks: seq[tuple[module: WasmModule, callback: proc(editor: int32, oldMode: cstring, newMode: cstring): void {.gcsafe.}]]
    postInitializeCallbacks: seq[tuple[module: WasmModule, callback: proc(): bool {.gcsafe.}]]
    handleCallbackCallbacks: seq[tuple[module: WasmModule, callback: proc(id: int32, args: cstring): bool {.gcsafe.}]]
    handleAnyCallbackCallbacks: seq[tuple[module: WasmModule, callback: proc(id: int32, args: cstring): cstring {.gcsafe.}]]
    handleScriptActionCallbacks: seq[tuple[module: WasmModule, callback: proc(name: cstring, args: cstring): cstring {.gcsafe.}]]

    stack: seq[WasmModule]

    vfs*: VFSWasmContext

  VFSWasmContext* = ref object of VFS

method readImpl*(self: VFSWasmContext, path: string): Future[Option[string]] {.async.} =
  log lvlError, &"[VFSWasmContext] read({path}): not found"
  return string.none

var createEditorWasmImports: proc(): WasmImports {.gcsafe, raises: [].}

method getCurrentContext*(self: ScriptContextWasm): string =
  result = "plugs://"
  if self.stack.len > 0:
    result.add self.stack[^1].path.splitFile.name
    result.add "/"

macro invoke*(self: ScriptContextWasm; pName: untyped; args: varargs[typed]; returnType: typedesc): untyped =
  result = quote do:
    default(`returnType`)

proc loadModules(self: ScriptContextWasm, path: string): Future[void] {.async.} =
  let (files, _) = await self.fs.getApplicationDirectoryListing(path)

  {.gcsafe.}:
    var editorImports = createEditorWasmImports()

  for file in files:
    if not file.endsWith(".wasm"):
      continue

    try:
      log lvlInfo, fmt"Try to load wasm module '{file}' from app directory"
      let module = await newWasmModule(file, @[editorImports], self.fs)

      if module.getSome(module):
        self.vfs.mount(file.splitFile.name & "/", newInMemoryVFS())
        self.stack.add module
        defer: discard self.stack.pop

        log(lvlInfo, fmt"Loaded wasm module '{file}'")

        # todo: shouldn't need to specify gcsafe here, findFunction should handle that
        if findFunction(module, "handleEditorModeChangedWasm", void, proc(editor: int32, oldMode: cstring, newMode: cstring): void {.gcsafe.}).getSome(f):
          self.editorModeChangedCallbacks.add (module, f)

        if findFunction(module, "postInitializeWasm", bool, proc(): bool {.gcsafe.}).getSome(f):
          self.postInitializeCallbacks.add (module, f)

        if findFunction(module, "handleCallbackWasm", bool, proc(id: int32, arg: cstring): bool {.gcsafe.}).getSome(f):
          self.handleCallbackCallbacks.add (module, f)

        if findFunction(module, "handleAnyCallbackWasm", cstring, proc(id: int32, arg: cstring): cstring {.gcsafe.}).getSome(f):
          self.handleAnyCallbackCallbacks.add (module, f)

        if findFunction(module, "handleScriptActionWasm", cstring, proc(name: cstring, arg: cstring): cstring {.gcsafe.}).getSome(f):
          self.handleScriptActionCallbacks.add (module, f)

        self.modules.add module

        if findFunction(module, "plugin_main", void, proc(): void {.gcsafe.}).getSome(f):
          log lvlInfo, "Run plugin_main"
          f()
          log lvlInfo, "Finished plugin_main"

      else:
        log(lvlError, fmt"Failed to create wasm module for file {file}")

    except:
      log lvlError, &"Failde to load wasm module '{file}': {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

method init*(self: ScriptContextWasm, path: string, fs: Filesystem): Future[void] {.async.} =
  self.fs = fs
  await self.loadModules("./config/wasm")

method deinit*(self: ScriptContextWasm) = discard

method reload*(self: ScriptContextWasm): Future[void] {.async.} =
  self.editorModeChangedCallbacks.setLen 0
  self.postInitializeCallbacks.setLen 0
  self.handleCallbackCallbacks.setLen 0
  self.handleAnyCallbackCallbacks.setLen 0
  self.handleScriptActionCallbacks.setLen 0

  self.modules.setLen 0

  await self.loadModules("./config/wasm")

method handleEditorModeChanged*(self: ScriptContextWasm, editor: DocumentEditor, oldMode: string, newMode: string) {.gcsafe, raises: [].} =
  try:
    for (m, f) in self.editorModeChangedCallbacks:
      f(editor.id.int32, oldMode.cstring, newMode.cstring)
  except:
    log lvlError, &"Failed to run handleEditorModeChanged: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

method postInitialize*(self: ScriptContextWasm): bool {.gcsafe, raises: [].} =
  result = false
  try:
    for (m, f) in self.postInitializeCallbacks:
      self.stack.add m
      defer: discard self.stack.pop
      result = f() or result
  except:
    log lvlError, &"Failed to run post initialize: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

method handleCallback*(self: ScriptContextWasm, id: int, arg: JsonNode): bool {.gcsafe, raises: [].} =
  result = false
  try:
    let argStr = $arg
    for (m, f) in self.handleCallbackCallbacks:
      self.stack.add m
      defer: discard self.stack.pop
      if f(id.int32, argStr.cstring):
        return true
  except:
    log lvlError, &"Failed to run callback: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

method handleAnyCallback*(self: ScriptContextWasm, id: int, arg: JsonNode): JsonNode {.gcsafe, raises: [].} =
  try:
    result = nil
    let argStr = $arg
    for (m, f) in self.handleAnyCallbackCallbacks:
      self.stack.add m
      defer: discard self.stack.pop
      let str = $f(id.int32, argStr.cstring)
      if str.len == 0:
        continue

      try:
        return str.parseJson
      except:
        log lvlError, &"Failed to parse json from callback {id}({arg}): '{str}' is not valid json.\n{getCurrentExceptionMsg()}"
        continue
  except:
    log lvlError, &"Failed to run handleAnyCallback: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"


method handleScriptAction*(self: ScriptContextWasm, name: string, args: JsonNode): JsonNode {.gcsafe, raises: [].} =
  try:
    result = nil
    let argStr = $args
    for (m, f) in self.handleScriptActionCallbacks:
      self.stack.add m
      defer: discard self.stack.pop
      let res = $f(name.cstring, argStr.cstring)
      if res.len == 0:
        continue

      try:
        return res.parseJson
      except:
        log lvlError, &"Failed to parse json from script action {name}({args}): '{res}' is not valid json.\n{getCurrentExceptionMsg()}"
        continue
  except:
    log lvlError, &"Failed to run handleScriptAction: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

# Sets the implementation of createEditorWasmImports. This needs to happen late during compilation after any expose pragmas have been executed,
# because this goes through all exposed functions at compile time to create the wasm import data.
# That's why it's in a template
template createEditorWasmImportConstructor*() =
  proc createEditorWasmImportsImpl(): WasmImports =
    macro addEditorFunctions(imports: WasmImports): untyped =
      var list = nnkStmtList.newTree()
      for m, l in wasmImportedFunctions:
        for f in l:
          let name = f[0].strVal.newLit
          let function = f[0]

          let imp = genAst(imports, name, function):
            imports.addFunction(name, function)
          list.add imp

      return list

    var imports = WasmImports(namespace: "env")
    addEditorFunctions(imports)
    return imports

  createEditorWasmImports = createEditorWasmImportsImpl
