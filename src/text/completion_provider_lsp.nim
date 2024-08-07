import std/[strutils, sugar]
import misc/[custom_unicode, util, id, custom_async, event, timer, custom_logger, fuzzy_matching, response]
import language/[lsp_types, language_server_base]
import completion, text_document
import scripting_api

logCategory "Comp-Lsp"

type
  CompletionProviderLsp* = ref object of CompletionProvider
    document: TextDocument
    lastResponseLocation: Cursor
    languageServer: LanguageServer
    textInsertedHandle: Id
    textDeletedHandle: Id
    unfilteredCompletions: seq[CompletionItem]

proc updateFilterText(self: CompletionProviderLsp) =
  let selection = self.document.getCompletionSelectionAt(self.location)
  self.currentFilterText = self.document.contentString(selection)

proc refilterCompletions(self: CompletionProviderLsp) =
  # debugf"[LSP.refilterCompletions] {self.location}: '{self.currentFilterText}'"
  let timer = startTimer()

  self.filteredCompletions.setLen 0
  for item in self.unfilteredCompletions:
    let text = item.filterText.get(item.label)
    let score = matchFuzzySublime(self.currentFilterText, text, defaultCompletionMatchingConfig).score.float

    if score < 0:
      continue

    self.filteredCompletions.add Completion(
      item: item,
      filterText: self.currentFilterText,
      score: score,
    )

  if timer.elapsed.ms > 2:
    log lvlInfo, &"[Comp-Lsp] Filtering completions took {timer.elapsed.ms}ms ({self.filteredCompletions.len}/{self.unfilteredCompletions.len})"
  self.onCompletionsUpdated.invoke (self)

proc getLspCompletionsAsync(self: CompletionProviderLsp) {.async.} =
  let location = self.location

  # Right now we need to sleep a bit here because this function is triggered by textInserted and
  # the update to the LSP is also sent in textInserted, but it's bound after this and so it would be called
  # to late. The sleep makes sure we run the getCompletions call below after the server got the file change.
  await sleepAsync(2)

  # debugf"[getLspCompletionsAsync] start"
  let completions = await self.languageServer.getCompletions(self.document.fullPath, location)
  if completions.isSuccess:
    log lvlInfo, fmt"[getLspCompletionsAsync] at {location}: got {completions.result.items.len} completions"
    self.unfilteredCompletions = completions.result.items
    self.refilterCompletions()
  elif completions.isCanceled:
    discard
  else:
    log lvlError, fmt"Failed to get completions: {completions.error}"
    self.unfilteredCompletions = @[]
    self.refilterCompletions()

proc handleTextInserted(self: CompletionProviderLsp, document: TextDocument, location: Selection, text: string) =
  self.location = location.getChangedSelection(text).last
  # debugf"[Lsp.handleTextInserted] {self.location}"
  self.updateFilterText()
  self.refilterCompletions()
  asyncCheck self.getLspCompletionsAsync()

proc handleTextDeleted(self: CompletionProviderLsp, document: TextDocument, selection: Selection) =
  self.location = selection.first
  self.updateFilterText()
  self.refilterCompletions()
  asyncCheck self.getLspCompletionsAsync()

method forceUpdateCompletions*(provider: CompletionProviderLsp) =
  provider.updateFilterText()
  provider.refilterCompletions()
  asyncCheck provider.getLspCompletionsAsync()

proc newCompletionProviderLsp*(document: TextDocument, languageServer: LanguageServer): CompletionProviderLsp =
  let self = CompletionProviderLsp(document: document, languageServer: languageServer)
  self.textInsertedHandle = self.document.textInserted.subscribe (arg: tuple[document: TextDocument, location: Selection, text: string]) => self.handleTextInserted(arg.document, arg.location, arg.text)
  self.textDeletedHandle = self.document.textDeleted.subscribe (arg: tuple[document: TextDocument, location: Selection]) => self.handleTextDeleted(arg.document, arg.location)
  self
