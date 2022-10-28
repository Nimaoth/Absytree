include abs
import std/[strutils, sugar]

# {.line: ("config.nims", 4).}

proc handleAction*(action: string, arg: string): bool =
  log "[script] ", action, ", ", arg

  case action
  of "test":
    getActiveEditor().insertText(arg)

  # of "set-flag":
  #   setFlag(arg, not getFlag(arg))

  of "toggle-flag":
    let newValue = not getFlag(arg)
    setFlag(arg, newValue)
    echo "[script] ", arg, " = ", newValue

  of "set-max-loop-iterations":
    setOption("ast.max-loop-iterations", arg.parseInt)

  else: return false

  return true

proc handlePopupAction*(popup: Popup, action: string, arg: string): bool =
  case action:
  of "home":
    for i in 0..<3:
      popup.runAction "prev"
  of "end":
    for i in 0..<3:
      popup.runAction "next"

  else: return false

  return true

proc handleDocumentEditorAction(editor: DocumentEditor, action: string, arg: string): bool =
  return false

func charCategory(c: char): int =
  if c.isAlphaNumeric or c == '_': return 0
  if c == ' ' or c == '\t': return 1
  return 2

type SelectionCursor* = enum Both = "both", First = "first", Last = "last", Invalid

proc cursor(selection: Selection, which: SelectionCursor): Cursor =
  case which
  of Both:
    return selection.last
  of First:
    return selection.first
  of Last:
    return selection.last
  of Invalid:
    assert false

proc handleTextEditorAction(editor: TextDocumentEditor, action: string, arg: string): bool =
  case action
  of "cursor.left-word":
    let which = if arg.len == 0: Both else: parseEnum[SelectionCursor](arg, Invalid)
    if which == Invalid:
      log(fmt"[error] Invalid argument for script text editor action '{action} {arg}'")
      return true

    let selection = editor.selection
    var cursor = selection.cursor(which)
    let line = editor.getLine cursor.line

    if cursor.column == 0:
      if cursor.line > 0:
        let prevLine = editor.getLine cursor.line - 1
        cursor = (cursor.line - 1, prevLine.len)
    else:
      while cursor.column > 0 and cursor.column <= line.len:
        cursor.column -= 1
        if cursor.column > 0:
          let leftCategory = line[cursor.column - 1].charCategory
          let rightCategory = line[cursor.column].charCategory
          if leftCategory != rightCategory:
            break

    case which
    of Both: editor.selection = cursor.toSelection
    of First: editor.selection = (cursor, selection.last)
    of Last: editor.selection = (selection.first, cursor)
    of Invalid: assert false

  of "cursor.right-word":
    let which = if arg.len == 0: Both else: parseEnum[SelectionCursor](arg, Invalid)
    if which == Invalid:
      log(fmt"[error] Invalid argument for script text editor action '{action} {arg}'")
      return true

    let selection = editor.selection
    var cursor = selection.cursor(which)
    let line = editor.getLine cursor.line
    let lineCount = editor.getLineCount

    if cursor.column == line.len:
      if cursor.line + 1 < lineCount:
        cursor = (cursor.line + 1, 0)
    else:
      while cursor.column >= 0 and cursor.column < line.len:
        cursor.column += 1
        if cursor.column < line.len:
          let leftCategory = line[cursor.column - 1].charCategory
          let rightCategory = line[cursor.column].charCategory
          if leftCategory != rightCategory:
            break

    case which
    of Both: editor.selection = cursor.toSelection
    of First: editor.selection = (cursor, selection.last)
    of Last: editor.selection = (selection.first, cursor)
    of Invalid: assert false

  else: return false
  return true

proc handleAstEditorAction(editor: AstDocumentEditor, action: string, arg: string): bool =
  case action

  else: return false
  return true

proc postInitialize*() =
  log "[script] postInitialize()"

  # runAction "open-file", "test.txt"
  # runAction "prev-view"

setOption "ast.scroll-speed", 60

