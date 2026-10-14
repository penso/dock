// The dock's state that does not need Quickshell: where it sits, which apps it
// shows, and which window a click brings forward.

var POSITIONS = ["top", "bottom", "left", "right"]

function normalizePosition(value) {
  var position = String(value || "").trim().toLowerCase()
  return POSITIONS.indexOf(position) >= 0 ? position : "bottom"
}

function isVertical(position) {
  var normalized = normalizePosition(position)
  return normalized === "left" || normalized === "right"
}

function normalizeId(value) {
  var id = String(value || "").trim()
  if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
  return id
}

function pinnedIds(dockConfig, defaultsConfig) {
  var source = dockConfig && Array.isArray(dockConfig.pinned) ? dockConfig.pinned
    : (defaultsConfig && Array.isArray(defaultsConfig.pinned) ? defaultsConfig.pinned : [])
  var ids = []
  for (var i = 0; i < source.length; i++) {
    var id = normalizeId(source[i])
    if (id && ids.indexOf(id) === -1) ids.push(id)
  }
  return ids
}

// Only app windows on regular workspaces belong in the dock. Helpers without a
// visible desktop entry, such as the agent window, and anything parked on a
// special workspace, such as the scratchpad, stay out of it. A minimized window
// always belongs, entry or not, since the dock is the only way back to it.
function isDockWindow(window) {
  if (!window || !window.key) return false
  if (window.minimized === true) return true
  return window.hasEntry === true && window.workspaceId >= 1
}

// Minimizing moves a window to this special workspace, and the dock brings it
// back.
var MINIMIZED_WORKSPACE = "special:minimized"

function isMinimizedWorkspace(name) {
  return String(name || "") === MINIMIZED_WORKSPACE
}

// A terminal app's window carries the app id its launcher gave the terminal,
// which no desktop entry names as its class. The entry that passes that app id
// claims it, and so does a terminal entry for the command Omarchy's TUI
// launcher named it after (org.omarchy.nvim for nvim). Entries are
// { id, execString, command, runInTerminal }.
function claimingEntryId(appId, entries) {
  var id = String(appId || "")
  if (!id) return ""
  var list = entries || []
  var flag = "--app-id=" + id
  for (var i = 0; i < list.length; i++) {
    var words = String(list[i].execString || "").split(/\s+/)
    if (words.indexOf(flag) >= 0) return list[i].id
  }
  if (id.indexOf("org.omarchy.") !== 0) return ""
  var command = id.slice("org.omarchy.".length)
  for (var j = 0; j < list.length; j++) {
    var program = String((list[j].command || [])[0] || "")
    if (list[j].runInTerminal && program.slice(program.lastIndexOf("/") + 1) === command) return list[j].id
  }
  return ""
}

// Pinned apps come first, in pin order, whether or not they run. Running apps
// that are not pinned follow in the order their first window appeared. Each
// window is { key, hasEntry, workspaceId, ... } where key is the desktop id of
// the entry that claims it.
function buildItems(pinned, windows) {
  var items = []
  var byKey = {}

  function itemFor(key, isPinned) {
    if (!byKey[key]) {
      byKey[key] = { key: key, pinned: isPinned, windows: [] }
      items.push(byKey[key])
    }
    return byKey[key]
  }

  for (var i = 0; i < (pinned || []).length; i++) {
    if (pinned[i]) itemFor(pinned[i], true)
  }

  for (var j = 0; j < (windows || []).length; j++) {
    var window = windows[j]
    if (isDockWindow(window)) itemFor(window.key, false).windows.push(window)
  }

  return items
}

function withLauncherEntries(items, entries) {
  return items.map(function(item) {
    var activity = entries[normalizeId(item.key)] || {}
    var urgent = activity.urgent === true || item.windows.some(function(window) { return window.urgent === true && !window.activated })
    return Object.assign({}, item, { activity: activity, urgent: urgent })
  })
}

function windowAddress(value) {
  return String(value || "").trim().replace(/^0x/i, "").toLowerCase()
}

