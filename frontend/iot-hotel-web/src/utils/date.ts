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

export function now(): dayjs.Dayjs {
  return dayjs().tz(TZ)
}

export function toTz(val: any): dayjs.Dayjs | null {
  const d = ensureDayjs(val)
  return d ? d.tz(TZ) : null
}
