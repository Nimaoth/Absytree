import std/[json]
import "../src/scripting_api"

## This file is auto generated, don't modify.

proc editor_text_setMode_void_TextDocumentEditor_string_impl*(
    self: TextDocumentEditor; mode: string) =
  discard
proc editor_text_mode_string_TextDocumentEditor_impl*(self: TextDocumentEditor): string =
  discard
proc editor_text_getContextWithMode_string_TextDocumentEditor_string_impl*(
    self: TextDocumentEditor; context: string): string =
  discard
proc editor_text_updateTargetColumn_void_TextDocumentEditor_SelectionCursor_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor) =
  discard
proc editor_text_invertSelection_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_insert_seq_Selection_TextDocumentEditor_seq_Selection_string_bool_bool_impl*(
    self: TextDocumentEditor; selections: seq[Selection]; text: string;
    notify: bool = true; record: bool = true): seq[Selection] =
  discard
proc editor_text_delete_seq_Selection_TextDocumentEditor_seq_Selection_bool_bool_impl*(
    self: TextDocumentEditor; selections: seq[Selection]; notify: bool = true;
    record: bool = true): seq[Selection] =
  discard
proc editor_text_selectPrev_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectNext_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectInside_void_TextDocumentEditor_Cursor_impl*(
    self: TextDocumentEditor; cursor: Cursor) =
  discard
proc editor_text_selectInsideCurrent_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectLine_void_TextDocumentEditor_int_impl*(
    self: TextDocumentEditor; line: int) =
  discard
proc editor_text_selectLineCurrent_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectParentTs_void_TextDocumentEditor_Selection_impl*(
    self: TextDocumentEditor; selection: Selection) =
  discard
proc editor_text_selectParentCurrentTs_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_insertText_void_TextDocumentEditor_string_impl*(
    self: TextDocumentEditor; text: string) =
  discard
proc editor_text_indent_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_unindent_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_undo_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_redo_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_copy_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_paste_void_TextDocumentEditor_impl*(self: TextDocumentEditor) =
  discard
proc editor_text_scrollText_void_TextDocumentEditor_float32_impl*(
    self: TextDocumentEditor; amount: float32) =
  discard
proc editor_text_duplicateLastSelection_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_addCursorBelow_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_addCursorAbove_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_getPrevFindResult_Selection_TextDocumentEditor_Cursor_int_impl*(
    self: TextDocumentEditor; cursor: Cursor; offset: int = 0): Selection =
  discard
proc editor_text_getNextFindResult_Selection_TextDocumentEditor_Cursor_int_impl*(
    self: TextDocumentEditor; cursor: Cursor; offset: int = 0): Selection =
  discard
proc editor_text_addNextFindResultToSelection_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_addPrevFindResultToSelection_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_setAllFindResultToSelection_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_clearSelections_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_moveCursorColumn_void_TextDocumentEditor_int_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; distance: int;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_moveCursorLine_void_TextDocumentEditor_int_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; distance: int;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_moveCursorHome_void_TextDocumentEditor_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true) =
  discard
proc editor_text_moveCursorEnd_void_TextDocumentEditor_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true) =
  discard
proc editor_text_moveCursorTo_void_TextDocumentEditor_string_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; str: string;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_moveCursorBefore_void_TextDocumentEditor_string_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; str: string;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_moveCursorNextFindResult_void_TextDocumentEditor_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true) =
  discard
proc editor_text_moveCursorPrevFindResult_void_TextDocumentEditor_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true) =
  discard
proc editor_text_scrollToCursor_void_TextDocumentEditor_SelectionCursor_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config) =
  discard
proc editor_text_centerCursor_void_TextDocumentEditor_SelectionCursor_impl*(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config) =
  discard
proc editor_text_reloadTreesitter_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_deleteLeft_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_deleteRight_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_getCommandCount_int_TextDocumentEditor_impl*(
    self: TextDocumentEditor): int =
  discard
proc editor_text_setCommandCount_void_TextDocumentEditor_int_impl*(
    self: TextDocumentEditor; count: int) =
  discard
proc editor_text_setCommandCountRestore_void_TextDocumentEditor_int_impl*(
    self: TextDocumentEditor; count: int) =
  discard
proc editor_text_updateCommandCount_void_TextDocumentEditor_int_impl*(
    self: TextDocumentEditor; digit: int) =
  discard
proc editor_text_setFlag_void_TextDocumentEditor_string_bool_impl*(
    self: TextDocumentEditor; name: string; value: bool) =
  discard
proc editor_text_getFlag_bool_TextDocumentEditor_string_impl*(
    self: TextDocumentEditor; name: string): bool =
  discard
