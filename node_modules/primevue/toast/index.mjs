import { cn } from '@primeuix/utils';
import { setAttribute } from '@primeuix/utils/dom';
import { isEmpty } from '@primeuix/utils/object';
import { ZIndex } from '@primeuix/utils/zindex';
import Portal from 'primevue/portal';
import ToastEventBus from 'primevue/toasteventbus';
import BaseComponent from '@primevue/core/basecomponent';
import ToastStyle from 'primevue/toast/style';
import CheckIcon from '@primevue/icons/check';
import ExclamationTriangleIcon from '@primevue/icons/exclamationtriangle';
import InfoCircleIcon from '@primevue/icons/infocircle';
import TimesIcon from '@primevue/icons/times';
import TimesCircleIcon from '@primevue/icons/timescircle';
import Ripple from 'primevue/ripple';
import { resolveDirective, createElementBlock, openBlock, mergeProps, createBlock, resolveDynamicComponent, createCommentVNode, Fragment, createElementVNode, toDisplayString, normalizeProps, withDirectives, resolveComponent, withCtx, createVNode, TransitionGroup, renderList } from 'vue';

var script$2 = {
  name: 'BaseToast',
  "extends": BaseComponent,
  props: {
    group: {
      type: String,
      "default": null
    },
    position: {
      type: String,
      "default": 'top-right'
    },
    autoZIndex: {
      type: Boolean,
      "default": true
    },
    baseZIndex: {
      type: Number,
      "default": 0
    },
    breakpoints: {
      type: Object,
      "default": null
    },
    closeIcon: {
      type: String,
      "default": undefined
    },
    infoIcon: {
      type: String,
      "default": undefined
    },
    warnIcon: {
      type: String,
      "default": undefined
    },
    errorIcon: {
      type: String,
      "default": undefined
    },
    successIcon: {
      type: String,
      "default": undefined
    },
    closeButtonProps: {
      type: null,
      "default": null
    },
    onMouseEnter: {
      type: Function,
      "default": undefined
    },
    onMouseLeave: {
      type: Function,
      "default": undefined
    },
    onClick: {
      type: Function,
      "default": undefined
    }
  },
  style: ToastStyle,
  provide: function provide() {
    return {
      $pcToast: this,
      $parentInstance: this
    };
  }
};

