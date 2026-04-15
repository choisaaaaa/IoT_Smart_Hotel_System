import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import { normalizeRole, CANONICAL_ROLES } from '@/api/auth'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/guest/booking'
  },
  {
    path: '/system',
    component: () => import('@/components/layout/SystemLayout.vue'),
    meta: { requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] },
    children: [
      {
        path: '',
        redirect: '/system/dashboard'
      },
      {
        path: 'dashboard',
        name: 'SystemDashboard',
        component: () => import('@/views/system/GlobalDashboard.vue'),
        meta: { title: '集团运营总览', icon: 'DashboardOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      },
      {
        path: 'hotels',
        name: 'HotelManagement',
        component: () => import('@/views/system/HotelManagement.vue'),
        meta: { title: '酒店维护', icon: 'BankOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      },
      {
        path: 'devices',
        name: 'SystemDeviceManagement',
        component: () => import('@/views/system/SystemDeviceManagement.vue'),
        meta: { title: '全局设备', icon: 'MobileOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      },
      {
        path: 'users',
        name: 'SystemUserManagement',
        component: () => import('@/views/system/UserManagement.vue'),
        meta: { title: '账户管理', icon: 'UserOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      },
      {
        path: 'coupons',
        name: 'SystemCoupons',
        component: () => import('@/views/admin/CouponManage.vue'),
        meta: { title: '优惠券管理', icon: 'GiftOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      },
      {
        path: 'settings',
        name: 'SystemSettings',
        component: () => import('@/views/system/SystemSettings.vue'),
        meta: { title: '会员方案配置', icon: 'SettingOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.SYSTEM_ADMIN] }
      }
    ]
  },
  {
    path: '/hotel-admin',
    component: () => import('@/components/layout/AdminLayout.vue'),
    meta: { title: '管理端', icon: 'SettingOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] },
    children: [
      {
        path: '',
        redirect: '/hotel-admin/dashboard'
      },
      {
        path: 'dashboard',
        name: 'AdminDashboard',
        component: () => import('@/views/admin/Dashboard.vue'),
        meta: { title: '总览仪表盘', icon: 'DashboardOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'devices',
        name: 'DeviceMonitor',
        component: () => import('@/views/admin/DeviceMonitor.vue'),
        meta: { title: '设备监控', icon: 'MonitorOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'environment',
        name: 'AdminEnvironmentMonitor',
        component: () => import('@/views/admin/EnvironmentMonitor.vue'),
        meta: { title: '环境监测', icon: 'EnvironmentOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'rooms/edit',
        name: 'RoomEdit',
        component: () => import('@/views/admin/RoomEdit.vue'),
        meta: { title: '房间管理', icon: 'HomeOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'rooms/types',
        name: 'RoomTypeManage',
        component: () => import('@/views/admin/RoomTypeManage.vue'),
        meta: { title: '房型维护', icon: 'TagsOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'rooms/floors',
        name: 'FloorManage',
        component: () => import('@/views/admin/FloorManage.vue'),
        meta: { title: '楼层管理', icon: 'BarsOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'hotel/info',
        name: 'HotelInfoEdit',
        component: () => import('@/views/admin/HotelInfoEdit.vue'),
        meta: { title: '酒店信息编辑', icon: 'BankOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'hotel/price-calendar',
        name: 'PriceCalendar',
        component: () => import('@/views/admin/PriceCalendar.vue'),
        meta: { title: '价格日历', icon: 'CalendarOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'hotel/coupons',
        name: 'AdminCoupons',
        component: () => import('@/views/admin/CouponManage.vue'),
        meta: { title: '优惠券管理', icon: 'TagOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'reports',
        name: 'AdminReports',
        component: () => import('@/views/admin/AdminReports.vue'),
        meta: { title: '账单报表', icon: 'FileTextOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'users',
        name: 'AdminUserManagement',
        component: () => import('@/views/system/UserManagement.vue'),
        meta: { title: '用户管理', icon: 'UserOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      },
      {
        path: 'knowledge-base',
        name: 'KnowledgeBaseManage',
        component: () => import('@/views/admin/KnowledgeBaseManage.vue'),
        meta: { title: 'AI知识库', icon: 'BookOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN] }
      }
    ]
  },
  {
    path: '/reception',
    component: () => import('@/components/layout/ReceptionLayout.vue'),
    meta: { title: '前台端', icon: 'CustomerServiceOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] },
    children: [
      {
        path: '',
        redirect: '/reception/dashboard'
      },
      {
        path: 'dashboard',
        name: 'ReceptionDashboard',
        component: () => import('@/views/reception/Dashboard.vue'),
        meta: { title: '前台总览', icon: 'DashboardOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'reception-center',
        name: 'ReceptionCenter',
        component: () => import('@/views/reception/CheckInOut.vue'),
        meta: { title: '接待中心', icon: 'UserOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'device-management',
        name: 'DeviceManagement',
        component: () => import('@/views/reception/DeviceManagement.vue'),
        meta: { title: '主控设备管理', icon: 'ControlOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'bookings',
        name: 'ReceptionBookings',
        component: () => import('@/views/reception/Bookings.vue'),
        meta: { title: '预订管理', icon: 'CalendarOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'room-availability',
        name: 'RoomAvailability',
        component: () => import('@/views/reception/RoomAvailability.vue'),
        meta: { title: '客房余量', icon: 'ApartmentOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'workorders',
        name: 'WorkOrders',
        component: () => import('@/views/reception/WorkOrders.vue'),
        meta: { title: '工单处理', icon: 'ToolOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'delivery',
        name: 'DeliveryOrders',
        component: () => import('@/views/reception/DeliveryOrders.vue'),
        meta: { title: '客房送物', icon: 'SendOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'voice-calls',
        name: 'VoiceCalls',
        component: () => import('@/views/reception/VoiceCalls.vue'),
        meta: { title: '语音通话', icon: 'PhoneOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'environment',
        name: 'ReceptionEnvironmentMonitor',
        component: () => import('@/views/reception/EnvironmentMonitor.vue'),
        meta: { title: '环境监测', icon: 'EnvironmentOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'price-calendar',
        name: 'ReceptionPriceCalendar',
        component: () => import('@/views/admin/PriceCalendar.vue'),
        meta: { title: '价格日历', icon: 'CalendarOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'coupons',
        name: 'ReceptionCoupons',
        component: () => import('@/views/admin/CouponManage.vue'),
        meta: { title: '优惠券管理', icon: 'TagOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      },
      {
        path: 'bills',
        name: 'Bills',
        component: () => import('@/views/reception/Bills.vue'),
        meta: { title: '账单报表', icon: 'DollarOutlined', requiresAuth: true, roles: [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF] }
      }
    ]
  },
  {
    path: '/guest',
    component: () => import('@/components/layout/GuestLayout.vue'),
    meta: { title: '客户端', icon: 'MobileOutlined', requiresAuth: false },
    children: [
      {
        path: '',
        redirect: '/guest/booking'
      },
      {
        path: 'booking',
        name: 'GuestBooking',
        component: () => import('@/views/guest/Booking.vue'),
        meta: { title: '客房预订', icon: 'CalendarOutlined', requiresAuth: false }
      },
      {
        path: 'checkin-online',
        name: 'OnlineCheckIn',
        component: () => import('@/views/guest/OnlineCheckIn.vue'),
        meta: { title: '在线办理入住', icon: 'IdcardOutlined', requiresAuth: false }
      },
      {
        path: 'room/:roomId?',
        name: 'GuestRoom',
        component: () => import('@/views/guest/GuestRoom.vue'),
        meta: { title: '客房服务', icon: 'HomeOutlined', requiresAuth: false }
      },
      {
        path: 'orders',
        name: 'MyOrders',
        component: () => import('@/views/guest/MyOrders.vue'),
        meta: { title: '我的订单', icon: 'OrderedListOutlined', requiresAuth: false }
      },
      {
        path: 'profile',
        name: 'UserProfile',
        component: () => import('@/views/guest/Profile.vue'),
        meta: { title: '个人中心', icon: 'UserOutlined', requiresAuth: true }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() {
    return { top: 0 }
  }
})

const whiteList = ['/login']

router.beforeEach((to, from, next) => {
  const title = to.meta.title as string
  document.title = title ? `${title} - 智联酒店` : '智联酒店 - 智慧酒店物联网控制系统'

  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const token = localStorage.getItem('auth_token')
  const userInfoStr = localStorage.getItem('user_info')
  const userInfo = userInfoStr ? JSON.parse(userInfoStr) : null
  const normalizedRole = normalizeRole(userInfo?.role)

  if (!requiresAuth) {
    if (to.path === '/login' && token && userInfo) {
      switch (normalizedRole) {
        case CANONICAL_ROLES.SYSTEM_ADMIN:
          next('/system/dashboard')
          break
        case CANONICAL_ROLES.HOTEL_ADMIN:
          next('/hotel-admin/dashboard')
          break
        case CANONICAL_ROLES.STAFF:
          next('/reception/dashboard')
          break
        case CANONICAL_ROLES.CUSTOMER:
          next('/guest/booking')
          break
        default:
          next('/guest/booking')
      }
    } else {
      next()
    }
    return
  }

  if (!token || !userInfo) {
    if (to.path.startsWith('/guest/')) {
      next({
        path: '/guest/booking',
        query: { login: '1', redirect: to.fullPath }
      })
    } else {
      next({
        path: '/guest/booking',
        query: { login: '1', redirect: to.fullPath }
      })
    }
    return
  }

  let allowedRoles: string[] = []
  to.matched.forEach(record => {
    if (record.meta.roles) {
      allowedRoles = allowedRoles.concat(record.meta.roles as string[])
    }
  })

  const normalizedAllowedRoles = allowedRoles.map((role) => normalizeRole(role))
  if (normalizedAllowedRoles.length > 0 && !normalizedAllowedRoles.includes(normalizedRole)) {
    switch (normalizedRole) {
      case CANONICAL_ROLES.SYSTEM_ADMIN:
        next('/system/dashboard')
        break
      case CANONICAL_ROLES.HOTEL_ADMIN:
        next('/hotel-admin/dashboard')
        break
      case CANONICAL_ROLES.STAFF:
        next('/reception/dashboard')
        break
      case CANONICAL_ROLES.CUSTOMER:
        next('/guest/booking')
        break
      default:
        next('/guest/booking?login=1')
    }
    return
  }

  next()
})

export default router
