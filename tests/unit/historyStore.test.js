import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useHistoryStore } from '@/stores/history.js'

describe('historyStore — searchRecords edge cases', () => {
  let store

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useHistoryStore()
  })

  it('searchRecords returns all records when query is empty', () => {
    const recs = [
      { id: 1, fert: 'F', erosion: 10, results: { soc: 20.5 } },
      { id: 2, fert: 'UNF', erosion: 20, results: { soc: 15.3 } }
    ]
    store.records = recs
    expect(store.searchRecords('')).toHaveLength(2)
  })

  it('searchRecords handles null/undefined fert field', () => {
    const recs = [
      { id: 1, fert: null, erosion: 10, results: { soc: 20.5 } },
      { id: 2, fert: undefined, erosion: 20, results: { soc: 15.3 } }
    ]
    store.records = recs
    expect(() => store.searchRecords('test')).not.toThrow()
    expect(store.searchRecords('test')).toHaveLength(0)
  })

  it('searchRecords handles null results field', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 10, results: null }
    ]
    expect(() => store.searchRecords('20')).not.toThrow()
  })

  it('searchRecords handles missing results field', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 10 }
    ]
    expect(() => store.searchRecords('F')).not.toThrow()
  })

  it('searchRecords handles empty records array', () => {
    store.records = []
    expect(store.searchRecords('anything')).toHaveLength(0)
  })

  it('searchRecords matches fert field', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 10, results: { soc: 20.5 } }
    ]
    expect(store.searchRecords('F')).toHaveLength(1)
    expect(store.searchRecords('f')).toHaveLength(1)
  })

  it('searchRecords matches erosion field (stringified)', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 10, results: { soc: 20.5 } }
    ]
    expect(store.searchRecords('10')).toHaveLength(1)
  })

  it('searchRecords matches soc value when present', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 10, results: { soc: 20.5 } }
    ]
    expect(store.searchRecords('20.5')).toHaveLength(1)
  })

  it('searchRecords handles erosion as number vs string', () => {
    store.records = [
      { id: 1, fert: 'F', erosion: 0, results: { soc: 23.9 } },
      { id: 2, fert: 'UNF', erosion: null, results: { soc: 15 } }
    ]
    expect(() => store.searchRecords('0')).not.toThrow()
  })

  it('searchRecords multichar query does not crash on partial match', () => {
    store.records = [
      { id: 1, fert: 'UNF', erosion: 30, results: { soc: 13.76 } }
    ]
    expect(store.searchRecords('UN')).toHaveLength(1)
    expect(store.searchRecords('un')).toHaveLength(1)
  })
})
