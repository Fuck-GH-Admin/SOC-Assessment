import { describe, it, expect } from 'vitest'
import {
  computeCarbonPoolByLayer, computeTotalCarbonPool,
  computeNetChange, computeAnnualRecoveryRate,
  computeStrawCarbonInput, computeStrawScenarios,
  assessResilience
} from '@/engine/resilienceAssessment.js'

const sampleLayer = (overrides = {}) => ({
  layerId: '0-20 cm', thickness: 20, bd: 1.15, socValue: 23.90,
  ...overrides
})

const fullSoilLayers = [
  { layerId: '0-20 cm', thickness: 20, bd: 1.15, socValue: 23.90 },
  { layerId: '20-30 cm', thickness: 10, bd: 1.15, socValue: 16.64 },
  { layerId: '30-40 cm', thickness: 10, bd: 1.15, socValue: 13.09 },
  { layerId: '40-50 cm', thickness: 10, bd: 1.15, socValue: 10.30 },
  { layerId: '50-60 cm', thickness: 10, bd: 1.15, socValue: 8.10 }
]

const initialLayers = [
  { layerId: '0-20 cm', thickness: 20, bd: 1.15, socValue: 23.90 },
  { layerId: '20-30 cm', thickness: 10, bd: 1.15, socValue: 16.64 },
  { layerId: '30-40 cm', thickness: 10, bd: 1.15, socValue: 13.09 },
  { layerId: '40-50 cm', thickness: 10, bd: 1.15, socValue: 10.30 },
  { layerId: '50-60 cm', thickness: 10, bd: 1.15, socValue: 8.10 }
]

describe('computeCarbonPoolByLayer', () => {
  it('normal calculation', () => {
    expect(computeCarbonPoolByLayer(23.90, 1.15, 20)).toBeCloseTo(5.497, 2)
  })

  it('handles zero socValue', () => {
    expect(computeCarbonPoolByLayer(0, 1.15, 20)).toBe(0)
  })

  it('handles negative socValue', () => {
    expect(computeCarbonPoolByLayer(-10, 1.15, 20)).toBe(-2.3)
  })

  it('handles undefined / NaN inputs', () => {
    const v = computeCarbonPoolByLayer(undefined, 1.15, 20)
    expect(v).toBeNaN()
  })
})

describe('computeTotalCarbonPool', () => {
  it('sums normal layers', () => {
    const total = computeTotalCarbonPool(fullSoilLayers)
    expect(total).toBeGreaterThan(0)
  })

  it('returns 0 for empty array', () => {
    expect(computeTotalCarbonPool([])).toBe(0)
  })

  it('handles layers with NaN values', () => {
    const layers = fullSoilLayers.map(l => ({ ...l, socValue: undefined }))
    const total = computeTotalCarbonPool(layers)
    expect(total).toBeNaN()
  })

  it('handles null layers', () => {
    expect(() => computeTotalCarbonPool(null)).toThrow()
  })
})

describe('computeNetChange', () => {
  it('positive change', () => {
    expect(computeNetChange(20, 10)).toBe(10)
  })

  it('negative change', () => {
    expect(computeNetChange(5, 10)).toBe(-5)
  })

  it('zero change', () => {
    expect(computeNetChange(10, 10)).toBe(0)
  })
})

describe('computeAnnualRecoveryRate', () => {
  it('normal positive rate', () => {
    expect(computeAnnualRecoveryRate(20, 10, 20)).toBe(0.5)
  })

  it('negative rate (loss)', () => {
    expect(computeAnnualRecoveryRate(5, 10, 20)).toBe(-0.25)
  })

  it('zero rate', () => {
    expect(computeAnnualRecoveryRate(10, 10, 20)).toBe(0)
  })

  it('division by zero returns Infinity', () => {
    expect(computeAnnualRecoveryRate(10, 5, 0)).toBe(Infinity)
  })

  it('defaults to 1 year', () => {
    expect(computeAnnualRecoveryRate(20, 10)).toBe(10)
  })
})

