import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(utc)
dayjs.extend(timezone)

const TZ = 'Asia/Shanghai'

function ensureDayjs(val: any): dayjs.Dayjs | null {
  if (!val) return null
  const d = dayjs(val)
  return d.isValid() ? d : null
}

export function formatDate(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY-MM-DD') : '-'
}

export function formatDateTime(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY-MM-DD HH:mm') : '-'
}

export function formatDateTimeFull(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY年MM月DD日 HH:mm') : '-'
}

export function formatDateCN(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY年MM月DD日') : '-'
}

export function formatShortDate(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('MM月DD日') : '-'
}

export function formatDotDate(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('MM.DD') : '-'
}

export function formatDotDateTime(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('MM.DD HH:mm') : '-'
}

export function formatSlashDateTime(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('MM/DD HH:mm') : '-'
}

export function formatDashDate(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('MM-DD') : '-'
}

export function formatMonthYear(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY年MM月') : '-'
}

export function formatTimeHHmm(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('HH:mm') : '-'
}

export function formatTimeHHmmss(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('HH:mm:ss') : '-'
}

export function formatDateTimeSec(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY-MM-DD HH:mm:ss') : '-'
}

export function formatDateWeekdayCN(val: any): string {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ).format('YYYY年MM月DD日 dddd') : '-'
}

export function now(): dayjs.Dayjs {
  return dayjs().tz(TZ)
}

export function toTz(val: any): dayjs.Dayjs | null {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ) : null
}

/**
 * 计算两个日期之间的天数差
 * @param start 开始日期
 * @param end 结束日期
 * @returns 天数差
 */
export function getDaysDiff(start: any, end: any): number {
  const d1 = dayjs(start).startOf('day')
  const d2 = dayjs(end).startOf('day')
  return d2.diff(d1, 'day')
}

/**
 * 验证日期是否有效
 * @param val 日期值
 * @returns 是否有效
 */
export function isValidDate(val: any): boolean {
  if (!val) return false
  const d = dayjs(val)
  if (!d.isValid()) return false
  
  // 额外检查：防止 dayjs 的自动进位（如 13月 变成明年 1月）
  if (typeof val === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(val)) {
    const [year, month, day] = val.split('-').map(Number)
    return d.year() === year && (d.month() + 1) === month && d.date() === day
  }
  
  return true
}
