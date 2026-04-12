const ROLE_ALIASES: Record<string, string> = {
  system: 'system_admin',
  sys_admin: 'system_admin',
  systemadmin: 'system_admin',
  system_admin: 'system_admin',
  super_admin: 'system_admin',
  platform_admin: 'system_admin',
  admin: 'hotel_admin',
  manager: 'hotel_admin',
  hotel_manager: 'hotel_admin',
  hoteladmin: 'hotel_admin',
  hotel_admin: 'hotel_admin',
  receptionist: 'staff',
  reception: 'staff',
  front_desk: 'staff',
  frontdesk: 'staff',
  user: 'customer',
  customer: 'customer',
  guest: 'customer',
};

export const CANONICAL_ROLES = {
  SYSTEM_ADMIN: 'system_admin',
  HOTEL_ADMIN: 'hotel_admin',
  STAFF: 'staff',
  CUSTOMER: 'customer',
} as const;

export type CanonicalRole = typeof CANONICAL_ROLES[keyof typeof CANONICAL_ROLES];

export function normalizeRole(role?: string | null): string {
  if (!role) {
    return '';
  }
  const normalized = role.trim().toLowerCase();
  return ROLE_ALIASES[normalized] || normalized;
}

export function hasRole(role: string | undefined | null, allowedRoles: string[]): boolean {
  const currentRole = normalizeRole(role);
  if (!currentRole) {
    return false;
  }
  return allowedRoles.map((item) => normalizeRole(item)).includes(currentRole);
}

export function isSystemAdmin(role?: string | null): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.SYSTEM_ADMIN;
}

export function isHotelAdmin(role?: string | null): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.HOTEL_ADMIN;
}

export function isStaff(role?: string | null): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.STAFF;
}

export function isCustomer(role?: string | null): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.CUSTOMER;
}
