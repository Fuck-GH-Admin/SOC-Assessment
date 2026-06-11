import { describe, it, expect } from 'vitest'
import {
  validateInput, lookupBaseSOC, calculateSOC,
  calculateCarbonStorage, calculateCarbonDensity,
  calculateNetChange, calculateRecoveryRate,
  calculateLossRate, computeAll
} from '@/engine/socCalculator.js'

const normalParams = () => ({
  fert: 'F', erosion: '0', depth: '10', bd: 1.15,
  ph: 5.60, wc: 18.00, clay: 96.29, tn: 1.59,
  cropBiomass: 8500, strawCarbonRatio: 0.45
})

describe('validateInput', () => {
  it('passes normal params', () => {
    expect(validateInput(normalParams())).toEqual([])
  })

  it('rejects bd out of range [0.5, 2.5]', () => {
    const err1 = validateInput({ ...normalParams(), bd: 0.4 })
    expect(err1.length).toBeGreaterThan(0)
    expect(err1[0]).toMatch(/土壤容重/)
    const err2 = validateInput({ ...normalParams(), bd: 2.6 })
    expect(err2.length).toBeGreaterThan(0)
    expect(err2[0]).toMatch(/土壤容重/)
    expect(validateInput({ ...normalParams(), bd: 2.5 })).toEqual([])
    expect(validateInput({ ...normalParams(), bd: 0.5 })).toEqual([])
  })

  it('rejects extreme ph values', () => {
    const err1 = validateInput({ ...normalParams(), ph: 2.9 })
    expect(err1.length).toBeGreaterThan(0)
    expect(err1[0]).toMatch(/pH/)
    const err2 = validateInput({ ...normalParams(), ph: 11.1 })
    expect(err2.length).toBeGreaterThan(0)
    expect(err2[0]).toMatch(/pH/)
    expect(validateInput({ ...normalParams(), ph: 3 })).toEqual([])
    expect(validateInput({ ...normalParams(), ph: 11 })).toEqual([])
  })

  it('rejects negative cropBiomass', () => {
    expect(validateInput({ ...normalParams(), cropBiomass: -1 })).toContain('秸秆生物量不能为负')
    expect(validateInput({ ...normalParams(), cropBiomass: 0 })).toEqual([])
  })

  it('rejects strawCarbonRatio outside [0, 1]', () => {
    const err1 = validateInput({ ...normalParams(), strawCarbonRatio: -0.01 })
    expect(err1.length).toBeGreaterThan(0)
    expect(err1[0]).toMatch(/秸秆/)
    const err2 = validateInput({ ...normalParams(), strawCarbonRatio: 1.01 })
    expect(err2.length).toBeGreaterThan(0)
    expect(err2[0]).toMatch(/秸秆/)
    expect(validateInput({ ...normalParams(), strawCarbonRatio: 0 })).toEqual([])
    expect(validateInput({ ...normalParams(), strawCarbonRatio: 1 })).toEqual([])
  })

  it('validates soilLayers', () => {
    const p = { ...normalParams(), soilLayers: [{ bd: 0.7, socValue: -1, thickness: 0 }] }
    const errs = validateInput(p)
    expect(errs.length).toBe(3)
  })

  it('rejects null/undefined params gracefully', () => {
    expect(() => validateInput(undefined)).toThrow()
    expect(() => validateInput(null)).toThrow()
  })
})

describe('lookupBaseSOC', () => {
  it('returns correct value for valid lookup', () => {
    expect(lookupBaseSOC('F', 0, 10)).toBe(23.90)
    expect(lookupBaseSOC('UNF', 70, 55)).toBe(8.56)
  })

  it('returns null for invalid fert key', () => {
    expect(lookupBaseSOC('X', 0, 10)).toBeNull()
  })

  it('returns null for missing erosion key', () => {
    expect(lookupBaseSOC('F', 999, 10)).toBeNull()
  })

  it('returns null for missing depth key', () => {
    expect(lookupBaseSOC('F', 0, 999)).toBeNull()
  })

  it('handles non-numeric keys', () => {
    expect(lookupBaseSOC(undefined, 0, 10)).toBeNull()
    expect(lookupBaseSOC('F', null, 10)).toBeNull()
  })
})

