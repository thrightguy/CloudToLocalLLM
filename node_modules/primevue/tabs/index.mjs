import BaseComponent from '@primevue/core/basecomponent';
import TabsStyle from 'primevue/tabs/style';
import { createElementBlock, openBlock, mergeProps, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseTabs',
  "extends": BaseComponent,
  props: {
    value: {
      type: [String, Number],
      "default": undefined
    },
    lazy: {
      type: Boolean,
      "default": false
    },
    scrollable: {
      type: Boolean,
      "default": false
    },
    showNavigators: {
      type: Boolean,
      "default": true
    },
    tabindex: {
      type: Number,
      "default": 0
    },
    selectOnFocus: {
      type: Boolean,
      "default": false
    }
  },
  style: TabsStyle,
  provide: function provide() {
    return {
      $pcTabs: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'Tabs',
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
    isVertical: function isVertical() {
      return this.orientation === 'vertical';
    }
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
