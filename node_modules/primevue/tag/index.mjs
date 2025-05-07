import { cn } from '@primeuix/utils';
import BaseComponent from '@primevue/core/basecomponent';
import TagStyle from 'primevue/tag/style';
import { createElementBlock, openBlock, mergeProps, createBlock, createCommentVNode, renderSlot, resolveDynamicComponent, createElementVNode, toDisplayString } from 'vue';

var script$1 = {
  name: 'BaseTag',
  "extends": BaseComponent,
  props: {
    value: null,
    severity: null,
    rounded: Boolean,
    icon: String
  },
  style: TagStyle,
  provide: function provide() {
    return {
      $pcTag: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Tag',
  "extends": script$1,
  inheritAttrs: false,
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty({
        rounded: this.rounded
      }, this.severity, this.severity));
    }
  }
};

var _hoisted_1 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("span", mergeProps({
    "class": _ctx.cx('root'),
    "data-p": $options.dataP
  }, _ctx.ptmi('root')), [_ctx.$slots.icon ? (openBlock(), createBlock(resolveDynamicComponent(_ctx.$slots.icon), mergeProps({
    key: 0,
    "class": _ctx.cx('icon')
  }, _ctx.ptm('icon')), null, 16, ["class"])) : _ctx.icon ? (openBlock(), createElementBlock("span", mergeProps({
    key: 1,
    "class": [_ctx.cx('icon'), _ctx.icon]
  }, _ctx.ptm('icon')), null, 16)) : createCommentVNode("", true), _ctx.value != null || _ctx.$slots["default"] ? renderSlot(_ctx.$slots, "default", {
    key: 2
  }, function () {
    return [createElementVNode("span", mergeProps({
      "class": _ctx.cx('label')
    }, _ctx.ptm('label')), toDisplayString(_ctx.value), 17)];
  }) : createCommentVNode("", true)], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
