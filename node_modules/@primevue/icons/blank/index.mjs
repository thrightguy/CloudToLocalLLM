import BaseIcon from '@primevue/icons/baseicon';
import { createElementBlock, openBlock, mergeProps, createElementVNode } from 'vue';

var script = {
  name: 'BlankIcon',
  "extends": BaseIcon
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("svg", mergeProps({
    width: "14",
    height: "14",
    viewBox: "0 0 14 14",
    fill: "none",
    xmlns: "http://www.w3.org/2000/svg"
  }, _ctx.pti()), _cache[0] || (_cache[0] = [createElementVNode("rect", {
    width: "1",
    height: "1",
    fill: "currentColor",
    "fill-opacity": "0"
  }, null, -1)]), 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
