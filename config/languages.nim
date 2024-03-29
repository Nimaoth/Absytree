import absytree_runtime

{.used.}

let useLSPWebsocketProxy = getBackend() == Browser

if useLSPWebsocketProxy:
  setOption "editor.text.languages-server.url", "localhost"
  setOption "editor.text.languages-server.port", 3001
else:
  setOption "editor.text.languages-server.url", ""
  setOption "editor.text.languages-server.port", 0

proc loadLspConfigFromFile*(file: string) =
  try:
    let str = loadApplicationFile(file).get
    let json = str.parseJson()
    infof"Loaded lsp config from file: {json}"
    setOption "editor.text.lsp", json
  except:
    info &"Failed to load lsp config from file: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

proc loadSnippetsFromFile*(file: string, language: string) =
  try:
    let str = loadApplicationFile(file).get
    let json = str.parseJson()
    infof"Loaded snippet config for {language} from {file}: {json}"
    # todo: better deal with languages
    setOption "editor.text.snippets." & language, json
  except:
    info &"Failed to load lsp config from file: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

setOption "editor.text.lsp.c.path", "clangd"
setOption "editor.text.lsp.cpp.path", "clangd"
setOption "editor.text.lsp.zig.path", "zls"
setOption "editor.text.lsp.rust.path", "rust-analyzer"
setOption "editor.text.lsp.nim.path", "nimlangserver"
setOption "editor.text.lsp.nim.args", %*["--stdio"]
setOption "editor.text.treesitter.rust.dll", "D:/dev/Nim/nimtreesitter/treesitter_rust/treesitter_rust/rust.dll"
setOption "editor.text.treesitter.zig.dll", "D:/dev/Nim/nimtreesitter/treesitter_zig/treesitter_zig/zig.dll"
setOption "editor.text.treesitter.javascript.dll", "D:/dev/Nim/nimtreesitter/treesitter_javascript/treesitter_javascript/javascript.dll"
setOption "editor.text.treesitter.nim.dll", "D:/dev/Nim/nimtreesitter/treesitter_nim/treesitter_nim/nim.dll"
setOption "editor.text.treesitter.python.dll", "D:/dev/Nim/nimtreesitter/treesitter_python/treesitter_python/python.dll"
setOption "editor.text.treesitter.cpp.dll", "D:/dev/Nim/nimtreesitter/treesitter_cpp/treesitter_cpp/cpp.dll"
setOption "editor.text.treesitter.c.dll", "D:/dev/Nim/nimtreesitter/treesitter_c/treesitter_c/c.dll"

setOption "editor.text.language.nim", %*{
  "tabWidth": 2,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "[", "enum", "object"],
  "lineComment": "#",
}

setOption "editor.text.language.python", %*{
  "tabWidth": 2,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "#",
}

setOption "editor.text.language.javascript", %*{
  "tabWidth": 4,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
  "ignoreContextLinePrefix": "{",
}

setOption "editor.text.language.typescript", %*{
  "tabWidth": 4,
  "indent": "tab",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
}

setOption "editor.text.language.rust", %*{
  "tabWidth": 4,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
}

setOption "editor.text.language.c", %*{
  "tabWidth": 4,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
}

setOption "editor.text.language.cpp", %*{
  "tabWidth": 4,
  "indent": "spaces",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
}

setOption "editor.text.language.java", %*{
  "tabWidth": 4,
  "indent": "tab",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
  "blockComment": ["/*", "*/"],
}

setOption "editor.text.language.zig", %*{
  "tabWidth": 4,
  "indent": "tab",
  "indentAfter": [":", "=", "(", "{", "["],
  "lineComment": "//",
}