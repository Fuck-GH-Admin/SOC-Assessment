import Dexie from 'dexie'

const db = new Dexie('SOCAssessmentDB')

db.version(1).stores({
  records: '++id, timestamp, fert, erosion, depth',
  settings: 'key'
})

export default db
