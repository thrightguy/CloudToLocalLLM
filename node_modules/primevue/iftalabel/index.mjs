import BaseComponent from '@primevue/core/basecomponent';
import IftaLabelStyle from 'primevue/iftalabel/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseIftaLabel',
  "extends": BaseComponent,
  style: IftaLabelStyle,
  provide: function provide() {
    return {
      $pcIftaLabel: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'IftaLabel',
  "extends": script$1,
  inheritAttrs: false
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("span", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default")], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