addCommand "editor", "<SPACE>tt", proc() =
  setOption("ast.max-loop-iterations", clamp(getOption[int]("ast.max-loop-iterations") * 2, 1, 1000000))
  echo "ast.max-loop-iterations: ", getOption[int]("ast.max-loop-iterations")

addCommand "editor", "<SPACE>tr", proc() =
  setOption("ast.max-loop-iterations", clamp(getOption[int]("ast.max-loop-iterations") div 2, 1, 1000000))
  echo "ast.max-loop-iterations: ", getOption[int]("ast.max-loop-iterations")

addCommand "editor", "<SPACE>td", "toggle-flag", "ast.render-vnode-depth"
addCommand "editor", "<SPACE>ff", "log-options"
addCommand "editor", "<ESCAPE>", "escape"
addCommand "editor", "<C-l><C-h>", "change-font-size", "-1"
addCommand "editor", "<C-l><C-f>", "change-font-size", "1"
addCommand "editor", "<C-g>", "toggle-status-bar-location"
addCommand "editor", "<C-l><C-n>", "set-layout horizontal"
addCommand "editor", "<C-l><C-r>", "set-layout vertical"
addCommand "editor", "<C-l><C-t>", "set-layout fibonacci"
addCommand "editor", "<CA-h>", "change-layout-prop main-split", "-0.05"
addCommand "editor", "<CA-f>", "change-layout-prop main-split", "+0.05"
addCommand "editor", "<CA-v>", "create-view"
addCommand "editor", "<CA-a>", "create-keybind-autocomplete-view"
addCommand "editor", "<CA-x>", "close-view"
addCommand "editor", "<CA-n>", "prev-view"
addCommand "editor", "<CA-t>", "next-view"
addCommand "editor", "<CS-n>", "move-view-prev"
addCommand "editor", "<CS-t>", "move-view-next"
addCommand "editor", "<CA-r>", "move-current-view-to-top"
addCommand "editor", "<C-s>", "write-file"
addCommand "editor", "<CS-r>", "load-file"
addCommand "editor", "<C-p>", "command-line"
addCommand "editor", "<C-l>tt", "choose-theme"
addCommand "editor", "<C-m>t", "test uiaeuiae"
addCommand "editor", "<C-m>r", "test xvlcxvl  xvlc\n lol"
addCommand "editor", "<SPACE>fr", "toggle-flag log-render-duration"
addCommand "editor", "<SPACE>fd", "toggle-flag render-debug-info"
addCommand "editor", "<SPACE>fo", "toggle-flag render-execution-output"
addCommand "editor", "gf", "choose-file new"

addCommand "commandLine", "<ESCAPE>", "exit-command-line"
addCommand "commandLine", "<ENTER>", "execute-command-line"

addCommand "popup.selector", "<ENTER>", "accept"
addCommand "popup.selector", "<TAB>", "accept"
addCommand "popup.selector", "<ESCAPE>", "cancel"
addCommand "popup.selector", "<UP>", "prev"
addCommand "popup.selector", "<DOWN>", "next"

addCommand "editor.text", "<LEFT>", "cursor.left"
addCommand "editor.text", "<RIGHT>", "cursor.right"
addCommand "editor.text", "<C-LEFT>", "cursor.left-word"
addCommand "editor.text", "<C-RIGHT>", "cursor.right-word"
addCommand "editor.text", "<CS-LEFT>", "cursor.left-word last"
addCommand "editor.text", "<CS-RIGHT>", "cursor.right-word last"
addCommand "editor.text", "<UP>", "cursor.up"
addCommand "editor.text", "<DOWN>", "cursor.down"
addCommand "editor.text", "<HOME>", "cursor.home"
addCommand "editor.text", "<END>", "cursor.end"
addCommand "editor.text", "<S-LEFT>", "cursor.left last"
addCommand "editor.text", "<S-RIGHT>", "cursor.right last"
addCommand "editor.text", "<S-UP>", "cursor.up last"
addCommand "editor.text", "<S-DOWN>", "cursor.down last"
addCommand "editor.text", "<S-HOME>", "cursor.home last"
addCommand "editor.text", "<S-END>", "cursor.end last"
addCommand "editor.text", "<ENTER>", "editor.insert \n"
addCommand "editor.text", "<SPACE>", "editor.insert  "
addCommand "editor.text", "<BACKSPACE>", "backspace"
addCommand "editor.text", "<DELETE>", "delete"

