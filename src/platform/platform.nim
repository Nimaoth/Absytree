import vmath
import ui/node
import misc/[event]
import input

export input, event

type
  WLayoutOptions* = object
    getTextBounds*: proc(text: string, fontSizeIncreasePercent: float = 0): Vec2
  Platform* = ref object of RootObj
    builder*: UINodeBuilder
    redrawEverything*: bool
    requestedRender*: bool
    showDrawnNodes*: bool = false
    supportsThinCursor*: bool
    onKeyPress*: Event[tuple[input: int64, modifiers: Modifiers]]
    onKeyRelease*: Event[tuple[input: int64, modifiers: Modifiers]]
    onRune*: Event[tuple[input: int64, modifiers: Modifiers]]
    onMousePress*: Event[tuple[button: MouseButton, modifiers: Modifiers, pos: Vec2]]
    onMouseRelease*: Event[tuple[button: MouseButton, modifiers: Modifiers, pos: Vec2]]
    onMouseMove*: Event[tuple[pos: Vec2, delta: Vec2, modifiers: Modifiers, buttons: set[MouseButton]]]
    onScroll*: Event[tuple[pos: Vec2, scroll: Vec2, modifiers: Modifiers]]
    onCloseRequested*: Event[void]
    onDropFile*: Event[tuple[path: string, content: string]]
    layoutOptions*: WLayoutOptions

method requestRender*(self: Platform, redrawEverything = false) {.base.} = discard
method render*(self: Platform) {.base.} = discard
method sizeChanged*(self: Platform): bool {.base.} = discard
method size*(self: Platform): Vec2 {.base.} = discard
method init*(self: Platform) {.base.} = discard
method deinit*(self: Platform) {.base.} = discard
method processEvents*(self: Platform): int {.base.} = discard
method `fontSize=`*(self: Platform, fontSize: float) {.base.} = discard
method `lineDistance=`*(self: Platform, lineDistance: float) {.base.} = discard
method setFont*(self: Platform, fontRegular: string, fontBold: string, fontItalic: string, fontBoldItalic: string, fallbackFonts: seq[string]) {.base.} = discard
method fontSize*(self: Platform): float {.base.} = discard
method lineDistance*(self: Platform): float {.base.} = discard
method lineHeight*(self: Platform): float {.base.} = discard
method charWidth*(self: Platform): float {.base.} = discard
method charGap*(self: Platform): float {.base.} = discard
method measureText*(self: Platform, text: string): Vec2 {.base.} = discard
method preventDefault*(self: Platform) {.base.} = discard
method getStatisticsString*(self: Platform): string {.base.} = discard

func totalLineHeight*(self: Platform): float = self.lineHeight + self.lineDistance