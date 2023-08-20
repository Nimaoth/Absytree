
import custom_logger

logCategory "main-js"

logger.enableConsoleLogger()

import std/[strformat, dom, macros]
import util, app, timer, platform/widget_builders, platform/platform, platform/browser_platform, text/text_document, event, theme, custom_async
import language/language_server
from scripting_api import Backend

createNimScriptContextConstructorAndGenerateBindings()

# Initialize renderer
var rend: BrowserPlatform = new BrowserPlatform
rend.init()

var initializedEditor = false
var hasRequestedRerender = false
var isRenderInProgress = false

var frameTime = 0.0
var frameIndex = 0

proc requestRender(redrawEverything = false) =
  if not initializedEditor:
    return
  if hasRequestedRerender:
    return
  if isRenderInProgress:
    return

  discard window.requestAnimationFrame proc(time: float) =
    # echo "requestAnimationFrame ", time

    hasRequestedRerender = false
    isRenderInProgress = true
    defer: isRenderInProgress = false
    defer: inc frameIndex

    var layoutTime, updateTime, renderTime: float
    block:
      gEditor.frameTimer = startTimer()

      let updateTimer = startTimer()
      gEditor.updateWidgetTree(frameIndex)
      updateTime = updateTimer.elapsed.ms

      let layoutTimer = startTimer()
      gEditor.layoutWidgetTree(rend.size, frameIndex)
      layoutTime = layoutTimer.elapsed.ms

      let renderTimer = startTimer()
      rend.render(gEditor.widget, frameIndex)
      renderTime = renderTimer.elapsed.ms

      frameTime = gEditor.frameTimer.elapsed.ms

    if frameTime > 20:
      log(lvlDebug, fmt"Frame: {frameTime:>5.2}ms (u: {updateTime:>5.2}ms, l: {layoutTime:>5.2}ms, r: {renderTime:>5.2}ms)")

proc runApp(): Future[void] {.async.} =
  discard await newEditor(Backend.Browser, rend)

  discard rend.onKeyPress.subscribe proc(event: auto): void = requestRender()
  discard rend.onKeyRelease.subscribe proc(event: auto): void = requestRender()
  discard rend.onRune.subscribe proc(event: auto): void = requestRender()
  discard rend.onMousePress.subscribe proc(event: auto): void = requestRender()
  discard rend.onMouseRelease.subscribe proc(event: auto): void = requestRender()
  discard rend.onMouseMove.subscribe proc(event: auto): void = requestRender()
  discard rend.onScroll.subscribe proc(event: auto): void = requestRender()
  discard rend.onCloseRequested.subscribe proc(_: auto) = requestRender()
  discard rend.onResized.subscribe proc(redrawEverything: bool) = requestRender(redrawEverything)

  initializedEditor = true
  requestRender()

asyncCheck runApp()

# Useful for debugging nim strings in the browser
# Just turns a nim string to a javascript string
proc nimStrToCStr(str: string): cstring {.exportc, used.} = str

# Override some functions with more optimized versions
{.emit: """
const hiXorLoJs_override_mask = BigInt("0xffffffffffffffff");
const hiXorLoJs_override_shift = BigInt("64");
function hiXorLoJs_override(a, b) {
    var prod = (a * b);
    return ((prod >> hiXorLoJs_override_shift) ^ (prod & hiXorLoJs_override_mask));
}

var hashWangYi1_override_c1 = BigInt("0xa0761d6478bd642f");
var hashWangYi1_override_c2 = BigInt("0xe7037ed1a0b428db");
var hashWangYi1_override_c3 = BigInt("0xeb44accab455d16d");

function hashWangYi1_override(x) {
    if (typeof BigInt != 'undefined') {
        var res = hiXorLoJs_override(hiXorLoJs_override(hashWangYi1_override_c1, (BigInt(x) ^ hashWangYi1_override_c2)), hashWangYi1_override_c3);
        return Number(BigInt.asIntN(32, res));
    }
    else {
        return (x & 4294967295);
    }
}

let nimCopyCounters = new Map();
let nimCopyTimers = new Map();
let breakOnCopyType = null;
let stats = []

function clearNimCopyStats() {
    nimCopyCounters.clear();
    nimCopyTimers.clear();
}

function dumpNimCopyStatsImpl(desc, map, sortBy, setBreakOnCopyTypeIndex) {
    let values = []
    for (let entry of map.entries()) {
        values.push(entry)
    }

    values.sort((a, b) => b[1][sortBy] - a[1][sortBy])

    stats = values

    console.log(desc)

    let i = 0;
    for (let [type, stat] of values) {
        if (i == setBreakOnCopyTypeIndex) {
            breakOnCopyType = type
        }
        console.log(stat, ": ", type)
        i++
        if (i > 20) {
          break
        }
    }
}

function selectType(setBreakOnCopyTypeIndex) {
    if (setBreakOnCopyTypeIndex < stats.length) {
        breakOnCopyType = stats[setBreakOnCopyTypeIndex][0]
    }
}

function dumpNimCopyStats(sortBy, setBreakOnCopyTypeIndex) {
    //dumpNimCopyStatsImpl("Counts: ", nimCopyCounters)
    dumpNimCopyStatsImpl("Times: ", nimCopyTimers, sortBy || 0, setBreakOnCopyTypeIndex)
}

function nimCopyOverride(dest, src, ti) {
    if (ti === breakOnCopyType) {
      debugger;
    }

    let existing = nimCopyCounters.get(ti) || 0;
    nimCopyCounters.set(ti, existing + 1)

    let start = Date.now()
    let result = window._old_nimCopy(dest, src, ti);
    let elapsed = Date.now() - start

    let existingTime = nimCopyTimers.get(ti) || [0, 0];
    nimCopyTimers.set(ti, [existingTime[0] + elapsed, existingTime[1] + 1])

    return result;
}
""".}

import hashes

macro overrideFunction(body: typed, override: untyped): untyped =
  # echo body.treeRepr
  let original = case body.kind
  of nnkCall: body[0]
  of nnkStrLit: body
  else: body

  return quote do:
    {.emit: ["window._old_", `original`, " = ", `original`, ";"].}
    {.emit: ["window.", `original`, " = ", `override`, ";"].}

overrideFunction(hashWangYi1(1.int64), "hashWangYi1_override")
overrideFunction(hashWangYi1(2.uint64), "hashWangYi1_override")
overrideFunction(hashWangYi1(3.Hash), "hashWangYi1_override")

# overrideFunction("nimCopy", "nimCopyOverride")