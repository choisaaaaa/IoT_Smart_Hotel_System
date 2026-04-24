import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { now } from '@/utils/date'

export const useAppStore = defineStore('app', () => {
  const sidebarCollapsed = ref(false)
  const currentTier = ref<'admin' | 'floor' | 'room'>('admin')
  const connected = ref(false)
  const userInfo = ref<any>(null)
  const userStatus = ref<any>(null)
  const systemConfigs = ref<any>({
    member_program_name: 'IOT',
    member_scheme: [],
    points_rate: 10,
    points_redeem_rate: 10,
    exp_rate: 0.1,
    checkin_points: 50,
    checkin_exp: 10
  })

  // 默认会员方案 (当后台未配置时使用)
  const defaultMemberScheme = [
    { key: 'standard', name: '普通会员', discount: 1.0, points_multiplier: 1, min_experience: 0, color: '#4b6cb7' },
    { key: 'silver', name: '银会员', discount: 0.95, points_multiplier: 5, min_experience: 100, color: '#2c3e50' },
    { key: 'gold', name: '金会员', discount: 0.88, points_multiplier: 9, min_experience: 500, color: '#d4af37' },
    { key: 'platinum', name: '铂金会员', discount: 0.85, points_multiplier: 12, min_experience: 2000, color: '#434343' },
    { key: 'diamond', name: '钻石会员', discount: 0.80, points_multiplier: 15, min_experience: 5000, color: '#330867' }
  ]

  // 获取有效的会员方案 (合并后台配置与默认值)
  const effectiveMemberScheme = computed(() => {
    const scheme = systemConfigs.value.member_scheme
    if (scheme && Array.isArray(scheme) && scheme.length > 0) {
      return scheme
    }
    return defaultMemberScheme
  })

  /**
   * 获取特定等级的配置信息
   */
  const getLevelInfo = (levelKey: string, experience: number = 0) => {
    const key = String(levelKey || 'standard').toLowerCase().trim()
    const scheme = [...effectiveMemberScheme.value].sort((a, b) => (a.min_experience || 0) - (b.min_experience || 0))
    
    const config = scheme.find(s => s.key === key) || scheme[0]
    const currentIndex = scheme.findIndex(s => s.key === key)
    const nextLevel = scheme[currentIndex + 1]
    
    const currentMin = config.min_experience || 0
    const nextExp = nextLevel ? nextLevel.min_experience : config.min_experience
    
    let percent = 100
    if (nextLevel) {
      percent = Math.floor(Math.min(100, Math.max(0, experience - currentMin) / (nextExp - currentMin) * 100))
    }

    return {
      label: config.name,
      key: config.key,
      discount: Number(config.discount || 1.0),
      multiplier: Number(config.points_multiplier || 1),
      color: config.color,
      nextExp,
      percent,
      level: currentIndex + 1
    }
  }

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
      time: now().format('HH:mm')
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

  const setSystemConfigs = (newConfigs: any) => {
    if (newConfigs) {
      // 深度合并或确保关键字段更新
      const updated = { ...systemConfigs.value, ...newConfigs }
      
      // 确保 member_scheme 是数组格式
      if (typeof updated.member_scheme === 'string') {
        try {
          updated.member_scheme = JSON.parse(updated.member_scheme)
        } catch (e) {
          updated.member_scheme = []
        }
      }
      
      systemConfigs.value = updated
      console.log('[Store] 系统配置已更新:', systemConfigs.value)
    }
  }

  // --- 语音通话全局状态 ---
  const incomingCall = ref<any>(null)
  const currentCall = ref<any>(null) // 新增：当前正在进行的通话
  const isRegistered = ref(false)
  const clientDisplayName = ref('')
  const webrtcConfig = ref<any>({ iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] })

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

  function setWebrtcConfig(config: any) {
    if (config) webrtcConfig.value = config
  }

  // 智能解析图片地址：如果是相对路径则自动补全 API 地址
  function resolveImageUrl(url: string | null | undefined) {
    if (!url) return ''
    if (url.startsWith('http') || url.startsWith('blob:') || url.startsWith('data:')) {
      return url
    }
    // 获取当前 API 的基础路径
    // 优先使用环境变量，其次使用当前页面的协议和主机（避免混合内容问题）
    const apiBase = import.meta.env.VITE_API_BASE_URL || `${window.location.protocol}//${window.location.host}`
    return `${apiBase}${url.startsWith('/') ? '' : '/'}${url}`
  }

  // --- 报警相关状态 ---
  const currentAlarm = ref<any>(null)
  const alarmModalVisible = ref(false)
  const alarmList = ref<any[]>([])

  function showAlarmModal(alarm: any) {
    currentAlarm.value = alarm
    alarmModalVisible.value = true
  }

  function hideAlarmModal() {
    alarmModalVisible.value = false
  }

  function setCurrentAlarm(alarm: any) {
    currentAlarm.value = alarm
  }

  function addAlarm(alarm: any) {
    alarmList.value.unshift(alarm)
    // 限制列表长度
    if (alarmList.value.length > 100) {
      alarmList.value = alarmList.value.slice(0, 100)
    }
  }

  function removeAlarm(alarmId: string) {
    alarmList.value = alarmList.value.filter(a => a.id !== alarmId)
  }

  function clearAlarms() {
    alarmList.value = []
  }

  function refreshAlarmList() {
    // 触发刷新报警列表的事件
    window.dispatchEvent(new CustomEvent('refresh-alarm-list'))
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
    webrtcConfig,
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
    systemConfigs,
    setSystemConfigs,
    effectiveMemberScheme,
    getLevelInfo,
    setIncomingCall,
    clearIncomingCall,
    setCurrentCall,
    clearCurrentCall,
    setCallState,
    setRegistration,
    setWebrtcConfig,
    resolveImageUrl,
    // 报警相关
    currentAlarm,
    alarmModalVisible,
    alarmList,
    showAlarmModal,
    hideAlarmModal,
    setCurrentAlarm,
    addAlarm,
    removeAlarm,
    clearAlarms,
    refreshAlarmList
  }
})
