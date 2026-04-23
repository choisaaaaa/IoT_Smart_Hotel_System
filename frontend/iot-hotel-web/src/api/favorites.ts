import request from './request'

export const favoritesApi = {
  // 获取收藏列表
  getFavorites: () =>
    request.get('/favorites'),

  // 添加收藏
  addFavorite: (hotelId: number) =>
    request.post('/favorites', { hotel_id: hotelId }),

  // 取消收藏
  removeFavorite: (hotelId: number) =>
    request.delete(`/favorites/${hotelId}`),

  // 检查是否已收藏
  checkFavorite: (hotelId: number) =>
    request.get(`/favorites/check/${hotelId}`)
}
