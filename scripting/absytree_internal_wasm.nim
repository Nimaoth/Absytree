import std/[json, options]
import "../src/scripting_api"

## This file is auto generated, don't modify.

proc editor_text_lineCount_int_TextDocumentEditor_impl(self: TextDocumentEditor): int  {.importc.}
proc editor_text_lineLength_int_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; line: int): int  {.importc.}
proc editor_text_screenLineCount_int_TextDocumentEditor_impl(
    self: TextDocumentEditor): int  {.importc.}
proc editor_text_doMoveCursorColumn_Cursor_TextDocumentEditor_Cursor_int_bool_bool_impl(
    self: TextDocumentEditor; cursor: Cursor; offset: int; wrap: bool = true;
    includeAfter: bool = true): Cursor  {.importc.}
proc editor_text_findSurroundStart_Option_Cursor_TextDocumentEditor_Cursor_int_char_char_int_impl(
    editor: TextDocumentEditor; cursor: Cursor; count: int; c0: char; c1: char;
    depth: int = 1): Option[Cursor]  {.importc.}
proc editor_text_findSurroundEnd_Option_Cursor_TextDocumentEditor_Cursor_int_char_char_int_impl(
    editor: TextDocumentEditor; cursor: Cursor; count: int; c0: char; c1: char;
    depth: int = 1): Option[Cursor]  {.importc.}
proc editor_text_setMode_void_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; mode: string)  {.importc.}
proc editor_text_mode_string_TextDocumentEditor_impl(self: TextDocumentEditor): string  {.importc.}
proc editor_text_getContextWithMode_string_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; context: string): string  {.importc.}
proc editor_text_updateTargetColumn_void_TextDocumentEditor_SelectionCursor_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = Last)  {.importc.}
proc editor_text_invertSelection_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_getText_string_TextDocumentEditor_Selection_bool_impl(
    self: TextDocumentEditor; selection: Selection; inclusiveEnd: bool = false): string  {.importc.}
proc editor_text_insert_seq_Selection_TextDocumentEditor_seq_Selection_string_bool_bool_impl(
    self: TextDocumentEditor; selections: seq[Selection]; text: string;
    notify: bool = true; record: bool = true): seq[Selection]  {.importc.}
proc editor_text_delete_seq_Selection_TextDocumentEditor_seq_Selection_bool_bool_bool_impl(
    self: TextDocumentEditor; selections: seq[Selection]; notify: bool = true;
    record: bool = true; inclusiveEnd: bool = false): seq[Selection]  {.importc.}
proc editor_text_edit_seq_Selection_TextDocumentEditor_seq_Selection_seq_string_bool_bool_bool_impl(
    self: TextDocumentEditor; selections: seq[Selection]; texts: seq[string];
    notify: bool = true; record: bool = true; inclusiveEnd: bool = false): seq[
    Selection]  {.importc.}
proc editor_text_deleteLines_void_TextDocumentEditor_Slice_int_Selections_impl(
    self: TextDocumentEditor; slice: Slice[int]; oldSelections: Selections)  {.importc.}
proc editor_text_selectPrev_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectNext_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectInside_void_TextDocumentEditor_Cursor_impl(
    self: TextDocumentEditor; cursor: Cursor)  {.importc.}
proc editor_text_selectInsideCurrent_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectLine_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; line: int)  {.importc.}
proc editor_text_selectLineCurrent_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectParentTs_void_TextDocumentEditor_Selection_impl(
    self: TextDocumentEditor; selection: Selection)  {.importc.}
proc editor_text_printTreesitterTree_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectParentCurrentTs_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_insertText_void_TextDocumentEditor_string_bool_impl(
    self: TextDocumentEditor; text: string; autoIndent: bool = true)  {.importc.}
proc editor_text_indent_void_TextDocumentEditor_impl(self: TextDocumentEditor)  {.importc.}
proc editor_text_unindent_void_TextDocumentEditor_impl(self: TextDocumentEditor)  {.importc.}
proc editor_text_undo_void_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; checkpoint: string = "word")  {.importc.}
proc editor_text_redo_void_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; checkpoint: string = "word")  {.importc.}
proc editor_text_addNextCheckpoint_void_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; checkpoint: string)  {.importc.}
proc editor_text_printUndoHistory_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; max: int = 50)  {.importc.}
proc editor_text_copy_void_TextDocumentEditor_string_bool_impl(
    self: TextDocumentEditor; register: string = ""; inclusiveEnd: bool = false)  {.importc.}