proc editor_text_runAction_bool_TextDocumentEditor_string_JsonNode_impl*(
    self: TextDocumentEditor; action: string; args: JsonNode): bool =
  discard
proc editor_text_findWordBoundary_Selection_TextDocumentEditor_Cursor_impl*(
    self: TextDocumentEditor; cursor: Cursor): Selection =
  discard
proc editor_text_getSelectionForMove_Selection_TextDocumentEditor_Cursor_string_int_impl*(
    self: TextDocumentEditor; cursor: Cursor; move: string; count: int = 0): Selection =
  discard
proc editor_text_setMove_void_TextDocumentEditor_JsonNode_impl*(
    self: TextDocumentEditor; args: JsonNode) =
  discard
proc editor_text_deleteMove_void_TextDocumentEditor_string_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_selectMove_void_TextDocumentEditor_string_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_changeMove_void_TextDocumentEditor_string_SelectionCursor_bool_impl*(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true) =
  discard
proc editor_text_moveLast_void_TextDocumentEditor_string_SelectionCursor_bool_int_impl*(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true;
    count: int = 0) =
  discard
proc editor_text_moveFirst_void_TextDocumentEditor_string_SelectionCursor_bool_int_impl*(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true;
    count: int = 0) =
  discard
proc editor_text_setSearchQuery_void_TextDocumentEditor_string_impl*(
    self: TextDocumentEditor; query: string) =
  discard
proc editor_text_setSearchQueryFromMove_void_TextDocumentEditor_string_int_impl*(
    self: TextDocumentEditor; move: string; count: int = 0) =
  discard
proc editor_text_toggleLineComment_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_gotoDefinition_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_getCompletions_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_gotoSymbol_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_hideCompletions_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectPrevCompletion_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_selectNextCompletion_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc editor_text_applySelectedCompletion_void_TextDocumentEditor_impl*(
    self: TextDocumentEditor) =
  discard
proc popup_selector_accept_void_SelectorPopup_impl*(self: SelectorPopup) =
  discard
proc popup_selector_cancel_void_SelectorPopup_impl*(self: SelectorPopup) =
  discard
proc popup_selector_prev_void_SelectorPopup_impl*(self: SelectorPopup) =
  discard
proc popup_selector_next_void_SelectorPopup_impl*(self: SelectorPopup) =
  discard
proc editor_ast_moveCursor_void_AstDocumentEditor_int_impl*(
    self: AstDocumentEditor; direction: int) =
  discard
proc editor_ast_moveCursorUp_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_moveCursorDown_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveCursorNext_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveCursorPrev_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveCursorNextLine_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveCursorPrevLine_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_selectContaining_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; container: string) =
  discard
proc editor_ast_deleteSelected_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_copySelected_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_finishEdit_void_AstDocumentEditor_bool_impl*(
    self: AstDocumentEditor; apply: bool) =
  discard
proc editor_ast_undo_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_redo_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_insertAfterSmart_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_insertAfter_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_insertBefore_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_insertChild_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_replace_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_replaceEmpty_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; nodeTemplate: string) =
  discard
proc editor_ast_replaceParent_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_wrap_void_AstDocumentEditor_string_impl*(self: AstDocumentEditor;
    nodeTemplate: string) =
  discard
proc editor_ast_editPrevEmpty_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_editNextEmpty_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_rename_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_selectPrevCompletion_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_selectNextCompletion_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_applySelectedCompletion_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_cancelAndNextCompletion_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_cancelAndPrevCompletion_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_cancelAndDelete_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveNodeToPrevSpace_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_moveNodeToNextSpace_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_selectPrev_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_selectNext_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_openGotoSymbolPopup_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_goto_void_AstDocumentEditor_string_impl*(self: AstDocumentEditor;
    where: string) =
  discard
proc editor_ast_runSelectedFunction_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_toggleOption_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; name: string) =
  discard
proc editor_ast_runLastCommand_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; which: string) =
  discard
proc editor_ast_selectCenterNode_void_AstDocumentEditor_impl*(
    self: AstDocumentEditor) =
  discard
proc editor_ast_scroll_void_AstDocumentEditor_float32_impl*(
    self: AstDocumentEditor; amount: float32) =
  discard
proc editor_ast_scrollOutput_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; arg: string) =
  discard
proc editor_ast_dumpContext_void_AstDocumentEditor_impl*(self: AstDocumentEditor) =
  discard
proc editor_ast_setMode_void_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; mode: string) =
  discard
proc editor_ast_mode_string_AstDocumentEditor_impl*(self: AstDocumentEditor): string =
  discard
