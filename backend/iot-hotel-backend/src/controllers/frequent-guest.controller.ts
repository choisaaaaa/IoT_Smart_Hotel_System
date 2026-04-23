import { Response } from 'express';
import { AuthRequest, successResponse, errorResponse, sendSuccess, sendError } from '../types';
import db from '../config/database';

// 获取当前用户的常用联系人列表
export async function list(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return sendError(res, errorResponse('请先登录', 401));
    }

    const [guests]: any = await db.execute(
      'SELECT * FROM frequent_guests WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );

    sendSuccess(res, { guests });
  } catch (error) {
    console.error('获取常用联系人失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 添加常用联系人
export async function create(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return sendError(res, errorResponse('请先登录', 401));
    }

    const { name, phone, id_type = 'idcard', id_number, relationship = 'self' } = req.body;

    if (!name || !phone || !id_number) {
      return sendError(res, errorResponse('姓名、电话和证件号不能为空', 400));
    }

    const [result]: any = await db.execute(
      `INSERT INTO frequent_guests (user_id, name, phone, id_type, id_number, relationship) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, name, phone, id_type, id_number, relationship]
    );

    sendSuccess(res, {
      id: result.insertId,
      name,
      phone,
      id_type,
      id_number,
      relationship,
      message: '添加成功'
    });
  } catch (error) {
    console.error('添加常用联系人失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 更新常用联系人
export async function update(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    const guestId = req.params.id;
    if (!userId) {
      return sendError(res, errorResponse('请先登录', 401));
    }

    const { name, phone, id_type, id_number, relationship } = req.body;

    // 检查权限
    const [guests]: any = await db.execute(
      'SELECT id FROM frequent_guests WHERE id = ? AND user_id = ?',
      [guestId, userId]
    );

    if (guests.length === 0) {
      return sendError(res, errorResponse('联系人不存在或无权修改', 404));
    }

    await db.execute(
      `UPDATE frequent_guests 
       SET name = ?, phone = ?, id_type = ?, id_number = ?, relationship = ? 
       WHERE id = ?`,
      [name, phone, id_type, id_number, relationship || 'self', guestId]
    );

    sendSuccess(res, { message: '更新成功' });
  } catch (error) {
    console.error('更新常用联系人失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 删除常用联系人
export async function remove(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    const guestId = req.params.id;
    if (!userId) {
      return sendError(res, errorResponse('请先登录', 401));
    }

    // 检查权限
    const [guests]: any = await db.execute(
      'SELECT id FROM frequent_guests WHERE id = ? AND user_id = ?',
      [guestId, userId]
    );

    if (guests.length === 0) {
      return sendError(res, errorResponse('联系人不存在或无权删除', 404));
    }

    await db.execute(
      'DELETE FROM frequent_guests WHERE id = ?',
      [guestId]
    );

    sendSuccess(res, { message: '删除成功' });
  } catch (error) {
    console.error('删除常用联系人失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}