proc editor_text_paste_void_TextDocumentEditor_string_bool_impl(
    self: TextDocumentEditor; register: string = ""; inclusiveEnd: bool = false)  {.importc.}
proc editor_text_scrollText_void_TextDocumentEditor_float32_impl(
    self: TextDocumentEditor; amount: float32)  {.importc.}
proc editor_text_scrollLines_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; amount: int)  {.importc.}
proc editor_text_duplicateLastSelection_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_addCursorBelow_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_addCursorAbove_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_getPrevFindResult_Selection_TextDocumentEditor_Cursor_int_bool_bool_impl(
    self: TextDocumentEditor; cursor: Cursor; offset: int = 0;
    includeAfter: bool = true; wrap: bool = true): Selection  {.importc.}
proc editor_text_getNextFindResult_Selection_TextDocumentEditor_Cursor_int_bool_bool_impl(
    self: TextDocumentEditor; cursor: Cursor; offset: int = 0;
    includeAfter: bool = true; wrap: bool = true): Selection  {.importc.}
proc editor_text_getPrevDiagnostic_Selection_TextDocumentEditor_Cursor_int_int_bool_bool_impl(
    self: TextDocumentEditor; cursor: Cursor; severity: int = 0;
    offset: int = 0; includeAfter: bool = true; wrap: bool = true): Selection  {.importc.}
proc editor_text_getNextDiagnostic_Selection_TextDocumentEditor_Cursor_int_int_bool_bool_impl(
    self: TextDocumentEditor; cursor: Cursor; severity: int = 0;
    offset: int = 0; includeAfter: bool = true; wrap: bool = true): Selection  {.importc.}
proc editor_text_addNextFindResultToSelection_void_TextDocumentEditor_bool_bool_impl(
    self: TextDocumentEditor; includeAfter: bool = true; wrap: bool = true)  {.importc.}
proc editor_text_addPrevFindResultToSelection_void_TextDocumentEditor_bool_bool_impl(
    self: TextDocumentEditor; includeAfter: bool = true; wrap: bool = true)  {.importc.}
proc editor_text_setAllFindResultToSelection_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_clearSelections_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_moveCursorColumn_void_TextDocumentEditor_int_SelectionCursor_bool_bool_bool_impl(
    self: TextDocumentEditor; distance: int;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true;
    wrap: bool = true; includeAfter: bool = true)  {.importc.}
proc editor_text_moveCursorLine_void_TextDocumentEditor_int_SelectionCursor_bool_bool_bool_impl(
    self: TextDocumentEditor; distance: int;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true;
    wrap: bool = true; includeAfter: bool = true)  {.importc.}
proc editor_text_moveCursorHome_void_TextDocumentEditor_SelectionCursor_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true)  {.importc.}
proc editor_text_moveCursorEnd_void_TextDocumentEditor_SelectionCursor_bool_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true; includeAfter: bool = true)  {.importc.}
proc editor_text_moveCursorTo_void_TextDocumentEditor_string_SelectionCursor_bool_impl(
    self: TextDocumentEditor; str: string;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_moveCursorBefore_void_TextDocumentEditor_string_SelectionCursor_bool_impl(
    self: TextDocumentEditor; str: string;
    cursor: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_moveCursorNextFindResult_void_TextDocumentEditor_SelectionCursor_bool_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true; wrap: bool = true)  {.importc.}
proc editor_text_moveCursorPrevFindResult_void_TextDocumentEditor_SelectionCursor_bool_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true; wrap: bool = true)  {.importc.}
proc editor_text_moveCursorLineCenter_void_TextDocumentEditor_SelectionCursor_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true)  {.importc.}
proc editor_text_moveCursorCenter_void_TextDocumentEditor_SelectionCursor_bool_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config;
    all: bool = true)  {.importc.}
