<template>
  <div class="reception-center">
    <div class="reception-header-logo">
      <div class="logo-wrapper">
        <div class="logo-icon">
          <img :src="getLogoUrl(hotelStore.hotelInfo?.logo)" alt="Logo" class="logo-img-header" />
        </div>
        <div class="header-divider"></div>
        <div class="hotel-info">
          <div class="hotel-name">
            <BankOutlined /> {{ hotelStore.hotelInfo?.hotel_name || '当前门店' }}
          </div>
          <div class="hotel-id">集团编号: {{ hotelStore.hotelInfo?.id || '-' }}</div>
        </div>
        <div class="header-divider"></div>
        <div class="user-info">
          <div class="user-name">
            <UserOutlined /> {{ appStore.userInfo?.username || '当前用户' }}
          </div>
          <div class="user-role">{{ appStore.userInfo?.role_name || appStore.userInfo?.role || '操作员' }}</div>
        </div>
        
        <div class="header-actions">
          <a-space>
            <a-select v-model:value="selectedDevice" placeholder="选择发卡/通信设备" style="width: 180px">
              <template #prefix><LaptopOutlined /></template>
              <a-select-option v-for="d in frontEndDevices" :key="d.device_id" :value="d.device_id">
                {{ d.device_name || d.device_id }}
              </a-select-option>
              <a-select-option v-if="frontEndDevices.length === 0" value="none" disabled>未发现可发卡设备</a-select-option>
            </a-select>
            <a-button @click="testCommunication" :loading="testing">
              <template #icon><ApiOutlined /></template>
              通信测试
            </a-button>
          </a-space>
          <a-button type="primary" @click="() => { inventoryModalVisible = true; fetchTodayInventory(); }">
            <template #icon><ShopOutlined /></template>
            今日可售余量管理
          </a-button>
        </div>
      </div>
    </div>
    <a-tabs v-model:activeKey="activeTab">
      <a-tab-pane key="checkin">
        <template #tab>
          <a-badge :count="todayBookings.length" :offset="[12, -4]" :show-zero="false">
            📥 入住办理
          </a-badge>
        </template>
        <a-row :gutter="16">
          <a-col :xs="24" :xl="15">
            <a-form :model="checkinForm" layout="vertical">
              <a-alert message="线下办理：请核验客人身份证件后录入信息" type="info" show-icon style="margin-bottom: 16px;" />
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="客人姓名" required>
                    <a-input v-model:value="checkinForm.guest_name" placeholder="请输入真实姓名" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="联系电话" required>
                    <div class="phone-input-wrapper">
                      <a-input v-model:value="checkinForm.phone" placeholder="手机号码" style="flex: 1;" />
                      <div class="member-status-info">
                        <a-tag v-if="getMemberByPhone(checkinForm.phone)" color="gold" style="margin: 0;">
                          {{ getLevelName(getMemberByPhone(checkinForm.phone)) }}
                        </a-tag>
                        <a-tag v-else-if="checkinForm.phone && checkinForm.phone.length >= 11" color="warning" style="margin: 0;">未注册</a-tag>
                      </div>
                    </div>
                  </a-form-item>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="证件类型">
                    <a-select v-model:value="checkinForm.id_type">
                      <a-select-option value="idcard">中国居民身份证/外国人永久居留身份证/港澳台居民居住证</a-select-option>
                      <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
                      <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
                      <a-select-option value="passport">外国护照</a-select-option>
                      <a-select-option value="other">其他</a-select-option>
                    </a-select>
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="证件号码">
                    <a-input v-model:value="checkinForm.id_number" placeholder="证件号码" />
                  </a-form-item>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="入住人数">
                    <a-input-number v-model:value="checkinForm.guest_count" :min="1" :max="8" style="width: 100%;" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="支付方式">
                    <a-select v-model:value="checkinForm.payment_method">
                      <a-select-option value="front_desk">前台收款（现金/刷卡/扫码）</a-select-option>
                      <a-select-option value="balance">会员余额支付</a-select-option>
                      <a-select-option value="alipay">支付宝</a-select-option>
                      <a-select-option value="wechat">微信支付</a-select-option>
                      <a-select-option value="credit_card">银行卡</a-select-option>
                      <a-select-option value="cash">现金</a-select-option>
                    </a-select>
                  </a-form-item>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="入住日期" required>
                    <a-date-picker v-model:value="checkinForm.check_in_date" style="width: 100%;" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="预计退房日期" required>
                    <a-date-picker v-model:value="checkinForm.check_out_date" style="width: 100%;" />
                  </a-form-item>
                </a-col>
              </a-row>
              <a-card size="small" class="selected-room-card">
                <div class="selected-room-header">
                  <span>{{ fillingBookingId ? (fillingBookingHasRoom ? '预订房间' : '请选择入住房间') : '已选空房' }}</span>
                  <a-tag v-if="selectedRoom" :color="fillingBookingId ? 'blue' : 'success'">{{ selectedRoom.room_number }}</a-tag>
                  <a-tag v-else color="warning">未选择</a-tag>
                </div>
                <div v-if="selectedRoom" class="selected-room-text">
                  {{ selectedRoom.room_name }} · ¥{{ selectedRoom.room_price }}/晚
                </div>
                <div v-else-if="fillingBookingId && !fillingBookingHasRoom" class="selected-room-text" style="color: #fa541c;">
                  该订单未分配具体房间，请从右侧选择对应房型的空房
                </div>
              </a-card>

              <a-divider orientation="left">费用与优惠</a-divider>

              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="使用优惠券">
                    <div style="display: flex; gap: 8px;">
                      <a-select
                        v-model:value="checkinForm.coupon_id"
                        placeholder="选择可用优惠券"
                        allow-clear
                        :loading="couponsLoading"
                        style="flex: 1;"
                        @change="updateEstimatedPrice"
                      >
                        <a-select-option v-for="c in userCoupons" :key="c.id" :value="c.id">
                          {{ c.coupon_name }} ({{ c.coupon_type === 'discount' ? c.discount_value + '折' : '减¥' + c.discount_value }})
                        </a-select-option>
                      </a-select>
                      <a-button type="primary" @click="showIssueCouponModal">
                        发放优惠券
                      </a-button>
                    </div>
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="现场打折 (需经理授权)">
                    <div style="display: flex; gap: 8px;">
                      <a-input-number
                        v-model:value="checkinForm.manual_discount"
                        :min="0.1" :max="1" :step="0.05"
                        style="width: 45%"
                        placeholder="折扣率"
                        :disabled="!isAuthorized"
                        @change="updateEstimatedPrice"
                      >
                        <template #addonBefore>折</template>
                      </a-input-number>
                      <a-input-number
                        v-model:value="checkinForm.manual_reduce"
                        :min="0"
                        style="width: 45%"
                        placeholder="立减"
                        :disabled="!isAuthorized"
                        @change="updateEstimatedPrice"
                      >
                        <template #addonBefore>减</template>
                      </a-input-number>
                      <a-button 
                        :type="isAuthorized ? 'default' : 'primary'" 
                        :danger="isAuthorized"
                        @click="openAuthorizeModal"
                      >
                        <template #icon><ControlOutlined /></template>
                        {{ isAuthorized ? '取消' : '授权' }}
                      </a-button>
                    </div>
                  </a-form-item>
                </a-col>
              </a-row>

              <a-form-item label="预估应付金额 (含折扣/优惠)" style="margin-top: 12px;">
                <div class="price-display">
                  <a-statistic :value="estimatedPrice" prefix="¥" :precision="2" :loading="priceLoading" />
                  <div class="price-detail" v-if="priceDetailText">
                    <a-tooltip :title="priceDetailText">
                      <InfoCircleOutlined /> 计价详情
                    </a-tooltip>
                  </div>
                </div>
              </a-form-item>
              <a-divider orientation="left">同住人</a-divider>
              <a-space direction="vertical" style="width: 100%;">
                <a-card v-for="(item, index) in companions" :key="index" size="small">
                  <a-row :gutter="12">
                    <a-col :span="6"><a-input v-model:value="item.name" placeholder="姓名" /></a-col>
                    <a-col :span="6"><a-input v-model:value="item.phone" placeholder="手机号" /></a-col>
                    <a-col :span="5">
                      <a-select v-model:value="item.id_type" style="width: 100%;">
                        <a-select-option value="idcard">身份证/永居证/居住证</a-select-option>
                        <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
                        <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
                        <a-select-option value="passport">外国护照</a-select-option>
                        <a-select-option value="other">其他</a-select-option>
                      </a-select>
                    </a-col>
                    <a-col :span="5"><a-input v-model:value="item.id_number" placeholder="证件号" /></a-col>
                    <a-col :span="2">
                      <a-button danger @click="removeCompanion(index)">
                        <DeleteOutlined />
                      </a-button>
                    </a-col>
                  </a-row>
                </a-card>
              </a-space>
              <a-button type="dashed" block style="margin-top: 8px;" @click="addCompanion">
                <PlusOutlined /> 添加同住人
              </a-button>
              <a-form-item label="备注" style="margin-top: 12px;">
                <a-textarea v-model:value="checkinForm.remark" :rows="2" placeholder="特殊要求等" />
              </a-form-item>
              <a-form-item>
                <a-space>
                  <a-button type="primary" size="large" @click="handleCheckIn" :loading="submitting">
                    <UserAddOutlined /> 确认入住
                  </a-button>
                  <a-button v-if="lastCreatedBookingId" type="primary" ghost size="large" @click="openCardModal('issue', { id: lastCreatedBookingId, room_number: selectedRoom?.room_number, guest_name: checkinForm.guest_name })">
                    <KeyOutlined /> 立即发卡
                  </a-button>
                  <a-button @click="resetCheckinForm">重置</a-button>
                </a-space>
              </a-form-item>
            </a-form>
          </a-col>
          <a-col :xs="24" :xl="9">
            <a-card size="small" title="空房清单">
              <template v-if="fillingBookingId && !fillingBookingHasRoom && fillingBookingRoomTypeId" #extra>
                <a-tag color="orange">按订单房型筛选</a-tag>
              </template>
              <a-input v-model:value="roomSearchKeyword" placeholder="搜索房号/房名" allow-clear />
              <div class="room-grid">
                <div
                  v-for="room in searchedRooms"
                  :key="room.id"
                  class="room-tile"
                  :class="{ active: checkinForm.room_id === room.id }"
                >
                  <div class="room-main" @click="chooseRoom(room)">
                    <div class="room-type-text">{{ room.room_name }}</div>
                    <div class="room-num-text">{{ room.room_number }}</div>
                  </div>
                  <a-button type="link" size="small" class="detail-link" @click.stop="showRoomDetail(room)">详情</a-button>
                </div>
              </div>
            </a-card>

    <!-- 房间详情弹窗 -->
    <a-modal v-model:open="roomDetailVisible" title="房间详情" :footer="null" width="400px">
      <div v-if="roomDetail" class="room-detail-modal-content">
        <a-descriptions :column="1" bordered size="small">
          <a-descriptions-item label="房号">{{ roomDetail.room_number }}</a-descriptions-item>
          <a-descriptions-item label="房型">{{ roomDetail.room_name }}</a-descriptions-item>
          <a-descriptions-item label="基准价格">¥{{ roomDetail.room_price }}/晚</a-descriptions-item>
          <a-descriptions-item label="面积">{{ roomDetail.area }}㎡</a-descriptions-item>
          <a-descriptions-item label="床型">{{ roomDetail.bed_type }}</a-descriptions-item>
          <a-descriptions-item label="最大入住">{{ roomDetail.max_guests }}人</a-descriptions-item>
          <a-descriptions-item label="设施">
            <a-tag v-for="f in roomDetail.facilities" :key="f" size="small">{{ f }}</a-tag>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-modal>
            <a-card size="small" style="margin-top: 12px;" :loading="todayBookingLoading">
              <template #title>
                <a-badge :count="todayBookings.length" :offset="[15, 0]" :show-zero="false">
                  今日预定清单
                </a-badge>
              </template>
              <a-space style="margin-bottom: 8px;">
                <a-button size="small" type="primary" @click="fetchTodayBookings">刷新</a-button>
                <a-button 
                  size="small" 
                  type="primary" 
                  :disabled="selectedBookingKeys.length === 0"
                  :class="{ 'disabled-primary-btn': selectedBookingKeys.length === 0 }"
                  @click="checkInSelectedBooking"
                >
                  办理选中预订
                </a-button>
              </a-space>
              <a-table
                :columns="todayBookingColumns"
                :data-source="todayBookings"
                :pagination="{ pageSize: 5 }"
                row-key="id"
                size="small"
                :row-selection="{ selectedRowKeys: selectedBookingKeys, onChange: onBookingSelectionChange }"
              >
                <template #bodyCell="{ column, record }">
                  <template v-if="column.key === 'nights'">
                    {{ record.stay_nights }}晚
                  </template>
                  <template v-if="column.dataIndex === 'room_number'">
                    <span v-if="record.room_number && record.room_number !== '-'">{{ record.room_number }}</span>
                    <a-tag v-else color="warning">待分配</a-tag>
                  </template>
                  <template v-if="column.dataIndex === 'room_type_name'">
                    <a-tag color="blue">{{ record.room_type_name }}</a-tag>
                  </template>
                  <template v-if="column.key === 'action'">
                    <a-button type="link" size="small" style="padding: 0;" @click="fillByBooking(record)">办理入住</a-button>
                  </template>
                </template>
              </a-table>
            </a-card>
          </a-col>
        </a-row>
      </a-tab-pane>

      <a-tab-pane key="checkout" tab="📤 在店人员信息">
        <div class="checkout-actions" style="margin-bottom: 16px;">
          <a-space>
            <a-popconfirm
              title="确定要对选中的房间进行批量退房吗？"
              :disabled="checkoutKeys.length === 0"
              @confirm="handleBatchCheckout"
            >
              <a-button type="primary" :disabled="checkoutKeys.length === 0">批量退房</a-button>
            </a-popconfirm>
            <a-button :disabled="checkoutKeys.length !== 1" @click="openCardModal('revoke')">
              <template #icon><CloseCircleOutlined /></template>
              收回房卡
            </a-button>
          </a-space>
        </div>
        <a-table
          :columns="checkoutColumns"
          :data-source="currentGuests"
          :row-selection="{ selectedRowKeys: checkoutKeys, onChange: onCheckoutSelectionChange }"
          :pagination="{ pageSize: 8 }"
          row-key="id"
          size="middle"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'amount'"><strong>¥{{ record.total_amount }}</strong></template>
            <template v-if="column.key === 'action'">
              <a-space>
                <a-popconfirm title="确认办理退房？" @confirm="handleCheckout(record)">
                  <a-button type="primary" size="small">办理退房</a-button>
                </a-popconfirm>
                <a-button type="link" size="small" @click="showIssueCouponModalForPhone(record.phone, record.guest_name)">发券</a-button>
                <a-dropdown>
                  <a-button type="link" size="small">
                    房卡 <DownOutlined />
                  </a-button>
                  <template #overlay>
                    <a-menu>
                      <a-menu-item key="issue" @click="openCardModal('issue', record)">
                        <template #icon><KeyOutlined /></template>
                        发放房卡
                      </a-menu-item>
                      <a-menu-item key="revoke" @click="openCardModal('revoke', record)">
                        <template #icon><CloseCircleOutlined /></template>
                        收回房卡
                      </a-menu-item>
                    </a-menu>
                  </template>
                </a-dropdown>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>

    <!-- 发放优惠券弹窗 -->
    <a-modal
      v-model:open="issueCouponModalVisible"
      title="发放优惠券"
      @ok="handleIssueCoupon"
      :confirmLoading="issuingCoupon"
      width="400px"
    >
      <a-form layout="vertical">
        <a-form-item label="选择优惠券" required>
          <a-select v-model:value="selectedIssueCouponId" placeholder="选择要发放的优惠券">
            <a-select-option v-for="c in allAvailableCoupons" :key="c.id" :value="c.id">
              {{ c.coupon_name }} ({{ c.coupon_type === 'discount' ? c.discount_value + '折' : '减¥' + c.discount_value }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-alert :message="`将发放给：${targetIssueName} (${targetIssuePhone})`" type="info" />
      </a-form>
    </a-modal>

    <!-- 经理授权弹窗 -->
    <a-modal
      v-model:open="authorizeModalVisible"
      title="经理权限授权"
      @ok="handleAuthorize"
      :confirmLoading="authorizing"
      width="400px"
    >
      <a-form layout="vertical">
        <a-form-item label="选择经理" required>
          <a-select v-model:value="authForm.manager_id" placeholder="选择当前门店经理">
            <a-select-option v-for="m in managers" :key="m.id" :value="m.id">
              {{ m.username }} ({{ m.phone || '无手机号' }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="授权密码" required>
          <a-input-password v-model:value="authForm.password" placeholder="请输入经理登录密码" />
        </a-form-item>
        <a-alert message="现场打折需要经理级别账号输入密码进行二次确认" type="info" show-icon />
      </a-form>
    </a-modal>

    <!-- 今日余量管理弹窗 -->
    <a-modal
      v-model:open="inventoryModalVisible"
      title="今日可售余量与挂牌价管理"
      @ok="handleUpdateInventory"
      :confirmLoading="updatingInventory"
      :ok-button-props="{ disabled: !['hotel_admin', 'system_admin', 'staff'].includes(appStore.userInfo?.role || '') }"
      width="800px"
    >
      <a-alert v-if="!['hotel_admin', 'system_admin', 'staff'].includes(appStore.userInfo?.role || '')" message="您的权限仅支持查看今日余量，无法进行修改。请联系门店经理进行调整。" type="info" show-icon style="margin-bottom: 16px;" />
      <a-alert v-else message="此处设置仅影响今日（或实时）各房型及方案的可售余量与挂牌价格。预订系统将根据此处设置进行库存校验与计费。" type="warning" show-icon style="margin-bottom: 16px;" />
      <a-table
        :columns="[
          { title: '房型', dataIndex: 'room_type_name', key: 'room_type_name', width: 120 },
          { title: '方案名称', dataIndex: 'plan_name', key: 'plan_name', width: 150 },
          { title: '今日挂牌价', key: 'price', width: 120 },
          { title: '今日余量', key: 'inventory', width: 120 },
          { title: '标准余量', key: 'default_inventory', width: 120 },
          { title: '已售', dataIndex: 'sold_count', key: 'sold_count', width: 80 }
        ]"
        :data-source="todayInventoryList"
        :loading="inventoryLoading"
        :pagination="false"
        size="small"
        :row-key="(record: any) => `${record.room_type_id}-${record.rate_plan_id || 'default'}`"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'price'">
            <a-input-number v-model:value="record.current_price" :min="0" :precision="2" prefix="¥" style="width: 100%" />
          </template>
          <template v-if="column.key === 'inventory'">
            <a-input-number v-model:value="record.inventory_count" :min="0" style="width: 100%" />
          </template>
          <template v-if="column.key === 'default_inventory'">
            <a-input-number v-model:value="record.default_inventory" :min="0" style="width: 100%" placeholder="默认值" />
          </template>
        </template>
      </a-table>
    </a-modal>

    <!-- 房卡管理弹窗 -->
    <a-modal
      v-model:open="cardModalVisible"
      :title="cardOpType === 'issue' ? '发放房卡' : '收回房卡'"
      @ok="handleCardOp"
      :confirmLoading="cardOpLoading"
      width="600px"
    >
      <div v-if="selectedGuestForCard" class="card-op-info">
        <a-row :gutter="24">
          <a-col :span="10">
            <a-descriptions :column="1" size="small" style="margin-bottom: 16px;" bordered>
              <a-descriptions-item label="房间号">{{ selectedGuestForCard.room_number }}</a-descriptions-item>
              <a-descriptions-item label="住客姓名">{{ selectedGuestForCard.guest_name }}</a-descriptions-item>
              <a-descriptions-item label="已发卡">{{ bookingCards.length }} 张</a-descriptions-item>
            </a-descriptions>

            <template v-if="cardOpType === 'issue'">
              <div class="verify-section">
                <div style="margin-bottom: 8px; font-weight: 500;">安全验证：</div>
                <a-input-password
                  v-model:value="idLastFour"
                  placeholder="证件号后四位"
                  :maxlength="4"
                  size="large"
                >
                  <template #prefix><SafetyCertificateOutlined /></template>
                </a-input-password>
                <div style="margin-top: 8px; color: #8c8c8c; font-size: 12px;">
                  * 请核对住客身份。支持多次发卡。
                </div>
              </div>
            </template>
            <template v-else>
              <div style="text-align: center; padding: 10px 0;">
                <p>请将房卡置于发卡器上执行注销。</p>
                <a-spin v-if="cardOpLoading" tip="正在通信..." />
              </div>
            </template>
          </a-col>
          
          <a-col :span="14">
            <div style="margin-bottom: 8px; font-weight: 500; display: flex; justify-content: space-between;">
              <span>当前已发房卡详情：</span>
              <a-button type="link" size="small" @click="fetchBookingCards(selectedGuestForCard.id)" :loading="cardsLoading">刷新</a-button>
            </div>
            <a-table
              :columns="[
                { title: 'UID', dataIndex: 'card_uid', key: 'uid', width: 120 },
                { title: '状态', dataIndex: 'status', key: 'status', width: 80 },
                { title: '发卡时间', dataIndex: 'issued_at', key: 'time' }
              ]"
              :data-source="bookingCards"
              size="small"
              :pagination="false"
              scroll="{ y: 200 }"
            >
              <template #bodyCell="{ column, record }">
                <template v-if="column.key === 'status'">
                  <a-tag :color="record.status === 'active' ? 'success' : 'default'">
                    {{ record.status === 'active' ? '有效' : '无效' }}
                  </a-tag>
                </template>
                <template v-if="column.key === 'time'">
                  {{ formatDotDateTime(record.issued_at) }}
                </template>
              </template>
            </a-table>
          </a-col>
        </a-row>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import request from '@/api/request'
import {
  UserAddOutlined,
  PlusOutlined,
  DeleteOutlined,
  CloseCircleOutlined,
  KeyOutlined,
  SafetyCertificateOutlined,
  DownOutlined,
  InfoCircleOutlined,
  ControlOutlined,
  ShopOutlined,
  BankOutlined,
  UserOutlined,
  LaptopOutlined,
  ApiOutlined
} from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { formatDotDateTime } from '@/utils/date'
import { useHotelStore } from '@/stores/hotel'
import { useAppStore } from '@/stores/app'
import { useNotificationStore } from '@/stores/notification'
import { bookingApi } from '@/api/booking'
import { deviceApi } from '@/api/device'
import { initWebSocket } from '@/utils/websocket'
import { useRoute } from 'vue-router'
import { memberApi } from '@/api/member'
import { userApi, type UserProfile } from '@/api/user'
import type { RoomInfo, DeviceInfo } from '@/types'

const hotelStore = useHotelStore()
const appStore = useAppStore()
const notificationStore = useNotificationStore()
const route = useRoute()
const activeTab = ref('checkin')
const submitting = ref(false)
const checkoutKeys = ref<number[]>([])
const currentGuests = ref<any[]>([])
const roomSearchKeyword = ref('')
const todayBookings = ref<any[]>([])
const selectedBookingKeys = ref<number[]>([])
const todayBookingLoading = ref(false)
const companions = ref<any[]>([])

// 设备选择与测试
const frontEndDevices = ref<DeviceInfo[]>([])
const selectedDevice = ref<string | undefined>(undefined)
const testing = ref(false)

async function fetchFrontEndDevices() {
  try {
    const res = await deviceApi.getDeviceList({ audit_status: 'approved' })
    if (res.data) {
      // 发卡/通信：前台 front_desk，或统一固件客房主控 room / room_terminal（后端 room-card 已支持）
      const list = res.data.filter(d =>
        d.device_type === 'front_desk' ||
        d.device_type === 'room' ||
        d.device_type === 'room_terminal' ||
        (d.device_id && d.device_id.startsWith('FRN_'))
      )
      frontEndDevices.value = list
      if (list.length > 0 && !selectedDevice.value) {
        selectedDevice.value = list[0].device_id
      }
    }
  } catch (error) {
    console.error('获取前台设备失败:', error)
  }
}

const getLogoUrl = (url?: string) => {
  return appStore.resolveImageUrl(url) || '/logo-small.png'
}

async function testCommunication() {
  if (!selectedDevice.value) {
    return $notify.warning({ title: '请选择设备', description: '请先选择一台发卡设备（前台或客房终端）' })
  }
  testing.value = true
  try {
    await deviceApi.testBeep(selectedDevice.value)
    $notify.success({ title: '测试指令已发送', description: '请检查前台设备蜂鸣器是否响应 🔔' })
  } catch (error) {
    $notify.error({ title: '通信测试失败', description: '请检查设备连接是否正常' })
  } finally {
    testing.value = false
  }
}

// 经理授权相关
const isAuthorized = ref(false)
const authorizeModalVisible = ref(false)
const authorizing = ref(false)
const managers = ref<UserProfile[]>([])
const authForm = reactive({
  manager_id: undefined as number | undefined,
  password: ''
})

// 今日余量管理相关
const inventoryModalVisible = ref(false)
const inventoryLoading = ref(false)
const updatingInventory = ref(false)
const todayInventoryList = ref<any[]>([])

async function fetchTodayInventory() {
  inventoryLoading.value = true
  try {
    const res: any = await request.get('/price-calendar/today')
    todayInventoryList.value = res.data || []
  } catch (error) {
    $notify.error({ title: '获取失败', description: '获取今日余量数据失败，请稍后重试' })
  } finally {
    inventoryLoading.value = false
  }
}

async function handleUpdateInventory() {
  updatingInventory.value = true
  try {
    const updates = todayInventoryList.value.map(item => ({
      room_type_id: item.room_type_id,
      rate_plan_id: item.rate_plan_id,
      price: item.current_price,
      inventory: item.inventory_count,
      default_inventory: item.default_inventory
    }))
    await request.post('/price-calendar/today/update', { updates })
    NotifyPreset.profileUpdated('余量数据')
    inventoryModalVisible.value = false
  } catch (error) {
    NotifyPreset.operationFailed('余量更新失败')
  } finally {
    updatingInventory.value = false
  }
}

async function fetchManagers() {
  try {
    const res: any = await userApi.getUserList({ 
      role: 'hotel_admin', 
      hotel_id: hotelStore.hotelInfo?.id,
      pageSize: 100 
    })
    managers.value = res.data?.users || []
  } catch (error) {
    console.error('获取经理列表失败:', error)
  }
}

function openAuthorizeModal() {
  if (isAuthorized.value) {
    isAuthorized.value = false
    checkinForm.manual_discount = 1.0
    checkinForm.manual_reduce = 0
    updateEstimatedPrice()
    $notify.info({ title: '授权已解除', description: '手动折扣已重置' })
    return
  }
  
  authForm.manager_id = undefined
  authForm.password = ''
  fetchManagers()
  authorizeModalVisible.value = true
}

async function handleAuthorize() {
  if (!authForm.manager_id || !authForm.password) {
    return $notify.warning({ title: '信息不完整', description: '请选择经理并输入密码' })
  }

  try {
    authorizing.value = true
    await userApi.authorizeManager({
      manager_id: authForm.manager_id,
      password: authForm.password
    })
    isAuthorized.value = true
    authorizeModalVisible.value = false
    NotifyPreset.managerAuthorized()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '经理授权失败')
  } finally {
    authorizing.value = false
  }
}

// 房间详情
const roomDetailVisible = ref(false)
const roomDetail = ref<RoomInfo | null>(null)

// 房卡管理
const cardModalVisible = ref(false)
const cardOpLoading = ref(false)
const cardOpType = ref<'issue' | 'revoke'>('issue')
const selectedGuestForCard = ref<any>(null)
const idLastFour = ref('')
const bookingCards = ref<any[]>([])
const cardsLoading = ref(false)

async function fetchBookingCards(bookingId: number) {
  if (!bookingId) return
  cardsLoading.value = true
  try {
    const res = await deviceApi.getBookingCards(bookingId)
    if (res.data) {
      bookingCards.value = res.data
    }
  } catch (error) {
    console.error('获取房卡列表失败:', error)
  } finally {
    cardsLoading.value = false
  }
}

function openCardModal(type: 'issue' | 'revoke', record?: any) {
  if (record) {
    selectedGuestForCard.value = record
  } else if (checkoutKeys.value.length === 1) {
    selectedGuestForCard.value = currentGuests.value.find(g => g.id === checkoutKeys.value[0])
  }

  if (!selectedGuestForCard.value) return

  cardOpType.value = type
  idLastFour.value = ''
  bookingCards.value = []
  fetchBookingCards(selectedGuestForCard.value.id)
  cardModalVisible.value = true
}

async function handleCardOp() {
  if (cardOpType.value === 'issue' && !idLastFour.value) {
    return $notify.warning({ title: '信息不完整', description: '请输入证件后四位进行验证' })
  }

  try {
    cardOpLoading.value = true
    const res: any = await request.post('/devices/room-card', {
      action: cardOpType.value,
      booking_id: selectedGuestForCard.value.id,
      id_last_four: idLastFour.value,
      ...(selectedDevice.value && selectedDevice.value !== 'none'
        ? { device_id: selectedDevice.value }
        : {})
    })

    // request 拦截器已解包为业务体；/devices/room-card 返回 { success, message, data }（非嵌套在 data 里）
    if (res.success) {
      $notify.info({ title: cardOpType.value === 'issue' ? '正在制卡' : '正在注销', description: cardOpType.value === 'issue' ? '请在设备上放置卡片...' : '正在注销房卡，请稍候...', key: 'card_op', duration: 0 })
      // 不立即关闭弹窗，等待 WebSocket 反馈或手动刷新
    } else {
      NotifyPreset.operationFailed(res.message || '发卡失败')
    }
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || error.message || '设备通信失败')
  } finally {
    cardOpLoading.value = false
  }
}

