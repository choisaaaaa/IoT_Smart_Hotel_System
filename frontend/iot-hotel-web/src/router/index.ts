import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import { normalizeRole } from '@/api/auth'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/guest/booking'
  },
  // 系统管理员路由
  {
    path: '/system',
    component: () => import('@/components/layout/SystemLayout.vue'),
    meta: { requiresAuth: true, roles: ['system'] },
    children: [
      {
        path: '',
        redirect: '/system/dashboard'
      },
      {
        path: 'dashboard',
        name: 'SystemDashboard',
        component: () => import('@/views/admin/Dashboard.vue'), // 复用 Dashboard
        meta: { title: '系统概览', icon: 'DashboardOutlined', requiresAuth: true, roles: ['system'] }
      },
      {
        path: 'hotels',
        name: 'HotelManagement',
        component: () => import('@/views/system/HotelManagement.vue'),
        meta: { title: '酒店维护', icon: 'BankOutlined', requiresAuth: true, roles: ['system'] }
      },
      {
        path: 'devices',
        name: 'SystemDeviceManagement',
        component: () => import('@/views/system/SystemDeviceManagement.vue'),
        meta: { title: '全局设备', icon: 'MobileOutlined', requiresAuth: true, roles: ['system'] }
      },
      {
        path: 'users',
        name: 'SystemUserManagement',
        component: () => import('@/views/system/UserManagement.vue'),
        meta: { title: '账户管理', icon: 'UserOutlined', requiresAuth: true, roles: ['system'] }
      }
    ]
  },
  // 酒店管理端路由
  {
    path: '/hotel-admin',
    component: () => import('@/components/layout/AdminLayout.vue'),
    meta: { title: '管理端', icon: 'SettingOutlined', requiresAuth: true, roles: ['admin', 'manager'] },
    children: [
      {
        path: '',
        redirect: '/hotel-admin/dashboard'
      },
      {
        path: 'dashboard',
        name: 'AdminDashboard',
        component: () => import('@/views/admin/Dashboard.vue'),
        meta: { title: '总览仪表盘', icon: 'DashboardOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'devices',
        name: 'DeviceMonitor',
        component: () => import('@/views/admin/DeviceMonitor.vue'),
        meta: { title: '设备监控', icon: 'MonitorOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'rooms/edit',
        name: 'RoomEdit',
        component: () => import('@/views/admin/RoomEdit.vue'),
        meta: { title: '房间管理', icon: 'HomeOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'rooms/types',
        name: 'RoomTypeManage',
        component: () => import('@/views/admin/RoomTypeManage.vue'),
        meta: { title: '房型维护', icon: 'TagsOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'rooms/floors',
        name: 'FloorManage',
        component: () => import('@/views/admin/FloorManage.vue'),
        meta: { title: '楼层管理', icon: 'BarsOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'hotel/info',
        name: 'HotelInfoEdit',
        component: () => import('@/views/admin/HotelInfoEdit.vue'),
        meta: { title: '酒店信息编辑', icon: 'BankOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'hotel/price-calendar',
        name: 'PriceCalendar',
        component: () => import('@/views/admin/PriceCalendar.vue'),
        meta: { title: '价格日历', icon: 'CalendarOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'hotel/coupons',
        name: 'AdminCoupons',
        component: () => import('@/views/admin/CouponManage.vue'),
        meta: { title: '优惠券管理', icon: 'TagOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'reports',
        name: 'AdminReports',
        component: () => import('@/views/admin/AdminReports.vue'),
        meta: { title: '账单报表', icon: 'FileTextOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      },
      {
        path: 'users',
        name: 'AdminUserManagement',
        component: () => import('@/views/system/UserManagement.vue'),
        meta: { title: '用户管理', icon: 'UserOutlined', requiresAuth: true, roles: ['admin', 'manager'] }
      }
    ]
  },
  {
    path: '/reception',
    component: () => import('@/components/layout/ReceptionLayout.vue'),
    meta: { title: '前台端', icon: 'CustomerServiceOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] },
    children: [
      {
        path: '',
        redirect: '/reception/dashboard'
      },
      {
        path: 'dashboard',
        name: 'ReceptionDashboard',
        component: () => import('@/views/reception/Dashboard.vue'),
        meta: { title: '前台总览', icon: 'DashboardOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'checkinout',
        name: 'CheckInOut',
        component: () => import('@/views/reception/CheckInOut.vue'),
        meta: { title: '入住退房', icon: 'LoginOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'bookings',
        name: 'ReceptionBookings',
        component: () => import('@/views/reception/Bookings.vue'),
        meta: { title: '预订管理', icon: 'CalendarOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'room-availability',
        name: 'RoomAvailability',
        component: () => import('@/views/reception/RoomAvailability.vue'),
        meta: { title: '客房余量', icon: 'ApartmentOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'workorders',
        name: 'WorkOrders',
        component: () => import('@/views/reception/WorkOrders.vue'),
        meta: { title: '工单处理', icon: 'ToolOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'delivery',
        name: 'DeliveryOrders',
        component: () => import('@/views/reception/DeliveryOrders.vue'),
        meta: { title: '客房送物', icon: 'SendOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'voice-calls',
        name: 'VoiceCalls',
        component: () => import('@/views/reception/VoiceCalls.vue'),
        meta: { title: '语音通话', icon: 'PhoneOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'price-calendar',
        name: 'ReceptionPriceCalendar',
        component: () => import('@/views/admin/PriceCalendar.vue'),
        meta: { title: '价格日历', icon: 'CalendarOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'coupons',
        name: 'ReceptionCoupons',
        component: () => import('@/views/admin/CouponManage.vue'),
        meta: { title: '优惠券管理', icon: 'TagOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
      },
      {
        path: 'bills',
        name: 'Bills',
        component: () => import('@/views/reception/Bills.vue'),
        meta: { title: '账单报表', icon: 'DollarOutlined', requiresAuth: true, roles: ['admin', 'manager', 'staff'] }
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

// 白名单路由 (不需要认证)
const whiteList = ['/login']

router.beforeEach((to, from, next) => {
  const title = to.meta.title as string
  document.title = title ? `${title} - 智联酒店` : '智联酒店 - 智慧酒店物联网控制系统'

  // 检查是否需要认证 (使用 to.matched 检查嵌套路由)
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const token = localStorage.getItem('auth_token')
  const userInfoStr = localStorage.getItem('user_info')
  const userInfo = userInfoStr ? JSON.parse(userInfoStr) : null
  const normalizedRole = normalizeRole(userInfo?.role)

  // 如果不需要认证，直接放行
  if (!requiresAuth) {
    // 如果已登录且访问登录页，重定向到对应角色的首页
    if (to.path === '/login' && token && userInfo) {
      switch (normalizedRole) {
        case 'system':
          next('/system/dashboard')
          break
        case 'admin':
          next('/hotel-admin/dashboard')
          break
        case 'manager':
          next('/hotel-admin/dashboard')
          break
        case 'staff':
          next('/reception/dashboard')
          break
        case 'user':
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

  // 需要认证但未登录，重定向到首页并开启登录弹窗
  if (!token || !userInfo) {
    next({
      path: '/guest/booking',
      query: { login: '1', redirect: to.fullPath }
    })
    return
  }

  // 检查角色权限 (使用 to.matched 查找允许的角色)
  let allowedRoles: string[] = []
  to.matched.forEach(record => {
    if (record.meta.roles) {
      allowedRoles = allowedRoles.concat(record.meta.roles as string[])
    }
  })

  const normalizedAllowedRoles = allowedRoles.map((role) => normalizeRole(role))
  if (normalizedAllowedRoles.length > 0 && !normalizedAllowedRoles.includes(normalizedRole)) {
    // 角色权限不足，重定向到对应角色的首页
    switch (normalizedRole) {
      case 'system':
        next('/system/dashboard')
        break
      case 'admin':
      case 'manager':
        next('/hotel-admin/dashboard')
        break
      case 'staff':
        next('/reception/dashboard')
        break
      case 'user':
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
