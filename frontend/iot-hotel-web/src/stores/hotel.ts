import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { RoomInfo, HotelInfo } from '@/types'

export const useHotelStore = defineStore('hotel', () => {
  const hotelInfo = ref<HotelInfo | null>(null)
  const rooms = ref<RoomInfo[]>([])
  const loading = ref(false)

  async function fetchHotelInfo() {
    loading.value = true
    try {
      const { hotelManageApi } = await import('@/api/hotel-manage')
      const res: any = await hotelManageApi.getHotelInfo()
      hotelInfo.value = res.data
    } finally {
      loading.value = false
    }
  }

  async function fetchRooms(params?: any) {
    loading.value = true
    try {
      const { roomApi } = await import('@/api/room')
      const res: any = await roomApi.getRoomList(params)
      rooms.value = res.data?.list || []
      return res.data
    } finally {
      loading.value = false
    }
  }

  function getRoomsByFloor(floor: number): RoomInfo[] {
    return rooms.value.filter(r => r.floor === floor)
  }

  function getAvailableRooms(): RoomInfo[] {
    return rooms.value.filter(r => r.room_status === 'available')
  }

  function getOccupiedRooms(): RoomInfo[] {
    return rooms.value.filter(r => r.room_status === 'occupied')
  }

  return {
    hotelInfo,
    rooms,
    loading,
    fetchHotelInfo,
    fetchRooms,
    getRoomsByFloor,
    getAvailableRooms,
    getOccupiedRooms
  }
})