import { $dt } from '@primeuix/styled';
import { setCSSProperty } from '@primeuix/utils/dom';
import BaseComponent from '@primevue/core/basecomponent';
import ImageCompareStyle from 'primevue/imagecompare/style';
import { createElementBlock, openBlock, mergeProps, renderSlot, createElementVNode } from 'vue';

var script$1 = {
  name: 'BaseImageCompare',
  "extends": BaseComponent,
  props: {
    tabindex: {
      type: Number,
      "default": 0
    },
    ariaLabelledby: {
      type: String,
      "default": null
    },
    ariaLabel: {
      type: String,
      "default": null
    }
  },
  style: ImageCompareStyle,
  provide: function provide() {
    return {
      $pcImageCompare: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'ImageCompare',
  "extends": script$1,
  methods: {
    onSlide: function onSlide(event) {
      var value = event.target.value;
      var image = event.target.previousElementSibling;
      setCSSProperty(image, $dt('imagecompare.scope.x').name, "".concat(value, "%"));
    }
  }
};

var _hoisted_1 = ["aria-labelledby", "aria-label"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    "aria-labelledby": _ctx.ariaLabelledby,
    "aria-label": _ctx.ariaLabel
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "left"), renderSlot(_ctx.$slots, "right"), createElementVNode("input", mergeProps({
    type: "range",
    min: "0",
    max: "100",
    value: "50",
    onInput: _cache[0] || (_cache[0] = function () {
      return $options.onSlide && $options.onSlide.apply($options, arguments);
    }),
    "class": _ctx.cx('slider')
  }, _ctx.ptm('slider')), null, 16)], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
