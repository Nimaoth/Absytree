# Package

version       = "0.1.1"
author        = "Nimaoth"
description   = "Programming language + editor"
license       = "MIT"
srcDir        = "src"
bin           = @["absytree"]

# Dependencies

requires "nim >= 1.7.3"
requires "chroma >= 0.2.7"
requires "boxy >= 0.4.1"
requires "windy >= 0.0.0"
requires "winim >= 3.8.1"
requires "fusion >= 1.2"
requires "print >= 1.0.2"
requires "fuzzy >= 0.1.0"
requires "lrucache >= 1.1.4"
requires "nimsimd >= 1.2.4"
requires "https://github.com/Nimaoth/nimscripter >= 1.0.17"
requires "https://github.com/Nimaoth/nimtreesitter?subdir=treesitter >= 0.1.1"
requires "https://github.com/Nimaoth/nimtreesitter?subdir=treesitter_nim >= 0.1.1"

task createScriptingDocs, "Build the documentation for the scripting API":
  exec "nim doc --project --index:on --git.url:https://github.com/Nimaoth/Absytree/ --git.commit:main ./scripting/absytree_runtime.nim"
  exec "nim buildIndex -o:./scripting/htmldocs/theindex.html ./scripting/htmldocs"
  exec "nim ./postprocess_docs.nims"