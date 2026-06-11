export function computeCarbonPoolByLayer(soc_gkg, bd_gcm3, thickness_cm) {
  return (soc_gkg * bd_gcm3 * thickness_cm) / 100
}

export function computeTotalCarbonPool(layers) {
  return layers.reduce((sum, layer) => {
    return sum + computeCarbonPoolByLayer(layer.socValue, layer.bd, layer.thickness)
  }, 0)
}

export function computeNetChange(finalPool, initialPool) {
  return finalPool - initialPool
}

export function computeAnnualRecoveryRate(poolCurrent, poolPrevious, years = 1) {
  return (poolCurrent - poolPrevious) / years
}

export function computeStrawCarbonInput(biomass_kgha, carbonRatio, returnRatio) {
  return (biomass_kgha * carbonRatio * returnRatio) / 10000
}

export function computeStrawScenarios(biomass_kgha, carbonRatio, litterCarbonInput) {
  const scenarios = [0.3, 0.5, 1.0]
  return scenarios.map(ratio => ({
    label: `${Math.round(ratio * 100)}%秸秆还田`,
    returnRatio: ratio,
    strawInput: computeStrawCarbonInput(biomass_kgha, carbonRatio, ratio),
    totalInput: litterCarbonInput + computeStrawCarbonInput(biomass_kgha, carbonRatio, ratio)
  }))
}

export function assessResilience(params) {
  if (params === null || params === undefined) params = {}
  const {
    soilLayers,
    initialLayers,
    cropBiomass = 8500,
    strawCarbonRatio = 0.45,
    litterCarbonInput = 0.15
  } = params

  if (!soilLayers || soilLayers.length === 0) {
    return { success: false, errors: ['缺少土层数据'] }
  }
  if (!initialLayers || initialLayers.length === 0) {
    return { success: false, errors: ['缺少初始年份土层数据'] }
  }

  const finalPool_0_20 = computeTotalCarbonPool(
    soilLayers.filter(l => {
      const [start] = l.layerId.split('-').map(Number)
      return start < 20
    })
  )
  const finalPool_0_60 = computeTotalCarbonPool(soilLayers)

  const initialPool_0_20 = computeTotalCarbonPool(
    initialLayers.filter(l => {
      const [start] = l.layerId.split('-').map(Number)
      return start < 20
    })
  )
  const initialPool_0_60 = computeTotalCarbonPool(initialLayers)

  const netChange20yr = computeNetChange(finalPool_0_60, initialPool_0_60)
  const netChange100yr = computeNetChange(finalPool_0_20, initialPool_0_20)
  const recoveryRate = computeAnnualRecoveryRate(finalPool_0_60, initialPool_0_60, 20)

  const strawScenarios = computeStrawScenarios(cropBiomass, strawCarbonRatio, litterCarbonInput)

  const layerPools = soilLayers.map(l => ({
    layerId: l.layerId,
    carbonPool: +computeCarbonPoolByLayer(l.socValue, l.bd, l.thickness).toFixed(3),
    soc: l.socValue,
    bd: l.bd,
    thickness: l.thickness
  }))

  const status = netChange20yr > 0
    ? '碳库呈恢复趋势，土壤固碳能力正向'
    : netChange20yr === 0 ? '碳库基本稳定' : '碳库持续亏损，需加强管理干预'

  return {
    success: true,
    results: {
      carbonPool_0_20: +finalPool_0_20.toFixed(2),
      carbonPool_0_60: +finalPool_0_60.toFixed(2),
      netChange_20yr: +netChange20yr.toFixed(2),
      netChange_100yr: +netChange100yr.toFixed(2),
      recoveryRate_annual: +recoveryRate.toFixed(3),
      layerPools,
      strawScenarios,
      status
    }
  }
}
