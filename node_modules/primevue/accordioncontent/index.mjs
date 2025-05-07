import { mergeProps, createBlock, renderSlot, openBlock, Transition, withCtx, withDirectives, createCommentVNode, resolveDynamicComponent, createElementVNode, vShow, normalizeClass } from 'vue';
import BaseComponent from '@primevue/core/basecomponent';
import AccordionContentStyle from 'primevue/accordioncontent/style';

var script$1 = {
  name: 'BaseAccordionContent',
  "extends": BaseComponent,
  props: {
    as: {
      type: [String, Object],
      "default": 'DIV'
    },
    asChild: {
      type: Boolean,
      "default": false
    }
  },
  style: AccordionContentStyle,
  provide: function provide() {
    return {
      $pcAccordionContent: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'AccordionContent',
  "extends": script$1,
  inheritAttrs: false,
  inject: ['$pcAccordion', '$pcAccordionPanel'],
  computed: {
    id: function id() {
      return "".concat(this.$pcAccordion.id, "_accordioncontent_").concat(this.$pcAccordionPanel.value);
    },
    ariaLabelledby: function ariaLabelledby() {
      return "".concat(this.$pcAccordion.id, "_accordionheader_").concat(this.$pcAccordionPanel.value);
    },
    attrs: function attrs() {
      return mergeProps(this.a11yAttrs, this.ptmi('root', this.ptParams));
    },
    a11yAttrs: function a11yAttrs() {
      return {
        id: this.id,
        role: 'region',
        'aria-labelledby': this.ariaLabelledby,
        'data-pc-name': 'accordioncontent',
        'data-p-active': this.$pcAccordionPanel.active
      };
    },
    ptParams: function ptParams() {
      return {
        context: {
          active: this.$pcAccordionPanel.active
        }
      };
    }
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return !_ctx.asChild ? (openBlock(), createBlock(Transition, mergeProps({
    key: 0,
    name: "p-toggleable-content"
  }, _ctx.ptm('transition', $options.ptParams)), {
    "default": withCtx(function () {
      return [($options.$pcAccordion.lazy ? $options.$pcAccordionPanel.active : true) ? withDirectives((openBlock(), createBlock(resolveDynamicComponent(_ctx.as), mergeProps({
        key: 0,
        "class": _ctx.cx('root')
      }, $options.attrs), {
        "default": withCtx(function () {
          return [createElementVNode("div", mergeProps({
            "class": _ctx.cx('content')
          }, _ctx.ptm('content', $options.ptParams)), [renderSlot(_ctx.$slots, "default")], 16)];
        }),
        _: 3
      }, 16, ["class"])), [[vShow, $options.$pcAccordion.lazy ? true : $options.$pcAccordionPanel.active]]) : createCommentVNode("", true)];
    }),
    _: 3
  }, 16)) : renderSlot(_ctx.$slots, "default", {
    key: 1,
    "class": normalizeClass(_ctx.cx('root')),
    active: $options.$pcAccordionPanel.active,
    a11yAttrs: $options.a11yAttrs
  });
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
