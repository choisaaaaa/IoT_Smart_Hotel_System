import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import HelloWorld from '../HelloWorld.vue';

describe('HelloWorld 组件测试', () => {
  it('应该正确渲染传入的 msg', () => {
    const msg = 'Hello Vitest';
    const wrapper = mount(HelloWorld, {
      props: { msg }
    });
    
    expect(wrapper.text()).toContain(msg);
  });

  it('应该包含按钮元素', () => {
    const wrapper = mount(HelloWorld, {
      props: { msg: 'Test' }
    });
    
    const button = wrapper.find('button');
    expect(button.exists()).toBe(true);
  });

  it('点击按钮应该增加计数', async () => {
    const wrapper = mount(HelloWorld, {
      props: { msg: 'Test' }
    });
    
    const button = wrapper.find('button');
    const initialText = button.text();
    
    await button.trigger('click');
    
    expect(button.text()).not.toBe(initialText);
  });
});
