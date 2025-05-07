import { cn } from '@primeuix/utils';
import { isEmpty } from '@primeuix/utils/object';
import SpinnerIcon from '@primevue/icons/spinner';
import Badge from 'primevue/badge';
import Ripple from 'primevue/ripple';
import { mergeProps, resolveComponent, resolveDirective, withDirectives, renderSlot, createBlock, openBlock, resolveDynamicComponent, withCtx, createElementVNode, createCommentVNode, createElementBlock, toDisplayString, normalizeClass } from 'vue';
import BaseComponent from '@primevue/core/basecomponent';
import ButtonStyle from 'primevue/button/style';

var script$1 = {
  name: 'BaseButton',
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
    iconPos: {
      type: String,
      "default": 'left'
    },
    iconClass: {
      type: [String, Object],
      "default": null
    },
    badge: {
      type: String,
      "default": null
    },
    badgeClass: {
      type: [String, Object],
      "default": null
    },
    badgeSeverity: {
      type: String,
      "default": 'secondary'
    },
    loading: {
      type: Boolean,
      "default": false
    },
    loadingIcon: {
      type: String,
      "default": undefined
    },
    as: {
      type: [String, Object],
      "default": 'BUTTON'
    },
    asChild: {
      type: Boolean,
      "default": false
    },
    link: {
      type: Boolean,
      "default": false
    },
    severity: {
      type: String,
      "default": null
    },
    raised: {
      type: Boolean,
      "default": false
    },
    rounded: {
      type: Boolean,
      "default": false
    },
    text: {
      type: Boolean,
      "default": false
    },
    outlined: {
      type: Boolean,
      "default": false
    },
    size: {
      type: String,
      "default": null
    },
    variant: {
      type: String,
      "default": null
    },
    plain: {
      type: Boolean,
      "default": false
    },
    fluid: {
      type: Boolean,
      "default": null
    }
  },
  style: ButtonStyle,
  provide: function provide() {
    return {
      $pcButton: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Button',
  "extends": script$1,
  inheritAttrs: false,
  inject: {
    $pcFluid: {
      "default": null
    }
  },
  methods: {
    getPTOptions: function getPTOptions(key) {
      var _ptm = key === 'root' ? this.ptmi : this.ptm;
      return _ptm(key, {
        context: {
          disabled: this.disabled
        }
      });
    }
  },
  computed: {
    disabled: function disabled() {
      return this.$attrs.disabled || this.$attrs.disabled === '' || this.loading;
    },
    defaultAriaLabel: function defaultAriaLabel() {
      return this.label ? this.label + (this.badge ? ' ' + this.badge : '') : this.$attrs.ariaLabel;
    },
    hasIcon: function hasIcon() {
      return this.icon || this.$slots.icon;
    },
    attrs: function attrs() {
      return mergeProps(this.asAttrs, this.a11yAttrs, this.getPTOptions('root'));
    },
    asAttrs: function asAttrs() {
      return this.as === 'BUTTON' ? {
        type: 'button',
        disabled: this.disabled
      } : undefined;
    },
    a11yAttrs: function a11yAttrs() {
      return {
        'aria-label': this.defaultAriaLabel,
        'data-pc-name': 'button',
        'data-p-disabled': this.disabled,
        'data-p-severity': this.severity
      };
    },
    hasFluid: function hasFluid() {
      return isEmpty(this.fluid) ? !!this.$pcFluid : this.fluid;
    },
    dataP: function dataP() {
      return cn(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty(_defineProperty({}, this.size, this.size), 'icon-only', this.hasIcon && !this.label && !this.badge), "loading", this.loading), "fluid", this.hasFluid), "rounded", this.rounded), "raised", this.raised), "outlined", this.outlined || this.variant === 'outlined'), "text", this.text || this.variant === 'text'), "link", this.link || this.variant === 'link'), "vertical", (this.iconPos === 'top' || this.iconPos === 'bottom') && this.label));
    },
    dataIconP: function dataIconP() {
      return cn(_defineProperty(_defineProperty({}, this.iconPos, this.iconPos), this.size, this.size));
    },
    dataLabelP: function dataLabelP() {
      return cn(_defineProperty(_defineProperty({}, this.size, this.size), 'icon-only', this.hasIcon && !this.label && !this.badge));
    }
  },
  components: {
    SpinnerIcon: SpinnerIcon,
    Badge: Badge
  },
  directives: {
    ripple: Ripple
  }
};

var _hoisted_1 = ["data-p"];
var _hoisted_2 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_SpinnerIcon = resolveComponent("SpinnerIcon");
  var _component_Badge = resolveComponent("Badge");
  var _directive_ripple = resolveDirective("ripple");
  return !_ctx.asChild ? withDirectives((openBlock(), createBlock(resolveDynamicComponent(_ctx.as), mergeProps({
    key: 0,
    "class": _ctx.cx('root'),
    "data-p": $options.dataP
  }, $options.attrs), {
    "default": withCtx(function () {
      return [renderSlot(_ctx.$slots, "default", {}, function () {
        return [_ctx.loading ? renderSlot(_ctx.$slots, "loadingicon", mergeProps({
          key: 0,
          "class": [_ctx.cx('loadingIcon'), _ctx.cx('icon')]
        }, _ctx.ptm('loadingIcon')), function () {
          return [_ctx.loadingIcon ? (openBlock(), createElementBlock("span", mergeProps({
            key: 0,
            "class": [_ctx.cx('loadingIcon'), _ctx.cx('icon'), _ctx.loadingIcon]
          }, _ctx.ptm('loadingIcon')), null, 16)) : (openBlock(), createBlock(_component_SpinnerIcon, mergeProps({
            key: 1,
            "class": [_ctx.cx('loadingIcon'), _ctx.cx('icon')],
            spin: ""
          }, _ctx.ptm('loadingIcon')), null, 16, ["class"]))];
        }) : renderSlot(_ctx.$slots, "icon", mergeProps({
          key: 1,
          "class": [_ctx.cx('icon')]
        }, _ctx.ptm('icon')), function () {
          return [_ctx.icon ? (openBlock(), createElementBlock("span", mergeProps({
            key: 0,
            "class": [_ctx.cx('icon'), _ctx.icon, _ctx.iconClass],
            "data-p": $options.dataIconP
          }, _ctx.ptm('icon')), null, 16, _hoisted_1)) : createCommentVNode("", true)];
        }), createElementVNode("span", mergeProps({
          "class": _ctx.cx('label')
        }, _ctx.ptm('label'), {
          "data-p": $options.dataLabelP
        }), toDisplayString(_ctx.label || ' '), 17, _hoisted_2), _ctx.badge ? (openBlock(), createBlock(_component_Badge, {
          key: 2,
          value: _ctx.badge,
          "class": normalizeClass(_ctx.badgeClass),
          severity: _ctx.badgeSeverity,
          unstyled: _ctx.unstyled,
          pt: _ctx.ptm('pcBadge')
        }, null, 8, ["value", "class", "severity", "unstyled", "pt"])) : createCommentVNode("", true)];
      })];
    }),
    _: 3
  }, 16, ["class", "data-p"])), [[_directive_ripple]]) : renderSlot(_ctx.$slots, "default", {
    key: 1,
    "class": normalizeClass(_ctx.cx('root')),
    a11yAttrs: $options.a11yAttrs
  });
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