describe('computeStrawCarbonInput', () => {
  it('normal calculation', () => {
    const v = computeStrawCarbonInput(8500, 0.45, 1.0)
    expect(v).toBeCloseTo(0.3825, 4)
  })

  it('zero biomass', () => {
    expect(computeStrawCarbonInput(0, 0.45, 0.5)).toBe(0)
  })

  it('zero return ratio', () => {
    expect(computeStrawCarbonInput(8500, 0.45, 0)).toBe(0)
  })

  it('negative biomass', () => {
    expect(computeStrawCarbonInput(-100, 0.45, 0.5)).toBeLessThan(0)
  })
})

describe('computeStrawScenarios', () => {
  it('returns 3 scenarios', () => {
    const r = computeStrawScenarios(8500, 0.45, 0.15)
    expect(r).toHaveLength(3)
  })

  it('scenarios have correct labels', () => {
    const r = computeStrawScenarios(8500, 0.45, 0.15)
    expect(r[0].label).toContain('30')
    expect(r[1].label).toContain('50')
    expect(r[2].label).toContain('100')
  })

  it('totalInput increases with return ratio', () => {
    const r = computeStrawScenarios(8500, 0.45, 0.15)
    expect(r[0].totalInput).toBeLessThan(r[1].totalInput)
    expect(r[1].totalInput).toBeLessThan(r[2].totalInput)
  })

  it('handles zero inputs', () => {
    const r = computeStrawScenarios(0, 0, 0)
    r.forEach(s => expect(s.totalInput).toBe(0))
  })
})

describe('assessResilience — full pipeline edge cases', () => {
  it('succeeds with normal params', () => {
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers })
    expect(r.success).toBe(true)
    expect(r.results.carbonPool_0_20).toBeGreaterThan(0)
    expect(r.results.carbonPool_0_60).toBeGreaterThan(0)
    expect(r.results.strawScenarios).toHaveLength(3)
  })

  it('returns error for missing soilLayers', () => {
    const r = assessResilience({ soilLayers: [], initialLayers })
    expect(r.success).toBe(false)
    expect(r.errors).toContain('缺少土层数据')
  })

  it('returns error for missing initialLayers', () => {
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers: [] })
    expect(r.success).toBe(false)
    expect(r.errors).toContain('缺少初始年份土层数据')
  })

  it('returns error when initialLayers is null', () => {
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers: null })
    expect(r.success).toBe(false)
  })

  it('handles missing params gracefully', () => {
    const r = assessResilience({})
    expect(r.success).toBe(false)
  })

  it('handles no params at all (default {})', () => {
    const r = assessResilience()
    expect(r.success).toBe(false)
  })

  it('handles null params', () => {
    const r = assessResilience(null)
    expect(r.success).toBe(false)
  })

  it('uses default values for optional params', () => {
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers })
    expect(r.success).toBe(true)
    expect(r.results.strawScenarios[2].strawInput).toBeGreaterThan(0)
  })

  it('accepts custom cropBiomass/strawCarbonRatio', () => {
    const r = assessResilience({
      soilLayers: fullSoilLayers, initialLayers,
      cropBiomass: 10000, strawCarbonRatio: 0.5
    })
    expect(r.success).toBe(true)
  })

  it('handles single layer', () => {
    const r = assessResilience({
      soilLayers: [sampleLayer()],
      initialLayers: [sampleLayer()]
    })
    expect(r.success).toBe(true)
  })

  it('handles layers with NaN socValue', () => {
    const layers = fullSoilLayers.map(l => ({ ...l, socValue: undefined }))
    const r = assessResilience({ soilLayers: layers, initialLayers: layers })
    expect(r.results.carbonPool_0_20).toBeNaN()
    expect(r.results.status).toContain('亏损')
  })

  it('status is "恢复趋势" when netChange > 0', () => {
    const degradedInit = initialLayers.map(l => ({ ...l, socValue: l.socValue * 0.5 }))
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers: degradedInit })
    expect(r.success).toBe(true)
    expect(r.results.status).toContain('恢复趋势')
  })

  it('status is "稳定" when netChange === 0', () => {
    const r = assessResilience({ soilLayers: fullSoilLayers, initialLayers })
    expect(r.results.status).toContain('稳定')
  })

  it('status is "亏损" when netChange < 0', () => {
    const degradedSoil = fullSoilLayers.map(l => ({ ...l, socValue: l.socValue * 0.5 }))
    const r = assessResilience({ soilLayers: degradedSoil, initialLayers })
    expect(r.results.status).toContain('亏损')
  })
})
