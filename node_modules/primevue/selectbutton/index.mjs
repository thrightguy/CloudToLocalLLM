import { cn } from '@primeuix/utils';
import { equals, resolveFieldData } from '@primeuix/utils/object';
import Ripple from 'primevue/ripple';
import ToggleButton from 'primevue/togglebutton';
import BaseEditableHolder from '@primevue/core/baseeditableholder';
import SelectButtonStyle from 'primevue/selectbutton/style';
import { resolveComponent, createElementBlock, openBlock, mergeProps, Fragment, renderList, createBlock, createSlots, withCtx, renderSlot, createElementVNode, toDisplayString } from 'vue';

var script$1 = {
  name: 'BaseSelectButton',
  "extends": BaseEditableHolder,
  props: {
    options: Array,
    optionLabel: null,
    optionValue: null,
    optionDisabled: null,
    multiple: Boolean,
    allowEmpty: {
      type: Boolean,
      "default": true
    },
    dataKey: null,
    ariaLabelledby: {
      type: String,
      "default": null
    },
    size: {
      type: String,
      "default": null
    }
  },
  style: SelectButtonStyle,
  provide: function provide() {
    return {
      $pcSelectButton: this,
      $parentInstance: this
    };
  }
};

function _createForOfIteratorHelper(r, e) { var t = "undefined" != typeof Symbol && r[Symbol.iterator] || r["@@iterator"]; if (!t) { if (Array.isArray(r) || (t = _unsupportedIterableToArray(r)) || e) { t && (r = t); var _n = 0, F = function F() {}; return { s: F, n: function n() { return _n >= r.length ? { done: true } : { done: false, value: r[_n++] }; }, e: function e(r) { throw r; }, f: F }; } throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); } var o, a = true, u = false; return { s: function s() { t = t.call(r); }, n: function n() { var r = t.next(); return a = r.done, r; }, e: function e(r) { u = true, o = r; }, f: function f() { try { a || null == t["return"] || t["return"](); } finally { if (u) throw o; } } }; }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
var script = {
  name: 'SelectButton',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['change'],
  methods: {
    getOptionLabel: function getOptionLabel(option) {
      return this.optionLabel ? resolveFieldData(option, this.optionLabel) : option;
    },
    getOptionValue: function getOptionValue(option) {
      return this.optionValue ? resolveFieldData(option, this.optionValue) : option;
    },
    getOptionRenderKey: function getOptionRenderKey(option) {
      return this.dataKey ? resolveFieldData(option, this.dataKey) : this.getOptionLabel(option);
    },
    isOptionDisabled: function isOptionDisabled(option) {
      return this.optionDisabled ? resolveFieldData(option, this.optionDisabled) : false;
    },
    isOptionReadonly: function isOptionReadonly(option) {
      if (this.allowEmpty) return false;
      var selected = this.isSelected(option);
      if (this.multiple) {
        return selected && this.d_value.length === 1;
      } else {
        return selected;
      }
    },
    onOptionSelect: function onOptionSelect(event, option, index) {
      var _this = this;
      if (this.disabled || this.isOptionDisabled(option) || this.isOptionReadonly(option)) {
        return;
      }
      var selected = this.isSelected(option);
      var optionValue = this.getOptionValue(option);
      var newValue;
      if (this.multiple) {
        if (selected) {
          newValue = this.d_value.filter(function (val) {
            return !equals(val, optionValue, _this.equalityKey);
          });
          if (!this.allowEmpty && newValue.length === 0) return;
        } else {
          newValue = this.d_value ? [].concat(_toConsumableArray(this.d_value), [optionValue]) : [optionValue];
        }
      } else {
        if (selected && !this.allowEmpty) return;
        newValue = selected ? null : optionValue;
      }
      this.writeValue(newValue, event);
      this.$emit('change', {
        event: event,
        value: newValue
      });
    },
    isSelected: function isSelected(option) {
      var selected = false;
      var optionValue = this.getOptionValue(option);
      if (this.multiple) {
        if (this.d_value) {
          var _iterator = _createForOfIteratorHelper(this.d_value),
            _step;
          try {
            for (_iterator.s(); !(_step = _iterator.n()).done;) {
              var val = _step.value;
              if (equals(val, optionValue, this.equalityKey)) {
                selected = true;
                break;
              }
            }
          } catch (err) {
            _iterator.e(err);
          } finally {
            _iterator.f();
          }
        }
      } else {
        selected = equals(this.d_value, optionValue, this.equalityKey);
      }
      return selected;
    }
  },
  computed: {
    equalityKey: function equalityKey() {
      return this.optionValue ? null : this.dataKey;
    },
    dataP: function dataP() {
      return cn({
        invalid: this.$invalid
      });
    }
  },
  directives: {
    ripple: Ripple
  },
  components: {
    ToggleButton: ToggleButton
  }
};

var _hoisted_1 = ["aria-labelledby", "data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_ToggleButton = resolveComponent("ToggleButton");
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root'),
    role: "group",
    "aria-labelledby": _ctx.ariaLabelledby
  }, _ctx.ptmi('root'), {
    "data-p": $options.dataP
  }), [(openBlock(true), createElementBlock(Fragment, null, renderList(_ctx.options, function (option, index) {
    return openBlock(), createBlock(_component_ToggleButton, {
      key: $options.getOptionRenderKey(option),
      modelValue: $options.isSelected(option),
      onLabel: $options.getOptionLabel(option),
      offLabel: $options.getOptionLabel(option),
      disabled: _ctx.disabled || $options.isOptionDisabled(option),
      unstyled: _ctx.unstyled,
      size: _ctx.size,
      readonly: $options.isOptionReadonly(option),
      onChange: function onChange($event) {
        return $options.onOptionSelect($event, option, index);
      },
      pt: _ctx.ptm('pcToggleButton')
    }, createSlots({
      _: 2
    }, [_ctx.$slots.option ? {
      name: "default",
      fn: withCtx(function () {
        return [renderSlot(_ctx.$slots, "option", {
          option: option,
          index: index
        }, function () {
          return [createElementVNode("span", mergeProps({
            ref_for: true
          }, _ctx.ptm('pcToggleButton')['label']), toDisplayString($options.getOptionLabel(option)), 17)];
        })];
      }),
      key: "0"
    } : undefined]), 1032, ["modelValue", "onLabel", "offLabel", "disabled", "unstyled", "size", "readonly", "onChange", "pt"]);
  }), 128))], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
