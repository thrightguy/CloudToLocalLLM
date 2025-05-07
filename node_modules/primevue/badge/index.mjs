import { cn } from '@primeuix/utils';
import BaseComponent from '@primevue/core/basecomponent';
import BadgeStyle from 'primevue/badge/style';
import { createElementBlock, openBlock, mergeProps, renderSlot, createTextVNode, toDisplayString } from 'vue';

var script$1 = {
  name: 'BaseBadge',
  "extends": BaseComponent,
  props: {
    value: {
      type: [String, Number],
      "default": null
    },
    severity: {
      type: String,
      "default": null
    },
    size: {
      type: String,
      "default": null
    }
  },
  style: BadgeStyle,
  provide: function provide() {
    return {
      $pcBadge: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Badge',
  "extends": script$1,
  inheritAttrs: false,
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty(_defineProperty({
        circle: this.value != null && String(this.value).length === 1,
        empty: this.value == null && !this.$slots["default"]
      }, this.severity, this.severity), this.size, this.size));
    }
  }
};

var _hoisted_1 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("span", mergeProps({
    "class": _ctx.cx('root'),
    "data-p": $options.dataP
  }, _ctx.ptmi('root')), [renderSlot(_ctx.$slots, "default", {}, function () {
    return [createTextVNode(toDisplayString(_ctx.value), 1)];
  })], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
