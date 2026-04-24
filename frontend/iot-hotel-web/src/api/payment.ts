import request from './request'
import type { ApiResponse } from '@/types'

export interface PaymentCreateParams {
  order_type: string
  order_id: number
  amount: number
  payment_method: string
  description?: string
}

export interface PaymentInfo {
  id: number
  payment_no: string
  order_type: string
  order_id: number
  amount: number
  payment_method: string
  status: string
  transaction_no?: string
  paid_at?: string
  created_at: string
}

class PaymentApi {
  async createPayment(params: PaymentCreateParams): Promise<PaymentInfo> {
    const response: any = await request.post<ApiResponse<PaymentInfo>>('/payments', params)
    return response?.data
  }

  async payPayment(paymentId: number, transactionNo?: string): Promise<void> {
    await request.put<ApiResponse<void>>(`/payments/${paymentId}/pay`, {
      transaction_no: transactionNo || ('T' + Date.now())
    })
  }

  async getPaymentStatus(paymentId: number): Promise<PaymentInfo> {
    const response: any = await request.get<ApiResponse<PaymentInfo>>(`/payments/${paymentId}`)
    return response?.data
  }

  async getPaymentHistory(params?: {
    page?: number
    pageSize?: number
    status?: string
  }): Promise<{ list: PaymentInfo[]; total: number }> {
    const response: any = await request.get<ApiResponse<{ list: PaymentInfo[]; total: number }>>('/payments', { params })
    return response?.data || { list: [], total: 0 }
  }

  async refundPayment(paymentId: number, refundReason?: string): Promise<PaymentInfo> {
    const response: any = await request.put<ApiResponse<PaymentInfo>>(`/payments/${paymentId}/refund`, {
      refund_reason: refundReason || '管理员手动退款'
    })
    return response?.data
  }
}

export const paymentApi = new PaymentApi()