function showRoomDetail(room: RoomInfo) {
  roomDetail.value = room
  roomDetailVisible.value = true
}

const checkinForm = reactive({
  guest_name: '', phone: '', id_type: 'idcard', id_number: '',
  room_id: undefined as number | undefined, guest_count: 1,
  check_in_date: dayjs(), check_out_date: dayjs().add(2, 'day'),
  payment_method: 'front_desk', remark: '',
  coupon_id: undefined as number | undefined,
  manual_discount: 1.0,
  manual_reduce: 0
})

const userCoupons = ref<any[]>([])
const couponsLoading = ref(false)
const priceDetailText = ref('')

// 优惠券发放
const issueCouponModalVisible = ref(false)
const issuingCoupon = ref(false)
const allAvailableCoupons = ref<any[]>([])
const selectedIssueCouponId = ref<number | undefined>(undefined)
const targetIssuePhone = ref('')
const targetIssueName = ref('')

async function showIssueCouponModal() {
  if (!checkinForm.phone || checkinForm.phone.length < 11) {
    return $notify.warning({ title: '信息不完整', description: '请先输入完整的客人手机号' })
  }
  showIssueCouponModalForPhone(checkinForm.phone, checkinForm.guest_name)
}

async function showIssueCouponModalForPhone(phone: string, name: string) {
  if (!phone || phone.length < 11) {
    return $notify.warning({ title: '格式错误', description: '手机号格式不正确，请检查后重新输入' })
  }
  targetIssuePhone.value = phone
  targetIssueName.value = name || '客人'

  try {
    const res: any = await request.get('/coupons')
    allAvailableCoupons.value = res.data.list || []
    issueCouponModalVisible.value = true
  } catch (error) {
    NotifyPreset.operationFailed('获取优惠券列表失败')
  }
}

