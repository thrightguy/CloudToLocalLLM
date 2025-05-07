import { cn } from '@primeuix/utils';
import { mergeProps, createElementBlock, openBlock } from 'vue';
import BaseInput from '@primevue/core/baseinput';
import TextareaStyle from 'primevue/textarea/style';

var script$1 = {
  name: 'BaseTextarea',
  "extends": BaseInput,
  props: {
    autoResize: Boolean
  },
  style: TextareaStyle,
  provide: function provide() {
    return {
      $pcTextarea: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Textarea',
  "extends": script$1,
  inheritAttrs: false,
  observer: null,
  mounted: function mounted() {
    var _this = this;
    if (this.autoResize) {
      this.observer = new ResizeObserver(function () {
        // Firefox has issues without the requestAnimationFrame - ResizeObserver loop completed with undelivered notifications.
        requestAnimationFrame(function () {
          _this.resize();
        });
      });
      this.observer.observe(this.$el);
    }
  },
  updated: function updated() {
    if (this.autoResize) {
      this.resize();
    }
  },
  beforeUnmount: function beforeUnmount() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },
  methods: {
    resize: function resize() {
      if (!this.$el.offsetParent) return;
      this.$el.style.height = 'auto';
      this.$el.style.height = this.$el.scrollHeight + 'px';
      if (parseFloat(this.$el.style.height) >= parseFloat(this.$el.style.maxHeight)) {
        this.$el.style.overflowY = 'scroll';
        this.$el.style.height = this.$el.style.maxHeight;
      } else {
        this.$el.style.overflow = 'hidden';
      }
    },
    onInput: function onInput(event) {
      if (this.autoResize) {
        this.resize();
      }
      this.writeValue(event.target.value, event);
    }
  },
  computed: {
    attrs: function attrs() {
      return mergeProps(this.ptmi('root', {
        context: {
          filled: this.$filled,
          disabled: this.disabled
        }
      }), this.formField);
    },
    dataP: function dataP() {
      return cn(_defineProperty({
        invalid: this.$invalid,
        fluid: this.$fluid,
        filled: this.$variant === 'filled'
      }, this.size, this.size));
    }
  }
};

var _hoisted_1 = ["value", "name", "disabled", "aria-invalid", "data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("textarea", mergeProps({
    "class": _ctx.cx('root'),
    value: _ctx.d_value,
    name: _ctx.name,
    disabled: _ctx.disabled,
    "aria-invalid": _ctx.invalid || undefined,
    "data-p": $options.dataP,
    onInput: _cache[0] || (_cache[0] = function () {
      return $options.onInput && $options.onInput.apply($options, arguments);
    })
  }, $options.attrs), null, 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