proc editor_ast_getContextWithMode_string_AstDocumentEditor_string_impl*(
    self: AstDocumentEditor; context: string): string =
  discard
proc editor_model_scroll_void_ModelDocumentEditor_float32_impl*(
    self: ModelDocumentEditor; amount: float32) =
  discard
proc editor_model_setMode_void_ModelDocumentEditor_string_impl*(
    self: ModelDocumentEditor; mode: string) =
  discard
proc editor_model_mode_string_ModelDocumentEditor_impl*(self: ModelDocumentEditor): string =
  discard
proc editor_model_getContextWithMode_string_ModelDocumentEditor_string_impl*(
    self: ModelDocumentEditor; context: string): string =
  discard
proc editor_model_moveCursorLeft_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorRight_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLeftLine_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorRightLine_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLineStart_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLineEnd_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLineStartInline_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLineEndInline_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorUp_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorDown_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorLeftCell_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_moveCursorRightCell_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_selectNode_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_selectParentCell_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_selectPrevPlaceholder_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_selectNextPlaceholder_void_ModelDocumentEditor_bool_impl*(
    self: ModelDocumentEditor; select: bool = false) =
  discard
proc editor_model_deleteLeft_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_deleteRight_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_createNewNode_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_insertTextAtCursor_bool_ModelDocumentEditor_string_impl*(
    self: ModelDocumentEditor; input: string): bool =
  discard
proc editor_model_undo_void_ModelDocumentEditor_impl*(self: ModelDocumentEditor) =
  discard
proc editor_model_redo_void_ModelDocumentEditor_impl*(self: ModelDocumentEditor) =
  discard
proc editor_model_toggleUseDefaultCellBuilder_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_showCompletions_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_hideCompletions_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_selectPrevCompletion_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_selectNextCompletion_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_applySelectedCompletion_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_model_runSelectedFunction_void_ModelDocumentEditor_impl*(
    self: ModelDocumentEditor) =
  discard
proc editor_getBackend_Backend_App_impl*(): Backend =
  discard
proc editor_saveAppState_void_App_impl*() =
  discard
proc editor_requestRender_void_App_bool_impl*(redrawEverything: bool = false) =
  discard
proc editor_setHandleInputs_void_App_string_bool_impl*(context: string;
    value: bool) =
  discard
proc editor_setHandleActions_void_App_string_bool_impl*(context: string;
    value: bool) =
  discard
proc editor_setConsumeAllActions_void_App_string_bool_impl*(context: string;
    value: bool) =
  discard
proc editor_setConsumeAllInput_void_App_string_bool_impl*(context: string;
    value: bool) =
  discard
proc editor_clearWorkspaceCaches_void_App_impl*() =
  discard
proc editor_openGithubWorkspace_void_App_string_string_string_impl*(user: string;
    repository: string; branchOrHash: string) =
  discard
proc editor_openAbsytreeServerWorkspace_void_App_string_impl*(url: string) =
  discard
proc editor_openLocalWorkspace_void_App_string_impl*(path: string) =
  discard
proc editor_getFlag_bool_App_string_bool_impl*(flag: string;
    default: bool = false): bool =
  discard
proc editor_setFlag_void_App_string_bool_impl*(flag: string; value: bool) =
  discard
proc editor_toggleFlag_void_App_string_impl*(flag: string) =
  discard
proc editor_setOption_void_App_string_JsonNode_impl*(option: string;
    value: JsonNode) =
  discard
proc editor_quit_void_App_impl*() =
  discard
proc editor_changeFontSize_void_App_float32_impl*(amount: float32) =
  discard
proc editor_changeLayoutProp_void_App_string_float32_impl*(prop: string;
    change: float32) =
  discard
proc editor_toggleStatusBarLocation_void_App_impl*() =
  discard
proc editor_createView_void_App_impl*() =
  discard
proc editor_closeCurrentView_void_App_impl*() =
  discard
proc editor_moveCurrentViewToTop_void_App_impl*() =
  discard
proc editor_nextView_void_App_impl*() =
  discard
proc editor_prevView_void_App_impl*() =
  discard
proc editor_moveCurrentViewPrev_void_App_impl*() =
  discard
proc editor_moveCurrentViewNext_void_App_impl*() =
  discard
proc editor_setLayout_void_App_string_impl*(layout: string) =
  discard
proc editor_commandLine_void_App_string_impl*(initialValue: string = "") =
  discard
proc editor_exitCommandLine_void_App_impl*() =
  discard
proc editor_executeCommandLine_bool_App_impl*(): bool =
  discard
proc editor_writeFile_void_App_string_bool_impl*(path: string = "";
    app: bool = false) =
  discard