async function handleIssueCoupon() {
  if (!selectedIssueCouponId.value) return $notify.warning({ title: '请选择优惠券', description: '请先选择一张优惠券再发放' })

  try {
    issuingCoupon.value = true
    await request.post('/coupons/issue-to-user', {
      coupon_id: selectedIssueCouponId.value,
      phone: targetIssuePhone.value
    })
    NotifyPreset.couponIssued()
    issueCouponModalVisible.value = false
    if (targetIssuePhone.value === checkinForm.phone) {
      fetchUserCoupons(checkinForm.phone) // 刷新当前客人的可用优惠券
    }
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '优惠券发放失败')
  } finally {
    issuingCoupon.value = false
  }
}

async function fetchUserCoupons(phone: string) {
  if (!phone || phone.length < 11) {
    userCoupons.value = []
    return
  }
  try {
    couponsLoading.value = true
    const res: any = await request.get('/coupons/me', { params: { phone } })
    userCoupons.value = res.data || []
  } catch (error) {
    console.error('获取用户优惠券失败:', error)
  } finally {
    couponsLoading.value = false
  }
}

watch(() => checkinForm.phone, (newVal) => {
  if (newVal && newVal.length === 11) {
    fetchUserCoupons(newVal)
  }
})

const availableRooms = computed(() => hotelStore.getAvailableRooms())
const searchedRooms = computed(() => {
  let rooms = availableRooms.value
  if (fillingBookingId.value && !fillingBookingHasRoom.value && fillingBookingRoomTypeId.value) {
    rooms = rooms.filter(room => Number(room.room_type_id) === Number(fillingBookingRoomTypeId.value))
  }
  const keyword = roomSearchKeyword.value.trim().toLowerCase()
  if (!keyword) return rooms
  return rooms.filter(room =>
    String(room.room_number).toLowerCase().includes(keyword) ||
    String(room.room_name).toLowerCase().includes(keyword)
  )
})
const selectedRoom = computed(() => {
  if (!checkinForm.room_id) return null;

  const fromAvailable = availableRooms.value.find(room => room.id === checkinForm.room_id);
  if (fromAvailable) return fromAvailable;

  const fromAllRooms = hotelStore.rooms.find(room => room.id === checkinForm.room_id);
  if (fromAllRooms) return fromAllRooms;

  if (fillingBookingId.value) {
    const booking = todayBookings.value.find(b => b.id === fillingBookingId.value);
    if (booking && booking.room_id) {
      return {
        id: booking.room_id,
        room_number: booking.room_number,
        room_name: booking.room_name || booking.room_type,
        room_price: booking.total_price / (dayjs(booking.check_out_date).diff(dayjs(booking.check_in_date), 'day') || 1)
      };
    }
  }

  return null;
})
const phoneRegistered = computed(() => isPhoneRegistered(checkinForm.phone))

