import db from './src/config/database';
import { hashPassword } from './src/utils/password';

async function reset() {
  try {
    const newHash = await hashPassword('123456');
    console.log('Generated Hash for 123456:', newHash);
    
    const usernames = ['admin', 'staff01', 'guest', 'reception'];
    
    for (const username of usernames) {
      const [result]: any = await db.execute(
        'UPDATE users SET password = ? WHERE username = ?',
        [newHash, username]
      );
      console.log(`Updated user ${username}, rows affected: ${result.affectedRows}`);
    }
    
    console.log('Password reset complete.');
    process.exit(0);
  } catch (error) {
    console.error('Reset failed:', error);
    process.exit(1);
  }
}

reset();
