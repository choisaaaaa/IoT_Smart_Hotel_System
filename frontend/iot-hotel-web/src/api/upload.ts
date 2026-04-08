import request from './request'
import type { ApiResponse } from '@/types'

export const uploadApi = {
  uploadImage: (formData: FormData) =>
    request.post<ApiResponse<{ url: string; filename: string }>>('/upload/image', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
}
