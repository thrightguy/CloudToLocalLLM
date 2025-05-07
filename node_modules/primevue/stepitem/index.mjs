import BaseComponent from '@primevue/core/basecomponent';
import StepItemStyle from 'primevue/stepitem/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseStepItem',
  "extends": BaseComponent,
  props: {
    value: {
      type: [String, Number],
      "default": undefined
    }
  },
  style: StepItemStyle,
  provide: function provide() {
    return {
      $pcStepItem: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'StepItem',
  "extends": script$1,
  inheritAttrs: false,
  inject: ['$pcStepper'],
  computed: {
    isActive: function isActive() {
      var _this$$pcStepper;
      return ((_this$$pcStepper = this.$pcStepper) === null || _this$$pcStepper === void 0 ? void 0 : _this$$pcStepper.d_value) === this.value;
    }
  }
};

var _hoisted_1 = ["data-p-active"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    "data-p-active": $options.isActive
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default")], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
