import plugin_runtime, keybindings_normal

proc loadCustomKeybindings*() {.expose("load-custom-keybindings").} =
  loadNormalKeybindings()

  info "Applying Custom keybindings"

  # clearCommands("editor.text")
  # for id in getAllEditors():
  #   if id.isTextEditor(editor):
  #     editor.setMode("")

  # Normal mode
  setHandleInputs "editor.text", false
  setOption "editor.text.cursor.movement.", "both"
  setOption "editor.text.cursor.wide.", true

  # navigation
  addTextCommand "", "<C-d>", "move-cursor-line", 30
  addTextCommand "", "<C-u>", "move-cursor-line", -30

  addTextCommandBlock "", "gg":
    let count = editor.getCommandCount
    if count == 0:
      editor.selection = (0, 0).toSelection
    else:
      editor.selection = (count, 0).toSelection
      editor.setCommandCount 0
    editor.scrollToCursor(Last)

  addTextCommand "", "G", "move-last", "file"

  addTextCommand "", "n", "select-move", "next-find-result", true
  addTextCommand "", "N", "select-move", "prev-find-result", true
  addTextCommand "", "<C-e>", "addNextFindResultToSelection"
  addTextCommand "", "<C-E>", "addPrevFindResultToSelection"
  addTextCommand "", "<A-e>", "setAllFindResultToSelection"
  addTextCommandBlock "", "*": editor.setSearchQueryFromMove("word")

  addTextCommand "", "<C-l>", "select-line-current"
  addTextCommand "", "miw", "select-inside-current"

  # lsp
  addTextCommand "", "gd", "goto-definition"
  addTextCommand "", "gs", "goto-symbol"
  addTextCommand "", "<C-SPACE>", "get-completions"

  # editing
  addTextCommand "", "x", "delete-right"
  addTextCommand "", "u", "undo"
  addTextCommand "", "U", "redo"
  addTextCommand "", "y", "copy"
  addTextCommand "", "p", "paste"

  # mode switches
  addTextCommand "", "i", "set-mode", "insert"
  addTextCommandBlock "", "a":
    editor.setMode("insert")
    editor.selections = editor.selections.mapIt((it.first, it.last.move(columns=1)))

  addTextCommand "", "v", "set-mode", "visual"
  addTextCommand "", "V", "set-mode", "visual-temp"

  addTextCommandBlock "", "s":
    editor.setMode("insert")
    editor.selections = editor.delete(editor.selections)

  for i in 0..9:
    capture i:
      proc updateCommandCountHelper(editor: TextDocumentEditor) =
        editor.updateCommandCount i
        # echo "updateCommandCount ", editor.getCommandCount
        editor.setCommandCountRestore editor.getCommandCount
        editor.setCommandCount 0

      addTextCommand "", $i, updateCommandCountHelper
      addTextCommand "delete", $i, updateCommandCountHelper
      addTextCommand "move", $i, updateCommandCountHelper

  addTextCommandBlock "", "d":
    editor.setMode "move"
    setOption "text.move-action", "delete-move"
    setOption "text.move-next-mode", ""
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommand "", "D", "delete-move", "line"

  addTextCommandBlock "", "c":
    editor.setMode "move"
    setOption "text.move-action", "change-move"
    setOption "text.move-next-mode", "insert"
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommandBlock "", "y":
    editor.setMode "move"
    setOption "text.move-action", "copy-move"
    setOption "text.move-next-mode", ""
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommandBlock "", "f":
    setOption("text.move-next-mode", editor.mode)
    editor.setMode "move-to"
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommandBlock "", "t":
    setOption("text.move-next-mode", editor.mode)
    editor.setMode "move-before"
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommandBlock "", "D":
    editor.deleteMove("line")

  addTextCommandBlock "", "C":
    editor.deleteMove("line")
    editor.setMode("insert")

  addTextCommandBlock "", "Y":
    editor.selectMove("line")
    editor.copy()

  addTextCommand "", "dl", "delete-move", "line-next"
  addTextCommand "", "b", "move-last", "word-line-back"
  addTextCommand "", "w", "move-last", "word-line"
  addTextCommand "", "e", "move-last", "word-line"
  addTextCommand "", "<HOME>", "move-first", "line"
  addTextCommand "", "<END>", "move-last", "line"
  addTextCommandBlock "", "o":
    editor.moveCursorEnd()
    editor.insertText("\n")
    editor.setMode("insert")
  addTextCommandBlock "", "O":
    editor.moveCursorEnd()
    editor.insertText("\n")
  addTextCommandBlock "", "<ESCAPE>":
    editor.setMode("")
    editor.selection = editor.selection.last.toSelection
  addTextCommandBlock "", "<S-ESCAPE>":
    editor.setMode("")
    editor.selection = editor.selection.last.toSelection

  # move mode
  setHandleInputs "editor.text.move", false
  setOption "editor.text.cursor.wide.move", true
  setOption "editor.text.cursor.movement.move", "both"
  addTextCommand "move", "i", "set-mode", "move-inside"

  template addTextMoveCommand(keys: string, move: string): untyped =
    addTextCommand "move", keys, "apply-move", move, false
    addTextCommand "move-inside", keys, "apply-move", move, true

  addTextMoveCommand "w", "word-line"
  addTextMoveCommand "W", "word"
  addTextMoveCommand "b", "word-line-back"
  addTextMoveCommand "B", "word-back"
  addTextMoveCommand "p", "paragraph"
  addTextMoveCommand "l", "line-next"
  addTextMoveCommand "L", "line"
  addTextMoveCommand "d", "line-next"
  addTextMoveCommand "F", "file"
  addTextMoveCommand "\"", "\""
  addTextMoveCommand "'", "'"
  addTextMoveCommand "(", "("
  addTextMoveCommand ")", "("
  addTextMoveCommand "[", "["
  addTextMoveCommand "]", "["
  addTextMoveCommand "}", "}"

  addTextCommandBlock "move", "f":
    editor.setMode "move-to"
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  addTextCommandBlock "move", "t":
    editor.setMode "move-before"
    setOption "text.move-command-count", editor.getCommandCount()
    editor.setCommandCount 0

  # move-to mode
  setHandleActions "editor.text.move-to", false
  setTextInputHandler "move-to", proc(editor: TextDocumentEditor, input: string): bool =
    editor.setMode getOption[string]("text.move-next-mode")
    if getOption[string]("text.move-action") != "":
      editor.setCommandCount getOption[int]("text.move-command-count")
      var args = newJArray()
      args.add newJString("move-to " & input)
      discard editor.runAction(getOption[string]("text.move-action"), args)
      setOption[string]("text.move-action", "")
    else:
      editor.moveCursorTo(input)
    return true
  setOption "editor.text.cursor.wide.move-to", true
  setOption "editor.text.cursor.movement.move-to", "both"

  # move-before mode
  setHandleActions "editor.text.move-before", false
  setTextInputHandler "move-before", proc(editor: TextDocumentEditor, input: string): bool =
    editor.setMode getOption[string]("text.move-next-mode")
    if getOption[string]("text.move-action") != "":
      editor.setCommandCount getOption[int]("text.move-command-count")
      var args = newJArray()
      args.add newJString("move-before " & input)
      discard editor.runAction(getOption[string]("text.move-action"), args)
      setOption[string]("text.move-action", "")
    else:
      editor.moveCursorBefore(input)
    return true
  setOption "editor.text.cursor.wide.move-before", true
  setOption "editor.text.cursor.movement.move-before", "both"

  # Insert mode
  setHandleInputs "editor.text.insert", true
  setOption "editor.text.cursor.wide.insert", false
  addTextCommand "insert", "<ENTER>", "insert-text", "\n"
  addTextCommand "insert", "<SPACE>", "insert-text", " "

  # Visual mode
  setHandleInputs "editor.text.visual", false
  setOption "editor.text.cursor.wide.visual", true
  setOption "editor.text.cursor.movement.visual", "last"
  addTextCommandBlock "visual", "i":
    editor.setMode("move")
    setOption("text.move-action", "select-move")
    setOption("text.move-next-mode", "visual")

  addTextCommandBlock "visual", "d":
    editor.selections = editor.delete(editor.selections)
    editor.setMode("")
    editor.scrollToCursor(Last)
    editor.updateTargetColumn(Last)

  addTextCommandBlock "visual", "c":
    editor.selections = editor.delete(editor.selections)
    editor.setMode("insert")
    editor.scrollToCursor(Last)
    editor.updateTargetColumn(Last)

  # Visual temp mode
  setHandleInputs "editor.text.visual-temp", false
  setOption "editor.text.cursor.wide.visual-temp", false
  setOption "editor.text.cursor.movement.visual-temp", "last-to-first"
  addTextCommandBlock "visual-temp", "i":
    editor.setMode("move")
    setOption("text.move-action", "select-move")
    setOption("text.move-next-mode", "visual-temp")

  addTextCommandBlock "visual", "d":
    editor.selections = editor.delete(editor.selections)
    editor.setMode("")
    editor.scrollToCursor(Last)
    editor.updateTargetColumn(Last)

  addTextCommandBlock "visual", "c":
    editor.selections = editor.delete(editor.selections)
    editor.setMode("insert")
    editor.scrollToCursor(Last)
    editor.updateTargetColumn(Last)

  addTextCommand "", "<C-b>", "set-mode", "cursor-build"
  addTextCommand "cursor-build", "c", "set-mode", "normal"
  addTextCommand "cursor-build", "<LEFT>", "move-cursor-column", -1, "config", false
  addTextCommand "cursor-build", "<RIGHT>", "move-cursor-column", 1, "config", false
  addTextCommand "cursor-build", "<C-LEFT>", "move-first", "word-line", "config", false
  addTextCommand "cursor-build", "<C-RIGHT>", "move-last", "word-line", "config", false
  addTextCommand "cursor-build", "<HOME>", "move-first", "line", "config", false
  addTextCommand "cursor-build", "<END>", "move-last", "line", "config", false
  addTextCommand "cursor-build", "<CS-LEFT>", "move-first", "word-line", "last", false
  addTextCommand "cursor-build", "<CS-RIGHT>", "move-last", "word-line", "last", false
  addTextCommand "cursor-build", "<UP>", "move-cursor-line", -1, "config", false
  addTextCommand "cursor-build", "<DOWN>", "move-cursor-line", 1, "config", false
  addTextCommand "cursor-build", "<C-HOME>", "move-first", "file", "config", false
  addTextCommand "cursor-build", "<C-END>", "move-last", "file", "config", false
  addTextCommand "cursor-build", "<CS-HOME>", "move-first", "file", "last", false
  addTextCommand "cursor-build", "<CS-END>", "move-last", "file", "last", false
  addTextCommand "cursor-build", "<S-LEFT>", "move-cursor-column", -1, "last", false
  addTextCommand "cursor-build", "<S-RIGHT>", "move-cursor-column", 1, "last", false
  addTextCommand "cursor-build", "<S-UP>", "move-cursor-line", -1, "last", false
  addTextCommand "cursor-build", "<S-DOWN>", "move-cursor-line", 1, "last", false
  addTextCommand "cursor-build", "<S-HOME>", "move-first", "line", "last", false
  addTextCommand "cursor-build", "<S-END>", "move-last", "line", "last", false
  addTextCommand "cursor-build", "n", "select-move", "next-find-result", false, false
  addTextCommand "cursor-build", "N", "select-move", "prev-find-result", false, false
  addTextCommandBlock "cursor-build", "y":
    editor.runAction("duplicate-last-selection")
    editor.runAction("select-move", "\"next-find-result\" false false")
  addTextCommandBlock "cursor-build", "Y":
    editor.runAction("duplicate-last-selection")
    editor.runAction("select-move", "\"prev-find-result\" false false")