function urgencyEvent(state, event, data) {
  if (["urgent", "activewindowv2", "closewindow"].indexOf(event) < 0) return state
  var address = windowAddress(data)
  if (!/^[0-9a-f]+$/.test(address)) return state
  var next = Object.assign({}, state)
  if (event === "urgent") next[address] = true
  else delete next[address]
  return next
}

// Puts the items in the dock's own order, which the dock keeps for the
// session: an app keeps its slot while it stays in the dock, and an app that
// joins goes at the end. Items the order does not know yet follow in the order
// buildItems gave them.
function orderItems(items, order) {
  var byKey = {}
  for (var i = 0; i < (items || []).length; i++) byKey[items[i].key] = items[i]
  var result = []
  var placed = {}
  for (var j = 0; j < (order || []).length; j++) {
    var key = order[j]
    if (byKey[key] && !placed[key]) {
      result.push(byKey[key])
      placed[key] = true
    }
  }
  for (var k = 0; k < (items || []).length; k++) {
    if (!placed[items[k].key]) result.push(items[k])
  }
  return result
}

// The order with key moved to index, counted once key has left its old slot.
function orderWithKeyAt(order, key, index) {
  var keys = (order || []).filter(function(other) { return other !== key })
  keys.splice(Math.max(0, Math.min(keys.length, index)), 0, key)
  return keys
}

// Where a dragged icon lands: its own slot moved by however many slots the
// pointer has travelled, kept within the dock.
function dropIndex(fromIndex, offset, slotSize, count) {
  if (count <= 0 || !(slotSize > 0)) return fromIndex
  var target = fromIndex + Math.round(offset / slotSize)
  return Math.max(0, Math.min(count - 1, target))
}

// The pins to save for the dock's order: the pinned apps in that order, then
// pins the dock is not showing, because their app is not installed, as they
// were. pinned holds the pinned desktop ids as keys.
function pinsInOrder(order, pinned, allPinned) {
  var result = (order || []).filter(function(key) { return pinned[key] === true })
  for (var i = 0; i < (allPinned || []).length; i++) {
    if (result.indexOf(allPinned[i]) === -1 && (order || []).indexOf(allPinned[i]) === -1) result.push(allPinned[i])
  }
  return result
}

// The window a click on an app brings forward. Windows on the workspace in
// front of the user come first, then minimized ones, which come back to it,
// and only then those on other workspaces. Clicking again while one of them
// is focused moves on to the next in that order. Windows are
// { workspaceId, minimized, activated }.
function pickWindow(windows, workspaceId) {
  var list = windows || []
  if (list.length === 0) return -1

  function rank(window) {
    if (window.minimized) return 1
    return window.workspaceId === workspaceId ? 0 : 2
  }

  var order = list.map(function(window, index) { return index })
  order.sort(function(a, b) { return rank(list[a]) - rank(list[b]) || a - b })

  for (var i = 0; i < order.length; i++) {
    if (list[order[i]].activated) return order[(i + 1) % order.length]
  }
  return order[0]
}


// A tile's size is the difference between its warped edges, not a sample
// of a scale curve at its center. See docs/apple-dock-analysis.md.
function magnification(distance, radius, maximum) {
  if (!(radius > 0)) return 1
  var peak = maximum === undefined ? 1.32 : Math.max(1, Math.min(2, maximum))
  var tile = radius / 3
  var amplitude = (peak - 1) * tile / (2 * Math.sin(Math.PI / 12))
  return 1 + (fishDisplacement(distance + tile / 2, radius, amplitude)
    - fishDisplacement(distance - tile / 2, radius, amplitude)) / tile
}

function fishDisplacement(distance, radius, amplitude) {
  return amplitude * Math.sin(Math.max(-1, Math.min(1, distance / radius)) * Math.PI / 2)
}

function fishDuration(sizeDelta) {
  return Math.floor(1 + 42 * Math.log(1 + Math.abs(sizeDelta) / 2))
}

function fishTransition(from, to, elapsed, duration) {
  var t = duration > 0 ? Math.max(0, Math.min(1, elapsed / duration)) : 1
  return from + (to - from) * (0.5 - 0.5 * Math.cos(Math.PI * t))
}

