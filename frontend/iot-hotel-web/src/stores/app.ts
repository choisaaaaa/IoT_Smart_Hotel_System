import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAppStore = defineStore('app', () => {
  const sidebarCollapsed = ref(false)
  const currentTier = ref<'admin' | 'floor' | 'room'>('admin')
  const connected = ref(false)
  const userInfo = ref<any>(null)
  const userStatus = ref<any>(null)
  const showLoginModal = ref(false)
  const notifications = ref<{ id: string; type: string; message: string; time: string }[]>([])

  const notificationCount = computed(() => notifications.value.length)

  function toggleSidebar() {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }

  function setCurrentTier(tier: 'admin' | 'floor' | 'room') {
    currentTier.value = tier
  }

  function setConnected(status: boolean) {
    connected.value = status
  }

  function addNotification(type: string, message: string) {
    notifications.value.unshift({
      id: Date.now().toString(),
      type,
      message,
      time: new Date().toLocaleTimeString()
    })
    if (notifications.value.length > 50) notifications.value.pop()
  }

  function removeNotification(id: string) {
    notifications.value = notifications.value.filter(n => n.id !== id)
  }

  function clearNotifications() {
    notifications.value = []
  }

  // 初始化从 localStorage 加载用户信息
  const initUserInfo = () => {
    const info = localStorage.getItem('user_info')
    if (info) {
      try {
        userInfo.value = JSON.parse(info)
      } catch (e) {
        console.error('解析用户信息失败', e)
      }
    }
  }

  const setUserInfo = (info: any) => {
    userInfo.value = info
    if (info) {
      localStorage.setItem('user_info', JSON.stringify(info))
    } else {
      localStorage.removeItem('user_info')
      localStorage.removeItem('auth_token')
      userStatus.value = null
    }
  }

  const setUserStatus = (status: any) => {
    userStatus.value = status
  }

  // --- 语音通话全局状态 ---
  const incomingCall = ref<any>(null)
  const currentCall = ref<any>(null) // 新增：当前正在进行的通话
  const isRegistered = ref(false)
  const clientDisplayName = ref('')

  // 通话实时状态
  const callState = ref({
    connectionState: 'new',
    inputVolume: 0,
    outputVolume: 0,
    localSpeaking: false,
    remoteSpeaking: false,
    duration: '00:00'
  })

  function setIncomingCall(call: any) {
    incomingCall.value = call
  }

  function clearIncomingCall() {
    incomingCall.value = null
  }

  function setCurrentCall(call: any) {
    currentCall.value = call
    if (!call) {
      resetCallState()
    }
  }

  function clearCurrentCall() {
    currentCall.value = null
    resetCallState()
  }

  function setCallState(state: Partial<typeof callState.value>) {
    Object.assign(callState.value, state)
  }

  function resetCallState() {
    callState.value = {
      connectionState: 'new',
      inputVolume: 0,
      outputVolume: 0,
      localSpeaking: false,
      remoteSpeaking: false,
      duration: '00:00'
    }
  }

  function setRegistration(status: boolean, name: string = '') {
    isRegistered.value = status
    clientDisplayName.value = name
  }

  return {
    sidebarCollapsed,
    currentTier,
    connected,
    userInfo,
    showLoginModal,
    notifications,
    notificationCount,
    incomingCall,
    currentCall,
    callState,
    isRegistered,
    clientDisplayName,
    toggleSidebar,
    setCurrentTier,
    setConnected,
    addNotification,
    removeNotification,
    clearNotifications,
    initUserInfo,
    setUserInfo,
    userStatus,
    setUserStatus,
    setIncomingCall,
    clearIncomingCall,
    setCurrentCall,
    clearCurrentCall,
    setCallState,
    setRegistration
  }
})
