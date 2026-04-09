const ROLE_ALIASES: Record<string, string> = {
  sys_admin: 'system',
  systemadmin: 'system',
  system_admin: 'system',
  super_admin: 'system',
  platform_admin: 'system',
  receptionist: 'staff',
  front_desk: 'staff',
  frontdesk: 'staff'
};

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

export function isSystemRole(role?: string | null): boolean {
  return normalizeRole(role) === 'system';
}
