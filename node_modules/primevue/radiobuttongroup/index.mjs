import { uuid } from '@primeuix/utils';
import BaseEditableHolder from '@primevue/core/baseeditableholder';
import RadioButtonGroupStyle from 'primevue/radiobuttongroup/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseRadioButtonGroup',
  "extends": BaseEditableHolder,
  style: RadioButtonGroupStyle,
  provide: function provide() {
    return {
      $pcRadioButtonGroup: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'RadioButtonGroup',
  "extends": script$1,
  inheritAttrs: false,
  data: function data() {
    return {
      groupName: this.name
    };
  },
  watch: {
    name: function name(newValue) {
      this.groupName = newValue || uuid('radiobutton-group-');
    }
  },
  mounted: function mounted() {
    this.groupName = this.groupName || uuid('radiobutton-group-');
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default")], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
