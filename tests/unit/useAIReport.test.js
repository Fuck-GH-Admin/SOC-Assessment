import { describe, it, expect, vi, beforeEach } from 'vitest'
import { useAIReport } from '@/composables/useAIReport.js'

// Real API config for live testing
const API_URL = 'https://api.deepseek.com/chat/completions'
const API_KEY = process.env.DEEPSEEK_API_KEY || ''
const MODEL = 'deepseek-v4-flash'
const TEST_TIMEOUT = 40000

const sampleData = {
  fert: 'F',
  erosion: '0',
  bd: 1.15,
  results: {
    soc: 23.9,
    carbonStorage: 4.6,
    carbonDensity: 23,
    netChange: 1.2,
    recoveryRate: 0.06,
    lossRate: 0
  }
}

describe('useAIReport — mock edge cases', () => {
  let report

  beforeEach(() => {
    report = useAIReport()
  })

  it('generating ref starts as false', () => {
    expect(report.generating.value).toBe(false)
  })

  it('error ref starts as null', () => {
    expect(report.error.value).toBe(null)
  })

  it('handles network failure gracefully', async () => {
    vi.spyOn(globalThis, 'fetch').mockRejectedValueOnce(new TypeError('Failed to fetch'))
    const result = await report.generateReport('https://invalid.url', 'sk-test', 'test-model', sampleData)
    expect(result).toBeNull()
    expect(report.error.value).not.toBeNull()
    expect(report.generating.value).toBe(false)
  })

  it('handles HTTP error status', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: false, status: 401, statusText: 'Unauthorized'
    })
    const result = await report.generateReport('https://api.test.com/v1', 'bad-key', 'test-model', sampleData)
    expect(result).toBeNull()
    expect(report.error.value).toContain('401')
  })

  it('returns empty string when API returns no content', async () => {
    const encoder = new TextEncoder()
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      body: new ReadableStream({
        start(controller) {
          controller.enqueue(encoder.encode('data: {"choices":[{"delta":{"content":""},"index":0}]}\n\n'))
          controller.enqueue(encoder.encode('data: [DONE]\n\n'))
          controller.close()
        }
      })
    })
    const result = await report.generateReport('https://api.test.com/v1', 'sk-test', 'test-model', sampleData)
    expect(result).not.toBeNull()
    expect(result).toBe('（未生成内容）')
  })

  it('handles stream error gracefully (simulates abort/timeout)', async () => {
    // Simulate a ReadableStream that throws (as if AbortSignal fired)
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      body: new ReadableStream({
        start(controller) {
          controller.error(new DOMException('The operation was aborted', 'AbortError'))
        }
      })
    })
    const result = await report.generateReport('https://api.test.com/v1', 'sk-test', 'test-model', sampleData)
    expect(result).toBeNull()
    expect(report.error.value).not.toBeNull()
  })

  it('handles null results gracefully with custom prompt', async () => {
    // The function uses data.results?.soc ?? '' which safely handles null.
    // With null results, it will still attempt the fetch call (and fail).
    vi.spyOn(globalThis, 'fetch').mockRejectedValueOnce(new TypeError('Failed to fetch'))
    const result = await report.generateReport(API_URL, API_KEY, MODEL, {
      fert: 'F', erosion: '0', bd: 1.15, results: null
    })
    expect(result).toBeNull()
    expect(report.generating.value).toBe(false)
  })
})

describe('useAIReport — live API integration', () => {
  let report

  beforeEach(() => {
    report = useAIReport()
  })

  const skipLive = !API_KEY
  const itLive = skipLive ? it.skip : it

  itLive('generates report with real API', async () => {
    const result = await report.generateReport(API_URL, API_KEY, MODEL, sampleData)
    expect(result).not.toBeNull()
    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(10)
    expect(report.generating.value).toBe(false)
    expect(report.error.value).toBeNull()
  }, TEST_TIMEOUT)

  itLive('resets error state before each generation', async () => {
    report.error.value = 'old error'
    await report.generateReport(API_URL, API_KEY, MODEL, sampleData)
    expect(report.error.value).toBeNull()
  }, TEST_TIMEOUT)

  itLive('handles extreme SOC values', async () => {
    const extremeData = {
      ...sampleData,
      results: {
        soc: 999999,
        carbonStorage: 0,
        carbonDensity: 999,
        netChange: -999,
        recoveryRate: 0,
        lossRate: 999
      }
    }
    const result = await report.generateReport(API_URL, API_KEY, MODEL, extremeData)
    expect(result).not.toBeNull()
    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(10)
  }, TEST_TIMEOUT)

  itLive('handles all-zero results', async () => {
    const zeroData = {
      ...sampleData,
      results: {
        soc: 0, carbonStorage: 0, carbonDensity: 0,
        netChange: 0, recoveryRate: 0, lossRate: 0
      }
    }
    const result = await report.generateReport(API_URL, API_KEY, MODEL, zeroData)
    expect(result).not.toBeNull()
    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(10)
  }, TEST_TIMEOUT)
})
