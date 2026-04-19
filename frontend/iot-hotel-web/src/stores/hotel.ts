import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import type { RoomInfo, HotelInfo } from '@/types'

export const useHotelStore = defineStore('hotel', () => {
  const hotelInfo = ref<HotelInfo | null>(null)
  const currentHotelId = ref<number | null>(null)
  const rooms = ref<RoomInfo[]>([])
  const loading = ref(false)
  const roomFetchAt = ref(0)
  const roomFetchKey = ref('')
  const roomFetchPromise = ref<Promise<any> | null>(null)
  const roomRateLimitedUntil = ref(0)

  async function fetchHotelInfo(hotelId?: number) {
    loading.value = true
    try {
      const { hotelManageApi } = await import('@/api/hotel-manage')
      // 如果传入了 hotelId，或者 currentHotelId 有值，则作为参数传递
      const params = (hotelId || currentHotelId.value) ? { hotel_id: hotelId || currentHotelId.value! } : undefined
      const res: any = await hotelManageApi.getHotelInfo(params)
      hotelInfo.value = res.data
      if (res.data && res.data.id !== undefined) {
        currentHotelId.value = res.data.id
      }
    } finally {
      loading.value = false
    }
  }

  function setCurrentHotelId(hotelId: number) {
    currentHotelId.value = hotelId
  }

  async function fetchRooms(params?: any, forceRefresh = false) {
    const nextKey = JSON.stringify(params || {})
    const now = Date.now()
    if (!forceRefresh && now < roomRateLimitedUntil.value) {
      return {
        list: rooms.value,
        total: rooms.value.length,
        page: 1,
        pageSize: rooms.value.length,
        totalPages: 1
      }
    }
    if (!forceRefresh && roomFetchPromise.value && roomFetchKey.value === nextKey) {
      return roomFetchPromise.value
    }
    if (!forceRefresh && roomFetchKey.value === nextKey && now - roomFetchAt.value < 2000 && rooms.value.length > 0) {
      return {
        list: rooms.value,
        total: rooms.value.length,
        page: 1,
        pageSize: rooms.value.length,
        totalPages: 1
      }
    }
    roomFetchKey.value = nextKey
    loading.value = true
    const task = (async () => {
      const { roomApi } = await import('@/api/room')
      try {
        // 自动添加当前酒店ID
        const requestParams = {
          ...params,
          ...(currentHotelId.value ? { hotel_id: currentHotelId.value } : {})
        }
        const res: any = await roomApi.getRoomList(requestParams)
        rooms.value = res.data?.list || []
        roomFetchAt.value = Date.now()
        return res.data
      } catch (error: any) {
        const status = Number(error?.response?.status || 0)
        if (status === 429) {
          roomRateLimitedUntil.value = Date.now() + 10000
          return {
            list: rooms.value,
            total: rooms.value.length,
            page: 1,
            pageSize: rooms.value.length,
            totalPages: 1
          }
        }
        throw error
      }
    })()
    roomFetchPromise.value = task
    try {
      return await task
    } finally {
      roomFetchPromise.value = null
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

  const floors = computed(() => {
    const floorSet = new Set<number>()
    rooms.value.forEach(room => floorSet.add(Number(room.floor)))
    return Array.from(floorSet).sort((a, b) => a - b).map(floor => ({ floor }))
  })

  const groupedRooms = computed(() => {
    return floors.value.map(item => ({
      floor: item.floor,
      rooms: rooms.value
        .filter(room => Number(room.floor) === item.floor)
        .sort((a, b) => String(a.room_number).localeCompare(String(b.room_number)))
    }))
  })

  return {
    hotelInfo,
    currentHotelId,
    rooms,
    loading,
    floors,
    groupedRooms,
    fetchHotelInfo,
    setCurrentHotelId,
    fetchRooms,
    getRoomsByFloor,
    getAvailableRooms,
    getOccupiedRooms
  }
})
