import BaseComponent from '@primevue/core/basecomponent';
import AvatarGroupStyle from 'primevue/avatargroup/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseAvatarGroup',
  "extends": BaseComponent,
  style: AvatarGroupStyle,
  provide: function provide() {
    return {
      $pcAvatarGroup: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'AvatarGroup',
  "extends": script$1,
  inheritAttrs: false
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default")], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
