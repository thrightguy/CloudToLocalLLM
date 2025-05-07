import BaseComponent from '@primevue/core/basecomponent';
import StepperStyle from 'primevue/stepper/style';
import { createElementBlock, openBlock, mergeProps, renderSlot, createCommentVNode } from 'vue';

var script$1 = {
  name: 'BaseStepper',
  "extends": BaseComponent,
  props: {
    value: {
      type: [String, Number],
      "default": undefined
    },
    linear: {
      type: Boolean,
      "default": false
    }
  },
  style: StepperStyle,
  provide: function provide() {
    return {
      $pcStepper: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'Stepper',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['update:value'],
  data: function data() {
    return {
      d_value: this.value
    };
  },
  watch: {
    value: function value(newValue) {
      this.d_value = newValue;
    }
  },
  methods: {
    updateValue: function updateValue(newValue) {
      if (this.d_value !== newValue) {
        this.d_value = newValue;
        this.$emit('update:value', newValue);
      }
    },
    isStepActive: function isStepActive(value) {
      return this.d_value === value;
    },
    isStepDisabled: function isStepDisabled() {
      return this.linear;
    }
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    role: "tablist"
  }, _ctx.ptmi('root')), [_ctx.$slots.start ? renderSlot(_ctx.$slots, "start", {
    key: 0
  }) : createCommentVNode("", true), renderSlot(_ctx.$slots, "default"), _ctx.$slots.end ? renderSlot(_ctx.$slots, "end", {
    key: 1
  }) : createCommentVNode("", true)], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
