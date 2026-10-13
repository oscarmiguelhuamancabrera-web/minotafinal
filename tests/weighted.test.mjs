import test from 'node:test'
import assert from 'node:assert/strict'
import { courseCreditIsConfirmed, storedCourseCredits, weightedAverageSummary } from '../src/utils/weighted.js'

test('weighted summary uses persisted credits and excludes courses without history', () => {
  const courses = [
    { id: 'a', credits: 4 },
    { id: 'b', credits: 3 },
    { id: 'c', credits: null }
  ]
  const history = [
    { course_id: 'a', current_average: 18 },
    { course_id: 'b', current_average: 16 },
    { course_id: 'c', current_average: 14 }
  ]
  const result = weightedAverageSummary(courses, history)
  assert.equal(result.totalCredits, 8)
  assert.equal(result.average, 16.75)
  assert.equal(result.rows.length, 3)
  assert.equal(storedCourseCredits(courses[2]), null)
})

test('credit confirmation is scoped to the preference timestamp', () => {
  const preference = { confirmed_at: '2026-10-13T10:00:00.000Z' }
  assert.equal(courseCreditIsConfirmed({ credits: 4, student_course_updated_at: '2026-10-13T09:59:00.000Z' }, preference), true)
  assert.equal(courseCreditIsConfirmed({ credits: 4, student_course_updated_at: '2026-10-13T10:01:00.000Z' }, preference), false)
  assert.equal(courseCreditIsConfirmed({ credits: null, student_course_updated_at: '2026-10-13T09:00:00.000Z' }, preference), false)
})
