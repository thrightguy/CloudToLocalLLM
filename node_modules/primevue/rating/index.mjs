import { cn } from '@primeuix/utils';
import { getFirstFocusableElement, focus } from '@primeuix/utils/dom';
import BanIcon from '@primevue/icons/ban';
import StarIcon from '@primevue/icons/star';
import StarFillIcon from '@primevue/icons/starfill';
import BaseEditableHolder from '@primevue/core/baseeditableholder';
import RatingStyle from 'primevue/rating/style';
import { createElementBlock, openBlock, mergeProps, Fragment, renderList, createElementVNode, renderSlot, normalizeClass, createBlock, resolveDynamicComponent } from 'vue';

var script$1 = {
  name: 'BaseRating',
  "extends": BaseEditableHolder,
  props: {
    readonly: {
      type: Boolean,
      "default": false
    },
    stars: {
      type: Number,
      "default": 5
    },
    onIcon: {
      type: String,
      "default": undefined
    },
    offIcon: {
      type: String,
      "default": undefined
    }
  },
  style: RatingStyle,
  provide: function provide() {
    return {
      $pcRating: this,
      $parentInstance: this
    };
  }
};

var script = {
  name: 'Rating',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['change', 'focus', 'blur'],
  data: function data() {
    return {
      focusedOptionIndex: -1,
      isFocusVisibleItem: true
    };
  },
  methods: {
    getPTOptions: function getPTOptions(key, value) {
      return this.ptm(key, {
        context: {
          active: value <= this.d_value,
          focused: value === this.focusedOptionIndex
        }
      });
    },
    onOptionClick: function onOptionClick(event, value) {
      if (!this.readonly && !this.disabled) {
        this.onOptionSelect(event, value);
        this.isFocusVisibleItem = false;
        var firstFocusableEl = getFirstFocusableElement(event.currentTarget);
        firstFocusableEl && focus(firstFocusableEl);
      }
    },
    onFocus: function onFocus(event, value) {
      var _event$sourceCapabili;
      this.focusedOptionIndex = value;
      this.isFocusVisibleItem = ((_event$sourceCapabili = event.sourceCapabilities) === null || _event$sourceCapabili === void 0 ? void 0 : _event$sourceCapabili.firesTouchEvents) === false;
      this.$emit('focus', event);
    },
    onBlur: function onBlur(event) {
      var _this$formField$onBlu, _this$formField;
      this.focusedOptionIndex = -1;
      this.$emit('blur', event);
      (_this$formField$onBlu = (_this$formField = this.formField).onBlur) === null || _this$formField$onBlu === void 0 || _this$formField$onBlu.call(_this$formField);
    },
    onChange: function onChange(event, value) {
      this.onOptionSelect(event, value);
      this.isFocusVisibleItem = true;
    },
    onOptionSelect: function onOptionSelect(event, value) {
      if (this.focusedOptionIndex === value || this.d_value === value) {
        this.focusedOptionIndex = -1;
        this.updateModel(event, null);
      } else {
        this.focusedOptionIndex = value;
        this.updateModel(event, value || null);
      }
    },
    updateModel: function updateModel(event, value) {
      this.writeValue(value, event);
      this.$emit('change', {
        originalEvent: event,
        value: value
      });
    },
    starAriaLabel: function starAriaLabel(value) {
      return value === 1 ? this.$primevue.config.locale.aria.star : this.$primevue.config.locale.aria.stars.replace(/{star}/g, value);
    },
    dataOption: function dataOption(value) {
      return cn({
        readonly: this.readonly,
        disabled: this.disabled,
        active: value <= this.d_value,
        'focus-visible': value === this.focusedOptionIndex && this.isFocusVisibleItem
      });
    }
  },
  computed: {
    namex: function namex() {
      return this.name || "".concat(this.$attrSelector, "_name");
    },
    dataP: function dataP() {
      return cn({
        readonly: this.readonly,
        disabled: this.disabled
      });
    }
  },
  components: {
    StarFillIcon: StarFillIcon,
    StarIcon: StarIcon,
    BanIcon: BanIcon
  }
};

var _hoisted_1 = ["data-p"];
var _hoisted_2 = ["onClick", "data-p-active", "data-p-focused", "data-p"];
var _hoisted_3 = ["value", "name", "checked", "disabled", "readonly", "aria-label", "onFocus", "onChange"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root'), {
    "data-p": $options.dataP
  }), [(openBlock(true), createElementBlock(Fragment, null, renderList(_ctx.stars, function (value) {
    return openBlock(), createElementBlock("div", mergeProps({
      key: value,
      "class": _ctx.cx('option', {
        value: value
      }),
      onClick: function onClick($event) {
        return $options.onOptionClick($event, value);
      },
      ref_for: true
    }, $options.getPTOptions('option', value), {
      "data-p-active": value <= _ctx.d_value,
      "data-p-focused": value === $data.focusedOptionIndex,
      "data-p": $options.dataOption(value)
    }), [createElementVNode("span", mergeProps({
      "class": "p-hidden-accessible",
      ref_for: true
    }, _ctx.ptm('hiddenOptionInputContainer'), {
      "data-p-hidden-accessible": true
    }), [createElementVNode("input", mergeProps({
      type: "radio",
      value: value,
      name: $options.namex,
      checked: _ctx.d_value === value,
      disabled: _ctx.disabled,
      readonly: _ctx.readonly,
      "aria-label": $options.starAriaLabel(value),
      onFocus: function onFocus($event) {
        return $options.onFocus($event, value);
      },
      onBlur: _cache[0] || (_cache[0] = function () {
        return $options.onBlur && $options.onBlur.apply($options, arguments);
      }),
      onChange: function onChange($event) {
        return $options.onChange($event, value);
      },
      ref_for: true
    }, _ctx.ptm('hiddenOptionInput')), null, 16, _hoisted_3)], 16), value <= _ctx.d_value ? renderSlot(_ctx.$slots, "onicon", {
      key: 0,
      value: value,
      "class": normalizeClass(_ctx.cx('onIcon'))
    }, function () {
      return [(openBlock(), createBlock(resolveDynamicComponent(_ctx.onIcon ? 'span' : 'StarFillIcon'), mergeProps({
        "class": [_ctx.cx('onIcon'), _ctx.onIcon],
        ref_for: true
      }, _ctx.ptm('onIcon')), null, 16, ["class"]))];
    }) : renderSlot(_ctx.$slots, "officon", {
      key: 1,
      value: value,
      "class": normalizeClass(_ctx.cx('offIcon'))
    }, function () {
      return [(openBlock(), createBlock(resolveDynamicComponent(_ctx.offIcon ? 'span' : 'StarIcon'), mergeProps({
        "class": [_ctx.cx('offIcon'), _ctx.offIcon],
        ref_for: true
      }, _ctx.ptm('offIcon')), null, 16, ["class"]))];
    })], 16, _hoisted_2);
  }), 128))], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
