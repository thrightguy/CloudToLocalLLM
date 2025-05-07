import { isClient } from '@primeuix/utils/dom';
import { renderSlot, createBlock, createCommentVNode, openBlock, Teleport } from 'vue';

var script = {
  name: 'Portal',
  props: {
    appendTo: {
      type: [String, Object],
      "default": 'body'
    },
    disabled: {
      type: Boolean,
      "default": false
    }
  },
  data: function data() {
    return {
      mounted: false
    };
  },
  mounted: function mounted() {
    this.mounted = isClient();
  },
  computed: {
    inline: function inline() {
      return this.disabled || this.appendTo === 'self';
    }
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return $options.inline ? renderSlot(_ctx.$slots, "default", {
    key: 0
  }) : $data.mounted ? (openBlock(), createBlock(Teleport, {
    key: 1,
    to: $props.appendTo
  }, [renderSlot(_ctx.$slots, "default")], 8, ["to"])) : createCommentVNode("", true);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