const estimatedPrice = ref(0)
const priceLoading = ref(false)

async function updateEstimatedPrice() {
  if (!checkinForm.room_id || !checkinForm.check_in_date || !checkinForm.check_out_date) {
    estimatedPrice.value = 0
    return
  }

  try {
    priceLoading.value = true
    const res: any = await bookingApi.getCalculatedPrice({
      room_id: checkinForm.room_id,
      check_in_date: checkinForm.check_in_date.format('YYYY-MM-DD'),
      check_out_date: checkinForm.check_out_date.format('YYYY-MM-DD'),
      guest_phone: checkinForm.phone || undefined,
      coupon_id: checkinForm.coupon_id,
      manual_discount: checkinForm.manual_discount < 1 ? checkinForm.manual_discount : undefined,
      manual_reduce: checkinForm.manual_reduce > 0 ? checkinForm.manual_reduce : undefined
    })

    let price = res.data?.total_price || 0
    let detail = `计价详情: ¥${price.toFixed(2)}`

    estimatedPrice.value = price
    priceDetailText.value = detail
  } catch (error) {
    console.error('计算预估价失败:', error)
  } finally {
    priceLoading.value = false
  }
}

watch(() => [
  checkinForm.room_id, 
  checkinForm.check_in_date, 
  checkinForm.check_out_date, 
  checkinForm.phone,
  checkinForm.coupon_id,
  checkinForm.manual_discount,
  checkinForm.manual_reduce
], () => {
  updateEstimatedPrice()
})

