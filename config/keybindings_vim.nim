import absytree_runtime, keybindings_normal
import timer

proc loadVimKeybindings*() {.scriptActionWasmNims("load-vim-keybindings").} =
  loadNormalKeybindings()

  let t = startTimer()
  defer:
    infof"loadVimKeybindings: {t.elapsed.ms} ms"

  info "Applying Vim keybindings"

  # clearCommands("editor.text")
  # for id in getAllEditors():
  #   if id.isTextEditor(editor):
  #     editor.setMode("")

  setModeChangedHandler proc(editor, oldMode, newMode: auto) =
    if oldMode == "" and newMode != "":
      editor.clearCurrentCommandHistory(retainLast=true)
    elif oldMode != "" and newMode == "":
      editor.saveCurrentCommandHistory()

  # Normal mode
  setHandleInputs "editor.text", false
  setOption "editor.text.cursor.movement.", "both"
  setOption "editor.text.cursor.wide.", true

  # navigation
  addTextCommand "", "<C-d>", "move-cursor-line", 30
  addTextCommand "", "<C-u>", "move-cursor-line", -30

  addTextCommandBlock "", "gg":
    let count = editor.getCommandCount
    editor.selection = (count, 0).toSelection
    editor.setCommandCount 0
    editor.scrollToCursor Last

  addTextCommand "", "G", "move-last", "file"

  addTextCommand "", "n", "select-move", "next-find-result", true
  addTextCommand "", "N", "select-move", "prev-find-result", true

  addTextCommandBlock "", "*": editor.setSearchQueryFromMove("word")

  # editing
  addTextCommand "", "x", "delete-right"
  addTextCommand "", "u", "undo"
  addTextCommand "", "U", "redo"
  addTextCommand "", "p", "paste"

  addTextCommand "", "\\>", "indent"
  addTextCommand "", "\\<", "unindent"

  addTextCommand "", ".", "run-saved-commands"

  # mode switches
  addTextCommand "", "i", "set-mode", "insert"
  addTextCommandBlock "", "I":
    editor.moveFirst("line-no-indent")
    editor.setMode("insert")
  addTextCommandBlock "", "a":
    editor.selections = editor.selections.mapIt(editor.doMoveCursorColumn(it.last, 1).toSelection)
    editor.setMode("insert")
  addTextCommandBlock "", "A":
    editor.moveLast("line")
    editor.setMode("insert")

  addTextCommand "", "v", "set-mode", "visual"

  addTextCommandBlock "", "s":
    editor.selections = editor.delete(editor.selections)
    editor.setMode("insert")

  for i in 0..9:
    capture i:
      proc updateCommandCountHelper(editor: TextDocumentEditor) =
        editor.updateCommandCount i
        # echo "updateCommandCount ", editor.getCommandCount
        editor.setCommandCountRestore editor.getCommandCount
        editor.setCommandCount 0

      addTextCommand "", $i, updateCommandCountHelper

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
  addTextCommandBlock "", "<C-e>":
    editor.setMode("")
    editor.selection = editor.selection.last.toSelection
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
  addTextMoveCommand "F", "file"
  addTextMoveCommand "\"", "\""
  addTextMoveCommand "'", "'"
  addTextMoveCommand "(", "("
  addTextMoveCommand ")", "("
  addTextMoveCommand "[", "["
  addTextMoveCommand "]", "["
  addTextMoveCommand "}", "}"

  addTextCommand "move", "d", "apply-move", "line-next", true
  addTextCommand "move-inside", "d", "apply-move", "line-next", true
  addTextCommand "move", "y", "apply-move", "line-next", true
  addTextCommand "move-inside", "y", "apply-move", "line-next", true

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
  addTextCommand "visual", "y", "copy"

  addTextCommandBlock "visual", "i":
    editor.setMode("move-inside")
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


  block: # model
    setHandleInputs "editor.model", false
    setOption "editor.model.cursor.wide.", true
    addCommand("editor.model", "<LEFT>", "move-cursor-left-line")
    addCommand("editor.model", "<RIGHT>", "move-cursor-right-line")
    addCommand("editor.model", "<A-LEFT>", "move-cursor-left")
    addCommand("editor.model", "<A-RIGHT>", "move-cursor-right")
    addCommand("editor.model", "<UP>", "move-cursor-up")
    addCommand("editor.model", "<DOWN>", "move-cursor-down")
    addCommand("editor.model", "<A-UP>", "select-node")
    addCommand("editor.model", "<A-DOWN>", "move-cursor-down")
    addCommand("editor.model", "<C-LEFT>", "move-cursor-left-cell")
    addCommand("editor.model", "<C-RIGHT>", "move-cursor-right-cell")
    addCommand("editor.model", "b", "move-cursor-left-cell")
    addCommand("editor.model", "w", "move-cursor-right-cell")
    addCommand("editor.model", "<HOME>", "move-cursor-line-start")
    addCommand("editor.model", "<END>", "move-cursor-line-end")
    addCommand("editor.model", "<A-HOME>", "move-cursor-line-start-inline")
    addCommand("editor.model", "<A-END>", "move-cursor-line-end-inline")
    addCommand("editor.model", "<C-UP>", "scroll-lines", 1)
    addCommand("editor.model", "<C-DOWN>", "scroll-lines", -1)

    addCommand("editor.model", "<S-LEFT>", "move-cursor-left-line", true)
    addCommand("editor.model", "<S-RIGHT>", "move-cursor-right-line", true)
    addCommand("editor.model", "<SA-LEFT>", "move-cursor-left", true)
    addCommand("editor.model", "<SA-RIGHT>", "move-cursor-right", true)
    addCommand("editor.model", "<S-UP>", "move-cursor-up", true)
    addCommand("editor.model", "<S-DOWN>", "move-cursor-down", true)
    addCommand("editor.model", "<SA-UP>", "move-cursor-up", true)
    addCommand("editor.model", "<SA-DOWN>", "move-cursor-down", true)
    addCommand("editor.model", "<SC-LEFT>", "move-cursor-left-cell", true)
    addCommand("editor.model", "<SC-RIGHT>", "move-cursor-right-cell", true)
    addCommand("editor.model", "<S-HOME>", "move-cursor-line-start", true)
    addCommand("editor.model", "<S-END>", "move-cursor-line-end", true)
    addCommand("editor.model", "<SA-HOME>", "move-cursor-line-start-inline", true)
    addCommand("editor.model", "<SA-END>", "move-cursor-line-end-inline", true)

    addCommand("editor.model", "<C-y>", "undo")
    addCommand("editor.model", "<C-z>", "redo")
    addCommand("editor.model", "u", "undo")
    addCommand("editor.model", "U", "redo")
    addCommand("editor.model", "<BACKSPACE>", "replace-left")
    addCommand("editor.model", "<DELETE>", "replace-right")
    addCommand("editor.model", "<C-BACKSPACE>", "delete-left")
    addCommand("editor.model", "<C-DELETE>", "delete-right")
    addCommand("editor.model", "<ENTER>", "create-new-node")
    addCommand("editor.model", "<TAB>", "select-next-placeholder")
    addCommand("editor.model", "<S-TAB>", "select-prev-placeholder")

    addCommand("editor.model", "<C-SPACE>", "show-completions")

    addCommand("editor.model", "<LEADER>mr", "run-selected-function")
    addCommand("editor.model", "<LEADER>md", "toggle-use-default-cell-builder")

    addCommand("editor.model.completion", "<ENTER>", "finish-edit", true)
    addCommand("editor.model.completion", "<ESCAPE>", "hide-completions")
    addCommand("editor.model.completion", "<UP>", "select-prev-completion")
    addCommand("editor.model.completion", "<DOWN>", "select-next-completion")
    addCommand("editor.model.completion", "<C-SPACE>", "move-cursor-start")
    addCommand("editor.model.completion", "<TAB>", "apply-selected-completion")

    addCommand "editor.model.goto", "<END>", "end"

    addModelCommandBlock "", "<C-e>":
      editor.setMode("")
      # editor.selection = editor.selection.last.toSelection
    addModelCommandBlock "", "<ESCAPE>":
      editor.setMode("")
      # editor.selection = editor.selection.last.toSelection
    addModelCommandBlock "", "<S-ESCAPE>":
      editor.setMode("")
      # editor.selection = editor.selection.last.toSelection

    addModelCommand "", "i", "set-mode", "insert"
    addModelCommandBlock "", "I":
      editor.moveCursorLineStart(false)
      editor.setMode("insert")
    addModelCommandBlock "", "a":
      # editor.selections = editor.selections.mapIt(editor.doMoveCursorColumn(it.last, 1).toSelection)
      editor.setMode("insert")
    addModelCommandBlock "", "A":
      editor.moveCursorLineEnd(false)
      editor.setMode("insert")

    # Insert mode
    setHandleInputs "editor.model.insert", true
    setOption "editor.model.cursor.wide.insert", false
    addModelCommand "insert", "<SPACE>", "insert-text-at-cursor", " "
