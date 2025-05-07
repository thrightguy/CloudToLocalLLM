import BaseComponent from '@primevue/core/basecomponent';
import IconFieldStyle from 'primevue/iconfield/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseIconField',
  "extends": BaseComponent,
  style: IconFieldStyle,
  provide: function provide() {
    return {
      $pcIconField: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'IconField',
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
