import request from './request'

export function getReviews(params: { hotel_id?: number; user_id?: number; page?: number; pageSize?: number }) {
  return request.get('/reviews', { params })
}

export function getMyReviews(params?: { page?: number; pageSize?: number }) {
  return request.get('/reviews/my', { params })
}

export function getReviewStats(hotelId: number) {
  return request.get('/reviews/stats', { params: { hotel_id: hotelId } })
}

export function getReviewById(id: number) {
  return request.get(`/reviews/${id}`)
}

export function createReview(data: {
  order_id: number
  hotel_id?: number
  room_type_id?: number
  score: number
  environment_rating?: number
  facility_rating?: number
  comfort_rating?: number
  content: string
  photos?: string[]
}) {
  return request.post('/reviews', data)
}

export function updateReview(id: number, data: {
  score?: number
  environment_rating?: number
  facility_rating?: number
  comfort_rating?: number
  content?: string
  photos?: string[]
}) {
  return request.put(`/reviews/${id}`, data)
}

export function deleteReview(id: number) {
  return request.delete(`/reviews/${id}`)
}

export function replyReview(id: number, reply: string) {
  return request.post(`/reviews/${id}/reply`, { reply })
}

export function getAppeals(params?: { hotel_id?: number; status?: string; page?: number; pageSize?: number }) {
  return request.get('/reviews/appeals', { params })
}

export function createAppeal(data: { review_id: number; appeal_reason: string }) {
  return request.post('/reviews/appeals', data)
}

export function handleAppeal(id: number, data: { action: string; handle_reason?: string }) {
  return request.put(`/reviews/appeals/${id}`, data)
}
