const assert = require('node:assert/strict')
const { test } = require('node:test')
const model = require('../DockModel.js')

test('edge-derived magnification is symmetric and fades to unit size outside the warp', () => {
  assert.ok(Math.abs(model.magnification(0, 125) - 1.32) < 1e-12)
  for (let distance = 0; distance <= 180; distance++) {
    const scale = model.magnification(distance, 125)
    assert.ok(Math.abs(scale - model.magnification(-distance, 125)) < 1e-12)
    assert.ok(scale >= 1 && scale <= 1.32 + 1e-12)
  }
  assert.ok(model.magnification(145.8, 125) - 1 < 0.00001)
  assert.equal(model.magnification(146, 125), 1)
})

test('dragging retains every item exactly once and does not mutate the live order', () => {
  const keys = ['a', 'b', 'c', 'd']
  assert.deepEqual(model.dragOrder(keys, 'd', 0), ['d', 'a', 'b', 'c'])
  assert.deepEqual(model.dragOrder(keys, 'a', 3), ['b', 'c', 'd', 'a'])
  assert.deepEqual(model.dragOrder(keys, 'b', 1), keys)
  assert.deepEqual(keys, ['a', 'b', 'c', 'd'])
})

test('wave motion is independent of refresh rate and settles without overshooting', () => {
  function simulate(rate) {
    let state = {position: 0, velocity: 0}
    for (let i = 0; i < rate / 2; i++) {
      state = model.springStep(state.position, state.velocity, 200, 1 / rate, 42)
      assert.ok(state.position >= 0 && state.position <= 200)
    }
    return state.position
  }
  assert.ok(Math.abs(simulate(60) - simulate(240)) < 0.000001)
  assert.ok(Math.abs(simulate(240) - 200) < 0.001)
})

test('a change of direction preserves continuous wave motion', () => {
  let state = model.springStep(0, 0, 200, 1 / 60, 42)
  const next = model.springStep(state.position, state.velocity, 0, 1 / 240, 42)
  assert.ok(Math.abs(next.position - state.position) < 12)
  assert.ok(Number.isFinite(next.velocity))
})

test('the expanded lens stays under the pointer across a long dock and its separator', () => {
  const keys = Array.from({length: 45}, (_, i) => String(i))
  for (const available of [10000, 900]) {
    let previous = -Infinity
    for (let pointer = 0; pointer <= 2300; pointer += 7) {
      const lens = model.lensLayout(keys, 30, 40, 2, pointer, 1, available)
      assert.ok(lens.focus >= previous, 'wave must not reverse while pointer moves forward')
      previous = lens.focus
      const first = lens.items[0].baseCenter, last = lens.items.at(-1).baseCenter
      if (lens.focus > first + 0.01 && lens.focus < last - 0.01) {
        assert.ok(Math.abs(lens.projected - pointer) < 0.02, 'expanded-coordinate alignment')
      }
      for (let i = 1; i < lens.items.length; i++) {
        const a = lens.items[i - 1], b = lens.items[i]
        assert.ok(b.position >= a.position + a.extent - 0.001, 'slots cannot overlap')
      }
    }
  }
})

test('hovering the displayed center of an end or middle icon gives it the peak', () => {
  const keys = Array.from({length: 12}, (_, i) => String(i))
  const baseline = model.lensLayout(keys, 8, 40, 2, 0, 0, 2000)
  for (const index of [0, 1, 6, 8, 12]) {
    const focus = baseline.items[index].baseCenter
    // Find the on-screen pointer that produces this logical focus.
    let lo = -200, hi = 1000
    for (let i = 0; i < 40; i++) {
      const p = (lo + hi) / 2
      if (model.lensLayout(keys, 8, 40, 2, p, 1, 2000).focus < focus) lo = p
      else hi = p
    }
    const result = model.lensLayout(keys, 8, 40, 2, (lo + hi) / 2, 1, 2000)
    assert.ok(Math.abs(result.items[index].scale - 2) < 0.00001)
  }
})

test('removing the lens restores exact slot positions and separators', () => {
  const a = model.lensLayout(['a','b','c'], 2, 40, 2, 100, 0, 1000)
  const b = model.lensLayout(['a','b','c'], 2, 40, 2, 200, 0, 1000)
  assert.deepEqual(a.items, b.items)
  assert.equal(a.length, 244)
  assert.ok(a.items.every(item => item.scale === 1))
})

test('expansion is cursor-anchored, with outward displacement at both ends', () => {
  const keys = Array.from({length: 20}, (_, i) => String(i))
  const left = model.lensLayout(keys, 20, 40, 2, 36, 1, 2000)
  const right = model.lensLayout(keys, 20, 40, 2, 1076, 1, 2000)
  assert.ok(left.offset > 0)
  assert.ok(right.offset < 0)
  for (let pointer = 36; pointer <= 1076; pointer += 20) {
    const lens = model.lensLayout(keys, 20, 40, 2, pointer, 1, 2000)
    assert.ok(Math.abs(lens.focus - pointer) < 0.01)
  }
})

test('sine coordinate warp has the recovered radius, saturation, and central tile width', () => {
  const tile = 48, peak = 96, radius = 3 * tile
  const amplitude = (peak - tile) / (2 * Math.sin(Math.PI / 12))
  const warp = x => x + model.fishDisplacement(x, radius, amplitude)
  assert.ok(Math.abs(warp(tile / 2) - warp(-tile / 2) - peak) < 1e-10)
  assert.equal(model.fishDisplacement(radius, radius, amplitude), amplitude)
  assert.equal(model.fishDisplacement(-radius - 100, radius, amplitude), -amplitude)
  for (let x = -300; x < 300; x++) assert.ok(warp(x + 1) > warp(x))
})

test('finite magnification uses size-dependent milliseconds and half-cosine easing', () => {
  assert.equal(model.fishDuration(48), 136)
  assert.equal(model.fishDuration(-48), 136)
  assert.ok(model.fishDuration(12) < model.fishDuration(48))
  assert.equal(model.fishTransition(0, 1, 0, 136), 0)
  assert.ok(Math.abs(model.fishTransition(0, 1, 68, 136) - 0.5) < 1e-12)
  assert.equal(model.fishTransition(0, 1, 136, 136), 1)
  assert.equal(model.fishTransition(1, 0, 200, 136), 0)
  assert.equal(model.fishTransition(0.4, 0, 0, 80), 0.4)
})
