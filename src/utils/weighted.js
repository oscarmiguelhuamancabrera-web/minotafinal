import { toNumber } from './grades.js'

export function storedCourseCredits(course) {
  const credits = toNumber(course?.credits)
  return credits !== null && credits > 0 ? credits : null
}

export function courseCreditIsConfirmed(course, preference) {
  const credits = storedCourseCredits(course)
  if (credits === null || !preference?.confirmed_at) return false
  const updatedAt = course?.student_course_updated_at || course?.updated_at
  if (!updatedAt) return true
  return new Date(updatedAt).getTime() <= new Date(preference.confirmed_at).getTime()
}

export function weightedAverageSummary(courses = [], history = []) {
  const latestHistoryForCourse = (courseId) => (history || []).find((item) => item.course_id === courseId) || null
  const rows = (courses || [])
    .map((course) => {
      const latest = latestHistoryForCourse(course.id)
      const average = toNumber(latest?.current_average)
      const credits = storedCourseCredits(course) || 1
      if (average === null) return null
      return { course, latest, average, credits, points: average * credits }
    })
    .filter(Boolean)
  const totalCredits = rows.reduce((sum, item) => sum + item.credits, 0)
  const totalPoints = rows.reduce((sum, item) => sum + item.points, 0)
  return { rows, totalCredits, average: totalCredits > 0 ? totalPoints / totalCredits : null }
}