proc editor_text_scrollToCursor_void_TextDocumentEditor_SelectionCursor_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config)  {.importc.}
proc editor_text_setCursorScrollOffset_void_TextDocumentEditor_float_SelectionCursor_impl(
    self: TextDocumentEditor; offset: float;
    cursor: SelectionCursor = SelectionCursor.Config)  {.importc.}
proc editor_text_getContentBounds_Vec2_TextDocumentEditor_impl(
    self: TextDocumentEditor): Vec2  {.importc.}
proc editor_text_centerCursor_void_TextDocumentEditor_SelectionCursor_impl(
    self: TextDocumentEditor; cursor: SelectionCursor = SelectionCursor.Config)  {.importc.}
proc editor_text_reloadTreesitter_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_deleteLeft_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_deleteRight_void_TextDocumentEditor_bool_impl(
    self: TextDocumentEditor; includeAfter: bool = true)  {.importc.}
proc editor_text_getCommandCount_int_TextDocumentEditor_impl(
    self: TextDocumentEditor): int  {.importc.}
proc editor_text_setCommandCount_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; count: int)  {.importc.}
proc editor_text_setCommandCountRestore_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; count: int)  {.importc.}
proc editor_text_updateCommandCount_void_TextDocumentEditor_int_impl(
    self: TextDocumentEditor; digit: int)  {.importc.}
proc editor_text_setFlag_void_TextDocumentEditor_string_bool_impl(
    self: TextDocumentEditor; name: string; value: bool)  {.importc.}
proc editor_text_getFlag_bool_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; name: string): bool  {.importc.}
proc editor_text_runAction_bool_TextDocumentEditor_string_JsonNode_impl(
    self: TextDocumentEditor; action: string; args: JsonNode): bool  {.importc.}
proc editor_text_findWordBoundary_Selection_TextDocumentEditor_Cursor_impl(
    self: TextDocumentEditor; cursor: Cursor): Selection  {.importc.}
proc editor_text_getSelectionInPair_Selection_TextDocumentEditor_Cursor_char_impl(
    self: TextDocumentEditor; cursor: Cursor; delimiter: char): Selection  {.importc.}
proc editor_text_getSelectionInPairNested_Selection_TextDocumentEditor_Cursor_char_char_impl(
    self: TextDocumentEditor; cursor: Cursor; open: char; close: char): Selection  {.importc.}
proc editor_text_extendSelectionWithMove_Selection_TextDocumentEditor_Selection_string_int_impl(
    self: TextDocumentEditor; selection: Selection; move: string; count: int = 0): Selection  {.importc.}
proc editor_text_getSelectionForMove_Selection_TextDocumentEditor_Cursor_string_int_impl(
    self: TextDocumentEditor; cursor: Cursor; move: string; count: int = 0): Selection  {.importc.}
proc editor_text_applyMove_void_TextDocumentEditor_JsonNode_impl(
    self: TextDocumentEditor; args: JsonNode)  {.importc.}
