import std/[strformat, strutils, sugar, tables, options, json, streams, algorithm, sets, sequtils]
import fusion/matching, bumpy, vmath, fuzzy
import misc/[util, custom_logger, timer, array_buffer, id, event, custom_async, myjsonutils, custom_unicode, delayed_task, fuzzy_matching, rect_utils]
from scripting_api as api import nil
import platform/[filesystem, platform]
import workspaces/[workspace]
import ui/node
import lang/[lang_language, cell_language, property_validator_language]

import ast/[generator_wasm, base_language_wasm, editor_language_wasm, model_state, cell_builder_database]
import document, document_editor, text/text_document, events, scripting/expose, input
import config_provider, app_interface, dispatch_tables, selector_popup
import model, base_language, editor_language, cells, ast_ids

const projectPath = "./model/playground.ast-project"
var gProject*: Project = nil
var gProjectWorkspace*: WorkspaceFolder = nil

logCategory "ast-project"

proc loadModelAsync*(project: Project, path: string): Future[Option[Model]] {.async.}
proc resolveModel*(project: Project, ws: WorkspaceFolder, id: ModelId): Future[Option[Model]] {.async.}
proc resolveLanguage*(project: Project, ws: WorkspaceFolder, id: LanguageId): Future[Option[Language]] {.async.}

proc setProjectWorkspace*(ws: WorkspaceFolder) =
  gProjectWorkspace = ws

proc getProjectWorkspace*(): Future[WorkspaceFolder] {.async.} =
  while gProjectWorkspace.isNil:
    sleepAsync(10).await
  return gProjectWorkspace

proc getGlobalProject*(): Future[Project] {.async.} =
  if gProject.isNil:
    log lvlInfo, fmt"Loading project source file '{projectPath}'"

    gProject = newProject()
    gProject.path = projectPath
    gProject.computationContext = newModelComputationContext(gProject)

    let ws = getProjectWorkspace().await
    let jsonText = ws.loadFile(gProject.path).await
    let json = jsonText.parseJson
    if gProject.loadFromJson(json):
      gProject.loaded = true

  return gProject

proc save*(project: Project): Future[void] {.async.} =
  log lvlInfo, fmt"Saving project '{project.path}'..."
  let ws = getProjectWorkspace().await
  let serialized = project.toJson.pretty
  ws.saveFile(project.path, serialized).await
  log lvlInfo, fmt"Saving project '{project.path}' done"

proc loadModelAsync*(project: Project, path: string): Future[Option[Model]] {.async.} =
  log lvlInfo, fmt"loadModelAsync {path}"

  let ws = getProjectWorkspace().await
  let jsonText = ws.loadFile(path).await
  let json = jsonText.parseJson

  var model = newModel()
  if not model.loadFromJsonAsync(project, ws, path, json, resolveLanguage, resolveModel).await:
    log lvlError, fmt"project.loadModelAsync: Failed to load model: no id"
    return Model.none

  if project.getModel(model.id).getSome(existing):
    log lvlInfo, fmt"project.loadModelAsync: Model {model.id} already exists in project"
    return existing.some

  project.addModel(model)

  return model.some

proc resolveLanguage*(project: Project, ws: WorkspaceFolder, id: LanguageId): Future[Option[Language]] {.async.} =
  if id == IdBaseLanguage:
    return base_language.baseLanguage.some
  elif id == IdBaseInterfaces:
    return base_language.baseInterfaces.some
  elif id == IdEditorLanguage:
    return editor_language.editorLanguage.some
  elif id == IdLangLanguage:
    return lang_language.langLanguage.some
  elif id == IdCellLanguage:
    return cell_language.cellLanguage.await.some
  elif id == IdPropertyValidatorLanguage:
    return property_validator_language.propertyValidatorLanguage.await.some
  elif project.dynamicLanguages.contains(id):
    return project.dynamicLanguages[id].some
  elif project.modelPaths.contains(id.ModelId):
    let languageModel = project.loadModelAsync(project.modelPaths[id.ModelId]).await.getOr:
      return Language.none

    if not languageModel.hasLanguage(IdLangLanguage):
      return Language.none

    let language = createLanguageFromModel(languageModel, ctx = project.computationContext.some).await
    project.dynamicLanguages[language.id] = language
    return language.some
  else:
    return Language.none

proc resolveModel*(project: Project, ws: WorkspaceFolder, id: ModelId): Future[Option[Model]] {.async.} =
  if id == baseInterfacesModel.id:
    return lang_language.baseInterfacesModel.some
  if id == baseLanguageModel.id:
    return lang_language.baseLanguageModel.some
  if id == langLanguageModel.id:
    return lang_language.langLanguageModel.some

  while not project.loaded:
    log lvlInfo, fmt"Waiting for project to load"
    sleepAsync(1).await

  log lvlInfo, fmt"resolveModel {id}"
  if project.getModel(id).getSome(model):
    return model.some

  if project.modelPaths.contains(id):
    let path = project.modelPaths[id]
    return project.loadModelAsync(path).await

  log lvlError, fmt"project.resolveModel {id}: not found"
  return Model.none

proc getAllAvailableLanguages*(project: Project): seq[LanguageId] =
  let l = collect(newSeq):
    for languageId in project.dynamicLanguages.keys:
      languageId
  return @[IdBaseLanguage, IdBaseInterfaces, IdEditorLanguage, IdLangLanguage, IdCellLanguage, IdPropertyValidatorLanguage] & l

proc updateLanguageFromModel*(project: Project, model: Model): Future[void] {.async.} =
  let languageId = model.id.LanguageId

  if languageId == IdCellLanguage:
    try:
      log lvlInfo, fmt"Updating cell language ({languageId}) with model {model.path} ({model.id})"
      updateCellLanguage(model).await
      return
    except CatchableError:
      log lvlError, fmt"Failed to update cell language from model: {getCurrentExceptionMsg()}"
    return

  if languageId == IdPropertyValidatorLanguage:
    try:
      log lvlInfo, fmt"Updating property validator language ({languageId}) with model {model.path} ({model.id})"
      updatePropertyValidatorLanguage(model).await
      return
    except CatchableError:
      log lvlError, fmt"Failed to update cell language from model: {getCurrentExceptionMsg()}"
    return

  if project.dynamicLanguages.contains(languageId):
    let language = project.dynamicLanguages[languageId]
    try:
      log lvlInfo, fmt"Updating language {language.name} ({language.id}) with model {model.path} ({model.id})"
      discard language.updateLanguageFromModel(model, ctx = project.computationContext.some).await
      return
    except CatchableError:
      log lvlError, fmt"Failed to update language from model: {getCurrentExceptionMsg()}"

  log lvlInfo, fmt"Compiling language from model {model.path} ({model.id})"
  let language = createLanguageFromModel(model, ctx = project.computationContext.some).await
  project.dynamicLanguages[language.id] = language