function _typeof$3(o) { "@babel/helpers - typeof"; return _typeof$3 = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof$3(o); }
function _defineProperty$3(e, r, t) { return (r = _toPropertyKey$3(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey$3(t) { var i = _toPrimitive$3(t, "string"); return "symbol" == _typeof$3(i) ? i : i + ""; }
function _toPrimitive$3(t, r) { if ("object" != _typeof$3(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof$3(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script$1 = {
  name: 'ToastMessage',
  hostName: 'Toast',
  "extends": BaseComponent,
  emits: ['close'],
  closeTimeout: null,
  createdAt: null,
  lifeRemaining: null,
  props: {
    message: {
      type: null,
      "default": null
    },
    templates: {
      type: Object,
      "default": null
    },
    closeIcon: {
      type: String,
      "default": null
    },
    infoIcon: {
      type: String,
      "default": null
    },
    warnIcon: {
      type: String,
      "default": null
    },
    errorIcon: {
      type: String,
      "default": null
    },
    successIcon: {
      type: String,
      "default": null
    },
    closeButtonProps: {
      type: null,
      "default": null
    }
  },
  mounted: function mounted() {
    if (this.message.life) {
      this.lifeRemaining = this.message.life;
      this.startTimeout();
    }
  },
  beforeUnmount: function beforeUnmount() {
    this.clearCloseTimeout();
  },
  methods: {
    startTimeout: function startTimeout() {
      var _this = this;
      this.createdAt = new Date().valueOf();
      this.closeTimeout = setTimeout(function () {
        _this.close({
          message: _this.message,
          type: 'life-end'
        });
      }, this.lifeRemaining);
    },
    close: function close(params) {
      this.$emit('close', params);
    },
    onCloseClick: function onCloseClick() {
      this.clearCloseTimeout();
      this.close({
        message: this.message,
        type: 'close'
      });
    },
    clearCloseTimeout: function clearCloseTimeout() {
      if (this.closeTimeout) {
        clearTimeout(this.closeTimeout);
        this.closeTimeout = null;
      }
    },
    onMessageClick: function onMessageClick(event) {
      var _this$props;
      ((_this$props = this.props) === null || _this$props === void 0 ? void 0 : _this$props.onClick) && this.props.onClick({
        originalEvent: event,
        message: this.message
      });
    },
    onMouseEnter: function onMouseEnter(event) {
      var _this$props2;
      if ((_this$props2 = this.props) !== null && _this$props2 !== void 0 && _this$props2.onMouseEnter) {
        this.props.onMouseEnter({
          originalEvent: event,
          message: this.message
        });
        if (event.defaultPrevented) {
          return;
        }
        if (this.message.life) {
          this.lifeRemaining = this.createdAt + this.lifeRemaining - Date().valueOf();
          this.createdAt = null;
          this.clearCloseTimeout();
        }
      }
    },
    onMouseLeave: function onMouseLeave(event) {
      var _this$props3;
      if ((_this$props3 = this.props) !== null && _this$props3 !== void 0 && _this$props3.onMouseLeave) {
        this.props.onMouseLeave({
          originalEvent: event,
          message: this.message
        });
        if (event.defaultPrevented) {
          return;
        }
        if (this.message.life) {
          this.startTimeout();
        }
      }
    }
  },
  computed: {
    iconComponent: function iconComponent() {
      return {
        info: !this.infoIcon && InfoCircleIcon,
        success: !this.successIcon && CheckIcon,
        warn: !this.warnIcon && ExclamationTriangleIcon,
        error: !this.errorIcon && TimesCircleIcon
      }[this.message.severity];
    },
    closeAriaLabel: function closeAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.close : undefined;
    },
    dataP: function dataP() {
      return cn(_defineProperty$3({}, this.message.severity, this.message.severity));
    }
  },
  components: {
    TimesIcon: TimesIcon,
    InfoCircleIcon: InfoCircleIcon,
    CheckIcon: CheckIcon,
    ExclamationTriangleIcon: ExclamationTriangleIcon,
    TimesCircleIcon: TimesCircleIcon
  },
  directives: {
    ripple: Ripple
  }
};

function _typeof$2(o) { "@babel/helpers - typeof"; return _typeof$2 = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof$2(o); }
function ownKeys$1(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread$1(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys$1(Object(t), true).forEach(function (r) { _defineProperty$2(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys$1(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty$2(e, r, t) { return (r = _toPropertyKey$2(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey$2(t) { var i = _toPrimitive$2(t, "string"); return "symbol" == _typeof$2(i) ? i : i + ""; }
function _toPrimitive$2(t, r) { if ("object" != _typeof$2(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof$2(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var _hoisted_1$1 = ["data-p"];
var _hoisted_2 = ["data-p"];
var _hoisted_3 = ["data-p"];
var _hoisted_4 = ["data-p"];
var _hoisted_5 = ["aria-label", "data-p"];
function render$1(_ctx, _cache, $props, $setup, $data, $options) {
  var _directive_ripple = resolveDirective("ripple");
  return openBlock(), createElementBlock("div", mergeProps({
    "class": [_ctx.cx('message'), $props.message.styleClass],
    role: "alert",
    "aria-live": "assertive",
    "aria-atomic": "true",
    "data-p": $options.dataP
  }, _ctx.ptm('message'), {
    onClick: _cache[1] || (_cache[1] = function () {
      return $options.onMessageClick && $options.onMessageClick.apply($options, arguments);
    }),
    onMouseenter: _cache[2] || (_cache[2] = function () {
      return $options.onMouseEnter && $options.onMouseEnter.apply($options, arguments);
    }),
    onMouseleave: _cache[3] || (_cache[3] = function () {
      return $options.onMouseLeave && $options.onMouseLeave.apply($options, arguments);
    })
  }), [$props.templates.container ? (openBlock(), createBlock(resolveDynamicComponent($props.templates.container), {
    key: 0,
    message: $props.message,
    closeCallback: $options.onCloseClick
  }, null, 8, ["message", "closeCallback"])) : (openBlock(), createElementBlock("div", mergeProps({
    key: 1,
    "class": [_ctx.cx('messageContent'), $props.message.contentStyleClass]
  }, _ctx.ptm('messageContent')), [!$props.templates.message ? (openBlock(), createElementBlock(Fragment, {
    key: 0
  }, [(openBlock(), createBlock(resolveDynamicComponent($props.templates.messageicon ? $props.templates.messageicon : $props.templates.icon ? $props.templates.icon : $options.iconComponent && $options.iconComponent.name ? $options.iconComponent : 'span'), mergeProps({
    "class": _ctx.cx('messageIcon')
  }, _ctx.ptm('messageIcon')), null, 16, ["class"])), createElementVNode("div", mergeProps({
    "class": _ctx.cx('messageText'),
    "data-p": $options.dataP
  }, _ctx.ptm('messageText')), [createElementVNode("span", mergeProps({
    "class": _ctx.cx('summary'),
    "data-p": $options.dataP
  }, _ctx.ptm('summary')), toDisplayString($props.message.summary), 17, _hoisted_3), $props.message.detail ? (openBlock(), createElementBlock("div", mergeProps({
    key: 0,
    "class": _ctx.cx('detail'),
    "data-p": $options.dataP
  }, _ctx.ptm('detail')), toDisplayString($props.message.detail), 17, _hoisted_4)) : createCommentVNode("", true)], 16, _hoisted_2)], 64)) : (openBlock(), createBlock(resolveDynamicComponent($props.templates.message), {
    key: 1,
    message: $props.message
  }, null, 8, ["message"])), $props.message.closable !== false ? (openBlock(), createElementBlock("div", normalizeProps(mergeProps({
    key: 2
  }, _ctx.ptm('buttonContainer'))), [withDirectives((openBlock(), createElementBlock("button", mergeProps({
    "class": _ctx.cx('closeButton'),
    type: "button",
    "aria-label": $options.closeAriaLabel,
    onClick: _cache[0] || (_cache[0] = function () {
      return $options.onCloseClick && $options.onCloseClick.apply($options, arguments);
    }),
    autofocus: "",
    "data-p": $options.dataP
  }, _objectSpread$1(_objectSpread$1({}, $props.closeButtonProps), _ctx.ptm('closeButton'))), [(openBlock(), createBlock(resolveDynamicComponent($props.templates.closeicon || 'TimesIcon'), mergeProps({
    "class": [_ctx.cx('closeIcon'), $props.closeIcon]
  }, _ctx.ptm('closeIcon')), null, 16, ["class"]))], 16, _hoisted_5)), [[_directive_ripple]])], 16)) : createCommentVNode("", true)], 16))], 16, _hoisted_1$1);
}

script$1.render = render$1;

function _typeof$1(o) { "@babel/helpers - typeof"; return _typeof$1 = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof$1(o); }
function _defineProperty$1(e, r, t) { return (r = _toPropertyKey$1(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey$1(t) { var i = _toPrimitive$1(t, "string"); return "symbol" == _typeof$1(i) ? i : i + ""; }
function _toPrimitive$1(t, r) { if ("object" != _typeof$1(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof$1(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
var messageIdx = 0;
var script = {
  name: 'Toast',
  "extends": script$2,
  inheritAttrs: false,
  emits: ['close', 'life-end'],
  data: function data() {
    return {
      messages: []
    };
  },
  styleElement: null,
  mounted: function mounted() {
    ToastEventBus.on('add', this.onAdd);
    ToastEventBus.on('remove', this.onRemove);
    ToastEventBus.on('remove-group', this.onRemoveGroup);
    ToastEventBus.on('remove-all-groups', this.onRemoveAllGroups);
    if (this.breakpoints) {
      this.createStyle();
    }
  },
  beforeUnmount: function beforeUnmount() {
    this.destroyStyle();
    if (this.$refs.container && this.autoZIndex) {
      ZIndex.clear(this.$refs.container);
    }
    ToastEventBus.off('add', this.onAdd);
    ToastEventBus.off('remove', this.onRemove);
    ToastEventBus.off('remove-group', this.onRemoveGroup);
    ToastEventBus.off('remove-all-groups', this.onRemoveAllGroups);
  },
  methods: {
    add: function add(message) {
      if (message.id == null) {
        message.id = messageIdx++;
      }
      this.messages = [].concat(_toConsumableArray(this.messages), [message]);
    },
    remove: function remove(params) {
      var index = this.messages.findIndex(function (m) {
        return m.id === params.message.id;
      });
      if (index !== -1) {
        this.messages.splice(index, 1);
        this.$emit(params.type, {
          message: params.message
        });
      }
    },
    onAdd: function onAdd(message) {
      if (this.group == message.group) {
        this.add(message);
      }
    },
    onRemove: function onRemove(message) {
      this.remove({
        message: message,
        type: 'close'
      });
    },
    onRemoveGroup: function onRemoveGroup(group) {
      if (this.group === group) {
        this.messages = [];
      }
    },
    onRemoveAllGroups: function onRemoveAllGroups() {
      var _this = this;
      this.messages.forEach(function (message) {
        return _this.$emit('close', {
          message: message
        });
      });
      this.messages = [];
    },
    onEnter: function onEnter() {
      if (this.autoZIndex) {
        ZIndex.set('modal', this.$refs.container, this.baseZIndex || this.$primevue.config.zIndex.modal);
      }
    },
    onLeave: function onLeave() {
      var _this2 = this;
      if (this.$refs.container && this.autoZIndex && isEmpty(this.messages)) {
        setTimeout(function () {
          ZIndex.clear(_this2.$refs.container);
        }, 200);
      }
    },
    createStyle: function createStyle() {
      if (!this.styleElement && !this.isUnstyled) {
        var _this$$primevue;
        this.styleElement = document.createElement('style');
        this.styleElement.type = 'text/css';
        setAttribute(this.styleElement, 'nonce', (_this$$primevue = this.$primevue) === null || _this$$primevue === void 0 || (_this$$primevue = _this$$primevue.config) === null || _this$$primevue === void 0 || (_this$$primevue = _this$$primevue.csp) === null || _this$$primevue === void 0 ? void 0 : _this$$primevue.nonce);
        document.head.appendChild(this.styleElement);
        var innerHTML = '';
        for (var breakpoint in this.breakpoints) {
          var breakpointStyle = '';
          for (var styleProp in this.breakpoints[breakpoint]) {
            breakpointStyle += styleProp + ':' + this.breakpoints[breakpoint][styleProp] + '!important;';
          }
          innerHTML += "\n                        @media screen and (max-width: ".concat(breakpoint, ") {\n                            .p-toast[").concat(this.$attrSelector, "] {\n                                ").concat(breakpointStyle, "\n                            }\n                        }\n                    ");
        }
        this.styleElement.innerHTML = innerHTML;
      }
    },
    destroyStyle: function destroyStyle() {
      if (this.styleElement) {
        document.head.removeChild(this.styleElement);
        this.styleElement = null;
      }
    }
  },
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty$1({}, this.position, this.position));
    }
  },
  components: {
    ToastMessage: script$1,
    Portal: Portal
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var _hoisted_1 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_ToastMessage = resolveComponent("ToastMessage");
  var _component_Portal = resolveComponent("Portal");
  return openBlock(), createBlock(_component_Portal, null, {
    "default": withCtx(function () {
      return [createElementVNode("div", mergeProps({
        ref: "container",
        "class": _ctx.cx('root'),
        style: _ctx.sx('root', true, {
          position: _ctx.position
        }),
        "data-p": $options.dataP
      }, _ctx.ptmi('root')), [createVNode(TransitionGroup, mergeProps({
        name: "p-toast-message",
        tag: "div",
        onEnter: $options.onEnter,
        onLeave: $options.onLeave
      }, _objectSpread({}, _ctx.ptm('transition'))), {
        "default": withCtx(function () {
          return [(openBlock(true), createElementBlock(Fragment, null, renderList($data.messages, function (msg) {
            return openBlock(), createBlock(_component_ToastMessage, {
              key: msg.id,
              message: msg,
              templates: _ctx.$slots,
              closeIcon: _ctx.closeIcon,
              infoIcon: _ctx.infoIcon,
              warnIcon: _ctx.warnIcon,
              errorIcon: _ctx.errorIcon,
              successIcon: _ctx.successIcon,
              closeButtonProps: _ctx.closeButtonProps,
              unstyled: _ctx.unstyled,
              onClose: _cache[0] || (_cache[0] = function ($event) {
                return $options.remove($event);
              }),
              pt: _ctx.pt
            }, null, 8, ["message", "templates", "closeIcon", "infoIcon", "warnIcon", "errorIcon", "successIcon", "closeButtonProps", "unstyled", "pt"]);
          }), 128))];
        }),
        _: 1
      }, 16, ["onEnter", "onLeave"])], 16, _hoisted_1)];
    }),
    _: 1
  });
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
