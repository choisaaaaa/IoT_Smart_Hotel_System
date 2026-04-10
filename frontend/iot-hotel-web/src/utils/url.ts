/**
 * 获取完整的图片访问 URL
 * @param path 数据库存储的路径或完整 URL
 * @returns 完整的图片 URL
 */
export function getImageUrl(path: string | null | undefined): string {
  if (!path) return '';
  
  // 如果已经是完整的 URL (http:// 或 https:// 开头)，则直接返回
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  
  // 生产环境下，如果后端和前端不在同一个域，且没有配置反向代理
  // 我们可能需要从环境变量中读取后端的基础地址
  const apiBase = import.meta.env.VITE_API_BASE_URL || '';
  
  // 确保路径以 / 开头
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  
  // 如果有 apiBase，则拼接；否则返回相对路径（依赖 Nginx 等反向代理）
  return `${apiBase}${normalizedPath}`;
}
