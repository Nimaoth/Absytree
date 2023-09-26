import std/[tables]
import app, custom_logger, document_editor, widgets, platform, rect_utils, theme
import widget_builders_base, widget_builder_ast_document, widget_builder_text_document, widget_builder_selector_popup, widget_builder_model_document
import scripting_api except DocumentEditor, TextDocumentEditor, AstDocumentEditor
import vmath, bumpy, chroma

import ui/node

logCategory "widget_builder"

proc updateStatusBar*(self: App, frameIndex: int, statusBarWidget: WPanel, completionsPanel: WPanel) =
  var statusWidget: WText
  var commandLineWidget: WPanel
  if statusBarWidget.len == 0:
    statusWidget = WText(anchor: (vec2(0, 0), vec2(1, 0.5)), lastHierarchyChange: frameIndex)
    statusBarWidget.add statusWidget

    commandLineWidget = WPanel(anchor: (vec2(0, 0.5), vec2(1, 1)), lastHierarchyChange: frameIndex)
    statusBarWidget.add commandLineWidget

    statusWidget.layoutWidget(statusBarWidget.lastBounds, frameIndex, self.platform.layoutOptions)
    commandLineWidget.layoutWidget(statusBarWidget.lastBounds, frameIndex, self.platform.layoutOptions)
  else:
    statusWidget = statusBarWidget[0].WText
    commandLineWidget = statusBarWidget[1].WPanel

  let textColor = self.theme.color("editor.foreground", color(225/255, 200/255, 200/255))

  statusWidget.text = if self.currentMode.len == 0: "normal" else: self.currentMode
  statusWidget.updateForegroundColor(textColor, frameIndex)
  statusWidget.updateLastHierarchyChangeFromChildren frameIndex
  statusBarWidget.lastHierarchyChange = max(statusBarWidget.lastHierarchyChange, statusWidget.lastHierarchyChange)

  self.getCommandLineTextEditor.active = self.commandLineMode
  self.getCommandLineTextEditor.updateWidget(self, commandLineWidget, completionsPanel, frameIndex)
  statusBarWidget.lastHierarchyChange = max(statusBarWidget.lastHierarchyChange, commandLineWidget.lastHierarchyChange)

proc updateWidgetTree*(self: App, frameIndex: int) =
  # self.platform.builder.buildUINodes()

  var headerColor = if self.commandLineMode: self.theme.color("tab.activeBackground", color(45/255, 45/255, 60/255)) else: self.theme.color("tab.inactiveBackground", color(45/255, 45/255, 45/255))
  headerColor.a = 1

  var rootFlags = &{FillX, FillY, OverlappingChildren, MaskContent}
  let builder = self.platform.builder
  builder.panel(rootFlags, backgroundColor = color(0, 0, 0)): # fullscreen overlay

    builder.panel(&{FillX, FillY, LayoutVerticalReverse}): # main panel
      builder.panel(&{FillX, SizeToContentY, LayoutHorizontalReverse, FillBackground}, backgroundColor = headerColor, pivot = vec2(0, 1)): # status bar
        let textColor = self.theme.color("editor.foreground", color(225/255, 200/255, 200/255))
        let text = if self.currentMode.len == 0: "normal" else: self.currentMode

        builder.panel(&{SizeToContentX, SizeToContentY, DrawText}, text = text, textColor = textColor, pivot = vec2(1, 0)):
          discard

        builder.panel(&{FillX, SizeToContentY}, pivot = vec2(1, 0)):
          self.getCommandLineTextEditor.createUI(builder, self)

      builder.panel(&{FillX, FillY}, pivot = vec2(0, 1)): # main panel
        let overlay = currentNode

        let rects = self.layout.layoutViews(self.layout_props, rect(0, 0, 1, 1), self.views.len)
        for i, view in self.views:
          let xy = rects[i].xy * overlay.bounds.wh
          let xwyh = rects[i].xwyh * overlay.bounds.wh
          let bounds = rect(xy, xwyh - xy)

          let wasActive = view.editor.active
          view.editor.active = self.currentView == i
          if view.editor.active != wasActive:
            view.editor.markDirty(notify=false)

          builder.panel(0.UINodeFlags, x = bounds.x, y = bounds.y, w = bounds.w, h = bounds.h):
            view.editor.createUI(builder, self)

    # popups
    for i, popup in self.popups:
      popup.createUI(builder, self)

  #     if viewPanel.children.len > previousChildren.high or widget.WWidget != previousChildren[viewPanel.children.len]:
  #       view.editor.markDirty(notify=false)