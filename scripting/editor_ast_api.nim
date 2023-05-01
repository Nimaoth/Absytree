import std/[json]
import "../src/scripting_api"
when defined(js):
  import absytree_internal_js
else:
  import absytree_internal

## This file is auto generated, don't modify.

proc moveCursor*(self: AstDocumentEditor; direction: int) =
  moveCursorScript_8120185021(self, direction)
proc moveCursorUp*(self: AstDocumentEditor) =
  moveCursorUpScript_8120185117(self)
proc moveCursorDown*(self: AstDocumentEditor) =
  moveCursorDownScript_8120185172(self)
proc moveCursorNext*(self: AstDocumentEditor) =
  moveCursorNextScript_8120185215(self)
proc moveCursorPrev*(self: AstDocumentEditor) =
  moveCursorPrevScript_8120185265(self)
proc moveCursorNextLine*(self: AstDocumentEditor) =
  moveCursorNextLineScript_8120185314(self)
proc moveCursorPrevLine*(self: AstDocumentEditor) =
  moveCursorPrevLineScript_8120185383(self)
proc selectContaining*(self: AstDocumentEditor; container: string) =
  selectContainingScript_8120185452(self, container)
proc deleteSelected*(self: AstDocumentEditor) =
  deleteSelectedScript_8120185658(self)
proc copySelected*(self: AstDocumentEditor) =
  copySelectedScript_8120185704(self)
proc finishEdit*(self: AstDocumentEditor; apply: bool) =
  finishEditScript_8120185750(self, apply)
proc undo*(self: AstDocumentEditor) =
  undoScript2_8120185842(self)
proc redo*(self: AstDocumentEditor) =
  redoScript2_8120185911(self)
proc insertAfterSmart*(self: AstDocumentEditor; nodeTemplate: string) =
  insertAfterSmartScript_8120185980(self, nodeTemplate)
proc insertAfter*(self: AstDocumentEditor; nodeTemplate: string) =
  insertAfterScript_8120186147(self, nodeTemplate)
proc insertBefore*(self: AstDocumentEditor; nodeTemplate: string) =
  insertBeforeScript_8120186282(self, nodeTemplate)
proc insertChild*(self: AstDocumentEditor; nodeTemplate: string) =
  insertChildScript_8120186416(self, nodeTemplate)
proc replace*(self: AstDocumentEditor; nodeTemplate: string) =
  replaceScript_8120186549(self, nodeTemplate)
proc replaceEmpty*(self: AstDocumentEditor; nodeTemplate: string) =
  replaceEmptyScript_8120186636(self, nodeTemplate)
proc replaceParent*(self: AstDocumentEditor) =
  replaceParentScript_8120186727(self)
proc wrap*(self: AstDocumentEditor; nodeTemplate: string) =
  wrapScript_8120186780(self, nodeTemplate)
proc editPrevEmpty*(self: AstDocumentEditor) =
  editPrevEmptyScript_8120186891(self)
proc editNextEmpty*(self: AstDocumentEditor) =
  editNextEmptyScript_8120186940(self)
proc rename*(self: AstDocumentEditor) =
  renameScript_8120186997(self)
proc selectPrevCompletion*(self: AstDocumentEditor) =
  selectPrevCompletionScript2_8120187040(self)
proc selectNextCompletion*(self: AstDocumentEditor) =
  selectNextCompletionScript2_8120187100(self)
proc applySelectedCompletion*(self: AstDocumentEditor) =
  applySelectedCompletionScript2_8120187160(self)
proc cancelAndNextCompletion*(self: AstDocumentEditor) =
  cancelAndNextCompletionScript_8120187316(self)
proc cancelAndPrevCompletion*(self: AstDocumentEditor) =
  cancelAndPrevCompletionScript_8120187359(self)
proc cancelAndDelete*(self: AstDocumentEditor) =
  cancelAndDeleteScript_8120187402(self)
proc moveNodeToPrevSpace*(self: AstDocumentEditor) =
  moveNodeToPrevSpaceScript_8120187448(self)
proc moveNodeToNextSpace*(self: AstDocumentEditor) =
  moveNodeToNextSpaceScript_8120187595(self)
proc selectPrev*(self: AstDocumentEditor) =
  selectPrevScript2_8120187743(self)
proc selectNext*(self: AstDocumentEditor) =
  selectNextScript2_8120187786(self)
proc openGotoSymbolPopup*(self: AstDocumentEditor) =
  openGotoSymbolPopupScript_8120187846(self)
proc goto*(self: AstDocumentEditor; where: string) =
  gotoScript_8120188128(self, where)
proc runSelectedFunction*(self: AstDocumentEditor) =
  runSelectedFunctionScript_8120188600(self)
proc toggleOption*(self: AstDocumentEditor; name: string) =
  toggleOptionScript_8120188862(self, name)
proc runLastCommand*(self: AstDocumentEditor; which: string) =
  runLastCommandScript_8120188916(self, which)
proc selectCenterNode*(self: AstDocumentEditor) =
  selectCenterNodeScript_8120188966(self)
proc scroll*(self: AstDocumentEditor; amount: float32) =
  scrollScript_8120189416(self, amount)
proc scrollOutput*(self: AstDocumentEditor; arg: string) =
  scrollOutputScript_8120189470(self, arg)
proc dumpContext*(self: AstDocumentEditor) =
  dumpContextScript_8120189531(self)
proc setMode*(self: AstDocumentEditor; mode: string) =
  setModeScript2_8120189578(self, mode)
proc mode*(self: AstDocumentEditor): string =
  modeScript2_8120189660(self)
proc getContextWithMode*(self: AstDocumentEditor; context: string): string =
  getContextWithModeScript2_8120189709(self, context)
