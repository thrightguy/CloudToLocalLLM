import { cn } from '@primeuix/utils';
import BaseComponent from '@primevue/core/basecomponent';
import AvatarStyle from 'primevue/avatar/style';
import { createElementBlock, openBlock, mergeProps, renderSlot, createBlock, createCommentVNode, toDisplayString, resolveDynamicComponent, normalizeClass } from 'vue';

var script$1 = {
  name: 'BaseAvatar',
  "extends": BaseComponent,
  props: {
    label: {
      type: String,
      "default": null
    },
    icon: {
      type: String,
      "default": null
    },
    image: {
      type: String,
      "default": null
    },
    size: {
      type: String,
      "default": 'normal'
    },
    shape: {
      type: String,
      "default": 'square'
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
  style: AvatarStyle,
  provide: function provide() {
    return {
      $pcAvatar: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Avatar',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['error'],
  methods: {
    onError: function onError(event) {
      this.$emit('error', event);
    }
  },
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty(_defineProperty({}, this.shape, this.shape), this.size, this.size));
    }
  }
};

var _hoisted_1 = ["aria-labelledby", "aria-label", "data-p"];
var _hoisted_2 = ["data-p"];
var _hoisted_3 = ["data-p"];
var _hoisted_4 = ["src", "alt", "data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    "aria-labelledby": _ctx.ariaLabelledby,
    "aria-label": _ctx.ariaLabel
  }, _ctx.ptmi('root'), {
    "data-p": $options.dataP
  }), [renderSlot(_ctx.$slots, "default", {}, function () {
    return [_ctx.label ? (openBlock(), createElementBlock("span", mergeProps({
      key: 0,
      "class": _ctx.cx('label')
    }, _ctx.ptm('label'), {
      "data-p": $options.dataP
    }), toDisplayString(_ctx.label), 17, _hoisted_2)) : _ctx.$slots.icon ? (openBlock(), createBlock(resolveDynamicComponent(_ctx.$slots.icon), {
      key: 1,
      "class": normalizeClass(_ctx.cx('icon'))
    }, null, 8, ["class"])) : _ctx.icon ? (openBlock(), createElementBlock("span", mergeProps({
      key: 2,
      "class": [_ctx.cx('icon'), _ctx.icon]
    }, _ctx.ptm('icon'), {
      "data-p": $options.dataP
    }), null, 16, _hoisted_3)) : _ctx.image ? (openBlock(), createElementBlock("img", mergeProps({
      key: 3,
      src: _ctx.image,
      alt: _ctx.ariaLabel,
      onError: _cache[0] || (_cache[0] = function () {
        return $options.onError && $options.onError.apply($options, arguments);
      })
    }, _ctx.ptm('image'), {
      "data-p": $options.dataP
    }), null, 16, _hoisted_4)) : createCommentVNode("", true)];
  })], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