const checkoutColumns = [
  { title: '客人', dataIndex: 'guest_name', width: 100 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '入住天数', dataIndex: 'stay_nights', width: 90 },
  { title: '应付金额', dataIndex: 'total_amount', key: 'amount', width: 120 },
  { title: '操作', key: 'action', width: 120 }
]

const todayBookingColumns = [
  { title: '姓名', dataIndex: 'guest_name', width: 80 },
  { title: '手机号', dataIndex: 'guest_phone', width: 110 },
  { title: '房间', dataIndex: 'room_number', width: 80 },
  { title: '房型', dataIndex: 'room_type_name', width: 80 },
  { title: '夜数', key: 'nights', width: 60 },
  { title: '操作', key: 'action', width: 70 }
]

function bookingStatusText(s: string): string {
  return ({ pending: '待确认', confirmed: '已确认', pre_checked_in: '预入住', checked_in: '已入住', checked_out: '已退房', cancelled: '已取消' } as Record<string, string>)[s] || s
}

function bookingStatusColor(s: string): string {
  return ({ pending: 'warning', confirmed: 'processing', pre_checked_in: 'cyan', checked_in: 'success', checked_out: 'default', cancelled: 'error' } as Record<string, string>)[s] || 'default'
}

function normalizePhone(phone: string): string {
  return String(phone || '').replace(/\D/g, '')
}

