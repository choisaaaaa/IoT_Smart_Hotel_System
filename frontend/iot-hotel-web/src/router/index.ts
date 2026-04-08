import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { title: '登录', requiresAuth: false }
  },
  {
    path: '/',
    redirect: '/guest/booking'
  },
  {
    path: '/admin',
    component: () => import('@/components/layout/AdminLayout.vue'),
    meta: { title: '管理端', icon: 'SettingOutlined', requiresAuth: true, roles: ['admin'] },
    children: [
      {
        path: '',
        redirect: '/admin/dashboard'
      },
      {
        path: 'dashboard',
        name: 'AdminDashboard',
        component: () => import('@/views/admin/Dashboard.vue'),
        meta: { title: '总览仪表盘', icon: 'DashboardOutlined', requiresAuth: true, roles: ['admin'] }
      },
      {
        path: 'devices',
        name: 'DeviceMonitor',
        component: () => import('@/views/admin/DeviceMonitor.vue'),
        meta: { title: '设备监控', icon: 'MonitorOutlined', requiresAuth: true, roles: ['admin'] }
      },
      {
        path: 'rooms/edit',
        name: 'RoomEdit',
        component: () => import('@/views/admin/RoomEdit.vue'),
        meta: { title: '房间信息管理', icon: 'HomeOutlined', requiresAuth: true, roles: ['admin'] }
      },
      {
        path: 'hotel/info',
        name: 'HotelInfoEdit',
        component: () => import('@/views/admin/HotelInfoEdit.vue'),
        meta: { title: '酒店信息编辑', icon: 'BankOutlined', requiresAuth: true, roles: ['admin'] }
      },
      {
        path: 'reports',
        name: 'AdminReports',
        component: () => import('@/views/admin/AdminReports.vue'),
        meta: { title: '账单报表', icon: 'FileTextOutlined', requiresAuth: true, roles: ['admin'] }
      }
    ]
  },
  {
    path: '/reception',
    component: () => import('@/components/layout/ReceptionLayout.vue'),
    meta: { title: '前台端', icon: 'CustomerServiceOutlined', requiresAuth: true, roles: ['admin', 'staff'] },
    children: [
      {
        path: '',
        redirect: '/reception/dashboard'
      },
      {
        path: 'dashboard',
        name: 'ReceptionDashboard',
        component: () => import('@/views/reception/Dashboard.vue'),
        meta: { title: '前台总览', icon: 'DashboardOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'checkinout',
        name: 'CheckInOut',
        component: () => import('@/views/reception/CheckInOut.vue'),
        meta: { title: '入住退房', icon: 'LoginOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'bookings',
        name: 'ReceptionBookings',
        component: () => import('@/views/reception/Bookings.vue'),
        meta: { title: '预订管理', icon: 'CalendarOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'room-availability',
        name: 'RoomAvailability',
        component: () => import('@/views/reception/RoomAvailability.vue'),
        meta: { title: '客房余量', icon: 'ApartmentOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'workorders',
        name: 'WorkOrders',
        component: () => import('@/views/reception/WorkOrders.vue'),
        meta: { title: '工单处理', icon: 'ToolOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'delivery',
        name: 'DeliveryOrders',
        component: () => import('@/views/reception/DeliveryOrders.vue'),
        meta: { title: '客房送物', id: 'SendOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
      },
      {
        path: 'bills',
        name: 'Bills',
        component: () => import('@/views/reception/Bills.vue'),
        meta: { title: '账单报表', icon: 'DollarOutlined', requiresAuth: true, roles: ['admin', 'staff'] }
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

  // 检查是否需要认证
  const requiresAuth = to.meta.requiresAuth === true
  const token = localStorage.getItem('auth_token')
  const userInfoStr = localStorage.getItem('user_info')
  const userInfo = userInfoStr ? JSON.parse(userInfoStr) : null

  // 如果不需要认证，直接放行
  if (!requiresAuth) {
    // 如果已登录且访问登录页，重定向到对应角色的首页
    if (to.path === '/login' && token && userInfo) {
      switch (userInfo.role) {
        case 'admin':
          next('/admin/dashboard')
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

  // 需要认证但未登录，重定向到登录页
  if (!token || !userInfo) {
    next({
      path: '/login',
      query: { redirect: to.fullPath }
    })
    return
  }

  // 检查角色权限
  const allowedRoles = to.meta.roles as string[] | undefined
  if (allowedRoles && !allowedRoles.includes(userInfo.role)) {
    // 角色权限不足，重定向到对应角色的首页
    switch (userInfo.role) {
      case 'admin':
        next('/admin/dashboard')
        break
      case 'staff':
        next('/reception/dashboard')
        break
      case 'user':
        next('/guest/booking')
        break
      default:
        next('/login')
    }
    return
  }

  next()
})

export default router