addCommand "editor.ast", "<A-LEFT>", "moveCursor", "-1"
addCommand "editor.ast", "<A-RIGHT>", "moveCursor", "1"
addCommand "editor.ast", "<A-UP>", "moveCursorUp"
addCommand "editor.ast", "<A-DOWN>", "moveCursorDown"
addCommand "editor.ast", "<HOME>", "cursor.home"
addCommand "editor.ast", "<END>", "cursor.end"
addCommand "editor.ast", "<UP>", "cursor.prev-line"
addCommand "editor.ast", "<DOWN>", "cursor.next-line"
addCommand "editor.ast", "<LEFT>", "cursor.prev"
addCommand "editor.ast", "<RIGHT>", "cursor.next"
addCommand "editor.ast", "n", "cursor.prev"
addCommand "editor.ast", "t", "cursor.next"
addCommand "editor.ast", "<S-LEFT>", "cursor.left last"
addCommand "editor.ast", "<S-RIGHT>", "cursor.right last"
addCommand "editor.ast", "<S-UP>", "cursor.up last"
addCommand "editor.ast", "<S-DOWN>", "cursor.down last"
addCommand "editor.ast", "<S-HOME>", "cursor.home last"
addCommand "editor.ast", "<S-END>", "cursor.end last"
addCommand "editor.ast", "<BACKSPACE>", "backspace"
addCommand "editor.ast", "<DELETE>", "delete"
addCommand "editor.ast", "<TAB>", "edit-next-empty"
addCommand "editor.ast", "<S-TAB>", "edit-prev-empty"
addCommand "editor.ast", "<A-f>", "select-containing function"
addCommand "editor.ast", "<A-c>", "select-containing const-decl"
addCommand "editor.ast", "<A-n>", "select-containing node-list"
addCommand "editor.ast", "<A-i>", "select-containing if"
addCommand "editor.ast", "<A-l>", "select-containing line"
addCommand "editor.ast", "e", "rename"
addCommand "editor.ast", "AE", "insert-after empty"
addCommand "editor.ast", "AP", "insert-after deleted"
addCommand "editor.ast", "ae", "insert-after-smart empty"
addCommand "editor.ast", "ap", "insert-after-smart deleted"
addCommand "editor.ast", "IE", "insert-before empty"
addCommand "editor.ast", "IP", "insert-before deleted"
addCommand "editor.ast", "ie", "insert-before-smart empty"
addCommand "editor.ast", "ip", "insert-before-smart deleted"
addCommand "editor.ast", "ke", "insert-child empty"
addCommand "editor.ast", "kp", "insert-child deleted"
addCommand "editor.ast", "s", "replace empty"
addCommand "editor.ast", "re", "replace empty"
addCommand "editor.ast", "rn", "replace number-literal"
addCommand "editor.ast", "rf", "replace call-func"
addCommand "editor.ast", "rp", "replace deleted"
addCommand "editor.ast", "rr", "replace-parent"
addCommand "editor.ast", "gd", "goto definition"
addCommand "editor.ast", "gp", "goto prev-usage"
addCommand "editor.ast", "gn", "goto next-usage"
addCommand "editor.ast", "GE", "goto prev-error"
addCommand "editor.ast", "ge", "goto next-error"
addCommand "editor.ast", "gs", "goto symbol"
addCommand "editor.ast", "<F12>", "goto next-error-diagnostic"
addCommand "editor.ast", "<S-F12>", "goto prev-error-diagnostic"
addCommand "editor.ast", "<F5>", "run-selected-function"
addCommand "editor.ast", "\"", "replace-empty \""
addCommand "editor.ast", "'", "replace-empty \""
addCommand "editor.ast", "+", "wrap +"
addCommand "editor.ast", "-", "wrap -"
addCommand "editor.ast", "*", "wrap *"
addCommand "editor.ast", "/", "wrap /"
addCommand "editor.ast", "%", "wrap %"
addCommand "editor.ast", "(", "wrap call-func"
addCommand "editor.ast", ")", "wrap call-arg"
addCommand "editor.ast", "{", "wrap {"
addCommand "editor.ast", "=<ENTER>", "wrap ="
addCommand "editor.ast", "==", "wrap =="
addCommand "editor.ast", "!=", "wrap !="
addCommand "editor.ast", "\\<\\>", "wrap <>"
addCommand "editor.ast", "\\<=", "wrap <="
addCommand "editor.ast", "\\>=", "wrap >="
addCommand "editor.ast", "\\<<ENTER>", "wrap <"
addCommand "editor.ast", "\\><ENTER>", "wrap >"
addCommand "editor.ast", "<SPACE>and", "wrap and"
addCommand "editor.ast", "<SPACE>or", "wrap or"
addCommand "editor.ast", "vc", "wrap const-decl"
addCommand "editor.ast", "vl", "wrap let-decl"
addCommand "editor.ast", "vv", "wrap var-decl"
addCommand "editor.ast", "d", "selected.delete"
addCommand "editor.ast", "y", "selected.copy"
addCommand "editor.ast", "u", "undo"
addCommand "editor.ast", "U", "redo"
addCommand "editor.ast", "<C-d>", "scroll -150"
addCommand "editor.ast", "<C-u>", "scroll 150"
addCommand "editor.ast", "<PAGE_DOWN>", "scroll -450"
addCommand "editor.ast", "<PAGE_UP>", "scroll 450"
addCommand "editor.ast", "<C-f>", "select-center-node"
addCommand "editor.ast", "<C-r>", "select-prev"
addCommand "editor.ast", "<C-t>", "select-next"
addCommand "editor.ast", "<C-LEFT>", "select-prev"
addCommand "editor.ast", "<C-RIGHT>", "select-next"
addCommand "editor.ast", "<SPACE>l", "toggle-option logging"
addCommand "editor.ast", "<SPACE>dc", "dump-context"
addCommand "editor.ast", "<SPACE>fs", "toggle-option render-selected-value"
addCommand "editor.ast", "<CA-DOWN>", "scroll-output -5"
addCommand "editor.ast", "<CA-UP>", "scroll-output 5"
addCommand "editor.ast", "<CA-HOME>", "scroll-output home"
addCommand "editor.ast", "<CA-END>", "scroll-output end"
addCommand "editor.ast", ".", "run-last-command edit"
addCommand "editor.ast", ",", "run-last-command move"
addCommand "editor.ast", ";", "run-last-command"
addCommand "editor.ast", "<A-t>", "move-node-to-next-space"
addCommand "editor.ast", "<A-n>", "move-node-to-prev-space"

addCommand "editor.ast.completion", "<ENTER>", "apply-rename"
addCommand "editor.ast.completion", "<ESCAPE>", "cancel-rename"
addCommand "editor.ast.completion", "<UP>", "prev-completion"
addCommand "editor.ast.completion", "<DOWN>", "next-completion"
addCommand "editor.ast.completion", "<TAB>", "apply-completion"
addCommand "editor.ast.completion", "<C-TAB>", "cancel-and-next-completion"
addCommand "editor.ast.completion", "<CS-TAB>", "cancel-and-prev-completion"
addCommand "editor.ast.completion", "<A-d>", "cancel-and-delete"
addCommand "editor.ast.completion", "<A-t>", "move-empty-to-next-space"
addCommand "editor.ast.completion", "<A-n>", "move-empty-to-prev-space"

addCommand "editor.ast.goto", "<ENTER>", "accept"
addCommand "editor.ast.goto", "<TAB>", "accept"
addCommand "editor.ast.goto", "<ESCAPE>", "cancel"
addCommand "editor.ast.goto", "<UP>", "prev"
addCommand "editor.ast.goto", "<DOWN>", "next"
addCommand "editor.ast.goto", "<HOME>", "home"
addCommand "editor.ast.goto", "<END>", "end"