proc editor_loadFile_void_App_string_impl*(path: string = "") =
  discard
proc editor_removeFromLocalStorage_void_App_impl*() =
  discard
proc editor_loadTheme_void_App_string_impl*(name: string) =
  discard
proc editor_chooseTheme_void_App_impl*() =
  discard
proc editor_chooseFile_void_App_string_impl*(view: string = "new") =
  discard
proc editor_chooseOpen_void_App_string_impl*(view: string = "new") =
  discard
proc editor_openPreviousEditor_void_App_impl*() =
  discard
proc editor_openNextEditor_void_App_impl*() =
  discard
proc editor_setGithubAccessToken_void_App_string_impl*(token: string) =
  discard
proc editor_reloadConfig_void_App_impl*() =
  discard
proc editor_logOptions_void_App_impl*() =
  discard
proc editor_clearCommands_void_App_string_impl*(context: string) =
  discard
proc editor_getAllEditors_seq_EditorId_App_impl*(): seq[EditorId] =
  discard
proc editor_setMode_void_App_string_impl*(mode: string) =
  discard
proc editor_mode_string_App_impl*(): string =
  discard
proc editor_getContextWithMode_string_App_string_impl*(context: string): string =
  discard
proc editor_scriptRunAction_void_string_string_impl*(action: string; arg: string) =
  discard
proc editor_scriptLog_void_string_impl*(message: string) =
  discard
proc editor_addCommandScript_void_App_string_string_string_string_impl*(
    context: string; keys: string; action: string; arg: string = "") =
  discard
proc editor_removeCommand_void_App_string_string_impl*(context: string;
    keys: string) =
  discard
proc editor_getActivePopup_EditorId_impl*(): EditorId =
  discard
proc editor_getActiveEditor_EditorId_impl*(): EditorId =
  discard
proc editor_getActiveEditor2_EditorId_App_impl*(): EditorId =
  discard
proc editor_loadCurrentConfig_void_App_impl*() =
  discard
proc editor_sourceCurrentDocument_void_App_impl*() =
  discard
proc editor_getEditor_EditorId_int_impl*(index: int): EditorId =
  discard
proc editor_scriptIsTextEditor_bool_EditorId_impl*(editorId: EditorId): bool =
  discard
proc editor_scriptIsAstEditor_bool_EditorId_impl*(editorId: EditorId): bool =
  discard
proc editor_scriptIsModelEditor_bool_EditorId_impl*(editorId: EditorId): bool =
  discard
proc editor_scriptRunActionFor_void_EditorId_string_string_impl*(
    editorId: EditorId; action: string; arg: string) =
  discard
proc editor_scriptInsertTextInto_void_EditorId_string_impl*(editorId: EditorId;
    text: string) =
  discard
proc editor_scriptTextEditorSelection_Selection_EditorId_impl*(editorId: EditorId): Selection =
  discard
proc editor_scriptSetTextEditorSelection_void_EditorId_Selection_impl*(
    editorId: EditorId; selection: Selection) =
  discard
proc editor_scriptTextEditorSelections_seq_Selection_EditorId_impl*(
    editorId: EditorId): seq[Selection] =
  discard
proc editor_scriptSetTextEditorSelections_void_EditorId_seq_Selection_impl*(
    editorId: EditorId; selections: seq[Selection]) =
  discard
proc editor_scriptGetTextEditorLine_string_EditorId_int_impl*(editorId: EditorId;
    line: int): string =
  discard
proc editor_scriptGetTextEditorLineCount_int_EditorId_impl*(editorId: EditorId): int =
  discard
proc editor_scriptGetOptionInt_int_string_int_impl*(path: string; default: int): int =
  discard
proc editor_scriptGetOptionFloat_float_string_float_impl*(path: string;
    default: float): float =
  discard
proc editor_scriptGetOptionBool_bool_string_bool_impl*(path: string;
    default: bool): bool =
  discard
proc editor_scriptGetOptionString_string_string_string_impl*(path: string;
    default: string): string =
  discard
proc editor_scriptSetOptionInt_void_string_int_impl*(path: string; value: int) =
  discard
proc editor_scriptSetOptionFloat_void_string_float_impl*(path: string;
    value: float) =
  discard
proc editor_scriptSetOptionBool_void_string_bool_impl*(path: string; value: bool) =
  discard
proc editor_scriptSetOptionString_void_string_string_impl*(path: string;
    value: string) =
  discard
proc editor_scriptSetCallback_void_string_int_impl*(path: string; id: int) =
  discard
proc editor_setRegisterText_void_App_string_string_impl*(text: string;
    register: string = "") =
  discard
