// 会员等级折扣映射
export const LEVEL_DISCOUNTS: Record<string, number> = {
  'diamond': 0.80,
  'platinum': 0.85,
  'gold': 0.88,
  'silver': 0.95,
  'standard': 1.0
};

// 会员等级积分倍率映射 (消费1元获得的基本积分 * 倍率)
export const LEVEL_POINTS_MULTIPLIER: Record<string, number> = {
  'diamond': 15,
  'platinum': 12,
  'gold': 9,
  'silver': 5,
  'standard': 1
};
