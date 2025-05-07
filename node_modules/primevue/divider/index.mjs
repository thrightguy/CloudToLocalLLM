import { cn } from '@primeuix/utils';
import BaseComponent from '@primevue/core/basecomponent';
import DividerStyle from 'primevue/divider/style';
import { createElementBlock, openBlock, mergeProps, createCommentVNode, renderSlot } from 'vue';

var script$1 = {
  name: 'BaseDivider',
  "extends": BaseComponent,
  props: {
    align: {
      type: String,
      "default": null
    },
    layout: {
      type: String,
      "default": 'horizontal'
    },
    type: {
      type: String,
      "default": 'solid'
    }
  },
  style: DividerStyle,
  provide: function provide() {
    return {
      $pcDivider: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Divider',
  "extends": script$1,
  inheritAttrs: false,
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty(_defineProperty(_defineProperty({}, this.align, this.align), this.layout, this.layout), this.type, this.type));
    }
  }
};

var _hoisted_1 = ["aria-orientation", "data-p"];
var _hoisted_2 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    style: _ctx.sx('root'),
    role: "separator",
    "aria-orientation": _ctx.layout,
    "data-p": $options.dataP
  }, _ctx.ptmi('root')), [_ctx.$slots["default"] ? (openBlock(), createElementBlock("div", mergeProps({
    key: 0,
    "class": _ctx.cx('content'),
    "data-p": $options.dataP
  }, _ctx.ptm('content')), [renderSlot(_ctx.$slots, "default")], 16, _hoisted_2)) : createCommentVNode("", true)], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
