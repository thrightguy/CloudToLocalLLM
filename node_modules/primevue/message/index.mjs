import { cn } from '@primeuix/utils';
import TimesIcon from '@primevue/icons/times';
import Ripple from 'primevue/ripple';
import BaseComponent from '@primevue/core/basecomponent';
import MessageStyle from 'primevue/message/style';
import { resolveComponent, resolveDirective, createBlock, openBlock, Transition, mergeProps, withCtx, withDirectives, createElementVNode, renderSlot, createElementBlock, createCommentVNode, normalizeClass, resolveDynamicComponent, vShow } from 'vue';

var script$1 = {
  name: 'BaseMessage',
  "extends": BaseComponent,
  props: {
    severity: {
      type: String,
      "default": 'info'
    },
    closable: {
      type: Boolean,
      "default": false
    },
    life: {
      type: Number,
      "default": null
    },
    icon: {
      type: String,
      "default": undefined
    },
    closeIcon: {
      type: String,
      "default": undefined
    },
    closeButtonProps: {
      type: null,
      "default": null
    },
    size: {
      type: String,
      "default": null
    },
    variant: {
      type: String,
      "default": null
    }
  },
  style: MessageStyle,
  provide: function provide() {
    return {
      $pcMessage: this,
      $parentInstance: this
    };
  }
};

function _typeof$1(o) { "@babel/helpers - typeof"; return _typeof$1 = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof$1(o); }
function _defineProperty$1(e, r, t) { return (r = _toPropertyKey$1(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey$1(t) { var i = _toPrimitive$1(t, "string"); return "symbol" == _typeof$1(i) ? i : i + ""; }
function _toPrimitive$1(t, r) { if ("object" != _typeof$1(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof$1(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Message',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['close', 'life-end'],
  timeout: null,
  data: function data() {
    return {
      visible: true
    };
  },
  mounted: function mounted() {
    var _this = this;
    if (this.life) {
      setTimeout(function () {
        _this.visible = false;
        _this.$emit('life-end');
      }, this.life);
    }
  },
  methods: {
    close: function close(event) {
      this.visible = false;
      this.$emit('close', event);
    }
  },
  computed: {
    closeAriaLabel: function closeAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.close : undefined;
    },
    dataP: function dataP() {
      return cn(_defineProperty$1(_defineProperty$1({
        outlined: this.variant === 'outlined',
        simple: this.variant === 'simple'
      }, this.severity, this.severity), this.size, this.size));
    }
  },
  directives: {
    ripple: Ripple
  },
  components: {
    TimesIcon: TimesIcon
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var _hoisted_1 = ["data-p"];
var _hoisted_2 = ["data-p"];
var _hoisted_3 = ["data-p"];
var _hoisted_4 = ["aria-label", "data-p"];
var _hoisted_5 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_TimesIcon = resolveComponent("TimesIcon");
  var _directive_ripple = resolveDirective("ripple");
  return openBlock(), createBlock(Transition, mergeProps({
    name: "p-message",
    appear: ""
  }, _ctx.ptmi('transition')), {
    "default": withCtx(function () {
      return [withDirectives(createElementVNode("div", mergeProps({
        "class": _ctx.cx('root'),
        role: "alert",
        "aria-live": "assertive",
        "aria-atomic": "true",
        "data-p": $options.dataP
      }, _ctx.ptm('root')), [_ctx.$slots.container ? renderSlot(_ctx.$slots, "container", {
        key: 0,
        closeCallback: $options.close
      }) : (openBlock(), createElementBlock("div", mergeProps({
        key: 1,
        "class": _ctx.cx('content'),
        "data-p": $options.dataP
      }, _ctx.ptm('content')), [renderSlot(_ctx.$slots, "icon", {
        "class": normalizeClass(_ctx.cx('icon'))
      }, function () {
        return [(openBlock(), createBlock(resolveDynamicComponent(_ctx.icon ? 'span' : null), mergeProps({
          "class": [_ctx.cx('icon'), _ctx.icon],
          "data-p": $options.dataP
        }, _ctx.ptm('icon')), null, 16, ["class", "data-p"]))];
      }), _ctx.$slots["default"] ? (openBlock(), createElementBlock("div", mergeProps({
        key: 0,
        "class": _ctx.cx('text'),
        "data-p": $options.dataP
      }, _ctx.ptm('text')), [renderSlot(_ctx.$slots, "default")], 16, _hoisted_3)) : createCommentVNode("", true), _ctx.closable ? withDirectives((openBlock(), createElementBlock("button", mergeProps({
        key: 1,
        "class": _ctx.cx('closeButton'),
        "aria-label": $options.closeAriaLabel,
        type: "button",
        onClick: _cache[0] || (_cache[0] = function ($event) {
          return $options.close($event);
        }),
        "data-p": $options.dataP
      }, _objectSpread(_objectSpread({}, _ctx.closeButtonProps), _ctx.ptm('closeButton'))), [renderSlot(_ctx.$slots, "closeicon", {}, function () {
        return [_ctx.closeIcon ? (openBlock(), createElementBlock("i", mergeProps({
          key: 0,
          "class": [_ctx.cx('closeIcon'), _ctx.closeIcon],
          "data-p": $options.dataP
        }, _ctx.ptm('closeIcon')), null, 16, _hoisted_5)) : (openBlock(), createBlock(_component_TimesIcon, mergeProps({
          key: 1,
          "class": [_ctx.cx('closeIcon'), _ctx.closeIcon],
          "data-p": $options.dataP
        }, _ctx.ptm('closeIcon')), null, 16, ["class", "data-p"]))];
      })], 16, _hoisted_4)), [[_directive_ripple]]) : createCommentVNode("", true)], 16, _hoisted_2))], 16, _hoisted_1), [[vShow, $data.visible]])];
    }),
    _: 3
  }, 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