const memberList = ref<any[]>([])

function getMemberByPhone(phone: string): any {
  const key = normalizePhone(phone)
  if (!key) return null
  return memberList.value.find(m => normalizePhone(m.phone) === key)
}

function getLevelName(member: any): string {
  if (!member) return '已注册'
  
  // 优先使用后端返回的标签
  if (member.level_label) return member.level_label
  
  const levels: Record<string, string> = {
    'diamond': '钻石会员',
    'platinum': '铂金会员',
    'gold': '金会员',
    'silver': '银会员',
    'standard': '普通会员'
  }
  
  // 以关键字 member_level 为准进行映射
  if (member.member_level && levels[member.member_level]) {
    return levels[member.member_level]
  }
  
  // 兜底显示数字等级
  return member.level ? `LEVEL ${member.level}` : '已注册'
}

function isPhoneRegistered(phone: string): boolean {
  return !!getMemberByPhone(phone)
}

function addCompanion() {
  companions.value.push({ name: '', phone: '', id_type: 'idcard', id_number: '' })
}

function removeCompanion(index: number) {
  companions.value.splice(index, 1)
}

function chooseRoom(room: RoomInfo) {
  checkinForm.room_id = room.id
}

function onBookingSelectionChange(keys: (string | number)[]) {
  selectedBookingKeys.value = keys as number[]
}

function onCheckoutSelectionChange(keys: (string | number)[]) {
  checkoutKeys.value = keys as number[]
}

async function fetchCurrentGuests() {
  try {
    const res: any = await bookingApi.getBookingList({ status: 'checked_in' })
    currentGuests.value = (res.data?.list || []).map((b: any) => {
      const nights = dayjs().diff(dayjs(b.check_in_date), 'day') || 1
      return {
        ...b,
        stay_nights: nights,
        total_amount: b.total_price
      }
    })
  } catch (error) {
    NotifyPreset.operationFailed('获取在住客人列表失败')
  }
}

async function fetchMemberList() {
  try {
    const res: any = await memberApi.getMemberList({ pageSize: 1000 })
    memberList.value = res.data?.list || []
  } catch (error) {
    memberList.value = []
  }
}

async function fetchTodayBookings(force = false) {
  if (todayBookingLoading.value && !force) return
  todayBookingLoading.value = true
  try {
    const res: any = await bookingApi.getBookingList({
      pageSize: 200
    } as any)
    const allList = res.data?.list || []
    console.log('[今日预定清单] 原始数据:', allList.length, '条')

    const today = dayjs().format('YYYY-MM-DD')
    const list = allList.filter((item: any) => {
      const isTodayCheckin = dayjs(item.check_in_date).isSame(today, 'day')
      const isTodayCheckout = dayjs(item.check_out_date).isSame(today, 'day')
      const isPendingCheckin = ['pending', 'confirmed', 'pre_checked_in'].includes(item.status) && isTodayCheckin
      return isPendingCheckin
    })
    console.log('[今日预定清单] 过滤后:', list.length, '条, 状态分布:',
      allList.reduce((acc: any, item: any) => {
        acc[item.status] = (acc[item.status] || 0) + 1
        return acc
      }, {})
    )

    todayBookings.value = list.map((item: any) => {
      const nights = dayjs(item.check_out_date).diff(dayjs(item.check_in_date), 'day') || 1
      return {
        ...item,
        stay_nights: nights,
        room_number: item.room_number || '-',
        room_type_name: item.room_type_name || item.room_type || '-',
        phone_registered: isPhoneRegistered(item.guest_phone)
      }
    })
  } catch (error) {
    NotifyPreset.operationFailed('获取今日预订列表失败')
  } finally {
    todayBookingLoading.value = false
  }
}

