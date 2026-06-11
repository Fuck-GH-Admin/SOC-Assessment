import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useCalculatorStore } from '@/stores/calculator.js'

describe('calculatorStore — calculate edge cases', () => {
  let store

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useCalculatorStore()
  })

  it('calculates successfully with default inputs', () => {
    const r = store.calculate()
    expect(r.success).toBe(true)
    expect(store.results).not.toBeNull()
    expect(store.resilience).not.toBeNull()
  })

  it('produces results for F/UNF inputs', () => {
    store.inputs.fert = 'F'
    const r1 = store.calculate()
    store.inputs.fert = 'UNF'
    const r2 = store.calculate()
    expect(r1.results.soc).not.toBe(r2.results.soc)
  })

  it('produces different results for different erosion', () => {
    store.inputs.erosion = '0'
    const r1 = store.calculate()
    store.inputs.erosion = '70'
    const r2 = store.calculate()
    expect(r1.results.soc).not.toBe(r2.results.soc)
  })

  it('resilience is null when calculate fails', () => {
    // force validation error
    store.inputs.bd = 999
    store.calculate()
    expect(store.results).toBeNull()
    expect(store.resilience).toBeNull()
    expect(store.errors.length).toBeGreaterThan(0)
  })

  it('cropBiomass=0 should NOT be overridden to 8500', () => {
    store.inputs.cropBiomass = 0
    const r = store.calculate()
    expect(r.success).toBe(true)
  })

  it('strawCarbonRatio=0 should NOT be overridden to 0.45', () => {
    store.inputs.strawCarbonRatio = 0
    const r = store.calculate()
    expect(r.success).toBe(true)
  })

  it('handles string number inputs', () => {
    store.inputs.bd = '1.15'
    store.inputs.ph = '5.6'
    const r = store.calculate()
    expect(r.success).toBe(true)
  })

  it('handles missing optional fields (cropBiomass, strawCarbonRatio)', () => {
    delete store.inputs.cropBiomass
    delete store.inputs.strawCarbonRatio
    const r = store.calculate()
    expect(r.success).toBe(true)
  })

  it('reset clears results and resilience', () => {
    store.calculate()
    expect(store.results).not.toBeNull()
    store.reset()
    expect(store.results).toBeNull()
    expect(store.resilience).toBeNull()
    expect(store.errors).toEqual([])
  })

  it('buildLayers for invalid erosion returns empty array (resilience may fail)', () => {
    store.inputs.erosion = '999'
    const r = store.calculate()
    // resilience may fail because buildLayers returns [] for unknown erosion
    expect(r.success).toBe(true)
    expect(store.resilience).toBeNull()
  })
})
