import std/[json, options]
import misc/[traits, custom_async]
import platform/platform
import finder/[finder, previewer]
import events, popup, document_editor, document, config_provider, selector_popup_builder, register
from scripting_api import EditorId

traitRef AppInterface:
  method platform*(self: AppInterface): Platform {.gcsafe, raises: [].}
  method configProvider*(self: AppInterface): ConfigProvider {.gcsafe, raises: [].}
  method getEventHandlerConfig*(self: AppInterface, context: string): EventHandlerConfig {.gcsafe, raises: [].}
  method setRegisterTextAsync*(self: AppInterface, text: string, register: string): Future[void] {.gcsafe, raises: [].}
  method getRegisterTextAsync*(self: AppInterface, register: string): Future[string] {.gcsafe, raises: [].}
  method setRegisterAsync*(self: AppInterface, register: string, value: sink Register): Future[void] {.gcsafe, raises: [].}
  method getRegisterAsync*(self: AppInterface, register: string, res: ptr Register): Future[bool] {.gcsafe, raises: [].}
  method recordCommand*(self: AppInterface, command: string, args: string) {.gcsafe, raises: [].}
  method openWorkspaceFile*(self: AppInterface, path: string, append: bool = false): Option[DocumentEditor] {.gcsafe, raises: [].}
  method openFile*(self: AppInterface, path: string): Option[DocumentEditor] {.gcsafe, raises: [].}
  method handleModeChanged*(self: AppInterface, editor: DocumentEditor, oldMode: string, newMode: string) {.gcsafe, raises: [].}
  method invokeCallback*(self: AppInterface, context: string, args: JsonNode): bool {.gcsafe, raises: [].}
  method invokeAnyCallback*(self: AppInterface, context: string, args: JsonNode): JsonNode {.gcsafe, raises: [].}
  method registerEditor*(self: AppInterface, editor: DocumentEditor): void {.gcsafe, raises: [].}
  method unregisterEditor*(self: AppInterface, editor: DocumentEditor): void {.gcsafe, raises: [].}
  method tryActivateEditor*(self: AppInterface, editor: DocumentEditor) {.gcsafe, raises: [].}
  method getActiveEditor*(self: AppInterface): Option[DocumentEditor] {.gcsafe, raises: [].}
  method getEditorForId*(self: AppInterface, id: EditorId): Option[DocumentEditor] {.gcsafe, raises: [].}
  method getEditorForPath*(self: AppInterface, path: string): Option[DocumentEditor] {.gcsafe, raises: [].}
  method getPopupForId*(self: AppInterface, id: EditorId): Option[Popup] {.gcsafe, raises: [].}
  method createSelectorPopup*(self: AppInterface): Popup {.gcsafe, raises: [].}
  method setLocationList*(self: AppInterface, list: seq[FinderItem],
    previewer: Option[Previewer] = Previewer.none) {.gcsafe, raises: [].}
  method pushSelectorPopup*(self: AppInterface, popup: SelectorPopupBuilder): ISelectorPopup {.gcsafe, raises: [].}
  method pushPopup*(self: AppInterface, popup: Popup) {.gcsafe, raises: [].}
  method popPopup*(self: AppInterface, popup: Popup) {.gcsafe, raises: [].}
  method popPopup*(self: AppInterface, popup: EditorId) {.gcsafe, raises: [].}
  method getAllDocuments*(self: AppInterface): seq[Document] {.gcsafe, raises: [].}
  method getDocument*(self: AppInterface, path: string, app: bool = false): Option[Document] {.gcsafe, raises: [].}
  method getOrOpenDocument*(self: AppInterface, path: string,
    app: bool = false, load: bool = true): Option[Document] {.gcsafe, raises: [].}
  method tryCloseDocument*(self: AppInterface, document: Document, force: bool): bool {.gcsafe, raises: [].}
  method onEditorRegisteredEvent*(self: AppInterface): var Event[DocumentEditor] {.gcsafe, raises: [].}
  method onEditorDeregisteredEvent*(self: AppInterface): var Event[DocumentEditor] {.gcsafe, raises: [].}

var gAppInterface*: AppInterface = nil