function fillByBooking(booking: any) {
  activeTab.value = 'checkin'
  fillingBookingId.value = booking.id
  fillingBookingRoomTypeId.value = booking.room_type_id || null
  fillingBookingHasRoom.value = !!booking.room_id
  checkinForm.guest_name = booking.guest_name || ''
  checkinForm.phone = booking.guest_phone || ''
  checkinForm.id_type = booking.id_type || 'idcard'
  checkinForm.id_number = booking.guest_id_number || ''
  checkinForm.guest_count = Number(booking.guest_count || 1)
  if (booking.check_in_date) checkinForm.check_in_date = dayjs(booking.check_in_date)
  if (booking.check_out_date) checkinForm.check_out_date = dayjs(booking.check_out_date)
  if (booking.payment_method) checkinForm.payment_method = booking.payment_method
  
  isAuthorized.value = false
  checkinForm.manual_discount = 1.0
  checkinForm.manual_reduce = 0
  
  companions.value = []
  
  if (booking.room_id) {
    checkinForm.room_id = booking.room_id
    const roomInList = availableRooms.value.find(item => item.id === booking.room_id)
    if (!roomInList) {
      console.log('预订房间不在空房列表中，强制回填房号:', booking.room_number)
    }
  } else {
    checkinForm.room_id = undefined
  }
}

function checkInSelectedBooking() {
  const targetId = selectedBookingKeys.value[0]
  if (!targetId) return
  const booking = todayBookings.value.find(item => Number(item.id) === Number(targetId))
  if (!booking) {
    $notify.warning({ title: '未找到记录', description: '未找到选中的预订记录，请重新选择' })
    return
  }
  fillByBooking(booking)
}

const lastCreatedBookingId = ref<number | null>(null)
const fillingBookingId = ref<number | null>(null)
const fillingBookingRoomTypeId = ref<number | null>(null)
const fillingBookingHasRoom = ref(false)

