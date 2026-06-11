const baseData = {
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

const erosionCoefficients = {
  0: 1.00, 10: 0.74, 20: 0.49, 30: 0.39,
  40: 0.52, 50: 0.83, 60: 0.37, 70: 0.31
}

const depthFactor = {
  10: 1.00, 25: 0.70, 35: 0.55, 45: 0.43, 55: 0.34
}

const fertilizerEffect = { F: 1.0, UNF: 0.92 }

export function validateInput(params) {
  const errors = []
  if (params.bd < 0.5 || params.bd > 2.5) errors.push('土壤容重应在0.5-2.5 g/cm³范围内')
  if (params.ph < 3 || params.ph > 11) errors.push('pH值应在3-11范围内')
  if (params.wc < 0 || params.wc > 100) errors.push('含水量应在0-100%范围内')
  if (params.clay < 0 || params.clay > 100) errors.push('黏粉粒含量应在0-100%范围内')
  if (params.tn < 0 || params.tn > 10) errors.push('全氮含量应在0-10 g/kg范围内')
  if (params.cropBiomass < 0) errors.push('秸秆生物量不能为负')
  if (params.strawCarbonRatio < 0 || params.strawCarbonRatio > 1) errors.push('秸秆碳含量应在0-1范围内')
  if (params.soilLayers) {
    params.soilLayers.forEach((layer, i) => {
      if (layer.bd < 0.8 || layer.bd > 1.8) errors.push(`第${i+1}层土壤容重应在0.8-1.8 g/cm³范围内`)
      if (layer.socValue < 0 || layer.socValue > 100) errors.push(`第${i+1}层SOC含量应在0-100 g/kg范围内`)
      if (layer.thickness <= 0) errors.push(`第${i+1}层厚度必须大于0`)
    })
  }
  return errors
}

export function lookupBaseSOC(fert, erosion, depth) {
  return baseData[fert]?.[erosion]?.[depth] ?? null
}

export function calculateSOC(params) {
  const fert = params.fert
  const erosion = parseInt(params.erosion)
  const depth = parseInt(params.depth)
  const erosionCoeff = erosionCoefficients[erosion] || 1.0
  const fertFactor = fertilizerEffect[fert] ?? 1.0
  if (!baseData[fert]) return NaN
  const baseSOC = baseData[fert]?.[erosion]?.[depth] ?? 10.0
  return Math.max(0, baseSOC * erosionCoeff * fertFactor)
}

export function calculateCarbonStorage(soc, bd, depthCm) {
  return Math.max(0, (soc * bd * Math.min(depthCm, 20)) / 100)
}

export function calculateCarbonDensity(carbonStorage, depthCm) {
  if (!depthCm || depthCm <= 0) return 0
  return Math.max(0, carbonStorage / (depthCm / 100))
}

export function calculateNetChange(soc, fert, erosion) {
  const baseSoc = baseData['F'][0][10]
  const erosionImpact = (erosion / 70) * 0.3
  const fertImpact = fert === 'F' ? 0.05 : -0.02
  return soc * (1 + fertImpact - erosionImpact)
}

export function calculateRecoveryRate(netChange, years = 20) {
  return Math.max(0, netChange / years)
}

export function calculateLossRate(soc, fert) {
  const baseSoc = baseData[fert]?.[0]?.[10]
  if (baseSoc === undefined || baseSoc === null) return 0
  return Math.max(0, ((baseSoc - soc) / baseSoc) * 100)
}

export function computeAll(params) {
  const errors = validateInput(params)
  if (errors.length > 0) return { success: false, errors }

  const soc = calculateSOC(params)
  const depthVal = parseInt(params.depth)
  const carbonStorage = calculateCarbonStorage(soc, params.bd, depthVal)
  const carbonDensity = calculateCarbonDensity(carbonStorage, depthVal)
  const netChange = calculateNetChange(soc, params.fert, parseInt(params.erosion))
  const recoveryRate = calculateRecoveryRate(netChange)
  const lossRate = calculateLossRate(soc, params.fert)

  return {
    success: true,
    results: {
      soc: +soc.toFixed(2),
      carbonStorage: +carbonStorage.toFixed(2),
      carbonDensity: +carbonDensity.toFixed(2),
      netChange: +netChange.toFixed(2),
      recoveryRate: +recoveryRate.toFixed(3),
      lossRate: +lossRate.toFixed(1)
    },
    params: { ...params }
  }
}
