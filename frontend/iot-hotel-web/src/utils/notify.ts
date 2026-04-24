import { notification, type ArgsProps } from 'ant-design-vue'

type NotifyType = 'success' | 'error' | 'warning' | 'info'

interface NotifyOptions {
  title: string
  description?: string
  duration?: number
  key?: string
  placement?: ArgsProps['placement']
}

const CLASS_MAP: Record<NotifyType, string> = {
  success: 'hotel-notify-success',
  error: 'hotel-notify-error',
  warning: 'hotel-notify-warning',
  info: 'hotel-notify-info',
}

function notify(type: NotifyType, options: NotifyOptions) {
  notification[type]({
    message: options.title,
    description: options.description || '',
    class: `hotel-notify ${CLASS_MAP[type]}`,
    duration: options.duration ?? 4.5,
    key: options.key,
    placement: options.placement ?? 'topRight',
  })
}

export const $notify = {
  success(options: NotifyOptions) {
    notify('success', options)
  },
  error(options: NotifyOptions) {
    notify('error', options)
  },
  warning(options: NotifyOptions) {
    notify('warning', options)
  },
  info(options: NotifyOptions) {
    notify('info', options)
  },
  destroy(key?: string) {
    notification.destroy(key)
  },
}

export const NotifyPreset = {
  loginSuccess(username?: string) {
    $notify.success({
      title: '登录成功',
      description: username ? `欢迎回来，${username}！祝您入住愉快 🎉` : '欢迎回来！祝您入住愉快 🎉',
      duration: 4,
    })
  },
  loginError(reason?: string) {
    $notify.error({
      title: '登录失败',
      description: reason || '手机号或密码错误，请重新输入',
      duration: 5,
    })
  },
  accountLocked(minutes?: number) {
    $notify.error({
      title: '账户已被锁定',
      description: `由于多次登录失败，账户已被临时锁定${minutes ? ` ${minutes} 分钟` : ''}，请稍后再试 🔒`,
      duration: 6,
    })
  },
  registerSuccess() {
    $notify.success({
      title: '注册成功',
      description: '您的账户已创建成功，请使用手机号和密码登录 🎊',
      duration: 4,
    })
  },
  logout() {
    $notify.info({
      title: '已安全退出',
      description: '您已成功退出登录，期待您的下次光临 👋',
      duration: 3,
    })
  },
  checkinSuccess(guestName: string, roomNumber?: string) {
    $notify.success({
      title: '入住办理成功',
      description: roomNumber
        ? `${guestName} 已成功入住 ${roomNumber} 房间，祝您入住愉快 🏨`
        : `${guestName} 的预订已确认入住，祝您入住愉快 🏨`,
      duration: 5,
    })
  },
  checkinFailed(reason?: string) {
    $notify.error({
      title: '入住办理失败',
      description: reason || '办理入住时出现错误，请检查信息后重试',
      duration: 5,
    })
  },
  checkoutSuccess(guestName: string, roomNumber: string, amount?: number) {
    $notify.success({
      title: '退房办理成功',
      description: amount
        ? `${guestName}（${roomNumber}）已成功退房，应付金额 ¥${amount}，期待再次光临 ✨`
        : `${guestName}（${roomNumber}）已成功退房，期待再次光临 ✨`,
      duration: 5,
    })
  },
  checkoutFailed(reason?: string) {
    $notify.error({
      title: '退房办理失败',
      description: reason || '办理退房时出现错误，请稍后重试',
      duration: 5,
    })
  },
  bookingSuccess(deadline?: boolean) {
    $notify.success({
      title: '预订成功',
      description: deadline
        ? '预订已提交！请在15分钟内到店支付，超时订单将自动取消 ⏰'
        : '预订已提交成功！我们将为您保留房间 🎉',
      duration: 6,
    })
  },
  bookingFailed(reason?: string) {
    $notify.error({
      title: '预订失败',
      description: reason || '提交预订时出现错误，请稍后重试',
      duration: 5,
    })
  },
  balanceInsufficient(current: number, required: number) {
    $notify.warning({
      title: '余额不足',
      description: `当前余额 ¥${current.toFixed(2)}，需支付 ¥${required.toFixed(2)}，建议切换支付方式 💳`,
      duration: 6,
    })
  },
  paymentSuccess(amount: number, method?: string) {
    $notify.success({
      title: '支付成功',
      description: `已成功支付 ¥${amount.toFixed(2)}${method ? `（${method}）` : ''}，感谢您的消费 💰`,
      duration: 4,
    })
  },
  paymentFailed(reason?: string) {
    $notify.error({
      title: '支付失败',
      description: reason || '支付过程中出现错误，请检查余额或更换支付方式',
      duration: 5,
    })
  },
  rechargeSuccess(amount: number, credit?: number) {
    $notify.success({
      title: '充值成功',
      description: credit
        ? `充值 ¥${amount} 成功，实际到账 ¥${credit} 🎉`
        : `充值 ¥${amount} 成功 🎉`,
      duration: 4,
    })
  },
  passwordChanged() {
    $notify.success({
      title: '密码修改成功',
      description: '您的密码已更新，下次请使用新密码登录 🔐',
      duration: 4,
    })
  },
  profileUpdated(field?: string) {
    $notify.success({
      title: '更新成功',
      description: field ? `${field}已更新` : '个人信息已更新',
      duration: 3,
    })
  },
  avatarUpdated() {
    $notify.success({
      title: '头像更新成功',
      description: '您的新头像已生效 📷',
      duration: 3,
    })
  },
  operationFailed(reason?: string) {
    $notify.error({
      title: '操作失败',
      description: reason || '操作过程中出现错误，请稍后重试',
      duration: 5,
    })
  },
  networkError() {
    $notify.error({
      title: '网络异常',
      description: '网络连接不稳定，请检查网络后重试 🌐',
      duration: 5,
    })
  },
  permissionDenied(action?: string) {
    $notify.warning({
      title: '权限不足',
      description: action ? `您没有权限执行「${action}」操作` : '您没有权限执行此操作',
      duration: 4,
    })
  },
  couponIssued(name?: string) {
    $notify.success({
      title: '优惠券发放成功',
      description: name ? `「${name}」已成功发放至客户账户 🎫` : '优惠券已成功发放 🎫',
      duration: 4,
    })
  },
  checkinDaily(experience?: number) {
    $notify.success({
      title: '签到成功',
      description: experience ? `获得 ${experience} 成长值，继续加油！🌟` : '今日签到成功 🌟',
      duration: 3,
    })
  },
  alreadyCheckedIn() {
    $notify.info({
      title: '今日已签到',
      description: '明天再来哦，坚持签到获取更多成长值 💪',
      duration: 3,
    })
  },
  workOrderCreated(ticketNo?: string) {
    $notify.success({
      title: '工单已创建',
      description: ticketNo ? `工单编号 ${ticketNo}，我们会尽快处理 🔧` : '工单已提交，我们会尽快处理 🔧',
      duration: 4,
    })
  },
  deliveryCreated(orderNo?: string) {
    $notify.success({
      title: '送物订单已创建',
      description: orderNo ? `订单编号 ${orderNo}，工作人员将尽快送达 📦` : '送物订单已提交，工作人员将尽快送达 📦',
      duration: 4,
    })
  },
  broadcastSuccess(count: number) {
    $notify.success({
      title: '广播已下发',
      description: `已成功下发至 ${count} 个房间 📢`,
      duration: 4,
    })
  },
  qrCodeExpired() {
    $notify.warning({
      title: '二维码已过期',
      description: '请点击刷新按钮重新获取二维码 🔄',
      duration: 4,
    })
  },
  cardCreated(uid?: string) {
    $notify.success({
      title: '房卡制作成功',
      description: uid ? `房卡 UID: ${uid}，请将房卡交给客人 🗝️` : '房卡已制作完成，请将房卡交给客人 🗝️',
      duration: 4,
    })
  },
  cardDestroyed() {
    $notify.success({
      title: '房卡已收回',
      description: '房卡已成功销毁/收回 🗝️',
      duration: 3,
    })
  },
  managerAuthorized() {
    $notify.success({
      title: '经理授权成功',
      description: '您已获得高级操作权限，可进行手动打折等操作 👔',
      duration: 4,
    })
  },
  authorizationExpired() {
    $notify.error({
      title: '授权已过期',
      description: '经理授权已失效，请重新进行授权验证 ⏰',
      duration: 5,
    })
  },
  orderCancelled() {
    $notify.success({
      title: '订单已取消',
      description: '预订订单已成功取消，如需重新预订请再次操作',
      duration: 4,
    })
  },
  batchCheckoutSuccess(count: number) {
    $notify.success({
      title: '批量退房成功',
      description: `共 ${count} 间房已成功办理退房 ✨`,
      duration: 5,
    })
  },
  couponImported() {
    $notify.success({
      title: '优惠券导入成功',
      description: '优惠券已添加至您的账户，可在预订时使用 🎫',
      duration: 4,
    })
  },
  favoriteRemoved() {
    $notify.success({
      title: '已取消收藏',
      description: '该酒店已从收藏列表中移除',
      duration: 3,
    })
  },
  roomSelected(name: string) {
    $notify.info({
      title: '已选择入住人',
      description: `${name} 将作为本次入住人`,
      duration: 3,
    })
  },
  qrCodeGenerated() {
    $notify.success({
      title: '二维码已生成',
      description: '请使用慧宿智联APP扫描二维码登录 📱',
      duration: 3,
    })
  },
  qrLoginSuccess() {
    $notify.success({
      title: '扫码登录成功',
      description: '欢迎回来！祝您入住愉快 🎉',
      duration: 4,
    })
  },
}
