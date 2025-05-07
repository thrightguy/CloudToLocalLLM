import { cn } from '@primeuix/utils';
import BaseComponent from '@primevue/core/basecomponent';
import SkeletonStyle from 'primevue/skeleton/style';
import { createElementBlock, openBlock, mergeProps } from 'vue';

var script$1 = {
  name: 'BaseSkeleton',
  "extends": BaseComponent,
  props: {
    shape: {
      type: String,
      "default": 'rectangle'
    },
    size: {
      type: String,
      "default": null
    },
    width: {
      type: String,
      "default": '100%'
    },
    height: {
      type: String,
      "default": '1rem'
    },
    borderRadius: {
      type: String,
      "default": null
    },
    animation: {
      type: String,
      "default": 'wave'
    }
  },
  style: SkeletonStyle,
  provide: function provide() {
    return {
      $pcSkeleton: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Skeleton',
  "extends": script$1,
  inheritAttrs: false,
  computed: {
    containerStyle: function containerStyle() {
      if (this.size) return {
        width: this.size,
        height: this.size,
        borderRadius: this.borderRadius
      };else return {
        width: this.width,
        height: this.height,
        borderRadius: this.borderRadius
      };
    },
    dataP: function dataP() {
      return cn(_defineProperty({}, this.shape, this.shape));
    }
  }
};

var _hoisted_1 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    style: [_ctx.sx('root'), $options.containerStyle],
    "aria-hidden": "true"
  }, _ctx.ptmi('root'), {
    "data-p": $options.dataP
  }), null, 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