describe('calculateSOC', () => {
  it('returns expected value for normal params', () => {
    const v = calculateSOC(normalParams())
    expect(v).toBeGreaterThan(0)
    expect(v).toBeLessThan(100)
  })

  it('handles unknown fert by returning NaN', () => {
    const v = calculateSOC({ ...normalParams(), fert: 'XXX' })
    expect(v).toBeNaN()
  })

  it('handles unknown erosion coefficient', () => {
    const v = calculateSOC({ ...normalParams(), erosion: '999' })
    expect(v).toBeGreaterThan(0)
  })

  it('does not go negative', () => {
    const v = calculateSOC({ ...normalParams(), fert: 'UNF', erosion: '999', depth: '999' })
    expect(v).toBeGreaterThanOrEqual(0)
  })
})

describe('calculateCarbonStorage', () => {
  it('normal calculation', () => {
    expect(calculateCarbonStorage(20, 1.15, 20)).toBeCloseTo(4.6, 2)
  })

  it('caps depth at 20cm', () => {
    const d20 = calculateCarbonStorage(20, 1.15, 20)
    const d60 = calculateCarbonStorage(20, 1.15, 60)
    expect(d60).toBe(d20)
  })

  it('handles zero soc', () => {
    expect(calculateCarbonStorage(0, 1.15, 20)).toBe(0)
  })

  it('handles zero bd', () => {
    expect(calculateCarbonStorage(20, 0, 20)).toBe(0)
  })

  it('handles negative soc', () => {
    expect(calculateCarbonStorage(-10, 1.15, 20)).toBe(0)
  })
})

describe('calculateCarbonDensity', () => {
  it('normal calculation', () => {
    const d = calculateCarbonDensity(4.6, 20)
    expect(d).toBeCloseTo(23, 0)
  })

  it('handles zero depthCm', () => {
    expect(calculateCarbonDensity(4.6, 0)).toBe(0)
  })

  it('handles negative depthCm', () => {
    expect(calculateCarbonDensity(4.6, -10)).toBe(0)
  })
})

describe('calculateNetChange', () => {
  it('returns positive for F with low erosion', () => {
    expect(calculateNetChange(23.9, 'F', 0)).toBeGreaterThan(0)
  })

  it('returns lower value for UNF', () => {
    const fVal = calculateNetChange(23.9, 'F', 0)
    const unfVal = calculateNetChange(23.9, 'UNF', 0)
    expect(unfVal).toBeLessThan(fVal)
  })

  it('decreases with higher erosion', () => {
    const low = calculateNetChange(23.9, 'F', 0)
    const high = calculateNetChange(23.9, 'F', 70)
    expect(high).toBeLessThan(low)
  })
})

describe('calculateRecoveryRate', () => {
  it('normal calculation', () => {
    expect(calculateRecoveryRate(10, 20)).toBe(0.5)
  })

  it('returns 0 for negative netChange', () => {
    expect(calculateRecoveryRate(-10, 20)).toBe(0)
  })

  it('handles zero years', () => {
    expect(calculateRecoveryRate(10, 0)).toBe(Infinity)
  })
})

describe('calculateLossRate', () => {
  it('returns 0 when soc equals baseline', () => {
    expect(calculateLossRate(23.9, 'F')).toBe(0)
  })

  it('returns positive when soc is lower', () => {
    expect(calculateLossRate(10, 'F')).toBeGreaterThan(0)
  })

  it('handles invalid fert key without crashing', () => {
    expect(() => calculateLossRate(10, 'X')).not.toThrow()
    expect(calculateLossRate(10, 'X')).toBe(0)
  })
})

describe('computeAll — full pipeline edge cases', () => {
  it('succeeds with normal params', () => {
    const r = computeAll(normalParams())
    expect(r.success).toBe(true)
    expect(r.results.soc).toBeGreaterThan(0)
  })

  it('fails with invalid bd', () => {
    const r = computeAll({ ...normalParams(), bd: 0.4 })
    expect(r.success).toBe(false)
    expect(r.errors.length).toBeGreaterThan(0)
  })

  it('handles unknown fert gracefully — returns NaN for SOC', () => {
    const r = computeAll({ ...normalParams(), fert: 'XXX' })
    expect(r.success).toBe(true)
    expect(r.results.soc).toBeNaN()
  })

  it('handles missing params without crashing', () => {
    expect(() => computeAll()).toThrow()
    const r = computeAll({})
    expect(r.success).toBe(true)
    expect(r.results.soc).toBeNaN()
  })

  it('handles string numbers', () => {
    const r = computeAll({ ...normalParams(), bd: '1.15', ph: '5.6' })
    expect(r.success).toBe(true)
  })

  it('handles undefined optional params', () => {
    const r = computeAll({
      fert: 'F', erosion: '0', depth: '10', bd: 1.15,
      ph: 5.60, wc: 18.00, clay: 96.29, tn: 1.59
    })
    expect(r.success).toBe(true)
  })
})
