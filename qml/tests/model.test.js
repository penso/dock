const assert = require('node:assert/strict')
const { test } = require('node:test')
const model = require('../DockModel.js')

test('magnification is symmetric, bounded, and fades continuously at the edge', () => {
  assert.equal(model.magnification(0, 125), 1.32)
  for (let distance = 0; distance <= 180; distance++) {
    const scale = model.magnification(distance, 125)
    assert.equal(scale, model.magnification(-distance, 125))
    assert.ok(scale >= 1 && scale <= 1.32)
  }
  assert.ok(model.magnification(124.9, 125) - 1 < 0.00001)
  assert.equal(model.magnification(126, 125), 1)
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
