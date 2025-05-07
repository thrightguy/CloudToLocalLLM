import BaseComponent from '@primevue/core/basecomponent';
import InputIconStyle from 'primevue/inputicon/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseInputIcon',
  "extends": BaseComponent,
  style: InputIconStyle,
  props: {
    "class": null
  },
  provide: function provide() {
    return {
      $pcInputIcon: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'InputIcon',
  "extends": script$1,
  inheritAttrs: false,
  computed: {
    containerClass: function containerClass() {
      return [this.cx('root'), this["class"]];
    }
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("span", mergeProps({
    "class": $options.containerClass
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default")], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