async function handleCheckIn() {
  if (submitting.value) {
    $notify.warning({ title: '请稍候', description: '正在办理入住中，请勿重复点击' })
    return
  }
  
  if (!checkinForm.guest_name || !checkinForm.phone) {
    $notify.warning({ title: '信息不完整', description: '请填写客人姓名和联系电话' }); return
  }
  if (fillingBookingId.value && !fillingBookingHasRoom.value && !checkinForm.room_id) {
    $notify.warning({ title: '请选择房间', description: '该订单未分配房间，请从右侧选择一间对应房型的空房' }); return
  }
  if (checkinForm.id_number) {
    if (checkinForm.id_type === 'idcard') {
      const idNumber = checkinForm.id_number.trim()
      if (idNumber.length !== 18 || !/^\d{17}[\dXx]$/.test(idNumber)) {
        $notify.warning({ title: '证件格式错误', description: '请填写正确的18位身份证号码' }); return
      }
    } else if (checkinForm.id_number.trim().length < 5) {
      $notify.warning({ title: '证件格式错误', description: '证件号码至少5位' }); return
    }
  }
  if (!hotelStore.hotelInfo?.id) {
    $notify.warning({ title: '数据异常', description: '未获取到门店信息，请刷新页面重试' }); return
  }

  submitting.value = true
  try {
    let existingBookingId: number | null = fillingBookingId.value
    
    if (!existingBookingId) {
      try {
        const lookupRes: any = await bookingApi.lookupBooking(checkinForm.phone)
        if (lookupRes.data && ['pending', 'confirmed', 'pre_checked_in'].includes(lookupRes.data.status)) {
          existingBookingId = lookupRes.data.id
          console.log('找到顾客匹配的预订:', existingBookingId, '状态:', lookupRes.data.status)
        }
      } catch (e) {
        console.log('查找预订失败:', e)
      }
    }

    let res: any
    if (existingBookingId) {
      const checkinData: any = {
        guest_name: checkinForm.guest_name,
        guest_phone: checkinForm.phone,
        guest_id_number: checkinForm.id_number,
        manual_discount: checkinForm.manual_discount < 1 ? checkinForm.manual_discount : undefined,
        manual_reduce: checkinForm.manual_reduce > 0 ? checkinForm.manual_reduce : undefined,
        total_price: estimatedPrice.value
      }
      if (checkinForm.room_id) {
        checkinData.room_id = checkinForm.room_id
      }
      res = await bookingApi.checkin(existingBookingId, checkinData)
      NotifyPreset.checkinSuccess(checkinForm.guest_name)
    } else {
      if (!checkinForm.room_id) {
        $notify.warning({ title: '请选择房间', description: '请从右侧选择一间空房' }); 
        submitting.value = false
        return
      }
      const payload: any = {
        ...checkinForm,
        hotel_id: hotelStore.hotelInfo.id,
        check_in_date: checkinForm.check_in_date.format('YYYY-MM-DD'),
        check_out_date: checkinForm.check_out_date.format('YYYY-MM-DD'),
        status: 'checked_in',
        guest_phone: checkinForm.phone,
        total_price: estimatedPrice.value,
        companions: companions.value.filter(item => item.name || item.phone || item.id_number)
      }
      res = await bookingApi.createBooking(payload)
      NotifyPreset.checkinSuccess(checkinForm.guest_name, selectedRoom.value?.room_number)
    }

    lastCreatedBookingId.value = res.data?.id || existingBookingId
    
    // 自动打开对应房号的发卡弹窗
    openCardModal('issue', {
      id: res.data?.id || existingBookingId,
      room_number: selectedRoom.value?.room_number,
      guest_name: checkinForm.guest_name
    })

    await Promise.all([
      fetchCurrentGuests(),
      fetchTodayBookings(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
    
    // 强制刷新今日预定清单，确保已入住的订单从列表中移除
    setTimeout(() => {
      fetchTodayBookings()
    }, 500)
    
    // 入住成功后重置表单，防止重复提交
    resetCheckinForm()
    
  } catch (error: any) {
    console.error('办理入住失败:', error)
    NotifyPreset.checkinFailed(error?.response?.data?.message)
  } finally {
    submitting.value = false
  }
}

function resetCheckinForm() {
  fillingBookingId.value = null
  fillingBookingRoomTypeId.value = null
  fillingBookingHasRoom.value = false
  checkinForm.guest_name = ''
  checkinForm.phone = ''
  checkinForm.id_type = 'idcard'
  checkinForm.id_number = ''
  checkinForm.guest_count = 1
  checkinForm.room_id = undefined
  checkinForm.check_in_date = dayjs()
  checkinForm.check_out_date = dayjs().add(1, 'day')
  checkinForm.payment_method = 'front_desk'
  checkinForm.remark = ''
  checkinForm.manual_discount = 1
  checkinForm.manual_reduce = 0
  isAuthorized.value = false
  companions.value = []
  // selectedRoom 是计算属性，通过设置 room_id 为 undefined 来重置
  estimatedPrice.value = 0
}

async function handleCheckout(record: any) {
  try {
    await bookingApi.updateBookingStatus(record.id, 'checked_out')
    NotifyPreset.checkoutSuccess(record.guest_name, record.room_number, record.total_amount)
    await Promise.all([
      fetchCurrentGuests(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
  } catch (error) {
    NotifyPreset.checkoutFailed()
  }
}

async function handleBatchCheckout() {
  if (checkoutKeys.value.length === 0) return
  try {
    await Promise.all(
      checkoutKeys.value.map(id => bookingApi.updateBookingStatus(id, 'checked_out'))
    )
    NotifyPreset.batchCheckoutSuccess(checkoutKeys.value.length)
    checkoutKeys.value = []
    await Promise.all([
      fetchCurrentGuests(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
  } catch (error) {
    NotifyPreset.operationFailed('批量退房失败，请稍后重试')
  }
}

async function fillByBookingId() {
  const bookingId = Number(route.query.booking_id || 0)
  if (!bookingId) return
  try {
    const res: any = await bookingApi.getBookingList({ pageSize: 200 })
    const booking = (res.data?.list || []).find((item: any) => Number(item.id) === bookingId)
    if (booking) fillByBooking(booking)
  } catch (error) {
    NotifyPreset.operationFailed('预订信息回填失败')
  }
}

onMounted(async () => {
  fetchFrontEndDevices()
  
  // 初始化 WebSocket 监听发卡反馈
  const socket = initWebSocket()
  socket.on('security_event', (event: any) => {
    if (event.event_type === 'card_issued') {
      NotifyPreset.cardCreated(event.data?.card_uid)
      if (selectedGuestForCard.value) {
        fetchBookingCards(selectedGuestForCard.value.id)
      }
    } else if (event.event_type === 'card_revoked') {
      NotifyPreset.cardDestroyed()
      if (selectedGuestForCard.value) {
        fetchBookingCards(selectedGuestForCard.value.id)
      }
    }
  })

  try {
    await Promise.allSettled([
      hotelStore.fetchHotelInfo(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
  } catch (error) {}
  await Promise.allSettled([
    fetchMemberList(),
    fetchCurrentGuests(),
    fetchTodayBookings(),
    fillByBookingId()
  ])
})
</script>

<style scoped>
.room-grid {
  margin-top: 12px;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 12px;
  max-height: 400px;
  overflow-y: auto;
  padding: 4px;
}
.room-tile {
  border: 1px solid #f0f0f0;
  border-radius: 10px;
  padding: 0;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.645, 0.045, 0.355, 1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #fff;
  min-height: 100px;
}
.room-tile:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
  transform: translateY(-2px);
}
.room-tile.active {
  border-color: #1890ff;
  background: #e6f7ff;
  box-shadow: 0 2px 8px rgba(24, 144, 255, 0.2);
}
.room-tile.active .room-type-text {
  color: #1890ff;
}
.room-main {
  padding: 12px 8px;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.room-type-text {
  font-size: 14px;
  font-weight: 700;
  color: rgba(0, 0, 0, 0.85);
  margin-bottom: 4px;
  width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.room-num-text {
  font-size: 16px;
  font-family: 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  color: rgba(0, 0, 0, 0.65);
  font-weight: 500;
}
.detail-link {
  font-size: 12px;
  height: 28px;
  line-height: 28px;
  padding: 0;
  border-top: 1px solid #f0f0f0;
  width: 100%;
  background: #fafafa;
  color: #8c8c8c;
}
.detail-link:hover {
  background: #f0f0f0;
  color: #1890ff;
}
.room-tile.active .detail-link {
  border-top-color: #91d5ff;
  background: #bae7ff;
  color: #0050b3;
}
.room-detail-modal-content {
  padding: 8px 0;
}

.card-op-info {
  padding: 8px;
}

.verify-section {
  background: #fffbe6;
  border: 1px solid #ffe58f;
  padding: 16px;
  border-radius: 8px;
}

.checkout-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.reception-center {
  padding: 0;
}

.reception-header-logo {
  background: #fff;
  padding: 32px;
  margin-bottom: 20px;
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.04);
}

.logo-wrapper {
  display: flex;
  align-items: center;
  width: 100%;
  min-height: 72px;
  padding: 0 24px;
  gap: 24px;
}

.header-actions {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 16px;
}

.logo-icon {
  background: linear-gradient(135deg, #1890ff, #0050b3);
  color: #fff;
  font-size: 22px;
  font-weight: 900;
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  letter-spacing: 1px;
  overflow: hidden;
  position: relative;
  box-shadow: 0 6px 16px rgba(24, 144, 255, 0.25);
}

.logo-fallback {
  font-family: 'Arial Black', Gadget, sans-serif;
  text-shadow: 0 2px 4px rgba(0,0,0,0.2);
}

.logo-img-header {
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 4px;
}

.logo-fallback {
  position: absolute;
  z-index: 0;
}

.header-divider {
  width: 1px;
  height: 48px;
  background: #f0f0f0;
  margin: 0 24px;
}

.hotel-info {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.hotel-name {
  font-size: 18px;
  font-weight: 600;
  color: #1a1a1a;
  display: flex;
  align-items: center;
  gap: 8px;
}

.hotel-id {
  font-size: 13px;
  color: #8c8c8c;
  background: #f5f5f5;
  padding: 2px 8px;
  border-radius: 4px;
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.user-name {
  font-size: 16px;
  font-weight: 500;
  color: #1a1a1a;
  display: flex;
  align-items: center;
  gap: 8px;
}

.user-role {
  font-size: 12px;
  color: #1890ff;
  background: #e6f7ff;
  padding: 1px 8px;
  border-radius: 4px;
  width: fit-content;
}

.room-grid {
  margin-top: 12px;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 12px;
  max-height: 400px;
  overflow-y: auto;
  padding: 4px;
}
.selected-room-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.selected-room-text {
  margin-top: 4px;
  color: rgba(0, 0, 0, 0.65);
}

.phone-input-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.member-status-info {
  flex-shrink: 0;
  min-width: 80px;
  display: flex;
  justify-content: flex-end;
}

.price-display {
  display: flex;
  align-items: center;
  gap: 16px;
}

.price-detail {
  font-size: 12px;
  color: #8c8c8c;
  cursor: help;
}

/* 禁用状态下保持白色文字 */
.disabled-primary-btn {
  color: #fff !important;
  background-color: #1890ff !important;
  border-color: #1890ff !important;
  opacity: 0.6;
}

.disabled-primary-btn:hover,
.disabled-primary-btn:focus {
  color: #fff !important;
  background-color: #1890ff !important;
  border-color: #1890ff !important;
}
</style>