// Sine-warp every slot edge, including the spacing between icon artwork.
// Screen clipping/scrolling is a host-specific adaptation of the geometry.
function lensLayout(keys, pinCount, iconSize, maximum, pointer, amount, available) {
  var unit = iconSize / 40
  var cell = 52 * unit
  var padding = 10 * unit
  // Keep a resize handle after the launcher/pins even with no running apps.
  var separatorStart = 0
  var slots = []
  var baseLength = padding
  for (var i = -1; i < keys.length; i++) {
    if (i === pinCount) {
      separatorStart = baseLength
      baseLength += 16 * unit
    }
    slots.push({key: i < 0 ? "" : keys[i], base: baseLength, center: baseLength + cell / 2})
    baseLength += cell
  }
  if (pinCount === keys.length) {
    separatorStart = baseLength
    baseLength += 16 * unit
  }
  baseLength += padding
  var strength = Math.max(0, Math.min(1, amount))
  var limit = available > 0 ? available : Infinity
  var peak = Math.max(1, Math.min(2, maximum))
  var radius = 3 * cell
  var amplitude = cell * (peak - 1) * strength / (2 * Math.sin(Math.PI / 12))
  function warp(position, focus) {
    return position + fishDisplacement(position - focus, radius, amplitude)
  }
  function metrics(focus) {
    var left = warp(0, focus), right = warp(baseLength, focus)
    var length = right - left
    var visible = Math.min(length, limit)
    var room = Math.max(0, (limit - visible) / 2)
    var offset = Math.max(-room, Math.min(room, (left + right - baseLength) / 2))
    return {projected: focus - left + (baseLength - visible) / 2 + offset, offset: offset, left: left, length: length}
  }
  var low = 0, high = baseLength
  if (pointer <= metrics(low).projected) high = low
  else if (pointer >= metrics(high).projected) low = high
  else for (var step = 0; step < 18; step++) {
    var middle = (low + high) / 2
    if (metrics(middle).projected < pointer) low = middle
    else high = middle
  }
  var focus = (low + high) / 2
  var resolved = metrics(focus)
  var result = []
  for (var k = 0; k < slots.length; k++) {
    var start = warp(slots[k].base, focus)
    var end = warp(slots[k].base + cell, focus)
    var extent = end - start
    result.push({key: slots[k].key, position: start - resolved.left,
      extent: extent, scale: extent / cell, baseCenter: slots[k].center})
  }
  return {items: result, length: resolved.length, focus: focus,
    projected: resolved.projected, offset: resolved.offset,
    separator: warp(separatorStart + 8 * unit, focus) - resolved.left}
}

// Analytic critically damped motion retains velocity when the target changes.
// Unlike restarting an easing animation for every mouse event, its response
// does not depend on the mouse polling rate or the display refresh rate.
function springStep(position, velocity, target, seconds, frequency) {
  var elapsed = Math.max(0, Math.min(seconds, 0.05))
  var offset = position - target
  var coefficient = velocity + frequency * offset
  var decay = Math.exp(-frequency * elapsed)
  return {
    position: target + (offset + coefficient * elapsed) * decay,
    velocity: (velocity - frequency * coefficient * elapsed) * decay
  }
}

// Keep the drag model separate from the live window model so new windows and
// title changes cannot destroy the pointer grab. The dragged key occupies a gap.
function dragOrder(keys, key, target) {
  return orderWithKeyAt(keys, key, target)
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizePosition: normalizePosition,
    isVertical: isVertical,
    normalizeId: normalizeId,
    pinnedIds: pinnedIds,
    isDockWindow: isDockWindow,
    isMinimizedWorkspace: isMinimizedWorkspace,
    claimingEntryId: claimingEntryId,
    buildItems: buildItems,
    withLauncherEntries: withLauncherEntries,
    windowAddress: windowAddress,
    urgencyEvent: urgencyEvent,
    orderItems: orderItems,
    orderWithKeyAt: orderWithKeyAt,
    dropIndex: dropIndex,
    pinsInOrder: pinsInOrder,
    pickWindow: pickWindow,
    magnification: magnification,
    lensLayout: lensLayout,
    fishDisplacement: fishDisplacement,
    fishDuration: fishDuration,
    fishTransition: fishTransition,
    springStep: springStep,
    dragOrder: dragOrder
  }
}
