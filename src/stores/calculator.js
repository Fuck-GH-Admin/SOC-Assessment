import { defineStore } from 'pinia'
import { ref } from 'vue'
import { computeAll } from '@/engine/socCalculator.js'
import { assessResilience } from '@/engine/resilienceAssessment.js'

const baseLookup = {
  F: {
    0: { 10: 23.90, 25: 16.64, 35: 13.09, 45: 10.30, 55: 8.10 },
    10: { 10: 17.64, 25: 10.16, 35: 7.09, 45: 4.91, 55: 5.89 },
    20: { 10: 11.77, 25: 8.48, 35: 6.84, 45: 5.77, 55: 4.94 },
    30: { 10: 9.30, 25: 12.62, 35: 8.93, 45: 7.47, 55: 7.06 },
    40: { 10: 12.51, 25: 11.50, 35: 8.80, 45: 8.28, 55: 6.50 },
    50: { 10: 19.92, 25: 13.39, 35: 11.54, 45: 9.94, 55: 7.17 },
    60: { 10: 8.82, 25: 9.81, 35: 8.36, 45: 8.20, 55: 6.79 },
    70: { 10: 7.40, 25: 9.81, 35: 7.95, 45: 7.46, 55: 7.70 }
  },
  UNF: {
    0: { 10: 23.90, 25: 17.71, 35: 15.03, 45: 8.34, 55: 10.58 },
    10: { 10: 17.64, 25: 18.31, 35: 12.43, 45: 9.04, 55: 7.89 },
    20: { 10: 21.03, 25: 17.02, 35: 15.03, 45: 11.93, 55: 9.47 },
    30: { 10: 13.76, 25: 13.45, 35: 10.54, 45: 8.52, 55: 7.81 },
    40: { 10: 13.16, 25: 14.08, 35: 10.91, 45: 9.04, 55: 7.71 },
    50: { 10: 12.41, 25: 14.52, 35: 12.15, 45: 10.19, 55: 8.26 },
    60: { 10: 10.53, 25: 10.80, 35: 8.80, 45: 8.30, 55: 7.21 },
    70: { 10: 12.81, 25: 13.24, 35: 11.36, 45: 9.38, 55: 8.56 }
  }
}

const depthConfigs = [
  { key: 10, label: '0-20 cm', thickness: 20 },
  { key: 25, label: '20-30 cm', thickness: 10 },
  { key: 35, label: '30-40 cm', thickness: 10 },
  { key: 45, label: '40-50 cm', thickness: 10 },
  { key: 55, label: '50-60 cm', thickness: 10 }
]

function buildLayers(fert, erosion) {
  const lookup = baseLookup[fert]?.[erosion]
  if (!lookup) return []
  return depthConfigs.map(cfg => ({
    layerId: cfg.label,
    thickness: cfg.thickness,
    bd: 1.15,
    socValue: lookup[cfg.key]
  }))
}

export const useCalculatorStore = defineStore('calculator', () => {
  const inputs = ref({
    fert: 'F',
    erosion: '0',
    depth: '10',
    bd: 1.15,
    ph: 5.60,
    wc: 18.00,
    clay: 96.29,
    tn: 1.59,
    cropBiomass: 8500,
    strawCarbonRatio: 0.45
  })

  const results = ref(null)
  const resilience = ref(null)
  const errors = ref([])

  function calculate() {
    const params = {
      fert: inputs.value.fert,
      erosion: parseInt(inputs.value.erosion),
      depth: parseInt(inputs.value.depth),
      bd: parseFloat(inputs.value.bd),
      ph: parseFloat(inputs.value.ph),
      wc: parseFloat(inputs.value.wc),
      clay: parseFloat(inputs.value.clay),
      tn: parseFloat(inputs.value.tn),
      cropBiomass: (() => { const v = parseFloat(inputs.value.cropBiomass); return isNaN(v) ? 8500 : v })(),
      strawCarbonRatio: (() => { const v = parseFloat(inputs.value.strawCarbonRatio); return isNaN(v) ? 0.45 : v })()
    }
    const result = computeAll(params)
    if (result.success) {
      results.value = result.results

      const soilLayers = buildLayers(inputs.value.fert, parseInt(inputs.value.erosion))
      const initialLayers = buildLayers(inputs.value.fert, 0)
      const resResult = assessResilience({
        soilLayers,
        initialLayers,
        cropBiomass: (() => { const v = parseFloat(inputs.value.cropBiomass); return isNaN(v) ? 8500 : v })(),
        strawCarbonRatio: (() => { const v = parseFloat(inputs.value.strawCarbonRatio); return isNaN(v) ? 0.45 : v })()
      })
      resilience.value = resResult.success ? resResult.results : null

      errors.value = []
    } else {
      results.value = null
      resilience.value = null
      errors.value = result.errors
    }
    return result
  }

  function reset() {
    inputs.value = {
      fert: 'F', erosion: '0', depth: '10', bd: 1.15,
      ph: 5.60, wc: 18.00, clay: 96.29, tn: 1.59,
      cropBiomass: 8500, strawCarbonRatio: 0.45
    }
    results.value = null
    resilience.value = null
    errors.value = []
  }

  return { inputs, results, resilience, errors, calculate, reset }
})
