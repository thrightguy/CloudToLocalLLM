import { cn } from '@primeuix/utils';
import MinusIcon from '@primevue/icons/minus';
import PlusIcon from '@primevue/icons/plus';
import Button from 'primevue/button';
import Ripple from 'primevue/ripple';
import BaseComponent from '@primevue/core/basecomponent';
import PanelStyle from 'primevue/panel/style';
import { resolveComponent, createElementBlock, openBlock, mergeProps, createElementVNode, createVNode, renderSlot, normalizeClass, createCommentVNode, toDisplayString, withCtx, createBlock, resolveDynamicComponent, Transition, withDirectives, vShow } from 'vue';

var script$1 = {
  name: 'BasePanel',
  "extends": BaseComponent,
  props: {
    header: String,
    toggleable: Boolean,
    collapsed: Boolean,
    toggleButtonProps: {
      type: Object,
      "default": function _default() {
        return {
          severity: 'secondary',
          text: true,
          rounded: true
        };
      }
    }
  },
  style: PanelStyle,
  provide: function provide() {
    return {
      $pcPanel: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'Panel',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['update:collapsed', 'toggle'],
  data: function data() {
    return {
      d_collapsed: this.collapsed
    };
  },
  watch: {
    collapsed: function collapsed(newValue) {
      this.d_collapsed = newValue;
    }
  },
  methods: {
    toggle: function toggle(event) {
      this.d_collapsed = !this.d_collapsed;
      this.$emit('update:collapsed', this.d_collapsed);
      this.$emit('toggle', {
        originalEvent: event,
        value: this.d_collapsed
      });
    },
    onKeyDown: function onKeyDown(event) {
      if (event.code === 'Enter' || event.code === 'NumpadEnter' || event.code === 'Space') {
        this.toggle(event);
        event.preventDefault();
      }
    }
  },
  computed: {
    buttonAriaLabel: function buttonAriaLabel() {
      return this.toggleButtonProps && this.toggleButtonProps.ariaLabel ? this.toggleButtonProps.ariaLabel : this.header;
    },
    dataP: function dataP() {
      return cn({
        toggleable: this.toggleable
      });
    }
  },
  components: {
    PlusIcon: PlusIcon,
    MinusIcon: MinusIcon,
    Button: Button
  },
  directives: {
    ripple: Ripple
  }
};

var _hoisted_1 = ["data-p"];
var _hoisted_2 = ["data-p"];
var _hoisted_3 = ["id"];
var _hoisted_4 = ["id", "aria-labelledby"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_Button = resolveComponent("Button");
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    "data-p": $options.dataP
  }, _ctx.ptmi('root')), [createElementVNode("div", mergeProps({
    "class": _ctx.cx('header'),
    "data-p": $options.dataP
  }, _ctx.ptm('header')), [renderSlot(_ctx.$slots, "header", {
    id: _ctx.$id + '_header',
    "class": normalizeClass(_ctx.cx('title'))
  }, function () {
    return [_ctx.header ? (openBlock(), createElementBlock("span", mergeProps({
      key: 0,
      id: _ctx.$id + '_header',
      "class": _ctx.cx('title')
    }, _ctx.ptm('title')), toDisplayString(_ctx.header), 17, _hoisted_3)) : createCommentVNode("", true)];
  }), createElementVNode("div", mergeProps({
    "class": _ctx.cx('headerActions')
  }, _ctx.ptm('headerActions')), [renderSlot(_ctx.$slots, "icons"), _ctx.toggleable ? renderSlot(_ctx.$slots, "togglebutton", {
    key: 0,
    collapsed: $data.d_collapsed,
    toggleCallback: function toggleCallback(event) {
      return $options.toggle(event);
    },
    keydownCallback: function keydownCallback(event) {
      return $options.onKeyDown(event);
    }
  }, function () {
    return [createVNode(_component_Button, mergeProps({
      id: _ctx.$id + '_header',
      "class": _ctx.cx('pcToggleButton'),
      "aria-label": $options.buttonAriaLabel,
      "aria-controls": _ctx.$id + '_content',
      "aria-expanded": !$data.d_collapsed,
      unstyled: _ctx.unstyled,
      onClick: _cache[0] || (_cache[0] = function ($event) {
        return $options.toggle(_ctx.event);
      }),
      onKeydown: _cache[1] || (_cache[1] = function ($event) {
        return $options.onKeyDown(_ctx.event);
      })
    }, _ctx.toggleButtonProps, {
      pt: _ctx.ptm('pcToggleButton')
    }), {
      icon: withCtx(function (slotProps) {
        return [renderSlot(_ctx.$slots, _ctx.$slots.toggleicon ? 'toggleicon' : 'togglericon', {
          collapsed: $data.d_collapsed
        }, function () {
          return [(openBlock(), createBlock(resolveDynamicComponent($data.d_collapsed ? 'PlusIcon' : 'MinusIcon'), mergeProps({
            "class": slotProps["class"]
          }, _ctx.ptm('pcToggleButton')['icon']), null, 16, ["class"]))];
        })];
      }),
      _: 3
    }, 16, ["id", "class", "aria-label", "aria-controls", "aria-expanded", "unstyled", "pt"])];
  }) : createCommentVNode("", true)], 16)], 16, _hoisted_2), createVNode(Transition, mergeProps({
    name: "p-toggleable-content"
  }, _ctx.ptm('transition')), {
    "default": withCtx(function () {
      return [withDirectives(createElementVNode("div", mergeProps({
        id: _ctx.$id + '_content',
        "class": _ctx.cx('contentContainer'),
        role: "region",
        "aria-labelledby": _ctx.$id + '_header'
      }, _ctx.ptm('contentContainer')), [createElementVNode("div", mergeProps({
        "class": _ctx.cx('content')
      }, _ctx.ptm('content')), [renderSlot(_ctx.$slots, "default")], 16), _ctx.$slots.footer ? (openBlock(), createElementBlock("div", mergeProps({
        key: 0,
        "class": _ctx.cx('footer')
      }, _ctx.ptm('footer')), [renderSlot(_ctx.$slots, "footer")], 16)) : createCommentVNode("", true)], 16, _hoisted_4), [[vShow, !$data.d_collapsed]])];
    }),
    _: 3
  }, 16)], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