proc editor_text_deleteMove_void_TextDocumentEditor_string_bool_SelectionCursor_bool_impl(
    self: TextDocumentEditor; move: string; inside: bool = false;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_selectMove_void_TextDocumentEditor_string_bool_SelectionCursor_bool_impl(
    self: TextDocumentEditor; move: string; inside: bool = false;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_extendSelectMove_void_TextDocumentEditor_string_bool_SelectionCursor_bool_impl(
    self: TextDocumentEditor; move: string; inside: bool = false;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_copyMove_void_TextDocumentEditor_string_bool_SelectionCursor_bool_impl(
    self: TextDocumentEditor; move: string; inside: bool = false;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_changeMove_void_TextDocumentEditor_string_bool_SelectionCursor_bool_impl(
    self: TextDocumentEditor; move: string; inside: bool = false;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true)  {.importc.}
proc editor_text_moveLast_void_TextDocumentEditor_string_SelectionCursor_bool_int_impl(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true;
    count: int = 0)  {.importc.}
proc editor_text_moveFirst_void_TextDocumentEditor_string_SelectionCursor_bool_int_impl(
    self: TextDocumentEditor; move: string;
    which: SelectionCursor = SelectionCursor.Config; all: bool = true;
    count: int = 0)  {.importc.}
proc editor_text_setSearchQuery_void_TextDocumentEditor_string_bool_impl(
    self: TextDocumentEditor; query: string; escapeRegex: bool = false)  {.importc.}
proc editor_text_setSearchQueryFromMove_Selection_TextDocumentEditor_string_int_string_string_impl(
    self: TextDocumentEditor; move: string; count: int = 0; prefix: string = "";
    suffix: string = ""): Selection  {.importc.}
proc editor_text_toggleLineComment_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_gotoDefinition_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_getCompletions_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_gotoSymbol_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_hideCompletions_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectPrevCompletion_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectNextCompletion_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_hasTabStops_bool_TextDocumentEditor_impl(
    self: TextDocumentEditor): bool  {.importc.}
proc editor_text_clearTabStops_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectNextTabStop_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_selectPrevTabStop_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_applySelectedCompletion_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_showHoverFor_void_TextDocumentEditor_Cursor_impl(
    self: TextDocumentEditor; cursor: Cursor)  {.importc.}
proc editor_text_showHoverForCurrent_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_hideHover_void_TextDocumentEditor_impl(self: TextDocumentEditor)  {.importc.}
proc editor_text_cancelDelayedHideHover_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_hideHoverDelayed_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_updateDiagnosticsForCurrent_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_showDiagnosticsForCurrent_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_isRunningSavedCommands_bool_TextDocumentEditor_impl(
    self: TextDocumentEditor): bool  {.importc.}
proc editor_text_runSavedCommands_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_clearCurrentCommandHistory_void_TextDocumentEditor_bool_impl(
    self: TextDocumentEditor; retainLast: bool = false)  {.importc.}
proc editor_text_saveCurrentCommandHistory_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_setSelection_void_TextDocumentEditor_Cursor_string_impl(
    self: TextDocumentEditor; cursor: Cursor; nextMode: string)  {.importc.}
proc editor_text_enterChooseCursorMode_void_TextDocumentEditor_string_impl(
    self: TextDocumentEditor; action: string)  {.importc.}
proc editor_text_recordCurrentCommand_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_runSingleClickCommand_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_runDoubleClickCommand_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_runTripleClickCommand_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc editor_text_runDragCommand_void_TextDocumentEditor_impl(
    self: TextDocumentEditor)  {.importc.}
proc popup_selector_accept_void_SelectorPopup_impl(self: SelectorPopup)  {.importc.}
proc popup_selector_cancel_void_SelectorPopup_impl(self: SelectorPopup)  {.importc.}
proc popup_selector_prev_void_SelectorPopup_impl(self: SelectorPopup)  {.importc.}
proc popup_selector_next_void_SelectorPopup_impl(self: SelectorPopup)  {.importc.}
proc editor_model_scrollPixels_void_ModelDocumentEditor_float32_impl(
    self: ModelDocumentEditor; amount: float32)  {.importc.}
proc editor_model_scrollLines_void_ModelDocumentEditor_float32_impl(
    self: ModelDocumentEditor; lines: float32)  {.importc.}
proc editor_model_setMode_void_ModelDocumentEditor_string_impl(
    self: ModelDocumentEditor; mode: string)  {.importc.}
proc editor_model_mode_string_ModelDocumentEditor_impl(self: ModelDocumentEditor): string  {.importc.}
proc editor_model_getContextWithMode_string_ModelDocumentEditor_string_impl(
    self: ModelDocumentEditor; context: string): string  {.importc.}
proc editor_model_isThickCursor_bool_ModelDocumentEditor_impl(
    self: ModelDocumentEditor): bool  {.importc.}
proc editor_model_gotoDefinition_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_gotoPrevReference_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_gotoNextReference_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_gotoPrevInvalidNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_gotoNextInvalidNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_gotoPrevNodeOfClass_void_ModelDocumentEditor_string_bool_impl(
    self: ModelDocumentEditor; className: string; select: bool = false)  {.importc.}
proc editor_model_gotoNextNodeOfClass_void_ModelDocumentEditor_string_bool_impl(
    self: ModelDocumentEditor; className: string; select: bool = false)  {.importc.}
proc editor_model_toggleBoolCell_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_invertSelection_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_selectPrev_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_selectNext_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_moveCursorLeft_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorRight_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLeftLine_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorRightLine_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLineStart_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLineEnd_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLineStartInline_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLineEndInline_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorUp_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorDown_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorLeftCell_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_moveCursorRightCell_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_selectNode_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_selectPrevNeighbor_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_selectNextNeighbor_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_selectPrevPlaceholder_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_selectNextPlaceholder_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; select: bool = false)  {.importc.}
proc editor_model_deleteLeft_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_deleteRight_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_replaceLeft_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_replaceRight_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_createNewNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_insertTextAtCursor_bool_ModelDocumentEditor_string_impl(
    self: ModelDocumentEditor; input: string): bool  {.importc.}
proc editor_model_undo_void_ModelDocumentEditor_impl(self: ModelDocumentEditor)  {.importc.}
proc editor_model_redo_void_ModelDocumentEditor_impl(self: ModelDocumentEditor)  {.importc.}
proc editor_model_toggleUseDefaultCellBuilder_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_showCompletions_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_showCompletionWindow_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_hideCompletions_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_selectPrevCompletion_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_selectNextCompletion_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_applySelectedCompletion_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_printSelectionInfo_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_clearModelCache_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_runSelectedFunction_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_copyNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_pasteNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_addLanguage_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_createNewModel_void_ModelDocumentEditor_string_impl(
    self: ModelDocumentEditor; name: string)  {.importc.}
proc editor_model_addModelToProject_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_importModel_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_compileLanguage_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_addRootNode_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_saveProject_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_loadLanguageModel_void_ModelDocumentEditor_impl(
    self: ModelDocumentEditor)  {.importc.}
proc editor_model_findDeclaration_void_ModelDocumentEditor_bool_impl(
    self: ModelDocumentEditor; global: bool)  {.importc.}
proc editor_getBackend_Backend_App_impl(): Backend  {.importc.}
proc editor_loadApplicationFile_Option_string_App_string_impl(path: string): Option[
    string]  {.importc.}
proc editor_toggleShowDrawnNodes_void_App_impl()  {.importc.}
proc editor_setMaxViews_void_App_int_impl(maxViews: int)  {.importc.}
proc editor_saveAppState_void_App_impl()  {.importc.}
proc editor_requestRender_void_App_bool_impl(redrawEverything: bool = false)  {.importc.}
proc editor_setHandleInputs_void_App_string_bool_impl(context: string;
    value: bool)  {.importc.}
proc editor_setHandleActions_void_App_string_bool_impl(context: string;
    value: bool)  {.importc.}
proc editor_setConsumeAllActions_void_App_string_bool_impl(context: string;
    value: bool)  {.importc.}
proc editor_setConsumeAllInput_void_App_string_bool_impl(context: string;
    value: bool)  {.importc.}
proc editor_clearWorkspaceCaches_void_App_impl()  {.importc.}
proc editor_openGithubWorkspace_void_App_string_string_string_impl(user: string;
    repository: string; branchOrHash: string)  {.importc.}
proc editor_openAbsytreeServerWorkspace_void_App_string_impl(url: string)  {.importc.}
proc editor_callScriptAction_JsonNode_App_string_JsonNode_impl(context: string;
    args: JsonNode): JsonNode  {.importc.}
proc editor_addScriptAction_void_App_string_string_seq_tuple_name_string_typ_string_string_impl(
    name: string; docs: string = "";
    params: seq[tuple[name: string, typ: string]] = @[]; returnType: string = "")  {.importc.}
proc editor_openLocalWorkspace_void_App_string_impl(path: string)  {.importc.}
proc editor_getFlag_bool_App_string_bool_impl(flag: string;
    default: bool = false): bool  {.importc.}
proc editor_setFlag_void_App_string_bool_impl(flag: string; value: bool)  {.importc.}
proc editor_toggleFlag_void_App_string_impl(flag: string)  {.importc.}
proc editor_setOption_void_App_string_JsonNode_impl(option: string;
    value: JsonNode)  {.importc.}
proc editor_quit_void_App_impl()  {.importc.}
proc editor_help_void_App_string_impl(about: string = "")  {.importc.}
proc editor_changeFontSize_void_App_float32_impl(amount: float32)  {.importc.}
proc editor_platformTotalLineHeight_float32_App_impl(): float32  {.importc.}
proc editor_platformLineHeight_float32_App_impl(): float32  {.importc.}
proc editor_platformLineDistance_float32_App_impl(): float32  {.importc.}
proc editor_changeLayoutProp_void_App_string_float32_impl(prop: string;
    change: float32)  {.importc.}
proc editor_toggleStatusBarLocation_void_App_impl()  {.importc.}
proc editor_createAndAddView_void_App_impl()  {.importc.}
proc editor_logs_void_App_impl()  {.importc.}
proc editor_toggleConsoleLogger_void_App_impl()  {.importc.}
proc editor_getOpenEditors_seq_EditorId_App_impl(): seq[EditorId]  {.importc.}
proc editor_getHiddenEditors_seq_EditorId_App_impl(): seq[EditorId]  {.importc.}
proc editor_closeCurrentView_void_App_bool_impl(keepHidden: bool = true)  {.importc.}
proc editor_closeOtherViews_void_App_bool_impl(keepHidden: bool = true)  {.importc.}
proc editor_moveCurrentViewToTop_void_App_impl()  {.importc.}
proc editor_nextView_void_App_impl()  {.importc.}
proc editor_prevView_void_App_impl()  {.importc.}
proc editor_moveCurrentViewPrev_void_App_impl()  {.importc.}
proc editor_moveCurrentViewNext_void_App_impl()  {.importc.}
proc editor_setLayout_void_App_string_impl(layout: string)  {.importc.}
proc editor_commandLine_void_App_string_impl(initialValue: string = "")  {.importc.}
proc editor_exitCommandLine_void_App_impl()  {.importc.}
proc editor_selectPreviousCommandInHistory_void_App_impl()  {.importc.}
proc editor_selectNextCommandInHistory_void_App_impl()  {.importc.}
proc editor_executeCommandLine_bool_App_impl(): bool  {.importc.}
proc editor_writeFile_void_App_string_bool_impl(path: string = "";
    app: bool = false)  {.importc.}
proc editor_loadFile_void_App_string_impl(path: string = "")  {.importc.}
proc editor_removeFromLocalStorage_void_App_impl()  {.importc.}
proc editor_loadTheme_void_App_string_impl(name: string)  {.importc.}
proc editor_chooseTheme_void_App_impl()  {.importc.}
proc editor_chooseFile_void_App_string_impl(view: string = "new")  {.importc.}
proc editor_chooseOpen_void_App_string_impl(view: string = "new")  {.importc.}
proc editor_openPreviousEditor_void_App_impl()  {.importc.}
proc editor_openNextEditor_void_App_impl()  {.importc.}
proc editor_setGithubAccessToken_void_App_string_impl(token: string)  {.importc.}
proc editor_reloadConfig_void_App_impl()  {.importc.}
proc editor_logOptions_void_App_impl()  {.importc.}
proc editor_clearCommands_void_App_string_impl(context: string)  {.importc.}
proc editor_getAllEditors_seq_EditorId_App_impl(): seq[EditorId]  {.importc.}
proc editor_setMode_void_App_string_impl(mode: string)  {.importc.}
proc editor_mode_string_App_impl(): string  {.importc.}
proc editor_getContextWithMode_string_App_string_impl(context: string): string  {.importc.}
proc editor_scriptRunAction_void_string_string_impl(action: string; arg: string)  {.importc.}
proc editor_scriptLog_void_string_impl(message: string)  {.importc.}
proc editor_changeAnimationSpeed_void_App_float_impl(factor: float)  {.importc.}
proc editor_setLeader_void_App_string_impl(leader: string)  {.importc.}
proc editor_setLeaders_void_App_seq_string_impl(leaders: seq[string])  {.importc.}
proc editor_addLeader_void_App_string_impl(leader: string)  {.importc.}
proc editor_addCommandScript_void_App_string_string_string_string_string_impl(
    context: string; subContext: string; keys: string; action: string;
    arg: string = "")  {.importc.}
proc editor_removeCommand_void_App_string_string_impl(context: string;
    keys: string)  {.importc.}
proc editor_getActivePopup_EditorId_impl(): EditorId  {.importc.}
proc editor_getActiveEditor_EditorId_impl(): EditorId  {.importc.}
proc editor_getActiveEditor2_EditorId_App_impl(): EditorId  {.importc.}
proc editor_loadCurrentConfig_void_App_impl()  {.importc.}
proc editor_logRootNode_void_App_impl()  {.importc.}
proc editor_sourceCurrentDocument_void_App_impl()  {.importc.}
proc editor_getEditor_EditorId_int_impl(index: int): EditorId  {.importc.}
proc editor_scriptIsTextEditor_bool_EditorId_impl(editorId: EditorId): bool  {.importc.}
proc editor_scriptIsAstEditor_bool_EditorId_impl(editorId: EditorId): bool  {.importc.}
proc editor_scriptIsModelEditor_bool_EditorId_impl(editorId: EditorId): bool  {.importc.}
proc editor_scriptRunActionFor_void_EditorId_string_string_impl(
    editorId: EditorId; action: string; arg: string)  {.importc.}
proc editor_scriptInsertTextInto_void_EditorId_string_impl(editorId: EditorId;
    text: string)  {.importc.}
proc editor_scriptTextEditorSelection_Selection_EditorId_impl(editorId: EditorId): Selection  {.importc.}
proc editor_scriptSetTextEditorSelection_void_EditorId_Selection_impl(
    editorId: EditorId; selection: Selection)  {.importc.}
proc editor_scriptTextEditorSelections_seq_Selection_EditorId_impl(
    editorId: EditorId): seq[Selection]  {.importc.}
proc editor_scriptSetTextEditorSelections_void_EditorId_seq_Selection_impl(
    editorId: EditorId; selections: seq[Selection])  {.importc.}
proc editor_scriptGetTextEditorLine_string_EditorId_int_impl(editorId: EditorId;
    line: int): string  {.importc.}
proc editor_scriptGetTextEditorLineCount_int_EditorId_impl(editorId: EditorId): int  {.importc.}
proc editor_scriptGetOptionInt_int_string_int_impl(path: string; default: int): int  {.importc.}
proc editor_scriptGetOptionFloat_float_string_float_impl(path: string;
    default: float): float  {.importc.}
proc editor_scriptGetOptionBool_bool_string_bool_impl(path: string;
    default: bool): bool  {.importc.}
proc editor_scriptGetOptionString_string_string_string_impl(path: string;
    default: string): string  {.importc.}
proc editor_scriptSetOptionInt_void_string_int_impl(path: string; value: int)  {.importc.}
proc editor_scriptSetOptionFloat_void_string_float_impl(path: string;
    value: float)  {.importc.}
proc editor_scriptSetOptionBool_void_string_bool_impl(path: string; value: bool)  {.importc.}
proc editor_scriptSetOptionString_void_string_string_impl(path: string;
    value: string)  {.importc.}
proc editor_scriptSetCallback_void_string_int_impl(path: string; id: int)  {.importc.}
proc editor_setRegisterText_void_App_string_string_impl(text: string;
    register: string = "")  {.importc.}
proc editor_getRegisterText_string_App_string_impl(register: string): string  {.importc.}
proc editor_startRecordingKeys_void_App_string_impl(register: string)  {.importc.}
proc editor_stopRecordingKeys_void_App_string_impl(register: string)  {.importc.}
proc editor_startRecordingCommands_void_App_string_impl(register: string)  {.importc.}
proc editor_stopRecordingCommands_void_App_string_impl(register: string)  {.importc.}
proc editor_isReplayingCommands_bool_App_impl(): bool  {.importc.}
proc editor_isReplayingKeys_bool_App_impl(): bool  {.importc.}
proc editor_isRecordingCommands_bool_App_string_impl(registry: string): bool  {.importc.}
proc editor_replayCommands_void_App_string_impl(register: string)  {.importc.}
proc editor_replayKeys_void_App_string_impl(register: string)  {.importc.}
proc editor_inputKeys_void_App_string_impl(input: string)  {.importc.}
proc lsp_lspLogVerbose_void_bool_impl(val: bool)  {.importc.}
proc lsp_lspToggleLogServerDebug_void_impl()  {.importc.}
proc lsp_lspLogServerDebug_void_bool_impl(val: bool)  {.importc.}
